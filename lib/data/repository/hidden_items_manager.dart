import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants.dart';

class HiddenItem {
  final String path;
  final String name;
  final bool isFolder;
  final String realPath;
  final int dateHidden;

  const HiddenItem({
    required this.path,
    required this.name,
    required this.isFolder,
    this.realPath = '',
    required this.dateHidden,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'isFolder': isFolder,
    'realPath': realPath,
    'dateHidden': dateHidden,
  };

  factory HiddenItem.fromJson(Map<String, dynamic> json) => HiddenItem(
    path: json['path'] ?? '',
    name: json['name'] ?? '',
    isFolder: json['isFolder'] ?? false,
    realPath: json['realPath'] ?? '',
    dateHidden: json['dateHidden'] is int ? json['dateHidden'] : int.tryParse(json['dateHidden']?.toString() ?? '') ?? 0,
  );
}

class HiddenItemsManager extends ChangeNotifier {
  static final HiddenItemsManager instance = HiddenItemsManager._internal();
  factory HiddenItemsManager() => instance;
  HiddenItemsManager._internal() {
    _loadHiddenItems();
  }

  static const String _keyItems = AppConstants.prefsHiddenItems;

  List<HiddenItem> _hiddenItems = [];
  final Set<String> _hiddenFolderPaths = {};
  final Set<String> _hiddenAudioPaths = {};

  List<HiddenItem> get hiddenItems => _hiddenItems;

  Future<void> _loadHiddenItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyItems);
    if (jsonStr == null || jsonStr.isEmpty) return;

    try {
      final list = jsonDecode(jsonStr) as List;
      _hiddenItems = list.map((e) => HiddenItem.fromJson(e as Map<String, dynamic>)).toList();
      _hiddenFolderPaths.clear();
      _hiddenAudioPaths.clear();

      for (final item in _hiddenItems) {
        if (item.isFolder) {
          _hiddenFolderPaths.add(item.path);
        } else {
          _hiddenAudioPaths.add(item.path);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  bool isFolderHidden(String path) => _hiddenFolderPaths.contains(path);
  bool isAudioHidden(String path) => _hiddenAudioPaths.contains(path);

  Future<void> hideItem({
    required String path,
    required String name,
    required bool isFolder,
    String realPath = '',
  }) async {
    if (path.isEmpty) return;
    _hiddenItems.removeWhere((i) => i.path == path);
    final newItem = HiddenItem(
      path: path,
      name: name,
      isFolder: isFolder,
      realPath: realPath,
      dateHidden: DateTime.now().millisecondsSinceEpoch,
    );
    _hiddenItems.add(newItem);

    if (isFolder) {
      _hiddenFolderPaths.add(path);
    } else {
      _hiddenAudioPaths.add(path);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_hiddenItems.map((e) => e.toJson()).toList());
    await prefs.setString(_keyItems, jsonStr);
  }

  Future<void> unhideItem(String path) async {
    _hiddenItems.removeWhere((i) => i.path == path);
    _hiddenFolderPaths.remove(path);
    _hiddenAudioPaths.remove(path);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_hiddenItems.map((e) => e.toJson()).toList());
    await prefs.setString(_keyItems, jsonStr);
  }
}
