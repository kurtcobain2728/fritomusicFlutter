import 'package:flutter/foundation.dart';
import '../data/network/innertube/innertube_models.dart';
import '../data/network/yt/youtube_repository.dart';

class OnlineLibraryProvider extends ChangeNotifier {
  final YouTubeRepository _ytRepo = YouTubeRepository.instance;

  List<SongItem> _likedSongs = [];
  Set<String> _likedSongIds = {};
  bool _isLoadingLiked = false;

  List<PlaylistItem> _onlinePlaylists = [];
  bool _isLoadingPlaylists = false;
  String? _onlineError;

  List<PlaylistItem> _featuredPlaylists = [];
  bool _isLoadingFeatured = false;

  List<ArtistItem> _subscribedArtists = [];
  bool _isLoadingSubscribed = false;

  List<SongItem> get likedSongs => _likedSongs;
  Set<String> get likedSongIds => _likedSongIds;
  bool get isLoadingLiked => _isLoadingLiked;

  List<PlaylistItem> get onlinePlaylists => _onlinePlaylists;
  bool get isLoadingPlaylists => _isLoadingPlaylists;
  String? get onlineError => _onlineError;

  List<PlaylistItem> get featuredPlaylists => _featuredPlaylists;
  bool get isLoadingFeatured => _isLoadingFeatured;

  List<ArtistItem> get subscribedArtists => _subscribedArtists;
  bool get isLoadingSubscribed => _isLoadingSubscribed;

  Future<void> loadOnlinePlaylists() async {
    _isLoadingPlaylists = true;
    _onlineError = null;
    notifyListeners();

    try {
      _onlinePlaylists = await _ytRepo.getUserPlaylists();
    } catch (e) {
      _onlineError = 'No se pudieron cargar tus listas de YouTube';
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }

    if (_featuredPlaylists.isEmpty) {
      loadFeaturedPlaylists();
    }
  }

  Future<void> loadLikedSongs({bool forceRefresh = false}) async {
    if (_isLoadingLiked) return;
    if (_likedSongs.isNotEmpty && !forceRefresh) return;

    _isLoadingLiked = true;
    notifyListeners();

    try {
      _likedSongs = await _ytRepo.getLikedSongs();
      _likedSongIds = _likedSongs.map((s) => s.id).toSet();
    } catch (e) {
      debugPrint('OnlineLibraryProvider: error al cargar canciones favoritas: $e');
    } finally {
      _isLoadingLiked = false;
      notifyListeners();
    }
  }

  Future<void> loadFeaturedPlaylists() async {
    _isLoadingFeatured = true;
    notifyListeners();

    try {
      _featuredPlaylists = await _ytRepo.getFeaturedPlaylists();
    } catch (_) {} finally {
      _isLoadingFeatured = false;
      notifyListeners();
    }
  }

  Future<void> loadSubscribedArtists({bool forceRefresh = false}) async {
    if (_isLoadingSubscribed) return;
    if (_subscribedArtists.isNotEmpty && !forceRefresh) return;

    _isLoadingSubscribed = true;
    notifyListeners();

    try {
      _subscribedArtists = await _ytRepo.getSubscribedArtists();
    } catch (e) {
      debugPrint('OnlineLibraryProvider: error al cargar artistas suscritos: $e');
    } finally {
      _isLoadingSubscribed = false;
      notifyListeners();
    }
  }

  void toggleOnlineLike(String videoId) {
    if (_likedSongIds.contains(videoId)) {
      _likedSongIds.remove(videoId);
      _likedSongs.removeWhere((s) => s.id == videoId);
    } else {
      _likedSongIds.add(videoId);
    }
    notifyListeners();
  }

  void likeSong(String videoId, bool like) {
    if (like) {
      _likedSongIds.add(videoId);
    } else {
      _likedSongIds.remove(videoId);
      _likedSongs.removeWhere((s) => s.id == videoId);
    }
    notifyListeners();
  }

  bool isLiked(String videoId) => _likedSongIds.contains(videoId);

  bool isSubscribed(String artistId) {
    final cleanId = artistId.startsWith('UC') ? artistId : 'UC$artistId';
    return _subscribedArtists.any((a) =>
        a.id == artistId ||
        a.id == cleanId ||
        (a.channelId != null && (a.channelId == cleanId || a.channelId == artistId)));
  }

  Future<bool> toggleSubscribeArtist(ArtistItem artist) async {
    final isSub = isSubscribed(artist.id);
    if (isSub) {
      return await unsubscribeArtist(artist.id);
    } else {
      return await subscribeArtist(artist);
    }
  }

  Future<bool> subscribeArtist(ArtistItem artist) async {
    final channelId = (artist.channelId != null && artist.channelId!.isNotEmpty)
        ? artist.channelId!
        : (artist.id.startsWith('UC') ? artist.id : 'UC${artist.id}');

    // Actualización optimista de la UI
    if (!_subscribedArtists.any((a) => a.id == artist.id || a.id == channelId)) {
      _subscribedArtists.insert(0, artist);
      notifyListeners();
    }

    final success = await _ytRepo.subscribeChannel(channelId);
    if (!success) {
      _subscribedArtists.removeWhere((a) => a.id == artist.id || a.id == channelId);
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> unsubscribeArtist(String artistId) async {
    final cleanId = artistId.startsWith('UC') ? artistId : 'UC$artistId';
    final existingIndex = _subscribedArtists.indexWhere((a) =>
        a.id == artistId ||
        a.id == cleanId ||
        (a.channelId != null && (a.channelId == cleanId || a.channelId == artistId)));

    ArtistItem? removed;
    if (existingIndex != -1) {
      removed = _subscribedArtists.removeAt(existingIndex);
      notifyListeners();
    }

    final success = await _ytRepo.unsubscribeChannel(cleanId);
    if (!success && removed != null) {
      _subscribedArtists.insert(existingIndex, removed);
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<bool> deleteOnlinePlaylist(String playlistId) async {
    final cleanId = playlistId.startsWith('VL') ? playlistId.substring(2) : playlistId;
    final existingIndex = _onlinePlaylists.indexWhere((p) =>
        p.id == playlistId ||
        p.id == cleanId ||
        p.id == 'VL$cleanId');

    PlaylistItem? removed;
    if (existingIndex != -1) {
      removed = _onlinePlaylists.removeAt(existingIndex);
      notifyListeners();
    }

    final success = await _ytRepo.deletePlaylist(cleanId);
    if (!success && removed != null) {
      _onlinePlaylists.insert(existingIndex, removed);
      notifyListeners();
      return false;
    }
    return true;
  }
}
