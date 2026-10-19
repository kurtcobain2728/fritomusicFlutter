import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../models/playlist.dart';

class PlaylistRepository extends ChangeNotifier {
  static const String _keyPlaylists = AppConstants.prefsPlaylistsData;
  List<Playlist> _playlists = [];

  List<Playlist> get playlists => _playlists;

  PlaylistRepository() {
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyPlaylists) ?? '[]';
    try {
      final list = jsonDecode(jsonString) as List;
      _playlists = list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_playlists.map((e) => e.toJson()).toList());
    await prefs.setString(_keyPlaylists, jsonString);
    notifyListeners();
  }

  Future<Playlist> createPlaylist(String name) async {
    final newPlaylist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      audioPaths: [],
    );
    _playlists.add(newPlaylist);
    await _savePlaylists();
    return newPlaylist;
  }

  Future<void> addToPlaylist(String playlistId, String audioPath) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      if (!playlist.audioPaths.contains(audioPath)) {
        final newPaths = List<String>.from(playlist.audioPaths)..add(audioPath);
        _playlists[index] = Playlist(id: playlist.id, name: playlist.name, audioPaths: newPaths);
        await _savePlaylists();
      }
    }
  }

  Future<void> removeFromPlaylist(String playlistId, String audioPath) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final playlist = _playlists[index];
      final newPaths = List<String>.from(playlist.audioPaths)..remove(audioPath);
      _playlists[index] = Playlist(id: playlist.id, name: playlist.name, audioPaths: newPaths);
      await _savePlaylists();
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _savePlaylists();
  }
}
