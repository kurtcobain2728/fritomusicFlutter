import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../network/innertube/innertube_models.dart';

class SpotifyLoginManager extends ChangeNotifier {
  static final SpotifyLoginManager instance = SpotifyLoginManager._internal();
  factory SpotifyLoginManager() => instance;
  SpotifyLoginManager._internal() {
    loadLogin();
  }

  static const String _keyToken = AppConstants.prefsSpotifyAccessToken;
  static const String _keyRefreshToken = AppConstants.prefsSpotifyRefreshToken;
  static const String _keyUserName = AppConstants.prefsSpotifyUserName;
  static const String _keyUserEmail = AppConstants.prefsSpotifyUserEmail;
  static const String _keyUserAvatar = AppConstants.prefsSpotifyUserAvatar;
  static const String _keyClientId = AppConstants.prefsSpotifyCustomClientId;
  static const String _keyRedirectUri = AppConstants.prefsSpotifyCustomRedirectUri;

  String _accessToken = '';
  String _refreshToken = '';
  String _userName = '';
  String _userEmail = '';
  String _userAvatar = '';
  String _clientId = '';
  String _redirectUri = 'https://open.spotify.com/';
  bool _isLoggedIn = false;

  List<SongItem> _likedSongs = [];
  bool _isLoadingLiked = false;

  List<PlaylistItem> _userPlaylists = [];
  bool _isLoadingPlaylists = false;

  List<ArtistItem> _followedArtists = [];
  bool _isLoadingFollowed = false;

  String get accessToken => _accessToken;
  String get refreshToken => _refreshToken;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String get userAvatar => _userAvatar;
  String get clientId => _clientId;
  String get redirectUri => _redirectUri;
  bool get isLoggedIn => _isLoggedIn;

  List<SongItem> get likedSongs => _likedSongs;
  bool get isLoadingLiked => _isLoadingLiked;

  List<PlaylistItem> get userPlaylists => _userPlaylists;
  bool get isLoadingPlaylists => _isLoadingPlaylists;

  List<ArtistItem> get followedArtists => _followedArtists;
  bool get isLoadingFollowed => _isLoadingFollowed;

  Future<void> saveCredentials({required String clientId, String redirectUri = 'https://open.spotify.com/'}) async {
    _clientId = clientId.trim();
    _redirectUri = redirectUri.trim().isEmpty ? 'https://open.spotify.com/' : redirectUri.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyClientId, _clientId);
    await prefs.setString(_keyRedirectUri, _redirectUri);
    notifyListeners();
  }

  Future<void> loadLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_keyToken) ?? '';
    _refreshToken = prefs.getString(_keyRefreshToken) ?? '';
    _userName = prefs.getString(_keyUserName) ?? '';
    _userEmail = prefs.getString(_keyUserEmail) ?? '';
    _userAvatar = prefs.getString(_keyUserAvatar) ?? '';
    _clientId = prefs.getString(_keyClientId) ?? '';
    _redirectUri = prefs.getString(_keyRedirectUri) ?? 'https://open.spotify.com/';
    _isLoggedIn = _accessToken.isNotEmpty;
    notifyListeners();

    if (_isLoggedIn) {
      loadLikedSongs();
      loadUserPlaylists();
      loadFollowedArtists();
    }
  }

  Future<void> saveLogin({
    required String accessToken,
    String refreshToken = '',
    String userName = '',
    String userEmail = '',
    String userAvatar = '',
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userName = userName;
    _userEmail = userEmail;
    _userAvatar = userAvatar;
    _isLoggedIn = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, accessToken);
    if (refreshToken.isNotEmpty) await prefs.setString(_keyRefreshToken, refreshToken);
    if (userName.isNotEmpty) await prefs.setString(_keyUserName, userName);
    if (userEmail.isNotEmpty) await prefs.setString(_keyUserEmail, userEmail);
    if (userAvatar.isNotEmpty) await prefs.setString(_keyUserAvatar, userAvatar);

    // Fetch user profile from Spotify API if name is empty
    if (_userName.isEmpty) {
      await fetchUserProfile();
    }

    loadLikedSongs(forceRefresh: true);
    loadUserPlaylists(forceRefresh: true);
    loadFollowedArtists(forceRefresh: true);
  }

  /// Refresca el access_token usando el refresh_token guardado (PKCE)
  Future<bool> refreshAccessToken() async {
    if (_refreshToken.isEmpty) return false;
    final id = _clientId.isNotEmpty ? _clientId : 'd8327917387a4149806b72a449767664';
    try {
      final res = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken,
          'client_id': id,
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          _accessToken = newAccess;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyToken, _accessToken);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await prefs.setString(_keyRefreshToken, _refreshToken);
          }
          notifyListeners();
          return true;
        }
      } else {
        debugPrint('Spotify refresh token error: ${res.statusCode} -> ${res.body}');
      }
    } catch (e) {
      debugPrint('Spotify refreshAccessToken exception: $e');
    }
    return false;
  }

  /// Petición autenticada con auto-refresh en caso de token expirado (401)
  Future<http.Response?> _authenticatedGet(Uri uri) async {
    if (_accessToken.isEmpty) return null;
    var res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    if (res.statusCode == 401 && _refreshToken.isNotEmpty) {
      final ok = await refreshAccessToken();
      if (ok) {
        res = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $_accessToken'},
        );
      }
    }
    return res;
  }

  Future<void> fetchUserProfile() async {
    if (_accessToken.isEmpty) return;
    try {
      final res = await _authenticatedGet(Uri.parse('https://api.spotify.com/v1/me'));
      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _userName = data['display_name'] ?? 'Usuario de Spot';
        _userEmail = data['email'] ?? '';
        final images = data['images'] as List? ?? [];
        if (images.isNotEmpty) {
          _userAvatar = images[0]['url'] ?? '';
        }
        notifyListeners();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserName, _userName);
        await prefs.setString(_keyUserEmail, _userEmail);
        await prefs.setString(_keyUserAvatar, _userAvatar);
      }
    } catch (e) {
      debugPrint('Spotify fetchUserProfile error: $e');
    }
  }

  Future<void> logout() async {
    _accessToken = '';
    _refreshToken = '';
    _userName = '';
    _userEmail = '';
    _userAvatar = '';
    _isLoggedIn = false;
    _likedSongs = [];
    _userPlaylists = [];
    _followedArtists = [];
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserAvatar);
  }

  /// Carga artistas seguidos de Spotify (/v1/me/following?type=artist)
  Future<void> loadFollowedArtists({bool forceRefresh = false}) async {
    if (_accessToken.isEmpty || _isLoadingFollowed) return;
    if (_followedArtists.isNotEmpty && !forceRefresh) return;

    _isLoadingFollowed = true;
    notifyListeners();

    try {
      final res = await _authenticatedGet(
        Uri.parse('https://api.spotify.com/v1/me/following?type=artist&limit=50'),
      );

      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['artists']?['items'] as List? ?? [];
        final parsed = <ArtistItem>[];

        for (final it in items) {
          final id = it['id'] ?? '';
          final name = it['name'] ?? '';
          final images = it['images'] as List? ?? [];
          final thumb = images.isNotEmpty ? (images[0]['url'] ?? '') : '';
          final followers = it['followers']?['total'] as int?;

          parsed.add(ArtistItem(
            id: 'spotify_artist_$id',
            title: name,
            thumbnail: thumb,
            subscriberCountText: followers != null ? '$followers seguidores' : null,
          ));
        }
        _followedArtists = parsed;
      }
    } catch (e) {
      debugPrint('Spotify loadFollowedArtists error: $e');
    } finally {
      _isLoadingFollowed = false;
      notifyListeners();
    }
  }

  /// Carga canciones favoritas ("Tus Me Gusta") de Spotify
  Future<void> loadLikedSongs({bool forceRefresh = false}) async {
    if (_accessToken.isEmpty || _isLoadingLiked) return;
    if (_likedSongs.isNotEmpty && !forceRefresh) return;

    _isLoadingLiked = true;
    notifyListeners();

    try {
      final res = await _authenticatedGet(
        Uri.parse('https://api.spotify.com/v1/me/tracks?limit=50'),
      );

      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        final parsed = <SongItem>[];

        for (final it in items) {
          final track = it['track'] as Map<String, dynamic>?;
          if (track != null) {
            final id = track['id'] ?? '';
            final title = track['name'] ?? '';
            final artistsList = (track['artists'] as List? ?? [])
                .map((a) => Artist(id: a['id'] ?? '', name: a['name'] ?? ''))
                .toList();
            final albumData = track['album'] as Map<String, dynamic>?;
            final album = albumData != null
                ? Album(id: albumData['id'] ?? '', name: albumData['name'] ?? '')
                : null;
            final images = albumData?['images'] as List? ?? [];
            final thumbnail = images.isNotEmpty ? (images[0]['url'] ?? '') : '';
            final durationMs = track['duration_ms'] as int? ?? 0;

            parsed.add(SongItem(
              id: id,
              title: title,
              artists: artistsList,
              album: album,
              duration: durationMs ~/ 1000,
              thumbnail: thumbnail,
            ));
          }
        }
        _likedSongs = parsed;
      }
    } catch (e) {
      debugPrint('Spotify loadLikedSongs error: $e');
    } finally {
      _isLoadingLiked = false;
      notifyListeners();
    }
  }

  /// Carga playlists del usuario de Spotify
  Future<void> loadUserPlaylists({bool forceRefresh = false}) async {
    if (_accessToken.isEmpty || _isLoadingPlaylists) return;
    if (_userPlaylists.isNotEmpty && !forceRefresh) return;

    _isLoadingPlaylists = true;
    notifyListeners();

    try {
      final res = await _authenticatedGet(
        Uri.parse('https://api.spotify.com/v1/me/playlists?limit=50'),
      );

      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        final parsed = <PlaylistItem>[];

        for (final it in items) {
          final id = it['id'] ?? '';
          final title = it['name'] ?? '';
          final images = it['images'] as List? ?? [];
          final thumbnail = images.isNotEmpty ? (images[0]['url'] ?? '') : '';
          final total = it['tracks']?['total'] as int? ?? 0;
          final owner = it['owner']?['display_name'] ?? 'Spot';

          parsed.add(PlaylistItem(
            id: 'spotify_$id',
            title: title,
            thumbnail: thumbnail,
            songCountText: '$total canciones',
            author: Artist(name: owner, id: ''),
          ));
        }
        _userPlaylists = parsed;
      }
    } catch (e) {
      debugPrint('Spotify loadUserPlaylists error: $e');
    } finally {
      _isLoadingPlaylists = false;
      notifyListeners();
    }
  }

  /// Obtiene canciones de una playlist de Spotify
  Future<List<SongItem>> getPlaylistTracks(String playlistId) async {
    final cleanId = playlistId.replaceAll('spotify_', '');
    if (_accessToken.isEmpty) return [];

    try {
      final res = await _authenticatedGet(
        Uri.parse('https://api.spotify.com/v1/playlists/$cleanId/tracks?limit=100'),
      );

      if (res != null && res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final items = data['items'] as List? ?? [];
        final songs = <SongItem>[];

        for (final it in items) {
          final track = it['track'] as Map<String, dynamic>?;
          if (track != null) {
            final id = track['id'] ?? '';
            final title = track['name'] ?? '';
            final artistsList = (track['artists'] as List? ?? [])
                .map((a) => Artist(id: a['id'] ?? '', name: a['name'] ?? ''))
                .toList();
            final albumData = track['album'] as Map<String, dynamic>?;
            final album = albumData != null
                ? Album(id: albumData['id'] ?? '', name: albumData['name'] ?? '')
                : null;
            final images = albumData?['images'] as List? ?? [];
            final thumbnail = images.isNotEmpty ? (images[0]['url'] ?? '') : '';
            final durationMs = track['duration_ms'] as int? ?? 0;

            songs.add(SongItem(
              id: id,
              title: title,
              artists: artistsList,
              album: album,
              duration: durationMs ~/ 1000,
              thumbnail: thumbnail,
            ));
          }
        }
        return songs;
      }
    } catch (e) {
      debugPrint('Spotify getPlaylistTracks error: $e');
    }
    return [];
  }
}
