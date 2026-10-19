import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class FavoritesRepository extends ChangeNotifier {
  static const String _keyFavorites = AppConstants.prefsFavoritePaths;
  Set<String> _favorites = {};

  Set<String> get favorites => _favorites;

  FavoritesRepository() {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyFavorites);
    if (list != null) {
      _favorites = list.toSet();
      notifyListeners();
    }
  }

  bool isFavorite(String path) {
    return _favorites.contains(path);
  }

  Future<void> toggleFavorite(String path) async {
    if (_favorites.contains(path)) {
      _favorites.remove(path);
    } else {
      _favorites.add(path);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavorites, _favorites.toList());
  }
}
