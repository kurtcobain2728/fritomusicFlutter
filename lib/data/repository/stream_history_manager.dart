import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';
import '../network/innertube/innertube_models.dart';

class StreamHistoryManager extends ChangeNotifier {
  static final StreamHistoryManager instance = StreamHistoryManager._internal();
  factory StreamHistoryManager() => instance;
  StreamHistoryManager._internal() {
    _loadHistory();
  }

  static const String _keyHistory = AppConstants.prefsRecentStreamSongs;
  static const int _maxHistoryItems = 30;

  List<SongItem> _recentSongs = [];
  List<SongItem> get recentSongs => _recentSongs;

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyHistory);
    if (jsonStr == null || jsonStr.isEmpty) return;

    try {
      final list = jsonDecode(jsonStr) as List;
      _recentSongs = list.map((e) => SongItem.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> recordSong(SongItem song) async {
    if (song.id.isEmpty) return;
    _recentSongs.removeWhere((s) => s.id == song.id);
    _recentSongs.insert(0, song);
    if (_recentSongs.length > _maxHistoryItems) {
      _recentSongs = _recentSongs.sublist(0, _maxHistoryItems);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_recentSongs.map((s) => s.toJson()).toList());
    await prefs.setString(_keyHistory, jsonStr);
  }

  Future<void> clearHistory() async {
    _recentSongs.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }
}
