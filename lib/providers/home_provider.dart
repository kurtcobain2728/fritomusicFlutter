import 'package:flutter/foundation.dart';
import '../data/models/audio_file.dart';
import '../data/models/folder_node.dart';
import '../data/repository/media_scanner.dart';
import '../data/repository/hidden_items_manager.dart';

class HomeProvider extends ChangeNotifier {
  final MediaScanner _scanner = MediaScanner();

  FolderNode? _rootNode;
  FolderNode? _currentNode;
  bool _isLoading = false;
  List<AudioFile> _allAudios = [];

  // Modo de selección múltiple
  bool _isSelectionMode = false;
  Set<String> _selectedFolderPaths = {};
  Set<String> _selectedAudioPaths = {};
  bool _requestDeleteMultipleEvent = false;

  FolderNode? get rootNode => _rootNode;
  FolderNode? get currentNode => _currentNode;
  bool get isLoading => _isLoading;
  List<AudioFile> get allAudios => _allAudios;

  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedFolderPaths => _selectedFolderPaths;
  Set<String> get selectedAudioPaths => _selectedAudioPaths;
  bool get requestDeleteMultipleEvent => _requestDeleteMultipleEvent;

  HomeProvider() {
    scanMusic(requestPermissionIfNeeded: false);
  }

  Future<void> scanMusic({bool requestPermissionIfNeeded = false}) async {
    if (_rootNode != null && _allAudios.isNotEmpty) return;
    await _scanInternal(requestPermissionIfNeeded: requestPermissionIfNeeded);
  }

  Future<void> rescan({bool requestPermissionIfNeeded = false}) async {
    await _scanInternal(requestPermissionIfNeeded: requestPermissionIfNeeded);
  }

  Future<void> _scanInternal({bool requestPermissionIfNeeded = false}) async {
    if (_rootNode == null) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final hasPerm = await _scanner.hasPermissions();
      if (!hasPerm) {
        if (requestPermissionIfNeeded) {
          final granted = await _scanner.checkAndRequestPermissions();
          if (!granted) return;
        } else {
          // Si no tiene permisos concedidos aún, no disparamos el diálogo del sistema
          // Esperamos a que el usuario presione el botón en la pantalla de permisos/onboarding.
          return;
        }
      }

      final root = await _scanner.scanLocalAudio();
      _rootNode = root;
      final current = _currentNode;
      if (current == null || current.path == '/' || current.path.isEmpty) {
        _currentNode = root;
      } else {
        _currentNode = _findNodeByPath(root, current.path) ?? root;
      }
      _allAudios = _flattenAudios(root);
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  FolderNode? _findNodeByPath(FolderNode node, String path) {
    if (node.path == path) return node;
    for (final sub in node.subfolders.values) {
      final found = _findNodeByPath(sub, path);
      if (found != null) return found;
    }
    return null;
  }

  List<AudioFile> _flattenAudios(FolderNode? node) {
    if (node == null) return [];
    final list = <AudioFile>[];
    void walk(FolderNode n) {
      list.addAll(n.audios);
      for (final sub in n.subfolders.values) {
        walk(sub);
      }
    }
    walk(node);
    return list;
  }

  void navigateToFolder(String folderName) {
    final current = _currentNode;
    if (current == null) return;
    final target = current.subfolders[folderName];
    if (target != null) {
      _currentNode = target;
      notifyListeners();
    }
  }

  void navigateUp() {
    final current = _currentNode;
    final root = _rootNode;
    if (current == null || root == null || current.path == root.path) return;

    final parts = current.path.split('/');
    if (parts.length > 1) {
      parts.removeLast();
      final joined = parts.join('/');
      final targetPath = joined.isEmpty ? '/' : joined;
      _currentNode = _findNodeByPath(root, targetPath) ?? root;
      notifyListeners();
    }
  }

  void enterSelectionMode({String? folderPath, String? audioPath}) {
    _selectedFolderPaths = folderPath != null ? {folderPath} : {};
    _selectedAudioPaths = audioPath != null ? {audioPath} : {};
    _isSelectionMode = true;
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedFolderPaths = {};
    _selectedAudioPaths = {};
    _requestDeleteMultipleEvent = false;
    notifyListeners();
  }

  void toggleFolder(String path) {
    if (_selectedFolderPaths.contains(path)) {
      _selectedFolderPaths.remove(path);
    } else {
      _selectedFolderPaths.add(path);
    }
    notifyListeners();
  }

  void toggleAudio(String path) {
    if (_selectedAudioPaths.contains(path)) {
      _selectedAudioPaths.remove(path);
    } else {
      _selectedAudioPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll(List<String> folderPaths, List<String> audioPaths) {
    _selectedFolderPaths = folderPaths.toSet();
    _selectedAudioPaths = audioPaths.toSet();
    notifyListeners();
  }

  void deselectAll() {
    _selectedFolderPaths = {};
    _selectedAudioPaths = {};
    notifyListeners();
  }

  void requestDeleteMultiple() {
    _requestDeleteMultipleEvent = true;
    notifyListeners();
  }

  void resetDeleteMultipleEvent() {
    _requestDeleteMultipleEvent = false;
    notifyListeners();
  }

  Future<void> hideSelected() async {
    final hiddenManager = HiddenItemsManager.instance;
    final node = _currentNode;
    if (node != null) {
      for (final f in node.subfolders.values) {
        if (_selectedFolderPaths.contains(f.path)) {
          await hiddenManager.hideItem(
            path: f.path,
            name: f.name,
            isFolder: true,
            realPath: f.realPath,
          );
        }
      }
      for (final a in node.audios) {
        if (_selectedAudioPaths.contains(a.path)) {
          await hiddenManager.hideItem(
            path: a.path,
            name: a.title,
            isFolder: false,
          );
        }
      }
    }
    exitSelectionMode();
    await rescan();
  }
}
