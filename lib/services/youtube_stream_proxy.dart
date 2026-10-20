import 'dart:async';
import 'dart:io';

class YouTubeStreamProxy {
  static final YouTubeStreamProxy instance = YouTubeStreamProxy._internal();
  YouTubeStreamProxy._internal();

  HttpServer? _server;
  final HttpClient _httpClient = HttpClient()
    ..idleTimeout = const Duration(seconds: 30)
    ..connectionTimeout = const Duration(seconds: 15);

  final Map<String, _StreamSession> _sessions = {};

  // Bloques de 512 KB para evitar el estrangulamiento y corte de ~1 MiB (30-60s) de googlevideo.com
  static const int _chunkSize = 512 * 1024;

  Future<void> ensureInitialized() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handleRequest, onError: (_) {});
  }

  /// Registra una URL de googlevideo.com y devuelve una URI local (http://127.0.0.1:port/stream/id)
  Future<Uri> registerStream({
    required String streamUrl,
    required String userAgent,
    int? contentLength,
    String mimeType = 'audio/mp4',
  }) async {
    await ensureInitialized();

    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    if (_sessions.length > 8) {
      _sessions.remove(_sessions.keys.first);
    }

    // Intentamos extraer clen (contentLength) o mime directamente de la URL de googlevideo si no fueron provistos
    final parsedUri = Uri.parse(streamUrl);
    final int? inferredLength = contentLength ??
        int.tryParse(parsedUri.queryParameters['clen'] ?? '');
    final String? rawMime = parsedUri.queryParameters['mime'];
    final String effectiveMime = (rawMime != null && rawMime.isNotEmpty)
        ? Uri.decodeComponent(rawMime).split(';').first
        : mimeType;

    _sessions[id] = _StreamSession(
      uri: parsedUri,
      userAgent: userAgent,
      contentLength: inferredLength,
      mimeType: effectiveMime,
    );

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

      // 1. Parsear el rango solicitado por ExoPlayer / AVPlayer
      int startByte = 0;
      int? endByte = session.contentLength != null ? session.contentLength! - 1 : null;

      final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        startByte = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          endByte = int.tryParse(parts[1]);
        }
      }

      // 2. Si aún no tenemos contentLength, hacemos un probe rápido al servidor
      if (session.contentLength == null) {
        await _probeTotalLength(session);
        if (session.contentLength != null && endByte == null) {
          endByte = session.contentLength! - 1;
        }
      }

      final int? totalLength = session.contentLength;

      // 3. Configurar cabeceras de respuesta 206 Partial Content para soportar Seek (barra de progreso)
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentTypeHeader, session.mimeType);
      req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      req.response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');

      if (totalLength != null) {
        final int effectiveEnd = (endByte != null && endByte < totalLength)
            ? endByte
            : (totalLength - 1);
        final int contentLen = (effectiveEnd - startByte) + 1;
        req.response.headers.set(HttpHeaders.contentLengthHeader, contentLen.toString());
        req.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $startByte-$effectiveEnd/$totalLength',
        );
      }

      // Si el reproductor solo envió una petición HEAD para verificar metadatos, cerramos aquí
      if (req.method.toUpperCase() == 'HEAD') {
        await req.response.close();
        return;
      }

      // 4. Descargar de googlevideo.com en chunks cerrados de 512 KB e inyectarlos al reproductor
      int currentStart = startByte;
      final int? targetEnd = endByte ?? (totalLength != null ? totalLength - 1 : null);

      while (targetEnd == null || currentStart <= targetEnd) {
        int currentEnd = currentStart + _chunkSize - 1;
        if (targetEnd != null && currentEnd > targetEnd) {
          currentEnd = targetEnd;
        }

        // Enviamos el rango acotado mediante el parámetro &range=start-end en la URL de googlevideo.com
        // (evita el throttling y evita el bloqueo de 1 MiB de YouTube)
        final Map<String, String> queryParams = Map<String, String>.from(session.uri.queryParameters);
        queryParams['range'] = '$currentStart-$currentEnd';
        final Uri chunkUri = session.uri.replace(queryParameters: queryParams);

        final HttpClientRequest ytReq = await _httpClient.getUrl(chunkUri);
        ytReq.headers.set(HttpHeaders.userAgentHeader, session.userAgent);
        ytReq.headers.set(HttpHeaders.acceptHeader, '*/*');
        ytReq.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
        ytReq.headers.set('Origin', 'https://music.youtube.com');
        ytReq.headers.set('Referer', 'https://music.youtube.com/');

        final HttpClientResponse ytRes = await ytReq.close();

        // Si el servidor ignora el query param &range=, reintentamos con el header Range estándar
        if (ytRes.statusCode != HttpStatus.ok && ytRes.statusCode != HttpStatus.partialContent) {
          await ytRes.drain();
          final HttpClientRequest fallbackReq = await _httpClient.getUrl(session.uri);
          fallbackReq.headers.set(HttpHeaders.userAgentHeader, session.userAgent);
          fallbackReq.headers.set(HttpHeaders.rangeHeader, 'bytes=$currentStart-$currentEnd');
          fallbackReq.headers.set(HttpHeaders.acceptHeader, '*/*');
          final HttpClientResponse fallbackRes = await fallbackReq.close();

          if (fallbackRes.statusCode != HttpStatus.ok &&
              fallbackRes.statusCode != HttpStatus.partialContent) {
            await fallbackRes.drain();
            break;
          }

          int receivedFallback = 0;
          await for (final data in fallbackRes) {
            req.response.add(data);
            receivedFallback += data.length;
          }
          await req.response.flush();

          final int expected = (currentEnd - currentStart) + 1;
          if (receivedFallback < expected || receivedFallback == 0) break;
          currentStart = currentEnd + 1;
          continue;
        }

        int received = 0;
        await for (final data in ytRes) {
          req.response.add(data);
          received += data.length;
        }
        await req.response.flush();

        final int expected = (currentEnd - currentStart) + 1;
        if (received < expected || received == 0) {
          break; // Llegamos al final del stream
        }

        currentStart = currentEnd + 1;
      }

      await req.response.close();
    } catch (_) {
      // Si el usuario adelanta la canción o cambia de pista, ExoPlayer cierra el socket anterior.
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  Future<void> _probeTotalLength(_StreamSession session) async {
    try {
      final probeReq = await _httpClient.getUrl(session.uri);
      probeReq.headers.set(HttpHeaders.userAgentHeader, session.userAgent);
      probeReq.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1');
      final probeRes = await probeReq.close();
      final contentRange = probeRes.headers.value(HttpHeaders.contentRangeHeader);
      if (contentRange != null && contentRange.contains('/')) {
        final totalStr = contentRange.split('/').last;
        session.contentLength = int.tryParse(totalStr);
      }
      await probeRes.drain();
    } catch (_) {}
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

class _StreamSession {
  final Uri uri;
  final String userAgent;
  int? contentLength;
  final String mimeType;

  _StreamSession({
    required this.uri,
    required this.userAgent,
    this.contentLength,
    required this.mimeType,
  });
}
