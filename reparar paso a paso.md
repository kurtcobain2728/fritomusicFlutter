# ROL Y OBJETIVO PRINCIPAL
Actúa como un Ingeniero Senior experto en Flutter, Dart, arquitectura de audio (ExoPlayer / `just_audio` / `audio_service`) y protocolos internos de streaming de YouTube (InnerTube API, `googlevideo.com`, `poToken` y `visitorData`).

Actualmente el modo de streaming del reproductor en este repositorio (`fritomusicFlutter`) funciona muy bien al buscar, resolver y empezar a reproducir canciones, pero tiene un bug crítico: **todas las canciones en modo stream se detienen o se cortan entre los 30 y 60 segundos de reproducción** (algo que en nuestra versión nativa de Kotlin con Media3/ExoPlayer no sucede).

Tu objetivo es **solucionar definitivamente este corte a los 30-60 segundos** implementando un Proxy HTTP Local por Chunks Acotados (`127.0.0.1`) y sincronizando los metadatos del extractor (`User-Agent`, `poToken`, `visitorData`), **SIN ROMPER ni reescribir el flujo actual de streaming, la cola de reproducción, los controles ni la interfaz gráfica**.

---

# REGLAS ESTRICTAS (LO QUE NO DEBES TOCAR)
1. **NO modifiques la UI, widgets, pantallas ni el diseño del reproductor.**
2. **NO alteres la lógica de reproducción de música local (archivos del dispositivo).**
3. **NO cambies la arquitectura de gestión de estado ni la lógica de colas (siguiente, anterior, aleatorio, repetir).**
4. **NO reemplaces el paquete de reproducción de audio actual ni elimines la lógica de búsqueda/extracción de streams que ya funciona.** Solo debes intervenir en los puntos exactos descritos en este plan.

---

# DIAGNÓSTICO TÉCNICO (POR QUÉ OCURRE EL CORTE A LOS 30-60 SEGUNDOS)
Un stream de audio de YouTube (`itag 140` M4A a 128 kbps o `itag 251` Opus a 160 kbps) consume ~16-20 KB/s. Entre 30 y 60 segundos equivalen exactamente a **512 KB - 1 MiB de datos**. El corte ocurre por la combinación de estas 3 causas:

1. **Bloqueo de `googlevideo.com` al primer Megabyte en peticiones `Range` abiertas:**
   El reproductor de Flutter abre la URL de `googlevideo.com` enviando `Range: bytes=0-` (rango abierto). YouTube entrega el *burst* inicial (~512 KB - 1 MiB, es decir, los primeros 30-60s de audio) y luego estrangula la conexión o lanza `HTTP 403 / Socket Drop` si el cliente no pide el audio en **bloques acotados (Bounded Range Requests, ej. de 512 KB en 512 KB)**.
2. **Desfase de `User-Agent` entre el Extractor y el Reproductor:**
   El servicio extractor obtiene la URL de `googlevideo.com` emulando un cliente específico de InnerTube (ej. `ANDROID_VR`, `IOS`, `ANDROID`, `WEB_REMIX`). Sin embargo, cuando el reproductor de Flutter (`just_audio` / `audioplayers`) consume esa URL, realiza la petición HTTP con su propio `User-Agent` por defecto (`ExoPlayerLib/...` o `just_audio/...`). Al pedir el segundo bloque de buffer (a los 30-60s), `googlevideo.com` detecta la discrepancia de `User-Agent` y cierra el stream.
3. **Desincronización de `poToken` y `visitorData` (Corte exacto al minuto 1:00):**
   En `po_token_generator.dart` y el cliente InnerTube, si el `visitorData` usado para generar el `poToken` no es exactamente el mismo string enviado en `context.client.visitorData` de la petición a `/youtubei/v1/player` (o si falta concatenar `&pot=` en la URL del stream cuando el cliente lo requiere), YouTube sirve únicamente los primeros 60 segundos y bloquea el resto.

---

# PLAN DE IMPLEMENTACIÓN PASO A PASO

Ejecuta este plan en orden. Primero inspecciona los archivos del repositorio para ubicar los nombres exactos de clases y métodos antes de editar.

## FASE 1: Auditoría Rápida del Repositorio
Busca y analiza en el proyecto:
1. El archivo generador de tokens (`po_token_generator.dart` y archivos relacionados).
2. El servicio o repositorio que extrae las URLs de streaming de YouTube/InnerTube.
3. El servicio/handler del reproductor de audio (donde se llama a `setAudioSource`, `AudioSource.uri`, `setUrl` o equivalente).

## FASE 2: Revisión Quirúrgica de `po_token_generator.dart` y el Extractor
Sin romper la extracción actual que ya resuelve las canciones:
1. **Sincronización de `visitorData`:** Verifica que el `visitorData` utilizado al generar el `poToken` sea **exactamente el mismo** que se envía dentro de `context.client.visitorData` en la petición a `/youtubei/v1/player`.
2. **Parámetro `pot`:** Verifica que si se genera un `poToken` válido para el cliente en uso, la URL final del stream (`adaptiveFormats`) incluya el parámetro `&pot=$poToken` si aún no lo tiene.
3. **Exposición de metadatos del Stream:** Asegúrate de que cuando el extractor devuelva la URL del stream al reproductor, también podamos conocer (o pasar) el **`userAgent` exacto** del cliente InnerTube que generó esa URL, el **`mimeType`** (`audio/mp4` o `audio/webm`) y opcionalmente el **`contentLength`** (total de bytes del formato).
4. **Seguridad (API Key expuesta):** Revisa `po_token_generator.dart` (especialmente alrededor de la línea 66). Si existe alguna `Google API Key` quemada en el código (`AIza...`), reemplázala por `String.fromEnvironment('GOOGLE_API_KEY', defaultValue: '...')` o el método seguro que use el proyecto para no exponer secretos en texto plano, manteniendo el funcionamiento intacto.

## FASE 3: Crear el Proxy HTTP Local por Chunks (`youtube_stream_proxy.dart`)
Crea un archivo nuevo en la capa de servicios de audio/streaming (por ejemplo, `lib/services/youtube_stream_proxy.dart` o dentro de la carpeta donde estén los servicios de stream).

Este proxy levanta un servidor local en `127.0.0.1` usando únicamente `dart:io` nativo. El reproductor de Flutter se conectará a `http://127.0.0.1:puerto/stream/id` (soportando *seeking*/barra de progreso con `206 Partial Content`), mientras que el proxy descargará el audio de `googlevideo.com` en **bloques cerrados de 512 KB** inyectando el `User-Agent` correcto.

Implementa este código asegurándote de que se adapte limpiamente al proyecto:

```dart
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

  /// Registra una URL de googlevideo.com y devuelve una URI local ([http://127.0.0.1](http://127.0.0.1):port/stream/id)
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

    return Uri.parse('[http://127.0.0.1](http://127.0.0.1):${_server!.port}/stream/$id');
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
        ytReq.headers.set('Origin', '[https://music.youtube.com](https://music.youtube.com)');
        ytReq.headers.set('Referer', '[https://music.youtube.com/](https://music.youtube.com/)');

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




FASE 4: Conectar el Proxy en el Reproductor (Sin romper el flujo actual)
Ubica el archivo donde el reproductor carga la URL cuando es una canción en modo stream (diferenciándolo de archivos locales en el dispositivo):

Justo antes de pasarle la URL de googlevideo.com al reproductor (AudioSource.uri(...) o setUrl(...)), regístrala en YouTubeStreamProxy.instance.registerStream(...):

final localProxyUri = await YouTubeStreamProxy.instance.registerStream(
  streamUrl: streamUrl,
  userAgent: streamUserAgent, // El mismo User-Agent usado en el extractor InnerTube
  contentLength: contentLength, // O null para que lo tome del parámetro 'clen' de la URL
  mimeType: mimeType,
);


Pasa localProxyUri al reproductor exactamente como se hacía antes con la URL original, conservando cualquier tag (MediaItem) o metadato de notificación en segundo plano que ya tenga el proyecto.

Si el reproductor utiliza just_audio, verifica la instanciación de AudioPlayer y asegúrate de configurar AndroidLoadControl dentro de AudioLoadConfiguration con minBufferDuration: Duration(seconds: 50) y maxBufferDuration: Duration(seconds: 120) para evitar caídas por inactividad de red.



VERIFICACIÓN FINAL
Una vez realizados los cambios:

Ejecuta flutter analyze para comprobar que no existan errores de tipado, imports faltantes ni warnings nuevos.

Verifica que la reproducción local de archivos del dispositivo no haya sido afectada en absoluto.

Muéstrame un resumen claro de los archivos que modificaste y qué cambiaste en cada uno.