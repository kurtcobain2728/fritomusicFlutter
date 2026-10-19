import 'audio_file.dart';

class FolderNode {
  final String name;
  final String path;
  String realPath;
  final Map<String, FolderNode> subfolders;
  final List<AudioFile> audios;

  FolderNode({
    required this.name,
    required this.path,
    this.realPath = '',
    Map<String, FolderNode>? subfolders,
    List<AudioFile>? audios,
  })  : subfolders = subfolders ?? {},
        audios = audios ?? [];

  /// Cuenta cuántos audios hay en esta carpeta y todas sus subcarpetas recursivamente
  int getTotalAudioCount() {
    int count = audios.length;
    for (final subfolder in subfolders.values) {
      count += subfolder.getTotalAudioCount();
    }
    return count;
  }
}
