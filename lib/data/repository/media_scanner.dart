import 'dart:io';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/audio_file.dart';
import '../models/folder_node.dart';
import 'custom_names_manager.dart';

class MediaScanner {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final Map<String, String?> _folderCoversCache = {};

  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      return (await Permission.audio.isGranted || await Permission.storage.isGranted);
    }
    return true;
  }

  Future<bool> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
        return true;
      }
      final status = await Permission.audio.request();
      if (status.isGranted) return true;
      final storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
    return true;
  }

  Future<FolderNode> scanLocalAudio() async {
    final rootNode = FolderNode(name: 'Dispositivo', path: '/');
    _folderCoversCache.clear();

    try {
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      for (final song in songs) {
        final path = song.data;
        if (path.contains('/Android/') ||
            path.contains('/Alarms/') ||
            path.contains('/Notifications/') ||
            path.contains('/Ringtones/')) {
          continue;
        }

        final file = File(path);
        final parentDir = file.parent;
        final isFritoMusic = path.toLowerCase().contains('/fritomusic/');

        // 1. Inferencia de metadatos (Algoritmo portado fielmente de Kotlin)
        String rawArtist = song.artist ?? '';
        String rawTitle = song.title;
        String rawAlbum = song.album ?? '';

        String finalArtist;
        String finalTitle;
        String finalAlbum;
        String? resolvedAlbumUri;

        final isArtistUnknown = rawArtist.isEmpty ||
            rawArtist.toLowerCase() == '<unknown>' ||
            rawArtist.toLowerCase() == 'artista desconocido' ||
            rawArtist.toLowerCase() == 'unknown artist' ||
            rawArtist.toLowerCase() == 'unknown';

        final isTitleUnknown = rawTitle.isEmpty ||
            rawTitle.toLowerCase() == '<unknown>' ||
            rawTitle.toLowerCase() == 'desconocido';

        final isAlbumUnknown = rawAlbum.isEmpty ||
            rawAlbum.toLowerCase() == '<unknown>' ||
            rawAlbum.toLowerCase() == 'álbum desconocido' ||
            rawAlbum.toLowerCase() == 'album desconocido';

        final fileNameWithoutExt = file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
            : song.displayNameWOExt;

        if (isFritoMusic) {
          final grandParent = parentDir.parent;
          final hasAlbumSubfolder = grandParent.path != parentDir.path &&
              !grandParent.path.toLowerCase().endsWith('/fritomusic') &&
              !grandParent.path.toLowerCase().endsWith('/music') &&
              grandParent.uri.pathSegments.where((s) => s.isNotEmpty).isNotEmpty;

          if (!isArtistUnknown) {
            finalArtist = rawArtist;
          } else if (hasAlbumSubfolder) {
            finalArtist = grandParent.uri.pathSegments.where((s) => s.isNotEmpty).last;
          } else if (!parentDir.path.toLowerCase().endsWith('/fritomusic')) {
            finalArtist = parentDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
          } else if (fileNameWithoutExt.contains(' - ')) {
            finalArtist = fileNameWithoutExt
                .replaceFirst(RegExp(r'^\d{1,3}\s*[-.]\s*'), '')
                .split(' - ')
                .first
                .trim();
          } else {
            finalArtist = 'Artista Desconocido';
          }

          final titleCandidate = (!isTitleUnknown)
              ? rawTitle
              : (fileNameWithoutExt.contains(' - ')
                  ? fileNameWithoutExt.split(' - ').sublist(1).join(' - ').trim()
                  : fileNameWithoutExt);
          finalTitle = titleCandidate
              .replaceFirst(RegExp(r'^\d{1,3}\s*[-.]\s*'), '')
              .trim();
          if (finalTitle.isEmpty) finalTitle = fileNameWithoutExt;

          if (!isAlbumUnknown) {
            finalAlbum = rawAlbum;
          } else if (hasAlbumSubfolder) {
            finalAlbum = parentDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
          } else {
            finalAlbum = 'Álbum Desconocido';
          }

          // Resolver carátula local de FritoMusic
          final songCover = File('${parentDir.path}/$fileNameWithoutExt.jpg');
          final parentPath = parentDir.path;
          final folderCover = _folderCoversCache.putIfAbsent(parentPath, () {
            final fc = File('$parentPath/cover.jpg');
            return fc.existsSync() ? fc.path : null;
          });

          if (songCover.existsSync()) {
            resolvedAlbumUri = songCover.path;
          } else if (folderCover != null) {
            resolvedAlbumUri = folderCover;
          } else if (song.albumId != null && song.albumId! > 0) {
            resolvedAlbumUri = 'content://media/external/audio/albumart/${song.albumId}';
          }
        } else {
          // Archivos generales (Descargas, WhatsApp, etc.)
          if (isArtistUnknown && fileNameWithoutExt.contains(' - ')) {
            final parts = fileNameWithoutExt.split(' - ');
            finalArtist = parts[0].replaceFirst(RegExp(r'^\d{1,3}\s*[-.]\s*'), '').trim();
            finalTitle = parts.sublist(1).join(' - ').trim();
          } else {
            finalArtist = !isArtistUnknown ? rawArtist : 'Artista Desconocido';
            finalTitle = !isTitleUnknown ? rawTitle : fileNameWithoutExt.replaceFirst(RegExp(r'^\d{1,3}\s*[-.]\s*'), '').trim();
          }
          if (finalTitle.isEmpty) finalTitle = fileNameWithoutExt;
          finalAlbum = !isAlbumUnknown ? rawAlbum : 'Álbum Desconocido';

          // Comprobar si hay cover.jpg en la carpeta
          final parentPath = parentDir.path;
          final folderCover = _folderCoversCache.putIfAbsent(parentPath, () {
            final fc = File('$parentPath/cover.jpg');
            return fc.existsSync() ? fc.path : null;
          });

          if (folderCover != null) {
            resolvedAlbumUri = folderCover;
          } else if (song.albumId != null && song.albumId! > 0) {
            resolvedAlbumUri = 'content://media/external/audio/albumart/${song.albumId}';
          }
        }

        // Título personalizado si el usuario lo renombró
        final customTitle = CustomNamesManager.instance.getCustomAudioTitle(path);
        if (customTitle != null && customTitle.isNotEmpty) {
          finalTitle = customTitle;
        }

        final audioFile = AudioFile(
          id: song.id,
          title: finalTitle,
          artist: finalArtist,
          path: path,
          durationMs: song.duration ?? 0,
          sizeBytes: song.size,
          albumUri: resolvedAlbumUri,
          album: finalAlbum,
          dateAdded: song.dateAdded ?? 0,
        );

        _insertIntoFolderTree(rootNode, parentDir, audioFile);
      }
    } catch (_) {}

    return rootNode;
  }

  void _insertIntoFolderTree(FolderNode root, Directory dir, AudioFile audio) {
    var relativePath = dir.path;

    // 1. Simplificar ruta de almacenamiento interno: empezar directo en las carpetas de 0
    if (relativePath.startsWith('/storage/emulated/0')) {
      relativePath = relativePath.substring('/storage/emulated/0'.length);
    } else if (relativePath.startsWith('/storage/')) {
      final parts = relativePath.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.length >= 2) {
        final sdCardId = parts[1];
        relativePath = relativePath.replaceFirst('/storage/$sdCardId', '/Tarjeta SD');
      }
    }

    final segments = relativePath.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();

    // Reconstruir lista de directorios ancestros reales para mantener realPath
    final ancestors = <Directory>[];
    Directory? temp = dir;
    while (temp != null &&
        temp.path != '/' &&
        temp.path != '/storage/emulated/0' &&
        !RegExp(r'^/storage/[^/]+$').hasMatch(temp.path)) {
      ancestors.insert(0, temp);
      final parent = temp.parent;
      if (parent.path == temp.path) break;
      temp = parent;
    }

    FolderNode currentNode = root;
    String currentPath = '';

    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      currentPath += '/$seg';
      final nodeRealPath = (i < ancestors.length) ? ancestors[i].path : '';

      final customName = CustomNamesManager.instance.getCustomFolderName(currentPath) ??
          (nodeRealPath.isNotEmpty ? CustomNamesManager.instance.getCustomFolderName(nodeRealPath) : null);
      final displayName = (customName != null && customName.isNotEmpty) ? customName : seg;

      if (!currentNode.subfolders.containsKey(seg)) {
        currentNode.subfolders[seg] = FolderNode(
          name: displayName,
          path: currentPath,
          realPath: nodeRealPath,
        );
      } else if (currentNode.subfolders[seg]!.realPath.isEmpty && nodeRealPath.isNotEmpty) {
        currentNode.subfolders[seg]!.realPath = nodeRealPath;
      }

      currentNode = currentNode.subfolders[seg]!;
    }

    currentNode.audios.add(audio);
  }
}
