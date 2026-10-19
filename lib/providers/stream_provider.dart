import 'package:flutter/foundation.dart';
import '../data/models/audio_file.dart';
import '../data/models/home_shelf.dart';
import '../data/models/streamable_track.dart';
import '../data/network/innertube/innertube_models.dart';
import '../data/network/yt/youtube_repository.dart';
import '../data/repository/favorite_artists_manager.dart';
import '../data/repository/stream_history_manager.dart';
import '../data/repository/spotify_login_manager.dart';
import '../data/repository/youtube_login_manager.dart';
import 'player_provider.dart';

class StreamProvider extends ChangeNotifier {
  final YouTubeRepository _ytRepo = YouTubeRepository.instance;
  final StreamHistoryManager _historyManager = StreamHistoryManager.instance;

  List<StreamableTrack>? _searchResults;
  List<ArtistItem>? _artistResults;
  List<PlaylistItem>? _playlistResults;
  List<String> _searchSuggestions = [];
  bool _isSearching = false;
  String? _errorMessage;
  String? _playbackError;

  List<HomeShelf> _homeShelves = [];
  bool _isLoadingHome = false;
  HomePage? _homePage;
  ExplorePage? _explorePage;

  ArtistPageData? _selectedArtist;
  AlbumPageData? _selectedAlbum;
  PlaylistPageData? _selectedPlaylist;
  bool _isLoadingDetail = false;

  // Listas de YouTube del usuario
  List<PlaylistItem> _userPlaylists = [];
  bool _isLoadingPlaylists = false;

  // Artistas paginados para "Artistas para ti" / "Ver todo" (descubrimiento infinito como en Kotlin)
  List<ArtistItem> _paginatedArtists = [];
  final List<String> _artistDiscoveryQueue = [];
  final Set<String> _seenArtistIds = {};
  bool _isLoadingMoreArtists = false;
  bool _isRefreshingArtists = false;

  List<StreamableTrack>? get searchResults => _searchResults;
  List<ArtistItem>? get artistResults => _artistResults;
  List<PlaylistItem>? get playlistResults => _playlistResults;
  List<String> get searchSuggestions => _searchSuggestions;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;
  String? get playbackError => _playbackError;

  List<HomeShelf> get homeShelves => _homeShelves;
  bool get isLoadingHome => _isLoadingHome;
  HomePage? get homePage => _homePage;
  ExplorePage? get explorePage => _explorePage;
  List<SongItem> get recentlyPlayed => _historyManager.recentSongs;

  ArtistPageData? get selectedArtist => _selectedArtist;
  AlbumPageData? get selectedAlbum => _selectedAlbum;
  PlaylistPageData? get selectedPlaylist => _selectedPlaylist;
  bool get isLoadingDetail => _isLoadingDetail;

  List<PlaylistItem> get userPlaylists => _userPlaylists;
  bool get isLoadingPlaylists => _isLoadingPlaylists;

  List<PlaylistItem> _featuredPlaylists = [];
  bool _isLoadingFeatured = false;
  List<PlaylistItem> get featuredPlaylists => _featuredPlaylists;
  bool get isLoadingFeatured => _isLoadingFeatured;

  List<ArtistItem> get paginatedArtists => _paginatedArtists;
  bool get isLoadingMoreArtists => _isLoadingMoreArtists;
  bool get isRefreshingArtists => _isRefreshingArtists;

  StreamProvider() {
    loadHomeContent();
  }

  /// Carga estrictamente las 3 secciones requeridas al abrir Stream:
  /// 1. Vuelve a escuchar
  /// 2. Recomendados para ti (basado en los likes y canciones favoritas)
  /// 3. Artistas para ti (con su botón de ver todo)
  Future<void> loadHomeContent({bool forceRefresh = false}) async {
    _isLoadingHome = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final futures = await Future.wait([
        _ytRepo.getHome(),
        _ytRepo.getMusicHistory(),
        _ytRepo.getLikedSongs(),
      ]);

      final rawShelves = futures[0] as List<Map<String, dynamic>>;
      final remoteHistory = futures[1] as List<SongItem>;
      final likedSongs = futures[2] as List<SongItem>;
      final localHistory = _historyManager.recentSongs;

      // ── 1. "Vuelve a escuchar" (historial combinado local + remoto sin duplicados) ──
      final historyCombined = <SongItem>[];
      for (final song in [...localHistory, ...remoteHistory]) {
        if (!historyCombined.any((s) => s.id == song.id)) {
          historyCombined.add(song);
        }
      }

      final shelves = <HomeShelf>[];

      if (historyCombined.isNotEmpty) {
        shelves.add(HomeShelf(
          id: 'recently_played',
          title: 'Vuelve a escuchar',
          items: historyCombined.take(20).toList(),
        ));
      }

      // ── 2. "Recomendados para ti" (basado en los likes y favoritos del usuario) ──
      final recommendedSongs = <SongItem>[];
      final knownIds = <String>{
        ...historyCombined.map((s) => s.id),
        ...likedSongs.map((s) => s.id),
      };

      // Extraer canciones recomendadas desde Home de YouTube
      for (final s in rawShelves) {
        final items = (s['items'] as List<YTItem>?) ?? [];
        for (final it in items) {
          if (it is SongItem && !knownIds.contains(it.id) && !recommendedSongs.any((x) => x.id == it.id)) {
            recommendedSongs.add(it);
          }
        }
      }

      // Si hay pocas canciones o para enriquecer según gustos, consultar radio de la semilla (like o historia)
      final seedSong = likedSongs.isNotEmpty ? likedSongs.first : (historyCombined.isNotEmpty ? historyCombined.first : null);
      if (recommendedSongs.length < 15 && seedSong != null) {
        try {
          final nextSongs = await _ytRepo.getNext(videoId: seedSong.id);
          for (final s in nextSongs) {
            if (!knownIds.contains(s.id) && !recommendedSongs.any((x) => x.id == s.id)) {
              recommendedSongs.add(s);
            }
          }
        } catch (_) {}
      }

      final finalRecommendations = (recommendedSongs..shuffle()).take(20).toList();
      if (finalRecommendations.isNotEmpty) {
        shelves.add(HomeShelf(
          id: 'recommendations',
          title: 'Recomendados para ti',
          items: finalRecommendations,
        ));
      }

      // ── 3. "Artistas para ti" (con botón "Ver todo" como en Kotlin) ──
      final candidateArtists = <ArtistItem>[];
      final favArtists = FavoriteArtistsManager.instance.favoriteArtists;
      final favArtistIds = favArtists.map((a) => a.id).toSet();

      // Artistas directos de Home
      for (final s in rawShelves) {
        final items = (s['items'] as List<YTItem>?) ?? [];
        for (final it in items) {
          if (it is ArtistItem && it.thumbnail != null && it.thumbnail!.isNotEmpty) {
            if (!candidateArtists.any((a) => a.id == it.id) && !favArtistIds.contains(it.id)) {
              candidateArtists.add(it);
            }
          }
        }
      }

      // Extraer semillas de favoritos, historial de reproducción y likes
      final seedArtistIds = <String>[
        ...favArtists.map((a) => a.id),
        ...historyCombined.expand((s) => s.artists).map((a) => a.id ?? ''),
        ...likedSongs.expand((s) => s.artists).map((a) => a.id ?? ''),
      ].where((id) => id.isNotEmpty).toSet().take(6).toList();

      final seedArtistNames = <String>[
        ...favArtists.map((a) => a.title),
        ...historyCombined.expand((s) => s.artists).map((a) => a.name),
        ...likedSongs.expand((s) => s.artists).map((a) => a.name),
      ].where((name) => name.isNotEmpty).toSet().take(6).toList();

      // Consultar artistas relacionados de YouTube Music
      if (seedArtistIds.isNotEmpty) {
        try {
          final relatedResults = await Future.wait(
            seedArtistIds.take(3).map((id) => _ytRepo.getRelatedArtists(id)),
          );
          for (final list in relatedResults) {
            for (final a in list) {
              if (a.thumbnail != null &&
                  a.thumbnail!.isNotEmpty &&
                  !candidateArtists.any((x) => x.id == a.id) &&
                  !favArtistIds.contains(a.id)) {
                candidateArtists.add(a);
              }
            }
          }
        } catch (_) {}
      }

      // Complementar con búsquedas por nombre de artista si faltan
      if (candidateArtists.length < 15 && seedArtistNames.isNotEmpty) {
        try {
          final extraSearches = await Future.wait(
            seedArtistNames.take(3).map((name) => _ytRepo.searchArtists(name)),
          );
          for (final list in extraSearches) {
            for (final a in list) {
              if (a.thumbnail != null &&
                  a.thumbnail!.isNotEmpty &&
                  !candidateArtists.any((x) => x.id == a.id) &&
                  !favArtistIds.contains(a.id)) {
                candidateArtists.add(a);
              }
            }
          }
        } catch (_) {}
      }

      final popularArtists = (candidateArtists..shuffle()).take(20).toList();
      if (popularArtists.isNotEmpty) {
        shelves.add(HomeShelf(
          id: 'popular_artists',
          title: 'Artistas para ti',
          items: popularArtists,
        ));
      }

      // ── ESTRICTAMENTE LAS 3 SECCIONES (Sin secciones adicionales que saturen la vista) ──
      _homeShelves = shelves;

      // Inicializar descubrimiento paginado de artistas para la pantalla "Ver todo"
      initPaginatedArtists(forceRefresh: forceRefresh);

      // Cargar listas destacadas y listas de usuario
      loadFeaturedPlaylists(forceRefresh: forceRefresh);
      if (YouTubeLoginManager.instance.isLoggedIn) {
        loadUserPlaylists();
      }
    } catch (e) {
      _errorMessage = 'No se pudo cargar el inicio de Stream';
    } finally {
      _isLoadingHome = false;
      notifyListeners();
    }
  }

  /// Carga las listas de reproducción destacadas y populares de YouTube Music
  Future<void> loadFeaturedPlaylists({bool forceRefresh = false}) async {
    if (!forceRefresh && _featuredPlaylists.isNotEmpty) return;
    _isLoadingFeatured = true;
    notifyListeners();

    try {
      final list = await _ytRepo.getFeaturedPlaylists();
      if (list.isNotEmpty) {
        _featuredPlaylists = list;
      }
    } catch (e) {
      debugPrint('StreamProvider: error al cargar listas destacadas: $e');
    } finally {
      _isLoadingFeatured = false;
      notifyListeners();
    }
  }

  /// Carga las listas de reproducción de la cuenta de YouTube del usuario
  Future<void> loadUserPlaylists() async {
    if (!YouTubeLoginManager.instance.isLoggedIn) return;
    _isLoadingPlaylists = true;
    notifyListeners();

    try {
      final playlists = await _ytRepo.getUserPlaylists();
      _userPlaylists = playlists;
    } catch (e) {
      debugPrint('StreamProvider: error al cargar listas de YouTube: $e');
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  /// Elimina una lista de reproducción del usuario de YouTube
  Future<bool> deleteUserPlaylist(String playlistId) async {
    final cleanId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
    final existingIndex = _userPlaylists.indexWhere((p) =>
        p.id == playlistId ||
        p.id == cleanId ||
        p.id == 'VL$cleanId');

    PlaylistItem? removed;
    if (existingIndex != -1) {
      removed = _userPlaylists.removeAt(existingIndex);
      notifyListeners();
    }

    final success = await _ytRepo.deletePlaylist(cleanId);
    if (!success && removed != null) {
      _userPlaylists.insert(existingIndex, removed);
      notifyListeners();
      return false;
    }
    return true;
  }

  /// Inicializa la lista paginada de "Artistas para ti" con artistas semilla y recomendaciones sin límite (igual a Kotlin)
  Future<void> initPaginatedArtists({bool forceRefresh = false}) async {
    if (!forceRefresh && _paginatedArtists.isNotEmpty) return;

    _isRefreshingArtists = true;
    notifyListeners();

    try {
      final favs = FavoriteArtistsManager.instance.favoriteArtists;
      final favIds = favs.map((a) => a.id).toSet();
      final historySeeds = recentlyPlayed.expand((s) => s.artists).map((a) => a.id ?? '').where((id) => id.isNotEmpty).toList();
      final homeArtists = <String>[];
      for (final s in _homeShelves) {
        for (final it in s.items) {
          if (it is ArtistItem && it.id.isNotEmpty) homeArtists.add(it.id);
        }
      }

      _artistDiscoveryQueue.clear();
      _seenArtistIds.clear();
      _seenArtistIds.addAll(favIds);

      final seeds = <String>{
        ...favs.map((a) => a.id),
        ...historySeeds,
        ...homeArtists,
      }.where((id) => id.isNotEmpty).toList()..shuffle();

      _artistDiscoveryQueue.addAll(seeds);

      final initialList = <ArtistItem>[];
      var attempts = 0;
      while (initialList.length < 24 && attempts < 8 && _artistDiscoveryQueue.isNotEmpty) {
        attempts++;
        final seed = _artistDiscoveryQueue.removeAt(0);
        final related = await _ytRepo.getRelatedArtists(seed);
        for (final artist in related) {
          if (!favIds.contains(artist.id) &&
              !_seenArtistIds.contains(artist.id) &&
              artist.thumbnail != null &&
              artist.thumbnail!.isNotEmpty) {
            _seenArtistIds.add(artist.id);
            initialList.add(artist);
            _artistDiscoveryQueue.add(artist.id);
          }
        }
      }

      // Si la cola inicial no dio suficientes, buscar por nombres
      if (initialList.length < 18) {
        final names = <String>[
          ...recentlyPlayed.expand((s) => s.artists).map((a) => a.name),
          ...favs.map((a) => a.title),
        ].where((n) => n.isNotEmpty).toSet().take(6);

        for (final name in names) {
          final searched = await _ytRepo.searchArtists(name);
          for (final a in searched) {
            if (!favIds.contains(a.id) &&
                !_seenArtistIds.contains(a.id) &&
                a.thumbnail != null &&
                a.thumbnail!.isNotEmpty) {
              _seenArtistIds.add(a.id);
              initialList.add(a);
              _artistDiscoveryQueue.add(a.id);
            }
          }
        }
      }

      _paginatedArtists = initialList;
    } catch (_) {} finally {
      _isRefreshingArtists = false;
      notifyListeners();
    }
  }

  /// Carga más artistas similares de manera infinita a medida que el usuario hace scroll hacia abajo en "Ver todo"
  Future<void> loadMoreArtists() async {
    if (_isLoadingMoreArtists || _isRefreshingArtists) return;

    _isLoadingMoreArtists = true;
    notifyListeners();

    try {
      final newArtists = <ArtistItem>[];
      var attempts = 0;
      final favIds = FavoriteArtistsManager.instance.favoriteArtists.map((a) => a.id).toSet();

      while (newArtists.length < 18 && attempts < 6 && _artistDiscoveryQueue.isNotEmpty) {
        attempts++;
        final seed = _artistDiscoveryQueue.removeAt(0);
        final related = await _ytRepo.getRelatedArtists(seed);
        for (final artist in related) {
          if (!favIds.contains(artist.id) &&
              !_seenArtistIds.contains(artist.id) &&
              artist.thumbnail != null &&
              artist.thumbnail!.isNotEmpty) {
            _seenArtistIds.add(artist.id);
            newArtists.add(artist);
            _artistDiscoveryQueue.add(artist.id);
          }
        }
      }

      if (newArtists.isEmpty && _paginatedArtists.isNotEmpty) {
        final lastQueries = _paginatedArtists.reversed.take(4).map((a) => a.title);
        for (final q in lastQueries) {
          final res = await _ytRepo.searchArtists(q);
          for (final a in res) {
            if (!favIds.contains(a.id) &&
                !_seenArtistIds.contains(a.id) &&
                a.thumbnail != null &&
                a.thumbnail!.isNotEmpty) {
              _seenArtistIds.add(a.id);
              newArtists.add(a);
              _artistDiscoveryQueue.add(a.id);
            }
          }
        }
      }

      if (newArtists.isNotEmpty) {
        _paginatedArtists = [..._paginatedArtists, ...newArtists];
      }
    } catch (_) {} finally {
      _isLoadingMoreArtists = false;
      notifyListeners();
    }
  }

  Future<void> refreshRecommendedArtists() async {
    await initPaginatedArtists(forceRefresh: true);
  }

  Future<void> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      clearSearch();
      return;
    }

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _ytRepo.searchSongs(cleanQuery),
        _ytRepo.searchArtists(cleanQuery),
        _ytRepo.searchPlaylists(cleanQuery),
      ]);

      final songs = results[0] as List<SongItem>;
      final artists = results[1] as List<ArtistItem>;
      final playlists = results[2] as List<PlaylistItem>;

      _searchResults = songs.map((s) => s.toStreamableTrack()).toList();
      _artistResults = artists;
      _playlistResults = playlists;
    } catch (e) {
      _errorMessage = 'Error en la búsqueda';
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      _searchSuggestions = [];
      notifyListeners();
      return;
    }
    _searchSuggestions = await _ytRepo.getSearchSuggestions(query);
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = null;
    _artistResults = null;
    _playlistResults = null;
    _searchSuggestions = [];
    _isSearching = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearPlaybackError() {
    _playbackError = null;
    notifyListeners();
  }

  Future<void> loadArtist(String artistId) async {
    _isLoadingDetail = true;
    _selectedArtist = null;
    notifyListeners();

    _selectedArtist = await _ytRepo.getArtist(artistId);
    _isLoadingDetail = false;
    notifyListeners();
  }

  Future<void> loadAlbum(String browseId) async {
    _isLoadingDetail = true;
    _selectedAlbum = null;
    notifyListeners();

    _selectedAlbum = await _ytRepo.getAlbum(browseId);
    _isLoadingDetail = false;
    notifyListeners();
  }

  Future<void> loadPlaylist(String playlistId) async {
    _isLoadingDetail = true;
    _selectedPlaylist = null;
    notifyListeners();

    if (playlistId.startsWith('spotify_')) {
      final tracks = await SpotifyLoginManager.instance.getPlaylistTracks(playlistId);
      final spotPl = SpotifyLoginManager.instance.userPlaylists.firstWhere(
        (p) => p.id == playlistId,
        orElse: () => PlaylistItem(
          id: playlistId,
          title: 'Playlist de Spotify',
          thumbnail: tracks.isNotEmpty ? tracks.first.thumbnail : null,
          songCountText: '${tracks.length} canciones',
        ),
      );
      _selectedPlaylist = PlaylistPageData(
        playlist: spotPl,
        songs: tracks,
      );
    } else {
      _selectedPlaylist = await _ytRepo.getPlaylist(playlistId);
    }
    _isLoadingDetail = false;
    notifyListeners();
  }

  Future<void> playTrack(
    StreamableTrack track,
    PlayerProvider playerProvider, {
    List<StreamableTrack>? queue,
  }) async {
    _playbackError = null;

    final audioFile = track.toAudioFile('yt://${track.videoId}');
    List<AudioFile>? newQueue;
    if (queue != null && queue.isNotEmpty) {
      newQueue = queue.map((t) => t.videoId == track.videoId ? audioFile : t.toAudioFile('yt://${t.videoId}')).toList();
    }

    _historyManager.recordSong(SongItem(
      id: track.videoId,
      title: track.title,
      artists: [Artist(name: track.artist)],
      thumbnail: track.thumbnailUrl,
      duration: track.durationMs ~/ 1000,
    ));

    try {
      await playerProvider.playAudio(audioFile, newQueue: newQueue, videoId: track.videoId);
    } catch (e) {
      _playbackError = 'Error al reproducir: $e';
      notifyListeners();
    }
  }

  Future<void> playArtistSong(
    SongItem song,
    PlayerProvider playerProvider, {
    List<SongItem>? queueSongs,
  }) async {
    final track = song.toStreamableTrack();
    final queue = queueSongs?.map((s) => s.toStreamableTrack()).toList();
    await playTrack(track, playerProvider, queue: queue);
  }

  Future<void> playAlbumSong(
    SongItem song,
    PlayerProvider playerProvider, {
    List<SongItem>? queueSongs,
  }) async {
    final track = song.toStreamableTrack();
    final queue = queueSongs?.map((s) => s.toStreamableTrack()).toList();
    await playTrack(track, playerProvider, queue: queue);
  }

  Future<String?> findArtistIdByName(String artistName) async {
    final clean = artistName.replaceAll(RegExp(r'\s*-\s*topic\b', caseSensitive: false), '').replaceAll(RegExp(r'\s*vevo\b', caseSensitive: false), '').trim();
    if (clean.isEmpty) return null;
    try {
      final results = await _ytRepo.search(clean, filter: 'artists');
      for (final r in results) {
        if (r is ArtistItem && r.id.isNotEmpty) return r.id;
      }
    } catch (_) {}
    return null;
  }

  Future<List<ArtistItem>> getRelatedArtists(String artistName, String currentArtistId) async {
    final clean = artistName.replaceAll(RegExp(r'\s*-\s*topic\b', caseSensitive: false), '').replaceAll(RegExp(r'\s*vevo\b', caseSensitive: false), '').trim();
    if (clean.isEmpty) return [];
    try {
      final results = await _ytRepo.search(clean, filter: 'artists');
      return results
          .whereType<ArtistItem>()
          .where((a) => a.id != currentArtistId && a.thumbnail != null && a.thumbnail!.isNotEmpty)
          .take(15)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> playStreamableTrack(
    StreamableTrack track,
    PlayerProvider playerProvider, {
    List<StreamableTrack>? queue,
  }) async {
    await playTrack(track, playerProvider, queue: queue);
    return _playbackError == null;
  }
}
