import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/network/innertube/innertube_client.dart';
import '../data/network/yt/stream_client_utils.dart';

/// Servidor proxy HTTP local (loopback) para reproducir streams de YouTube en just_audio / ExoPlayer.
///
/// Resuelve el error HTTP 403 Forbidden que produce ExoPlayer en Android al ignorar
/// cabeceras requeridas de GoogleVideo o al solicitar streams con rangos abiertos no admitidos.
/// Implementa streaming HTTP 206 Partial Content y segmenta las peticiones remotas en bloques seguros de 512 KB.
///
/// Nota crítica (medida empíricamente): googlevideo entrega ~31 KB/s si la petición NO
/// trae header `Range` (throttle) pero 6–8 MB/s si lo trae. Por eso TODAS las peticiones
/// upstream de este proxy llevan `Range` (los streams de googlevideo siempre traen `clen`
/// en la URL, por lo que se usa siempre la rama segmentada).
class LocalStreamProxy {
  static final LocalStreamProxy instance = LocalStreamProxy._internal();
  LocalStreamProxy._internal();

  HttpServer? _server;
  int get port => _server?.port ?? 0;
  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 20;

  bool get isRunning => _server != null;

  /// Inicia el servidor loopback en un puerto aleatorio disponible si aún no está iniciado.
  Future<void> ensureStarted() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      debugPrint('[LocalStreamProxy] Servidor proxy activo en http://127.0.0.1:$port');
      _server!.listen(_handleIncomingRequest, onError: (e) {
        debugPrint('[LocalStreamProxy] Error en listener del servidor: $e');
      });
    } catch (e) {
      debugPrint('[LocalStreamProxy] Error al vincular socket: $e');
    }
  }

  /// Versión asincrónica sin carrera: espera a que el servidor esté activo y
  /// lanza [StateError] si no está disponible (nunca debe devolver la URL
  /// directa de googlevideo: sin `Range` el stream va throttleado a ~31 KB/s).
  Future<String> getProxyUrlAsync(String originalUrl) async {
    try {
      final uri = Uri.parse(originalUrl);
      if (!StreamClientUtils.isYouTubeMediaHost(uri.host)) {
        return originalUrl;
      }
      await ensureStarted();
      final server = _server;
      if (server == null) {
        throw StateError('Proxy local no disponible (bind falló)');
      }
      return 'http://127.0.0.1:${server.port}/stream?url=${Uri.encodeComponent(originalUrl)}';
    } catch (e) {
      throw StateError('Proxy local no disponible: $e');
    }
  }

  Future<void> _handleIncomingRequest(HttpRequest request) async {
    final uri = request.uri;
    if (uri.path != '/stream') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final originalUrl = uri.queryParameters['url'];
    if (originalUrl == null || originalUrl.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    try {
      final targetUri = Uri.parse(originalUrl);
      var clenStr = targetUri.queryParameters['clen'];
      var clen = int.tryParse(clenStr ?? '');

      final profile = StreamClientUtils.resolveRequestProfile(originalUrl);
      final cookie = InnerTubeClient.instance.cookie;

      // Si clen no está en la URL, probe con bytes=0-0 para obtener el tamaño total
      if (clen == null || clen <= 0) {
        try {
          final probeReq = await _httpClient.getUrl(targetUri);
          probeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
          probeReq.headers.set(HttpHeaders.userAgentHeader, profile.userAgent);
          if (profile.origin != null) probeReq.headers.set('Origin', profile.origin!);
          if (profile.referer != null) probeReq.headers.set('Referer', profile.referer!);
          if (cookie != null && cookie.isNotEmpty) {
            probeReq.headers.set(HttpHeaders.cookieHeader, cookie);
          }
          final probeResp = await probeReq.close();
          final cRange = probeResp.headers.value(HttpHeaders.contentRangeHeader);
          if (cRange != null && cRange.contains('/')) {
            final totalPart = cRange.split('/').last.trim();
            clen = int.tryParse(totalPart);
          }
          await probeResp.drain();
        } catch (e) {
          debugPrint('[LocalStreamProxy] probe de tamaño falló: $e');
        }
      }

      final clientRange = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int end = (clen != null && clen > 0) ? clen - 1 : 0;
      if (clientRange != null && clientRange.startsWith('bytes=')) {
        final rangeValue = clientRange.substring(6);
        final parts = rangeValue.split('-');
        if (parts[0].isNotEmpty) {
          start = int.tryParse(parts[0]) ?? 0;
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.tryParse(parts[1]) ?? end;
        }
      }

      if (clen != null && clen > 0 && end >= clen) {
        end = clen - 1;
      }

      // Si no fue posible determinar clen, hacer streaming directo pasante.
      // Nunca sin `Range` upstream: googlevideo throttlea a ~31 KB/s si no lo trae.
      if (clen == null || clen <= 0) {
        final upstreamRange = clientRange ?? 'bytes=0-';
        final upstreamReq = await _httpClient.getUrl(targetUri);
        upstreamReq.headers.set(HttpHeaders.rangeHeader, upstreamRange);
        upstreamReq.headers.set(HttpHeaders.userAgentHeader, profile.userAgent);
        if (profile.origin != null) upstreamReq.headers.set('Origin', profile.origin!);
        if (profile.referer != null) upstreamReq.headers.set('Referer', profile.referer!);
        if (cookie != null && cookie.isNotEmpty) {
          upstreamReq.headers.set(HttpHeaders.cookieHeader, cookie);
        }

        final upstreamResp = await upstreamReq.close();
        request.response.statusCode = upstreamResp.statusCode;
        upstreamResp.headers.forEach((name, values) {
          if (name.toLowerCase() != 'content-length' && name.toLowerCase() != 'content-range') {
            request.response.headers.set(name, values);
          }
        });
        final remoteClen = upstreamResp.headers.value(HttpHeaders.contentLengthHeader);
        final remoteCRange = upstreamResp.headers.value(HttpHeaders.contentRangeHeader);
        if (remoteClen != null) request.response.headers.set(HttpHeaders.contentLengthHeader, remoteClen);
        if (remoteCRange != null) request.response.headers.set(HttpHeaders.contentRangeHeader, remoteCRange);

        await request.response.addStream(upstreamResp);
        await request.response.close();
        return;
      }

      final totalToServe = end - start + 1;
      final isPartial = clientRange != null;
      request.response.statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok;
      final isWebm = originalUrl.contains('audio%2Fwebm') || originalUrl.contains('audio/webm');
      request.response.headers.set(HttpHeaders.contentTypeHeader, isWebm ? 'audio/webm' : 'audio/mp4');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (isPartial) {
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$clen');
      }
      request.response.headers.set(HttpHeaders.contentLengthHeader, totalToServe.toString());
      request.response.headers.set('Access-Control-Allow-Origin', '*');

      debugPrint('[LocalStreamProxy] petición: cliente Range=${clientRange ?? "(sin Range)"} '
          '→ sirviendo bytes $start-$end/$clen en bloques de 512 KB');

      // Segmentación en bloques de 512 KB para evitar el bloqueo HTTP 403 de GoogleVideo
      const chunkSize = 512 * 1024;
      int current = start;
      int servedBytes = 0;

      while (current <= end) {
        final chunkEnd = min(current + chunkSize - 1, end);
        final chunkRange = 'bytes=$current-$chunkEnd';

        final result = await _fetchChunkWithRetry(targetUri, chunkRange, profile, cookie);
        final upstreamResp = result.response;
        if (upstreamResp == null) {
          debugPrint('[LocalStreamProxy] chunk $chunkRange falló tras reintentos '
              '(${result.error}); servidos $servedBytes de $totalToServe bytes');
          // Fallo ruidoso: destruir el socket para que el reproductor reciba un
          // error (y dispare la recuperación de stream) en vez de un EOF ambiguo
          // que puede dejar a ExoPlayer en buffering silencioso.
          _abortResponse(request);
          return;
        }

        final sw = Stopwatch()..start();
        try {
          await for (final data in upstreamResp) {
            servedBytes += data.length;
            request.response.add(data);
          }
        } catch (e) {
          debugPrint('[LocalStreamProxy] chunk $chunkRange falló en lectura tras '
              '$servedBytes bytes servidos: $e');
          result.client?.close(force: true);
          _abortResponse(request);
          return;
        }
        result.client?.close(force: true);

        debugPrint('[LocalStreamProxy] chunk $chunkRange OK '
            '(${sw.elapsedMilliseconds} ms; total $servedBytes/$totalToServe bytes)');
        current = chunkEnd + 1;
      }

      debugPrint('[LocalStreamProxy] stream completo: $servedBytes bytes servidos');
      await request.response.close();
    } catch (e) {
      debugPrint('[LocalStreamProxy] Error manejando petición: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Aborta la respuesta destruyendo el socket: el cliente (ExoPlayer) recibe
  /// un error de conexión en vez de un final de stream ambiguo.
  void _abortResponse(HttpRequest request) {
    try {
      request.response.detachSocket(writeHeaders: false).then((socket) {
        socket.destroy();
      }).catchError((_) {});
    } catch (_) {}
  }

  /// Descarga un chunk con `Range` forzado, reintentando una vez con un
  /// [HttpClient] nuevo (conexión fresca) si el primer intento falla.
  Future<_ChunkResult> _fetchChunkWithRetry(
    Uri target,
    String chunkRange,
    StreamRequestProfile profile,
    String? cookie,
  ) async {
    Object? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12)
        ..idleTimeout = const Duration(seconds: 30);
      try {
        final req = await client.getUrl(target);
        req.headers.set(HttpHeaders.rangeHeader, chunkRange);
        req.headers.set(HttpHeaders.userAgentHeader, profile.userAgent);
        if (profile.origin != null) req.headers.set('Origin', profile.origin!);
        if (profile.referer != null) req.headers.set('Referer', profile.referer!);
        if (cookie != null && cookie.isNotEmpty) {
          req.headers.set(HttpHeaders.cookieHeader, cookie);
        }
        final resp = await req.close();
        if (resp.statusCode == HttpStatus.partialContent || resp.statusCode == HttpStatus.ok) {
          return _ChunkResult(response: resp, client: client);
        }
        lastError = 'HTTP ${resp.statusCode}';
        await resp.drain();
        client.close(force: true);
      } catch (e) {
        lastError = e;
        client.close(force: true);
      }
    }
    return _ChunkResult(error: lastError);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

class _ChunkResult {
  final HttpClientResponse? response;
  final HttpClient? client;
  final Object? error;

  _ChunkResult({this.response, this.client, this.error});
}
