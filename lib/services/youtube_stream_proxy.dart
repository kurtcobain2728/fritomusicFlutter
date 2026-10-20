import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class YouTubeStreamProxy {
  static final YouTubeStreamProxy instance = YouTubeStreamProxy._internal();
  YouTubeStreamProxy._internal();

  HttpServer? _server;
  final Map<String, _StreamSession> _sessions = {};

  Future<void> ensureInitialized() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest, onError: (_) {});
  }

  Future<Uri> registerStream({
    required String streamUrl,
    required String userAgent,
    int? contentLength,
    String mimeType = 'audio/mp4',
  }) async {
    await ensureInitialized();

    // Limpiamos sesiones antiguas para liberar RAM inmediatamente
    if (_sessions.length >= 2) {
      final oldestKey = _sessions.keys.first;
      _sessions.remove(oldestKey)?.dispose();
    }

    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final Uri parsedUri = Uri.parse(streamUrl);

    final int? inferredLength = contentLength ??
        int.tryParse(parsedUri.queryParameters['clen'] ?? '');
    final String? rawMime = parsedUri.queryParameters['mime'];
    final String effectiveMime = (rawMime != null && rawMime.isNotEmpty)
        ? Uri.decodeComponent(rawMime).split(';').first
        : mimeType;

    final session = _StreamSession(
      id: id,
      rawUrl: streamUrl,
      userAgent: userAgent,
      totalLength: inferredLength,
      mimeType: effectiveMime,
    );

    _sessions[id] = session;
    // Iniciamos la descarga por chunks de 512 KB en segundo plano de inmediato
    unawaited(session.startDownloading());

    return Uri.parse('http://127.0.0.1:${_server!.port}/stream/$id');
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final segments = req.uri.pathSegments;
      if (segments.length < 2 || segments[0] != 'stream') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }

      final session = _sessions[segments[1]];
      if (session == null) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }

      // Esperamos hasta que al menos los primeros bytes o el totalLength estén listos
      await session.waitForInitialHeader();

      int startByte = 0;
      int? endByte = session.totalLength != null ? session.totalLength! - 1 : null;

      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        startByte = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          endByte = int.tryParse(parts[1]);
        }
      }

      final int? totalLength = session.totalLength;

      req.response.bufferOutput = false;
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentTypeHeader, session.mimeType);
      req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      req.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      if (totalLength != null && totalLength > 0) {
        final int effectiveEnd = (endByte != null && endByte < totalLength)
            ? endByte
            : (totalLength - 1);
        if (startByte >= totalLength) {
          req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await req.response.close();
          return;
        }
        final int contentLen = (effectiveEnd - startByte) + 1;
        req.response.headers.set(HttpHeaders.contentLengthHeader, contentLen.toString());
        req.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $startByte-$effectiveEnd/$totalLength',
        );
        endByte = effectiveEnd;
      }

      if (req.method.toUpperCase() == 'HEAD') {
        await req.response.close();
        return;
      }

      // Si el usuario adelantó la canción a un punto que aún no se ha descargado,
      // servimos desde el buffer en cuanto llegue o abrimos lectura directa
      await session.streamRangeToResponse(req.response, startByte, endByte);
      await req.response.close();
    } catch (_) {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    for (final s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
    await _server?.close(force: true);
    _server = null;
  }
}

class _StreamSession {
  final String id;
  final String rawUrl;
  final String userAgent;
  int? totalLength;
  final String mimeType;

  static const int _chunkSize = 512 * 1024; // 512 KB por bloque

  final List<int> _buffer = <int>[];
  bool _isCompleted = false;
  bool _isDisposed = false;
  bool _hasFailed = false;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  final HttpClient _httpClient = HttpClient()
    ..idleTimeout = const Duration(seconds: 30)
    ..connectionTimeout = const Duration(seconds: 15);

  _StreamSession({
    required this.id,
    required this.rawUrl,
    required this.userAgent,
    required this.totalLength,
    required this.mimeType,
  });

  void _notifyWaiters() {
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) {
        waiter.complete();
      }
    }
    _waiters.clear();
  }

  Future<void> _waitForMoreData() {
    if (_isCompleted || _hasFailed || _isDisposed) {
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  Future<void> waitForInitialHeader() async {
    while (!_isDisposed && !_isCompleted && !_hasFailed && _buffer.isEmpty && totalLength == null) {
      await _waitForMoreData();
    }
  }

  /// Construye la URL con &range=start-end SIN re-codificar ni romper la firma de googlevideo.com
  Uri _buildChunkUri(String baseRawUrl, int start, int end) {
    String cleaned = baseRawUrl.replaceAll(RegExp(r'([?&])range=[^&]*'), '');
    final String sep = cleaned.contains('?') ? '&' : '?';
    return Uri.parse('$cleaned${sep}range=$start-$end');
  }

  /// Abre petición HTTP siguiendo manualmente redirects 302 para no perder el User-Agent ni Range
  Future<HttpClientResponse?> _openChunkRequest(
    String targetUrl,
    int start,
    int end, {
    required bool useQueryParamRange,
  }) async {
    Uri currentUri = useQueryParamRange
        ? _buildChunkUri(targetUrl, start, end)
        : Uri.parse(targetUrl);

    for (int redirectCount = 0; redirectCount < 5; redirectCount++) {
      final req = await _httpClient.getUrl(currentUri);
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, userAgent);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
      if (!useQueryParamRange) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      }

      final res = await req.close();
      if (res.statusCode == HttpStatus.movedPermanently ||
          res.statusCode == HttpStatus.found ||
          res.statusCode == HttpStatus.seeOther ||
          res.statusCode == HttpStatus.temporaryRedirect ||
          res.statusCode == HttpStatus.permanentRedirect) {
        final location = res.headers.value(HttpHeaders.locationHeader);
        await res.drain();
        if (location == null || location.isEmpty) return null;
        currentUri = currentUri.resolve(location);
        continue;
      }
      return res;
    }
    return null;
  }

  Future<void> startDownloading() async {
    int currentStart = 0;
    int retries = 0;

    while (!_isDisposed && (totalLength == null || currentStart < totalLength!)) {
      int currentEnd = currentStart + _chunkSize - 1;
      if (totalLength != null && currentEnd >= totalLength!) {
        currentEnd = totalLength! - 1;
      }

      try {
        // Intento 1: Usando parámetro &range=start-end en URL cruda (evita throttling de YouTube)
        HttpClientResponse? res = await _openChunkRequest(
          rawUrl,
          currentStart,
          currentEnd,
          useQueryParamRange: true,
        );

        // Intento 2 (Fallback): Usando cabecera HTTP Range: bytes=start-end
        if (res == null ||
            (res.statusCode != HttpStatus.ok && res.statusCode != HttpStatus.partialContent)) {
          await res?.drain();
          res = await _openChunkRequest(
            rawUrl,
            currentStart,
            currentEnd,
            useQueryParamRange: false,
          );
        }

        if (res == null ||
            (res.statusCode != HttpStatus.ok && res.statusCode != HttpStatus.partialContent)) {
          await res?.drain();
          retries++;
          if (retries > 3) {
            debugPrint('[YouTubeStreamProxy] Fallo definitivo en byte $currentStart');
            _hasFailed = true;
            _notifyWaiters();
            break;
          }
          await Future.delayed(Duration(milliseconds: 250 * retries));
          continue;
        }

        // Extraer totalLength desde Content-Range o Content-Length si aún no lo teníamos
        if (totalLength == null) {
          final contentRange = res.headers.value(HttpHeaders.contentRangeHeader);
          if (contentRange != null && contentRange.contains('/')) {
            final totalStr = contentRange.split('/').last;
            final parsedTotal = int.tryParse(totalStr);
            if (parsedTotal != null && parsedTotal > 0) {
              totalLength = parsedTotal;
            }
          } else if (res.statusCode == HttpStatus.ok && res.contentLength > 0 && currentStart == 0) {
            totalLength = res.contentLength;
          }
        }

        int receivedInChunk = 0;
        await for (final List<int> data in res) {
          if (_isDisposed) break;
          _buffer.addAll(data);
          receivedInChunk += data.length;
          _notifyWaiters();
        }

        if (receivedInChunk == 0) {
          // Fin real del stream
          totalLength ??= _buffer.length;
          _isCompleted = true;
          _notifyWaiters();
          break;
        }

        retries = 0;
        // IMPORTANTE: Avanzamos exactamente la cantidad de bytes recibidos (nunca romper si received < 512KB)
        currentStart += receivedInChunk;

        if (totalLength != null && currentStart >= totalLength!) {
          _isCompleted = true;
          _notifyWaiters();
          break;
        }
      } catch (e) {
        retries++;
        if (retries > 3) {
          _hasFailed = true;
          _notifyWaiters();
          break;
        }
        await Future.delayed(Duration(milliseconds: 250 * retries));
      }
    }

    _isCompleted = true;
    _notifyWaiters();
  }

  Future<void> streamRangeToResponse(
    HttpResponse response,
    int startByte,
    int? endByte,
  ) async {
    int cursor = startByte;
    const int writeBatchSize = 64 * 1024; // Entregar en bloques de 64 KB al socket local

    while (!_isDisposed) {
      final int? targetEnd = endByte ?? (totalLength != null ? totalLength! - 1 : null);
      if (targetEnd != null && cursor > targetEnd) {
        break;
      }

      if (cursor < _buffer.length) {
        int availableEnd = _buffer.length - 1;
        if (targetEnd != null && availableEnd > targetEnd) {
          availableEnd = targetEnd;
        }
        if (availableEnd - cursor + 1 > writeBatchSize) {
          availableEnd = cursor + writeBatchSize - 1;
        }

        final Uint8List slice = Uint8List.fromList(
          _buffer.sublist(cursor, availableEnd + 1),
        );
        response.add(slice);
        await response.flush();
        cursor = availableEnd + 1;
      } else if (_isCompleted || _hasFailed) {
        break;
      } else {
        await _waitForMoreData();
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _notifyWaiters();
    _buffer.clear();
    _httpClient.close(force: true);
  }
}
