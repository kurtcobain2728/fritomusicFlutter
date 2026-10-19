import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'innertube_models.dart';
import 'innertube_parser.dart';
import '../yt/signature_timestamp_service.dart';

class InnerTubeClient {
  static final InnerTubeClient instance = InnerTubeClient._internal();
  factory InnerTubeClient() => instance;

  late final Dio _dio;

  String? visitorData;
  String? dataSyncId;
  String? cookie;
  String hl = 'es';
  String gl = 'ES';

  InnerTubeClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://music.youtube.com/youtubei/v1/',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
        'Cache-Control': 'no-cache',
      },
    ));
  }

  Map<String, String> _parseCookies(String cookieStr) {
    final map = <String, String>{};
    for (final pair in cookieStr.split(';')) {
      final idx = pair.indexOf('=');
      if (idx != -1) {
        final key = pair.substring(0, idx).trim();
        var val = pair.substring(idx + 1).trim();
        if (val.startsWith('"') && val.endsWith('"') && val.length >= 2) {
          val = val.substring(1, val.length - 1);
        }
        if (key.isNotEmpty) {
          map[key] = val;
        }
      }
    }
    return map;
  }

  Map<String, dynamic> _buildContext({
    bool withAuth = false,
    bool withOnBehalfOfUser = false,
    String clientName = 'WEB_REMIX',
    String clientVersion = '1.20260213.01.00',
  }) {
    final clientMap = <String, dynamic>{
      'clientName': clientName,
      'clientVersion': clientVersion,
      'hl': hl,
      'gl': gl,
    };
    if (visitorData != null && visitorData!.trim().isNotEmpty) {
      clientMap['visitorData'] = visitorData!.trim();
    }

    final context = <String, dynamic>{
      'client': clientMap,
    };

    // onBehalfOfUser solo debe enviarse si se solicita explícitamente (Brand Account)
    if (withOnBehalfOfUser &&
        cookie != null &&
        cookie!.trim().isNotEmpty &&
        dataSyncId != null &&
        dataSyncId!.trim().isNotEmpty) {
      final cleanSyncId = dataSyncId!.split('||').first.trim();
      if (cleanSyncId.isNotEmpty) {
        context['user'] = {
          'onBehalfOfUser': cleanSyncId,
        };
      }
    }

    return context;
  }

  /// Agrega defaults de playback (SOCS=CAI, PREF) a las cookies si están ausentes
  String cookieWithPlaybackDefaults(String cookieStr) {
    if (cookieStr.trim().isEmpty) return '';
    final parts = cookieStr
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final names = parts.map((p) => p.split('=').first.trim()).toSet();
    if (!names.contains('SOCS')) parts.add('SOCS=CAI');
    if (!names.contains('PREF')) parts.add('PREF=f2=8000000&hl=en');
    return parts.join('; ');
  }

  Map<String, String> _buildHeaders({
    bool withAuth = false,
    String? clientName,
    String? clientVersion,
    String? origin,
    String? userAgent,
  }) {
    final effectiveOrigin = origin ?? 'https://music.youtube.com';
    final effectiveUserAgent = userAgent ??
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0';
    final effectiveClientName = clientName ?? '67';
    final effectiveClientVersion = clientVersion ?? '1.20260213.01.00';

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': effectiveClientName,
      'X-YouTube-Client-Version': effectiveClientVersion,
      'X-Origin': effectiveOrigin,
      'Referer': '$effectiveOrigin/',
      'User-Agent': effectiveUserAgent,
    };

    if (visitorData != null && visitorData!.trim().isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitorData!.trim();
    }

    if (withAuth && cookie != null && cookie!.trim().isNotEmpty) {
      headers['Cookie'] = cookie!.trim();
      headers['X-Youtube-Bootstrap-Logged-In'] = 'true';

      final cookieMap = _parseCookies(cookie!.trim());
      final sapisid = cookieMap['SAPISID']?.replaceAll('"', '').trim() ??
          cookieMap['__Secure-3PAPISID']?.replaceAll('"', '').trim() ??
          cookieMap['APISID']?.replaceAll('"', '').trim();

      if (sapisid != null && sapisid.isNotEmpty) {
        final now = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final raw = '$now $sapisid $effectiveOrigin';
        final hash = sha1.convert(utf8.encode(raw)).toString();
        headers['Authorization'] = 'SAPISIDHASH ${now}_$hash';
      }
    }

    return headers;
  }

  @visibleForTesting
  Map<String, String> buildHeadersForTest({bool withAuth = false}) =>
      _buildHeaders(withAuth: withAuth);

  static const String filterSong = 'EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D';
  static const String filterVideo = 'EgWKAQIQAWoKEAkQChAFEAMQBA%3D%3D';
  static const String filterAlbum = 'EgWKAQIYAWoKEAkQChAFEAMQBA%3D%3D';
  static const String filterArtist = 'EgWKAQIgAWoKEAkQChAFEAMQBA%3D%3D';
  static const String filterFeaturedPlaylist = 'EgeKAQQoADgBagwQDhAKEAMQBRAJEAQ%3D';
  static const String filterCommunityPlaylist = 'EgeKAQQoAEABagoQAxAEEAoQCRAF';

  /// Búsqueda general o filtrada en YouTube Music (pública, 100% fiable)
  Future<List<YTItem>> search(String query, {String? filter}) async {
    try {
      final body = <String, dynamic>{
        'context': _buildContext(withAuth: false),
        'query': query,
      };
      if (filter != null) {
        body['params'] = filter;
      }

      final response = await _dio.post(
        'search',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseSearchResults(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<List<SongItem>> searchSongs(String query) async {
    final items = await search(query, filter: filterSong);
    final songs = items.whereType<SongItem>().toList();
    if (songs.isNotEmpty) return songs;
    final all = await search(query);
    return all.whereType<SongItem>().toList();
  }

  Future<List<ArtistItem>> searchArtists(String query) async {
    final items = await search(query, filter: filterArtist);
    final artists = items.whereType<ArtistItem>().toList();
    if (artists.isNotEmpty) return artists;
    final all = await search(query);
    return all.whereType<ArtistItem>().toList();
  }

  Future<List<PlaylistItem>> searchPlaylists(String query) async {
    try {
      final results = await Future.wait([
        search(query, filter: filterFeaturedPlaylist),
        search(query, filter: filterCommunityPlaylist),
      ]);
      final list = <PlaylistItem>[];
      for (final sub in results) {
        for (final item in sub) {
          if (item is PlaylistItem && !list.any((p) => p.id == item.id)) {
            list.add(item);
          }
        }
      }
      if (list.isNotEmpty) return list;

      final all = await search(query);
      for (final item in all) {
        if (item is PlaylistItem && !list.any((p) => p.id == item.id)) {
          list.add(item);
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Historial de reproducción de la cuenta (FEmusic_history)
  Future<List<SongItem>> getMusicHistory() async {
    if (cookie == null || cookie!.trim().isEmpty) return [];
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'browseId': 'FEmusic_history',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      return InnerTubeParser.parseMusicHistory(response.data);
    } catch (_) {
      return [];
    }
  }

  /// Canciones que te gustaron (FEmusic_liked_videos / LM)
  Future<List<SongItem>> getLikedSongs() async {
    if (cookie == null || cookie!.trim().isEmpty) return [];

    // Intento 1: Playlist oficial de Likes en YouTube Music (LM / VLLM)
    try {
      final page = await getPlaylist('LM');
      if (page != null && page.songs.isNotEmpty) {
        final filtered = page.songs.where((s) => s.isRealMusicTrack).toList();
        if (filtered.isNotEmpty) return filtered;
      }
    } catch (_) {}

    try {
      final page = await getPlaylist('VLLM');
      if (page != null && page.songs.isNotEmpty) {
        final filtered = page.songs.where((s) => s.isRealMusicTrack).toList();
        if (filtered.isNotEmpty) return filtered;
      }
    } catch (_) {}

    // Intento 2: Buscar playlist de Me Gusta en la biblioteca del usuario
    try {
      final userLists = await getUserPlaylists();
      for (final p in userLists) {
        final title = p.title.toLowerCase();
        if (p.id == 'LM' || p.id == 'VLLM' || title.contains('gusta') || title.contains('liked')) {
          final page = await getPlaylist(p.id);
          if (page != null && page.songs.isNotEmpty) {
            final filtered = page.songs.where((s) => s.isRealMusicTrack).toList();
            if (filtered.isNotEmpty) return filtered;
          }
        }
      }
    } catch (_) {}

    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'browseId': 'FEmusic_liked_videos',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final songs = InnerTubeParser.parseMusicHistory(response.data);
      final filtered = songs.where((s) => s.isRealMusicTrack).toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}

    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'browseId': 'LM',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final songs = InnerTubeParser.parseMusicHistory(response.data);
      return songs.where((s) => s.isRealMusicTrack).toList();
    } catch (_) {
      return [];
    }
  }

  /// Artistas y canales a los que el usuario se ha suscrito en YouTube Music
  Future<List<ArtistItem>> getSubscribedArtists() async {
    if (cookie == null || cookie!.trim().isEmpty) return [];

    // Intento 1: FEmusic_library_corpus_artists (artistas de la biblioteca de YouTube Music)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'browseId': 'FEmusic_library_corpus_artists',
      };
      final res = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      final list = InnerTubeParser.parseArtists(res.data);
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('InnerTube getSubscribedArtists error intento 1: $e');
    }

    // Intento 2: FEchannels (suscripciones de canales/artistas de la cuenta)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'browseId': 'FEchannels',
      };
      final res = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      final list = InnerTubeParser.parseArtists(res.data);
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint('InnerTube getSubscribedArtists error intento 2: $e');
    }

    return [];
  }

  /// Suscribirse a un canal o artista en YouTube / YouTube Music
  Future<bool> subscribeChannel(String channelId) async {
    if (cookie == null || cookie!.trim().isEmpty) return false;
    final cleanChannelId = channelId.startsWith('UC') ? channelId : 'UC$channelId';

    // Intento 1: WEB_REMIX (YouTube Music)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'channelIds': [cleanChannelId],
      };
      final res = await _dio.post(
        'subscription/subscribe',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('InnerTube subscribeChannel error (WEB_REMIX): $e');
    }

    // Intento 2: WEB (YouTube estándar)
    try {
      final body = {
        'context': _buildContext(withAuth: true, clientName: 'WEB', clientVersion: '2.20260213.01.00'),
        'channelIds': [cleanChannelId],
      };
      final res = await _dio.post(
        'subscription/subscribe',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('InnerTube subscribeChannel error (WEB): $e');
      return false;
    }
  }

  /// Desuscribirse de un canal o artista en YouTube / YouTube Music
  Future<bool> unsubscribeChannel(String channelId) async {
    if (cookie == null || cookie!.trim().isEmpty) return false;
    final cleanChannelId = channelId.startsWith('UC') ? channelId : 'UC$channelId';

    // Intento 1: WEB_REMIX (YouTube Music)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'channelIds': [cleanChannelId],
      };
      final res = await _dio.post(
        'subscription/unsubscribe',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('InnerTube unsubscribeChannel error (WEB_REMIX): $e');
    }

    // Intento 2: WEB (YouTube estándar)
    try {
      final body = {
        'context': _buildContext(withAuth: true, clientName: 'WEB', clientVersion: '2.20260213.01.00'),
        'channelIds': [cleanChannelId],
      };
      final res = await _dio.post(
        'subscription/unsubscribe',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('InnerTube unsubscribeChannel error (WEB): $e');
      return false;
    }
  }

  /// Sugerencias de búsqueda autocompletadas
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final body = {
        'context': _buildContext(withAuth: false),
        'input': query,
      };

      final response = await _dio.post(
        'music/get_search_suggestions',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseSearchSuggestions(response.data);
    } catch (e) {
      return [];
    }
  }

  /// Página principal de exploración / Home con fallback automático garantizado
  Future<List<Map<String, dynamic>>> getHome() async {
    // 1. Probar con sesión de usuario si está logueado
    if (cookie != null && cookie!.trim().isNotEmpty) {
      try {
        final body = {
          'context': _buildContext(withAuth: true),
          'browseId': 'FEmusic_home',
        };

        final response = await _dio.post(
          'browse',
          data: jsonEncode(body),
          options: Options(headers: _buildHeaders(withAuth: true)),
        );

        final shelves = InnerTubeParser.parseHomeShelves(response.data);
        if (shelves.isNotEmpty) return shelves;
      } catch (_) {}
    }

    // 2. Fallback público garantizado
    try {
      final body = {
        'context': _buildContext(withAuth: false),
        'browseId': 'FEmusic_home',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseHomeShelves(response.data);
    } catch (e) {
      return [];
    }
  }

  /// Datos completos de un artista (canciones top, álbumes, etc.)
  Future<ArtistPageData?> getArtist(String artistId) async {
    try {
      final body = {
        'context': _buildContext(withAuth: false),
        'browseId': artistId.startsWith('UC') || artistId.startsWith('FEmusic_library_privately_owned_artist_detail')
            ? artistId
            : 'UC$artistId',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseArtistPage(response.data, artistId);
    } catch (e) {
      return null;
    }
  }

  /// Datos completos de un álbum
  Future<AlbumPageData?> getAlbum(String browseId) async {
    try {
      final body = {
        'context': _buildContext(withAuth: false),
        'browseId': browseId,
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseAlbumPage(response.data, browseId);
    } catch (e) {
      return null;
    }
  }

  /// Datos y canciones de una lista de reproducción
  Future<PlaylistPageData?> getPlaylist(String playlistId) async {
    final isAuth = cookie != null && cookie!.trim().isNotEmpty;
    try {
      final body = {
        'context': _buildContext(withAuth: isAuth),
        'browseId': playlistId.startsWith('VL') ? playlistId : 'VL$playlistId',
      };

      final response = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: isAuth)),
      );

      final page = InnerTubeParser.parsePlaylistPage(response.data, playlistId);
      if (page != null) return page;
    } catch (_) {}

    // Fallback unauthenticated
    if (isAuth) {
      try {
        final body = {
          'context': _buildContext(withAuth: false),
          'browseId': playlistId.startsWith('VL') ? playlistId : 'VL$playlistId',
        };

        final response = await _dio.post(
          'browse',
          data: jsonEncode(body),
          options: Options(headers: _buildHeaders(withAuth: false)),
        );

        return InnerTubeParser.parsePlaylistPage(response.data, playlistId);
      } catch (_) {}
    }
    return null;
  }

  /// Playlists del usuario logueado en YouTube Music (idéntico a Kotlin YouTube.library("FEmusic_liked_playlists"))
  Future<List<PlaylistItem>> getUserPlaylists() async {
    if (cookie == null || cookie!.trim().isEmpty) {
      debugPrint('InnerTube: getUserPlaylists abortado porque la cookie está vacía');
      return [];
    }

    // Intento 1: FEmusic_liked_playlists estándar (exactamente como Kotlin YouTube.library("FEmusic_liked_playlists"))
    try {
      final body = {
        'context': _buildContext(withOnBehalfOfUser: false),
        'browseId': 'FEmusic_liked_playlists',
      };

      final response = await _dio.post(
        'browse',
        queryParameters: {'prettyPrint': false},
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final items = InnerTubeParser.parseUserPlaylists(response.data);
      debugPrint('InnerTube: getUserPlaylists intento 1 (FEmusic_liked_playlists): ${items.length} playlists obtenidas');
      if (items.isNotEmpty) return items;
    } catch (e) {
      debugPrint('InnerTube: error en getUserPlaylists intento 1: $e');
    }

    // Intento 2: FEmusic_library_corpus_track_types_playlists (nueva ruta de biblioteca de YouTube Music)
    try {
      final body = {
        'context': _buildContext(withOnBehalfOfUser: false),
        'browseId': 'FEmusic_library_corpus_track_types_playlists',
      };

      final response = await _dio.post(
        'browse',
        queryParameters: {'prettyPrint': false},
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final items = InnerTubeParser.parseUserPlaylists(response.data);
      debugPrint('InnerTube: getUserPlaylists intento 2 (corpus_track_types_playlists): ${items.length} playlists obtenidas');
      if (items.isNotEmpty) return items;
    } catch (e) {
      debugPrint('InnerTube: error en getUserPlaylists intento 2: $e');
    }

    // Intento 3: Con onBehalfOfUser (para Brand Accounts si existe dataSyncId)
    if (dataSyncId != null && dataSyncId!.trim().isNotEmpty) {
      try {
        final body = {
          'context': _buildContext(withOnBehalfOfUser: true),
          'browseId': 'FEmusic_liked_playlists',
        };

        final response = await _dio.post(
          'browse',
          queryParameters: {'prettyPrint': false},
          data: jsonEncode(body),
          options: Options(headers: _buildHeaders(withAuth: true)),
        );

        final items = InnerTubeParser.parseUserPlaylists(response.data);
        debugPrint('InnerTube: getUserPlaylists intento 3 (brand account): ${items.length} playlists obtenidas');
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('InnerTube: error en getUserPlaylists intento 3: $e');
      }
    }

    // Intento 4: FEmusic_liked_playlists con params de filtro (FILTER_PLAYLISTS_RECENTLY_SAVED)
    try {
      final body = {
        'context': _buildContext(withOnBehalfOfUser: false),
        'browseId': 'FEmusic_liked_playlists',
        'params': '4qmFsgIrEhdGRW11c2ljX2xpa2VkX3BsYXlsaXN0cxoQZ2dNR0tnUUlBQkFCb0FZQg%3D%3D',
      };

      final response = await _dio.post(
        'browse',
        queryParameters: {'prettyPrint': false},
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final items = InnerTubeParser.parseUserPlaylists(response.data);
      debugPrint('InnerTube: getUserPlaylists intento 4 (filter params): ${items.length} playlists obtenidas');
      if (items.isNotEmpty) return items;
    } catch (e) {
      debugPrint('InnerTube: error en getUserPlaylists intento 4: $e');
    }

    // Intento 5: FEmusic_library_landing
    try {
      final body = {
        'context': _buildContext(withOnBehalfOfUser: false),
        'browseId': 'FEmusic_library_landing',
      };

      final response = await _dio.post(
        'browse',
        queryParameters: {'prettyPrint': false},
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final items = InnerTubeParser.parseUserPlaylists(response.data);
      debugPrint('InnerTube: getUserPlaylists intento 5 (library_landing): ${items.length} playlists obtenidas');
      if (items.isNotEmpty) return items;
    } catch (e) {
      debugPrint('InnerTube: error en getUserPlaylists intento 5: $e');
    }

    return [];
  }

  /// Listas de reproducción destacadas / populares de YouTube Music
  Future<List<PlaylistItem>> getFeaturedPlaylists() async {
    final results = <PlaylistItem>[];
    final seenIds = <String>{};

    void addUnique(List<PlaylistItem> items) {
      for (final p in items) {
        if (p.id.isNotEmpty && !seenIds.contains(p.id)) {
          seenIds.add(p.id);
          results.add(p);
        }
      }
    }

    // 1. Obtener desde FEmusic_charts
    try {
      final body = {
        'context': _buildContext(withAuth: false),
        'browseId': 'FEmusic_charts',
      };
      final res = await _dio.post(
        'browse',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );
      final chartPlaylists = InnerTubeParser.parseUserPlaylists(res.data);
      addUnique(chartPlaylists);
    } catch (_) {}

    // 2. Obtener búsquedas de listas populares y tendencias
    try {
      final searches = await Future.wait([
        searchPlaylists('Éxitos'),
        searchPlaylists('Top 50'),
        searchPlaylists('Pop'),
        searchPlaylists('Rock'),
      ]);
      for (final list in searches) {
        addUnique(list);
      }
    } catch (_) {}

    return results;
  }

  /// Obtiene los datos del perfil del usuario (nombre, foto, email)
  Future<Map<String, String>?> getAccountInfo() async {
    if (cookie == null || cookie!.trim().isEmpty) return null;
    try {
      final response = await _dio.post(
        'account/account_menu',
        data: jsonEncode({'context': _buildContext(withAuth: true)}),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      return InnerTubeParser.parseAccountInfo(response.data);
    } catch (_) {
      return null;
    }
  }

  /// Datos de reproducción siguiente / radio / cola
  Future<List<SongItem>> getNext({required String videoId, String? playlistId}) async {
    try {
      final body = <String, dynamic>{
        'context': _buildContext(withAuth: false),
        'videoId': videoId,
      };
      if (playlistId != null) {
        body['playlistId'] = playlistId;
      }

      final response = await _dio.post(
        'next',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );

      return InnerTubeParser.parseNextSongs(response.data);
    } catch (e) {
      return [];
    }
  }

  /// Información del reproductor nativo de YouTube
  Future<Map<String, dynamic>?> getPlayer(String videoId, {String? poToken}) async {
    try {
      final hasAuth = cookie != null && cookie!.trim().isNotEmpty;
      final context = _buildContext(withAuth: hasAuth);
      if (poToken != null && poToken.isNotEmpty) {
        (context['serviceIntegrityDimensions'] ??= {})['poToken'] = poToken;
      }

      final sts = await SignatureTimestampService.instance.getSignatureTimestamp();

      final body = <String, dynamic>{
        'context': context,
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
        if (poToken != null && poToken.isNotEmpty)
          'serviceIntegrityDimensions': {'poToken': poToken},
        'playbackContext': {
          'contentPlaybackContext': {
            'signatureTimestamp': sts,
          }
        }
      };

      final response = await _dio.post(
        'player',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: hasAuth)),
      );

      return response.data as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Garantiza un `visitorData` de invitado (una sola petición ligera) para
  /// identificar la sesión cuando el usuario no inició sesión. Es necesario
  /// para generar PoTokens: el token debe vincularse al mismo visitorData que
  /// se envía en el `context` de los requests.
  Future<String?> ensureVisitorData() async {
    final current = visitorData?.trim();
    if (current != null && current.isNotEmpty) return current;
    try {
      final response = await _dio.post(
        'music/get_search_suggestions',
        data: jsonEncode({
          'context': _buildContext(withAuth: false),
          'query': 'a',
        }),
        options: Options(headers: _buildHeaders(withAuth: false)),
      );
      final extracted = _extractVisitorData(response.data);
      if (extracted != null && extracted.isNotEmpty) {
        visitorData = extracted;
        return extracted;
      }
    } catch (_) {}
    return null;
  }

  String? _extractVisitorData(dynamic data) {
    try {
      final responseContext = data is Map ? data['responseContext'] : null;
      if (responseContext is Map) {
        final value = responseContext['visitorData']?.toString();
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Crea una lista de reproducción en la cuenta de YouTube Music
  Future<String?> createPlaylist(String title, {String description = '', List<String>? videoIds}) async {
    if (cookie == null || cookie!.trim().isEmpty) return null;
    try {
      final body = <String, dynamic>{
        'context': _buildContext(withAuth: true),
        'title': title,
        'description': description,
        'privacyStatus': 'PRIVATE',
      };
      if (videoIds != null && videoIds.isNotEmpty) {
        body['videoIds'] = videoIds;
      }

      final response = await _dio.post(
        'playlist/create',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      final playlistId = response.data['playlistId']?.toString();
      return playlistId;
    } catch (e) {
      debugPrint('InnerTube: createPlaylist error: $e');
      return null;
    }
  }

  /// Agrega videos a una lista de reproducción existente en YouTube Music
  Future<bool> addPlaylistVideos(String playlistId, List<String> videoIds) async {
    if (cookie == null || cookie!.trim().isEmpty || videoIds.isEmpty) return false;
    try {
      final actions = videoIds.map((id) => {
        'action': 'ACTION_ADD_VIDEO',
        'addedVideoId': id,
      }).toList();

      final body = {
        'context': _buildContext(withAuth: true),
        'playlistId': playlistId,
        'actions': actions,
      };

      final response = await _dio.post(
        'browse/edit_playlist',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('InnerTube: addPlaylistVideos error: $e');
      return false;
    }
  }

  /// Elimina una lista de reproducción creada o guardada de la cuenta de YouTube
  Future<bool> deletePlaylist(String playlistId) async {
    if (cookie == null || cookie!.trim().isEmpty) return false;
    final cleanPlaylistId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;

    // Intento 1: playlist/delete con WEB_REMIX (YouTube Music)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'playlistId': cleanPlaylistId,
      };
      final res = await _dio.post(
        'playlist/delete',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('InnerTube deletePlaylist error (WEB_REMIX playlist/delete): $e');
    }

    // Intento 2: playlist/delete con cliente WEB (YouTube estándar)
    try {
      final body = {
        'context': _buildContext(withAuth: true, clientName: 'WEB', clientVersion: '2.20260213.01.00'),
        'playlistId': cleanPlaylistId,
      };
      final res = await _dio.post(
        'playlist/delete',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('InnerTube deletePlaylist error (WEB playlist/delete): $e');
    }

    // Intento 3: like/removelike (en caso de ser una lista guardada en la biblioteca)
    try {
      final body = {
        'context': _buildContext(withAuth: true),
        'target': {'playlistId': cleanPlaylistId},
      };
      final res = await _dio.post(
        'like/removelike',
        data: jsonEncode(body),
        options: Options(headers: _buildHeaders(withAuth: true)),
      );
      if (res.statusCode == 200) {
        return true;
      }
    } catch (e) {
      debugPrint('InnerTube deletePlaylist fallback error (like/removelike): $e');
    }

    return false;
  }
}

