import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../network/innertube/innertube_models.dart';

class FavoriteArtistsManager extends ChangeNotifier {
  static final FavoriteArtistsManager instance = FavoriteArtistsManager._internal();
  factory FavoriteArtistsManager() => instance;
  FavoriteArtistsManager._internal() {
    _loadFavorites();
  }

  static const String _keyArtists = AppConstants.prefsFavoriteArtists;
  List<ArtistItem> _favoriteArtists = [];

  List<ArtistItem> get favoriteArtists => _favoriteArtists;

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyArtists);
    if (jsonStr == null || jsonStr.isEmpty) return;

    try {
      final list = jsonDecode(jsonStr) as List;
      _favoriteArtists = list.map((e) => ArtistItem.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  bool isFavorite(String artistId) {
    if (artistId.isEmpty) return false;
    return _favoriteArtists.any((a) => a.id == artistId);
  }

  Future<void> toggleFavorite(ArtistItem artist) async {
    if (artist.id.isEmpty) return;
    final index = _favoriteArtists.indexWhere((a) => a.id == artist.id);
    if (index >= 0) {
      _favoriteArtists.removeAt(index);
    } else {
      _favoriteArtists.insert(0, artist);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_favoriteArtists.map((a) => a.toJson()).toList());
    await prefs.setString(_keyArtists, jsonStr);
  }

  Future<void> removeFavorite(String artistId) async {
    if (artistId.isEmpty) return;
    _favoriteArtists.removeWhere((a) => a.id == artistId);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_favoriteArtists.map((a) => a.toJson()).toList());
    await prefs.setString(_keyArtists, jsonStr);
  }
}
