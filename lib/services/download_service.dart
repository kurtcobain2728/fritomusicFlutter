import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../data/models/download_task.dart';
import '../data/network/yt/stream_client_utils.dart';
import '../data/network/yt/youtube_repository.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService instance = DownloadService._internal();
  factory DownloadService() => instance;
  DownloadService._internal();

  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => _tasks;

  static const MethodChannel _platformChannel = MethodChannel(AppConstants.platformChannel);

  Future<void> enqueueDownload({
    required String videoId,
    required String title,
    required String artist,
    String? album,
    String? thumbnailUrl,
    String quality = '320kbps',
  }) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final task = DownloadTask(
      taskId: taskId,
      videoId: videoId,
      title: title,
      artist: artist,
      album: album,
      thumbnailUrl: thumbnailUrl,
      savePath: '',
      status: DownloadStatus.enqueued,
      quality: quality,
    );

    _tasks.insert(0, task);
    notifyListeners();

    _startDownload(task);
  }

  Future<void> _startDownload(DownloadTask task) async {
    final index = _tasks.indexWhere((t) => t.taskId == task.taskId);
    if (index == -1) return;

    try {
      _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.running, progress: 10);
      notifyListeners();

      // 1. Permisos en Android
      if (Platform.isAndroid) {
        try {
          await [Permission.storage, Permission.audio].request();
        } catch (_) {}
      }

      // 2. Resolver URL de stream de YouTube
      final streamUrl = await YouTubeRepository.instance.getStreamUrl(task.videoId, title: task.title, artist: task.artist);
      if (streamUrl == null || streamUrl.isEmpty) {
        debugPrint('[DownloadService] No se pudo resolver URL de stream para ${task.videoId}');
        _tasks[index] = _tasks[index].copyWith(status: DownloadStatus.failed);
        notifyListeners();
        return;
      }

      // 3. Obtener directorio de almacenamiento seguro compatible con Scoped Storage
      Directory? baseDir;
      if (Platform.isAndroid) {
        final publicMusic = Directory('/storage/emulated/0/Music/FritoMusic');
        try {
          if (!await publicMusic.exists()) {
            await publicMusic.create(recursive: true);
          }
          baseDir = publicMusic;
        } catch (_) {
          try {
            final extDirs = await getExternalStorageDirectories(type: StorageDirectory.music);
            if (extDirs != null && extDirs.isNotEmpty) {
              baseDir = extDirs.first;
            }
          } catch (_) {}
          baseDir ??= await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      if (!await baseDir.exists()) {
        await baseDir.create(recursive: true);
      }

      final safeArtist = task.artist.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final safeTitle = task.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final targetFile = File('${baseDir.path}/$safeArtist - $safeTitle.m4a');
      final tempFile = File('${baseDir.path}/.temp_${task.taskId}.m4a');

      _tasks[index] = _tasks[index].copyWith(savePath: targetFile.path, progress: 20);
      notifyListeners();

      // 4. Descargar usando HttpClient con cabeceras requeridas de GoogleVideo
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..idleTimeout = const Duration(seconds: 30);

      final req = await client.getUrl(Uri.parse(streamUrl));
      if (StreamClientUtils.isYouTubeMediaHost(Uri.parse(streamUrl).host)) {
        final profile = StreamClientUtils.resolveRequestProfile(streamUrl);
        profile.headers.forEach((k, v) => req.headers.set(k, v));
      } else {
        req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      }

      final resp = await req.close();
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        client.close(force: true);
        throw HttpException('HTTP ${resp.statusCode}: Error en la descarga del stream');
      }

      final totalBytes = resp.contentLength;
      final sink = tempFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in resp) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final pct = 20 + ((receivedBytes / totalBytes) * 75).round();
          final currIdx = _tasks.indexWhere((t) => t.taskId == task.taskId);
          if (currIdx != -1 && _tasks[currIdx].progress != pct) {
            _tasks[currIdx] = _tasks[currIdx].copyWith(progress: pct.clamp(20, 95));
            notifyListeners();
          }
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // 5. Verificar integridad del archivo descargado
      if (!await tempFile.exists() || await tempFile.length() == 0) {
        if (await tempFile.exists()) await tempFile.delete();
        throw Exception('El archivo descargado está vacío');
      }

      // Mover al nombre definitivo
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      // 6. Notificar a Android MediaScanner para que la pista aparezca de inmediato en la biblioteca
      if (Platform.isAndroid) {
        try {
          await _platformChannel.invokeMethod('scanFile', {'path': targetFile.path});
        } catch (_) {}
      }

      final finalIdx = _tasks.indexWhere((t) => t.taskId == task.taskId);
      if (finalIdx != -1) {
        _tasks[finalIdx] = _tasks[finalIdx].copyWith(
          status: DownloadStatus.complete,
          progress: 100,
          savePath: targetFile.path,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DownloadService] Error en descarga para ${task.title}: $e');
      final failIdx = _tasks.indexWhere((t) => t.taskId == task.taskId);
      if (failIdx != -1) {
        _tasks[failIdx] = _tasks[failIdx].copyWith(status: DownloadStatus.failed);
        notifyListeners();
      }
    }
  }

  void removeTask(String taskId) {
    _tasks.removeWhere((t) => t.taskId == taskId);
    notifyListeners();
  }
}
