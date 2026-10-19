import 'dart:io';
import '../data/models/audio_file.dart';
import '../data/models/folder_node.dart';
import '../data/repository/custom_names_manager.dart';

class FileOperations {
  static String sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  }

  static Future<bool> renameAudio(AudioFile audio, String newTitle) async {
    final safeTitle = sanitizeFilename(newTitle);
    if (safeTitle.isEmpty) return false;

    final oldFile = File(audio.path);
    if (await oldFile.exists()) {
      try {
        final parent = oldFile.parent;
        final ext = oldFile.path.split('.').last;
        final newFile = File('${parent.path}/$safeTitle.$ext');
        if (oldFile.path != newFile.path) {
          await oldFile.rename(newFile.path);
        }
      } catch (_) {}
    }

    await CustomNamesManager.instance.setCustomAudioTitle(audio.path, safeTitle);
    return true;
  }

  static Future<bool> renameFolder(FolderNode folder, String newName) async {
    final safeName = sanitizeFilename(newName);
    if (safeName.isEmpty) return false;

    if (folder.realPath.isNotEmpty) {
      final oldDir = Directory(folder.realPath);
      if (await oldDir.exists()) {
        try {
          final parent = oldDir.parent;
          final newDir = Directory('${parent.path}/$safeName');
          if (oldDir.path != newDir.path) {
            await oldDir.rename(newDir.path);
          }
        } catch (_) {}
      }
    }

    await CustomNamesManager.instance.setCustomFolderName(folder.path, safeName);
    return true;
  }

  static Future<bool> deleteAudio(AudioFile audio) async {
    try {
      final file = File(audio.path);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteFolder(FolderNode folder) async {
    try {
      if (folder.realPath.isNotEmpty) {
        final dir = Directory(folder.realPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
