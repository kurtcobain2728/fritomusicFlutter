import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/potoken/po_token_generator.dart';
import '../innertube/innertube_client.dart';
import '../innertube/innertube_models.dart';
import '../saavn/saavn_resolver.dart';
import 'signature_timestamp_service.dart';
import 'stream_client_utils.dart';
import 'youtube_decipher_service.dart';

class _CachedUrl {
  final String url;
  final int timestamp;
  _CachedUrl(this.url, this.timestamp);
}

class YouTubeRepository {
  static final YouTubeRepository instance = YouTubeRepository._internal();
  factory YouTubeRepository() => instance;
  YouTubeRepository._internal();

  final Map<String, _CachedUrl> _streamUrlCache = {};
  static const int _streamUrlTtlMs = 4 * 60 * 60 * 1000;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  void invalidateStreamUrl(String videoId) {
    _streamUrlCache.remove(videoId);
  }

  String? getCachedStreamUrl(String videoId) {
    final cached = _streamUrlCache[videoId];
    if (cached == null) return null;
    if (DateTime.now().millisecondsSinceEpoch - cached.timestamp < _streamUrlTtlMs) {
      return cached.url;
    }
    _streamUrlCache.remove(videoId);
    return null;
  }

  Future<bool> isStreamUrlPlayable(String url) async {
    HttpClient? client;
    try {
      final uri = Uri.parse(url);
      client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final profile = StreamClientUtils.resolveRequestProfile(url);
      final isYouTube = StreamClientUtils.isYouTubeMediaHost(uri.host);
      request.headers.set('Range', 'bytes=0-0');
      if (isYouTube) {
        profile.headers.forEach((k, v) => request.headers.set(k, v));
      }
      final response = await request.close().timeout(const Duration(seconds: 8));
      final code = response.statusCode;
      response.drain();
      return (code >= 200 && code < 400) || code == 416;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Resolución vía cliente WEB_REMIX con PoToken (BotGuard).
  ///
  /// El token de jugador va en el cuerpo del request
  /// (`context.serviceIntegrityDimensions.poToken`) y el token de sesión se
  /// adjunta a la URL de stream como `?pot=`. Si el WebView del generador no
  /// está disponible, devuelve `null` y la cascada normal continúa.
  Future<String?> _resolveWebRemixWithPoToken(InnerTubeClient client, String videoId) async {
    final visitorData = (await client.ensureVisitorData())?.trim();
    if (visitorData == null || visitorData.isEmpty) return null;

    final poToken = await PoTokenGenerator.instance.getWebClientPoToken(videoId, visitorData);
    if (poToken == null) {
      // Sin PoToken el cliente WEB_REMIX devuelve UNPLAYABLE siempre
      // (verificado empíricamente): no gastar el request de /player.
      debugPrint('[StreamResolve] WEB_REMIX omitido para $videoId: sin PoToken');
      return null;
    }

    final data = await client.getPlayer(
      videoId,
      poToken: poToken.playerRequestPoToken,
      visitorData: visitorData,
    );
    if (data == null) return null;

    final status = data['playabilityStatus'];
    if (status is Map && status['status'] != 'OK') return null;

    var url = await _extractBestAudioUrl(data, poToken: poToken.streamingDataPoToken);
    if (url == null || url.isEmpty) return null;

    final streamingPot = poToken.streamingDataPoToken;
    if (streamingPot.isNotEmpty) {
      url = StreamClientUtils.appendPoToken(url, streamingPot);
    }

    // Validar que la URL responda antes de entregarla (evita URLs muertas).
    final playable = await isStreamUrlPlayable(url);
    if (!playable) return null;
    return url;
  }

  /// Resolución vía cliente WEB (Safari UA) para obtener manifest HLS (.m3u8).
  ///
  /// El streaming HLS de YouTube no sufre de estrangulamiento (n-challenge)
  /// ni de límite de descarga de 1 MB, y es reproducido de forma nativa por
  /// ExoPlayer (just_audio) sin requerir el proxy local de rangos.
  Future<String?> _resolveHls(InnerTubeClient client, String videoId) async {
    try {
      final sts = await SignatureTimestampService.instance.getSignatureTimestamp();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'User-Agent': StreamClientUtils.safariUserAgent,
        'X-YouTube-Client-Name': '1',
        'X-YouTube-Client-Version': '2.20260708.00.00',
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      };
      if (client.cookie != null && client.cookie!.trim().isNotEmpty) {
        final processedCookie = client.cookieWithPlaybackDefaults(client.cookie!.trim());
        headers['Cookie'] = processedCookie;
        headers['X-Youtube-Bootstrap-Logged-In'] = 'true';
        headers['X-Goog-AuthUser'] = '0';
      }

      final response = await _dio.post(
        'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        data: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB',
              'clientVersion': '2.20260708.00.00',
              'userAgent': StreamClientUtils.safariUserAgent,
              'hl': client.hl,
              'gl': client.gl,
              if (client.visitorData != null && client.visitorData!.trim().isNotEmpty)
                'visitorData': client.visitorData!.trim(),
            }
          },
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
          'playbackContext': {
            'contentPlaybackContext': {
              'html5Preference': 'HTML5_PREF_WANTS',
              'signatureTimestamp': sts,
            }
          }
        }),
        options: Options(headers: headers),
      );

      final playability = response.data?['playabilityStatus'];
      if (playability is Map && playability['status'] != 'OK') {
        debugPrint('[StreamResolve] HLS status != OK: ${playability['status']}');
        return null;
      }

      final hlsUrl = response.data?['streamingData']?['hlsManifestUrl']?.toString();
      if (hlsUrl != null && hlsUrl.isNotEmpty) {
        if (await _entregarUrlValidada(videoId, hlsUrl, 'HLS')) {
          return hlsUrl;
        }
      }
    } catch (e) {
      debugPrint('[StreamResolve] HLS falló para $videoId: $e');
    }
    return null;
  }

  /// Resuelve la URL directa de audio reproducible de un videoId de YouTube.
  /// Soportando formatos adaptativos directos (url) y cifrados (signatureCipher/cipher).
  Future<String?> _extractBestAudioUrl(dynamic data, {String? poToken}) async {
    if (data == null || data is! Map) return null;
    final streamingData = data['streamingData'];
    if (streamingData == null) return null;
    return YouTubeDecipherService.instance.extractBestAudioStream(streamingData, poToken: poToken);
  }

  /// Valida que la URL responda con una sonda de rango antes de entregarla al
  /// reproductor (captura URLs con playability OK pero 403/416 al usarlas).
  Future<bool> _entregarUrlValidada(String videoId, String url, String fuente) async {
    final playable = await isStreamUrlPlayable(url);
    if (!playable) {
      debugPrint('[StreamResolve] URL de $fuente no reproducible para $videoId; probando siguiente cliente');
      return false;
    }
    _streamUrlCache[videoId] = _CachedUrl(url, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[StreamResolve] $videoId OK vía $fuente');
    return true;
  }

  Future<String?> getStreamUrl(String videoId, {String? title, String? artist}) async {
    debugPrint('[StreamResolve] $videoId → resolviendo (título=$title, artista=$artist)');
    final cached = getCachedStreamUrl(videoId);
    if (cached != null) {
      debugPrint('[StreamResolve] $videoId OK vía cache');
      return cached;
    }

    // 1. Intentar resolver audio de alta fidelidad (320 kbps) sin cuota vía JioSaavn
    if (title != null && title.trim().isNotEmpty) {
      try {
        final saavn = await SaavnResolver.resolve(title.trim(), (artist ?? '').trim());
        if (saavn != null && saavn.streamUrl.isNotEmpty) {
          _streamUrlCache[videoId] = _CachedUrl(saavn.streamUrl, DateTime.now().millisecondsSinceEpoch);
          debugPrint('[StreamResolve] $videoId OK vía Saavn');
          return saavn.streamUrl;
        }
      } catch (e) {
        debugPrint('[StreamResolve] Saavn falló para $videoId: $e');
      }
    }

    final client = InnerTubeClient.instance;

    // 2. WEB_REMIX + PoToken (BotGuard): la vía "oficial" del cliente web de
    //    YouTube Music. Con timeout de 4s para nunca congelar la reproducción.
    try {
      final resolved = await _resolveWebRemixWithPoToken(client, videoId)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (resolved != null && resolved.isNotEmpty) {
        _streamUrlCache[videoId] = _CachedUrl(resolved, DateTime.now().millisecondsSinceEpoch);
        debugPrint('[StreamResolve] $videoId OK vía WEB_REMIX+PoToken');
        return resolved;
      }
    } catch (e) {
      debugPrint('[StreamResolve] WEB_REMIX+PoToken falló para $videoId: $e');
    }

    // 3. Probar cliente preferido nativo IOS via InnerTube (devuelve streams
    //    directos sin cifrado n-sig de forma ultra rápida)
    try {
      final sts = await SignatureTimestampService.instance.getSignatureTimestamp();
      final response = await _dio.post(
        'https://www.youtube.com/youtubei/v1/player',
        data: jsonEncode({
          'context': {
            'client': {
              'clientName': 'IOS',
              'clientVersion': '21.03.1',
              'deviceMake': 'Apple',
              'deviceModel': 'iPhone16,2',
              'osName': 'iOS',
              'osVersion': '18.2.22C152',
              'hl': client.hl,
              'gl': client.gl,
              if (client.visitorData != null) 'visitorData': client.visitorData,
            }
          },
          'videoId': videoId,
          'playbackContext': {
            'contentPlaybackContext': {
              'signatureTimestamp': sts,
            }
          }
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
            'X-YouTube-Client-Name': '5',
            'X-YouTube-Client-Version': '21.03.1',
            if (client.cookie != null && client.cookie!.trim().isNotEmpty) 'Cookie': client.cookie!.trim(),
          },
        ),
      );

      final vDetails = response.data is Map ? (response.data['videoDetails'] as Map?) : null;
      if (vDetails != null) {
        final extractedTitle = vDetails['title']?.toString();
        final extractedAuthor = vDetails['author']?.toString();
        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          try {
            final saavn = await SaavnResolver.resolve(extractedTitle, extractedAuthor ?? '');
            if (saavn != null && saavn.streamUrl.isNotEmpty) {
              _streamUrlCache[videoId] = _CachedUrl(saavn.streamUrl, DateTime.now().millisecondsSinceEpoch);
              debugPrint('[StreamResolve] $videoId OK vía Saavn (metadatos IOS)');
              return saavn.streamUrl;
            }
          } catch (_) {}
        }
      }

      final url = await _extractBestAudioUrl(response.data);
      if (url != null && await _entregarUrlValidada(videoId, url, 'IOS')) {
        return url;
      }
    } catch (e) {
      debugPrint('[StreamResolve] cliente IOS falló para $videoId: $e');
    }

    // 4. Probar cliente nativo ANDROID_VR
    try {
      final response = await _dio.post(
        'https://www.youtube.com/youtubei/v1/player',
        data: jsonEncode({
          'context': {
            'client': {
              'clientName': 'ANDROID_VR',
              'clientVersion': '1.43.32',
              'deviceMake': 'Oculus',
              'deviceModel': 'Quest 3',
              'osName': 'Android',
              'osVersion': '12',
              'androidSdkVersion': 32,
              'gl': client.gl,
              'hl': client.hl,
            }
          },
          'videoId': videoId,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
            'X-YouTube-Client-Name': '28',
            'X-YouTube-Client-Version': '1.43.32',
          },
        ),
      );

      final url = await _extractBestAudioUrl(response.data);
      if (url != null && await _entregarUrlValidada(videoId, url, 'ANDROID_VR')) {
        return url;
      }
    } catch (e) {
      debugPrint('[StreamResolve] cliente ANDROID_VR falló para $videoId: $e');
    }

    // 5. Fallback HLS (WEB Safari)
    try {
      final hlsResolved = await _resolveHls(client, videoId);
      if (hlsResolved != null && hlsResolved.isNotEmpty) {
        return hlsResolved;
      }
    } catch (e) {
      debugPrint('[StreamResolve] Fallback HLS falló para $videoId: $e');
    }

    // 3. TVHTML5_SIMPLY_EMBEDDED_PLAYER ELIMINADO (2026-10-15): devuelve
    //    ERROR "YouTube ya no es compatible con esta aplicación o dispositivo"
    //    (verificado empíricamente). Puede restaurarse si el cliente revive.
    // 5. Fallback a getPlayer de InnerTubeClient (WEB_REMIX sin PoToken; solo
    //    sirve con sesión logueada y contenido no restringido).
    try {
      final data = await InnerTubeClient.instance.getPlayer(videoId);
      final url = await _extractBestAudioUrl(data);
      if (url != null && await _entregarUrlValidada(videoId, url, 'WEB')) {
        return url;
      }
    } catch (e) {
      debugPrint('[StreamResolve] fallback WEB falló para $videoId: $e');
    }

    // 5. Piped / Invidious ELIMINADOS (2026-10-15): las 8 instancias
    //    configuradas estaban muertas (526/502/sin respuesta/401) y solo
    //    añadían esperas de hasta 8×6 s por canción fallida. Restaurar con una
    //    lista dinámica de instancias vivas si se quiere ese fallback.

    debugPrint('[StreamResolve] $videoId SIN RESPUESTA de ningún cliente');
    return null;
  }

  // Delegaciones rápidas
  Future<List<YTItem>> search(String query, {String? filter}) => InnerTubeClient.instance.search(query, filter: filter);
  Future<List<SongItem>> searchSongs(String query) => InnerTubeClient.instance.searchSongs(query);
  Future<List<ArtistItem>> searchArtists(String query) => InnerTubeClient.instance.searchArtists(query);
  Future<List<PlaylistItem>> searchPlaylists(String query) => InnerTubeClient.instance.searchPlaylists(query);
  Future<List<String>> getSearchSuggestions(String query) => InnerTubeClient.instance.getSearchSuggestions(query);
  Future<List<Map<String, dynamic>>> getHome() => InnerTubeClient.instance.getHome();
  Future<List<SongItem>> getMusicHistory() => InnerTubeClient.instance.getMusicHistory();
  Future<List<SongItem>> getLikedSongs() => InnerTubeClient.instance.getLikedSongs();
  Future<List<ArtistItem>> getSubscribedArtists() => InnerTubeClient.instance.getSubscribedArtists();
  Future<ArtistPageData?> getArtist(String artistId) => InnerTubeClient.instance.getArtist(artistId);
  Future<List<ArtistItem>> getRelatedArtists(String browseId) async {
    try {
      final page = await getArtist(browseId);
      if (page == null) return [];
      return page.relatedArtists.where((a) => a.id.isNotEmpty && a.id != browseId).toList();
    } catch (_) {
      return [];
    }
  }
  Future<AlbumPageData?> getAlbum(String browseId) => InnerTubeClient.instance.getAlbum(browseId);
  Future<PlaylistPageData?> getPlaylist(String playlistId) => InnerTubeClient.instance.getPlaylist(playlistId);
  Future<List<SongItem>> getNext({required String videoId, String? playlistId}) => InnerTubeClient.instance.getNext(videoId: videoId, playlistId: playlistId);
  Future<List<PlaylistItem>> getUserPlaylists() => InnerTubeClient.instance.getUserPlaylists();
  Future<List<PlaylistItem>> getFeaturedPlaylists() => InnerTubeClient.instance.getFeaturedPlaylists();
  Future<Map<String, String>?> getAccountInfo() => InnerTubeClient.instance.getAccountInfo();
  Future<bool> subscribeChannel(String channelId) => InnerTubeClient.instance.subscribeChannel(channelId);
  Future<bool> unsubscribeChannel(String channelId) => InnerTubeClient.instance.unsubscribeChannel(channelId);
  Future<bool> deletePlaylist(String playlistId) => InnerTubeClient.instance.deletePlaylist(playlistId);
}
