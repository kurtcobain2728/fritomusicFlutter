import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class CustomNamesManager extends ChangeNotifier {
  static final CustomNamesManager instance = CustomNamesManager._internal();
  factory CustomNamesManager() => instance;
  CustomNamesManager._internal() {
    _load();
  }

  static const String _keyAudioTitles = AppConstants.prefsCustomAudioTitles;
  static const String _keyFolderNames = AppConstants.prefsCustomFolderNames;

  final Map<String, String> _audioTitlesMap = {};
  final Map<String, String> _folderNamesMap = {};

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final audioJson = prefs.getString(_keyAudioTitles);
    if (audioJson != null && audioJson.isNotEmpty) {
      try {
        final map = jsonDecode(audioJson) as Map<String, dynamic>;
        _audioTitlesMap.addAll(map.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }

    final folderJson = prefs.getString(_keyFolderNames);
    if (folderJson != null && folderJson.isNotEmpty) {
      try {
        final map = jsonDecode(folderJson) as Map<String, dynamic>;
        _folderNamesMap.addAll(map.map((k, v) => MapEntry(k, v.toString())));
      } catch (_) {}
    }
    notifyListeners();
  }

  String? getCustomAudioTitle(String path) => _audioTitlesMap[path];
  String? getCustomFolderName(String path) => _folderNamesMap[path];

  Future<void> setCustomAudioTitle(String path, String customTitle) async {
    _audioTitlesMap[path] = customTitle;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAudioTitles, jsonEncode(_audioTitlesMap));
  }

  Future<void> setCustomFolderName(String path, String customName) async {
    _folderNamesMap[path] = customName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFolderNames, jsonEncode(_folderNamesMap));
  }
}
