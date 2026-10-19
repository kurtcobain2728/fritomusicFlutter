import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/network/innertube/innertube_client.dart';
import '../data/repository/playlist_repository.dart';

class MigratedTrack {
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? coverUrl;
  final String? originalUri;
  String? resolvedVideoId;

  MigratedTrack({
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.coverUrl,
    this.originalUri,
    this.resolvedVideoId,
  });

  String get searchTitle => '$artist - $title';
}

class MigratedPlaylist {
  final String title;
  final String? description;
  final String author;
  final String? coverUrl;
  final String platform;
  final List<MigratedTrack> tracks;
  final String originalUrl;

  MigratedPlaylist({
    required this.title,
    this.description,
    required this.author,
    this.coverUrl,
    required this.platform,
    required this.tracks,
    required this.originalUrl,
  });
}

class PlaylistMigratorService {
  static final PlaylistMigratorService instance = PlaylistMigratorService._internal();
  factory PlaylistMigratorService() => instance;
  PlaylistMigratorService._internal();

  static const Map<String, String> _webHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept-Language': 'es-419,es;q=0.9,en;q=0.8',
  };

  /// Detecta la plataforma de la URL
  String detectPlatform(String url) {
    final lower = url.toLowerCase().trim();
    if (lower.contains('spotify.com')) return 'Spotify';
    if (lower.contains('deezer.com') || lower.contains('deezer.page.link')) return 'Deezer';
    if (lower.contains('music.apple.com') || lower.contains('itunes.apple.com')) return 'Apple Music';
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'YouTube Music';
    if (lower.contains('soundcloud.com')) return 'SoundCloud';
    if (lower.contains('tidal.com')) return 'Tidal';
    return 'Desconocida';
  }

  /// Analiza y extrae las canciones de una URL de playlist
  Future<MigratedPlaylist> parsePlaylistUrl(String url) async {
    final cleanUrl = url.trim();
    final platform = detectPlatform(cleanUrl);

    switch (platform) {
      case 'Spotify':
        return _parseSpotify(cleanUrl);
      case 'Deezer':
        return _parseDeezer(cleanUrl);
      case 'YouTube Music':
        return _parseYouTube(cleanUrl);
      case 'Apple Music':
        return _parseAppleMusic(cleanUrl);
      case 'SoundCloud':
        return _parseSoundCloud(cleanUrl);
      case 'Tidal':
        return _parseTidal(cleanUrl);
      default:
        throw Exception('Plataforma no reconocida. Pega un enlace de Spotify, Deezer, Apple Music, YouTube Music, SoundCloud o Tidal.');
    }
  }

  // ==========================================
  // SPOTIFY
  // ==========================================
  Future<MigratedPlaylist> _parseSpotify(String url) async {
    final uri = Uri.parse(url);
    // Extraer playlist id
    final segments = uri.pathSegments;
    final playlistIdx = segments.indexOf('playlist');
    if (playlistIdx == -1 || playlistIdx + 1 >= segments.length) {
      throw Exception('La URL no parece ser una lista de reproducción válida de Spotify.');
    }
    final playlistId = segments[playlistIdx + 1].split('?').first;
    final embedUrl = 'https://open.spotify.com/embed/playlist/$playlistId';

    final res = await http.get(Uri.parse(embedUrl), headers: _webHeaders);
    if (res.statusCode != 200) {
      throw Exception('No se pudo acceder a la lista de Spotify (código ${res.statusCode}).');
    }

    final match = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>').firstMatch(res.body);
    if (match != null) {
      try {
        final jsonStr = match.group(1);
        final data = jsonDecode(jsonStr!);
        final entity = data['props']?['pageProps']?['state']?['data']?['entity'];
        if (entity != null) {
          final title = entity['name']?.toString() ?? 'Lista de Spotify';
          final author = entity['subtitle']?.toString() ?? 'Spotify';
          final coverUrl = (entity['coverArt']?['sources'] as List?)?.firstOrNull?['url']?.toString();
          final rawTracks = entity['trackList'] as List? ?? [];

          final tracks = <MigratedTrack>[];
          for (final t in rawTracks) {
            final tTitle = t['title']?.toString();
            final tArtist = t['subtitle']?.toString();
            if (tTitle != null && tTitle.isNotEmpty) {
              tracks.add(MigratedTrack(
                title: tTitle,
                artist: tArtist ?? 'Desconocido',
                durationMs: t['duration'] is int ? t['duration'] as int : null,
                originalUri: t['uri']?.toString(),
              ));
            }
          }

          if (tracks.isNotEmpty) {
            return MigratedPlaylist(
              title: title,
              author: author,
              coverUrl: coverUrl,
              platform: 'Spotify',
              tracks: tracks,
              originalUrl: url,
            );
          }
        }
      } catch (e) {
        debugPrint('Error parseando NEXT_DATA de Spotify: $e');
      }
    }

    // Fallback: Scraping HTML de elementos oEmbed
    final oEmbedRes = await http.get(
      Uri.parse('https://open.spotify.com/oembed?url=${Uri.encodeComponent(url)}'),
      headers: _webHeaders,
    );
    if (oEmbedRes.statusCode == 200) {
      final oData = jsonDecode(oEmbedRes.body);
      final title = oData['title']?.toString();
      if (title != null && title.isNotEmpty) {
        debugPrint('Spotify oEmbed title: $title');
      }
    }

    throw Exception('No se encontraron canciones en esta lista pública de Spotify. Asegúrate de que no sea privada.');
  }

  // ==========================================
  // DEEZER
  // ==========================================
  Future<MigratedPlaylist> _parseDeezer(String url) async {
    var targetUrl = url;
    // Si es un enlace acortado deezer.page.link, seguir redirección
    if (url.contains('deezer.page.link')) {
      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(url))..followRedirects = false;
        final res = await client.send(req);
        final loc = res.headers['location'];
        if (loc != null && loc.isNotEmpty) {
          targetUrl = loc;
        }
      } finally {
        client.close();
      }
    }

    final uri = Uri.parse(targetUrl);
    final segments = uri.pathSegments;
    final playlistIdx = segments.indexOf('playlist');
    if (playlistIdx == -1 || playlistIdx + 1 >= segments.length) {
      throw Exception('La URL no contiene un ID de lista de Deezer válido.');
    }
    final playlistId = segments[playlistIdx + 1].split('?').first;

    final apiRes = await http.get(Uri.parse('https://api.deezer.com/playlist/$playlistId'));
    if (apiRes.statusCode != 200) {
      throw Exception('Error al consultar lista en Deezer (código ${apiRes.statusCode}).');
    }

    final data = jsonDecode(apiRes.body);
    if (data['error'] != null) {
      throw Exception('Deezer indicó: ${data['error']?['message'] ?? 'Lista no encontrada'}');
    }

    final title = data['title']?.toString() ?? 'Lista de Deezer';
    final author = data['creator']?['name']?.toString() ?? 'Deezer';
    final coverUrl = data['picture_xl']?.toString() ?? data['picture_medium']?.toString();
    final rawTracks = data['tracks']?['data'] as List? ?? [];

    final tracks = <MigratedTrack>[];
    for (final t in rawTracks) {
      final tTitle = t['title']?.toString();
      final tArtist = t['artist']?['name']?.toString() ?? 'Desconocido';
      final tAlbum = t['album']?['title']?.toString();
      final duration = t['duration'] is int ? (t['duration'] as int) * 1000 : null;
      if (tTitle != null && tTitle.isNotEmpty) {
        tracks.add(MigratedTrack(
          title: tTitle,
          artist: tArtist,
          album: tAlbum,
          durationMs: duration,
          originalUri: t['link']?.toString(),
        ));
      }
    }

    if (tracks.isEmpty) {
      throw Exception('La lista de Deezer está vacía o es privada.');
    }

    return MigratedPlaylist(
      title: title,
      description: data['description']?.toString(),
      author: author,
      coverUrl: coverUrl,
      platform: 'Deezer',
      tracks: tracks,
      originalUrl: url,
    );
  }

  // ==========================================
  // YOUTUBE / YOUTUBE MUSIC
  // ==========================================
  Future<MigratedPlaylist> _parseYouTube(String url) async {
    final uri = Uri.parse(url);
    final playlistId = uri.queryParameters['list'];
    if (playlistId == null || playlistId.isEmpty) {
      throw Exception('No se encontró el parámetro de lista (?list=...) en el enlace de YouTube.');
    }

    final page = await InnerTubeClient.instance.getPlaylist(playlistId);
    if (page == null) {
      throw Exception('No se pudo cargar la lista de YouTube Music. Asegúrate de que sea pública o no listada.');
    }

    final tracks = page.songs.map((s) => MigratedTrack(
      title: s.title,
      artist: s.artistNames.isNotEmpty ? s.artistNames : 'YouTube',
      album: s.album?.name,
      coverUrl: s.thumbnail,
      resolvedVideoId: s.id,
      originalUri: 'https://youtube.com/watch?v=${s.id}',
    )).toList();

    return MigratedPlaylist(
      title: page.playlist.title,
      author: (page.playlist.author?.name != null && page.playlist.author!.name.isNotEmpty)
          ? page.playlist.author!.name
          : 'YouTube',
      coverUrl: page.playlist.thumbnail,
      platform: 'YouTube Music',
      tracks: tracks,
      originalUrl: url,
    );
  }

  // ==========================================
  // APPLE MUSIC
  // ==========================================
  Future<MigratedPlaylist> _parseAppleMusic(String url) async {
    final res = await http.get(Uri.parse(url), headers: _webHeaders);
    if (res.statusCode != 200) {
      throw Exception('No se pudo acceder a la página de Apple Music (código ${res.statusCode}).');
    }

    // Extraer título y portada de OpenGraph
    final titleMatch = RegExp(r'<meta property="og:title" content="(.*?)"').firstMatch(res.body);
    final imageMatch = RegExp(r'<meta property="og:image" content="(.*?)"').firstMatch(res.body);
    final title = titleMatch?.group(1) ?? 'Lista de Apple Music';
    final coverUrl = imageMatch?.group(1);

    // Buscar Schema.org JSON-LD o meta etiquetas de canciones
    final tracks = <MigratedTrack>[];
    final jsonLdMatches = RegExp(r'<script type="application/ld\+json">(.*?)</script>', dotAll: true).allMatches(res.body);
    for (final m in jsonLdMatches) {
      try {
        final jsonText = m.group(1)?.trim();
        if (jsonText != null && jsonText.contains('MusicPlaylist')) {
          final data = jsonDecode(jsonText);
          final rawTracks = data['track'] as List? ?? [];
          for (final t in rawTracks) {
            final tName = t['name']?.toString();
            final tArtist = t['byArtist']?['name']?.toString() ?? 'Apple Music';
            if (tName != null && tName.isNotEmpty) {
              tracks.add(MigratedTrack(
                title: tName,
                artist: tArtist,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Fallback: Parsear vía regex de atributos de canciones en el HTML
    if (tracks.isEmpty) {
      final songRegex = RegExp(r'class="songs-list-row__song-name"[^>]*>([^<]+)<.*?class="songs-list-row__link"[^>]*>([^<]+)<', dotAll: true);
      for (final match in songRegex.allMatches(res.body)) {
        final sTitle = match.group(1)?.trim();
        final sArtist = match.group(2)?.trim();
        if (sTitle != null && sTitle.isNotEmpty) {
          tracks.add(MigratedTrack(title: sTitle, artist: sArtist ?? 'Desconocido'));
        }
      }
    }

    if (tracks.isEmpty) {
      throw Exception('No se pudieron extraer canciones de este enlace de Apple Music. Verifica que sea una lista pública.');
    }

    return MigratedPlaylist(
      title: title,
      author: 'Apple Music',
      coverUrl: coverUrl,
      platform: 'Apple Music',
      tracks: tracks,
      originalUrl: url,
    );
  }

  // ==========================================
  // SOUNDCLOUD
  // ==========================================
  Future<MigratedPlaylist> _parseSoundCloud(String url) async {
    final oEmbedUri = Uri.parse('https://soundcloud.com/oembed?url=${Uri.encodeComponent(url)}&format=json');
    final oRes = await http.get(oEmbedUri, headers: _webHeaders);
    if (oRes.statusCode != 200) {
      throw Exception('No se pudo acceder a la lista de SoundCloud (código ${oRes.statusCode}).');
    }

    final oData = jsonDecode(oRes.body);
    final title = oData['title']?.toString() ?? 'Lista de SoundCloud';
    final author = oData['author_name']?.toString() ?? 'SoundCloud';
    final coverUrl = oData['thumbnail_url']?.toString();

    // Obtener la página para raspar títulos de canciones
    final pageRes = await http.get(Uri.parse(url), headers: _webHeaders);
    final tracks = <MigratedTrack>[];

    if (pageRes.statusCode == 200) {
      // SoundCloud set items
      final trackRegex = RegExp(r'<article itemprop="track" itemscope[^>]*>.*?<h2 itemprop="name"><a[^>]*>(.*?)</a>.*?itemprop="byArtist"[^>]*>(.*?)</a>', dotAll: true);
      for (final m in trackRegex.allMatches(pageRes.body)) {
        final tTitle = m.group(1)?.trim();
        final tArtist = m.group(2)?.trim() ?? author;
        if (tTitle != null && tTitle.isNotEmpty) {
          tracks.add(MigratedTrack(title: tTitle, artist: tArtist));
        }
      }
    }

    if (tracks.isEmpty) {
      // Si la lista solo devolvió el título principal
      tracks.add(MigratedTrack(title: title, artist: author));
    }

    return MigratedPlaylist(
      title: title,
      author: author,
      coverUrl: coverUrl,
      platform: 'SoundCloud',
      tracks: tracks,
      originalUrl: url,
    );
  }

  // ==========================================
  // TIDAL
  // ==========================================
  Future<MigratedPlaylist> _parseTidal(String url) async {
    final res = await http.get(Uri.parse(url), headers: _webHeaders);
    if (res.statusCode != 200) {
      throw Exception('No se pudo acceder a la lista de Tidal (código ${res.statusCode}).');
    }

    final titleMatch = RegExp(r'<meta property="og:title" content="(.*?)"').firstMatch(res.body);
    final imageMatch = RegExp(r'<meta property="og:image" content="(.*?)"').firstMatch(res.body);
    final title = titleMatch?.group(1) ?? 'Lista de Tidal';
    final coverUrl = imageMatch?.group(1);

    final tracks = <MigratedTrack>[];
    // Extraer canciones vía JSON-LD
    final jsonLdMatch = RegExp(r'<script type="application/ld\+json">(.*?)</script>', dotAll: true).firstMatch(res.body);
    if (jsonLdMatch != null) {
      try {
        final data = jsonDecode(jsonLdMatch.group(1)!);
        final rawTracks = data['track'] as List? ?? [];
        for (final t in rawTracks) {
          final tName = t['name']?.toString();
          final tArtist = t['byArtist']?['name']?.toString() ?? 'Tidal';
          if (tName != null && tName.isNotEmpty) {
            tracks.add(MigratedTrack(title: tName, artist: tArtist));
          }
        }
      } catch (_) {}
    }

    if (tracks.isEmpty) {
      throw Exception('No se pudieron extraer canciones de esta lista de Tidal.');
    }

    return MigratedPlaylist(
      title: title,
      author: 'Tidal',
      coverUrl: coverUrl,
      platform: 'Tidal',
      tracks: tracks,
      originalUrl: url,
    );
  }

  // ==========================================
  // RESOLUCIÓN DE CANCIONES CON YOUTUBE MUSIC
  // ==========================================
  Future<int> resolveTracksWithYouTube(
    MigratedPlaylist playlist, {
    required void Function(int current, int total, String currentSong) onProgress,
  }) async {
    final total = playlist.tracks.length;
    var resolvedCount = 0;

    for (var i = 0; i < total; i++) {
      final track = playlist.tracks[i];
      onProgress(i + 1, total, '${track.artist} - ${track.title}');

      // Si ya tiene resolvedVideoId (ej. migrado desde YT)
      if (track.resolvedVideoId != null && track.resolvedVideoId!.isNotEmpty) {
        resolvedCount++;
        continue;
      }

      try {
        final query = '${track.artist} ${track.title}'.trim();
        final searchResults = await InnerTubeClient.instance.searchSongs(query);
        if (searchResults.isNotEmpty) {
          track.resolvedVideoId = searchResults.first.id;
          resolvedCount++;
        }
      } catch (e) {
        debugPrint('Error resolviendo canción "${track.title}": $e');
      }

      // Pequeña pausa entre peticiones para evitar rate limiting
      if (i % 5 == 0 && i > 0) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    return resolvedCount;
  }

  // ==========================================
  // GUARDAR LOCALMENTE EN FRITOMUSIC
  // ==========================================
  Future<void> saveToLocalFritoMusic(
    MigratedPlaylist playlist,
    PlaylistRepository playlistRepo,
  ) async {
    // 1. Crear playlist local
    final newPlaylist = await playlistRepo.createPlaylist(playlist.title);

    // 2. Agregar pistas con prefijo streaming o identificador
    for (final track in playlist.tracks) {
      final id = track.resolvedVideoId;
      if (id != null && id.isNotEmpty) {
        await playlistRepo.addToPlaylist(newPlaylist.id, 'yt:$id');
      } else {
        // Formato de búsqueda guardada si no se resolvió
        await playlistRepo.addToPlaylist(newPlaylist.id, 'stream:${track.artist} - ${track.title}');
      }
    }
  }

  // ==========================================
  // SINCRONIZAR CON CUENTA DE YOUTUBE MUSIC
  // ==========================================
  Future<String?> syncToYouTubeAccount(MigratedPlaylist playlist) async {
    final videoIds = playlist.tracks
        .map((t) => t.resolvedVideoId)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (videoIds.isEmpty) {
      throw Exception('No hay canciones resueltas en YouTube para crear la lista.');
    }

    final playlistId = await InnerTubeClient.instance.createPlaylist(
      playlist.title,
      description: 'Migrada desde ${playlist.platform} con FritoMusic',
      videoIds: videoIds.take(50).toList(),
    );

    if (playlistId != null && videoIds.length > 50) {
      // Agregar restantes en bloques de 50
      final remaining = videoIds.sublist(50);
      for (var i = 0; i < remaining.length; i += 50) {
        final chunk = remaining.sublist(i, (i + 50 > remaining.length) ? remaining.length : i + 50);
        await InnerTubeClient.instance.addPlaylistVideos(playlistId, chunk);
      }
    }

    return playlistId;
  }
}
