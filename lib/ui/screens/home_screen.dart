import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../data/models/folder_node.dart';
import '../../data/repository/hidden_items_manager.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';
import '../../utils/file_operations.dart';
import '../components/frito_artwork_widget.dart';
import '../components/frito_pull_refresh.dart';

class HomeScreen extends StatefulWidget {
  final HomeProvider homeViewModel;
  final PlayerProvider playerViewModel;
  final bool isPlayerOpen;
  final AppColors appColors;

  const HomeScreen({
    super.key,
    required this.homeViewModel,
    required this.playerViewModel,
    this.isPlayerOpen = false,
    required this.appColors,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _renameController = TextEditingController();
  String _lastPath = '/';
  bool _isDrillingDown = true;

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAlbumArt(AudioFile audio) {
    return FritoArtworkWidget(
      audioId: audio.id,
      albumUri: audio.albumUri,
      size: 48,
      borderRadius: 12,
      appColors: widget.appColors,
    );
  }

  void _showItemOptions(dynamic item, bool isFolder) {
    final colors = widget.appColors;
    final title = isFolder ? (item as FolderNode).name : (item as AudioFile).title;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tirador superior moderno
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isFolder ? Icons.folder_rounded : Icons.music_note_rounded,
                          color: const Color(0xFF1DB954),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.edit_rounded, color: colors.textPrimary, size: 18),
                  ),
                  title: Text('Renombrar', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameDialog(item, isFolder);
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colors.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.visibility_off_rounded, color: colors.textSecondary, size: 18),
                  ),
                  title: Text('Ocultar', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isFolder) {
                      final f = item as FolderNode;
                      await HiddenItemsManager.instance.hideItem(
                        path: f.path,
                        name: f.name,
                        isFolder: true,
                        realPath: f.realPath,
                      );
                    } else {
                      final a = item as AudioFile;
                      await HiddenItemsManager.instance.hideItem(
                        path: a.path,
                        name: a.title,
                        isFolder: false,
                      );
                    }
                    await widget.homeViewModel.rescan();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  ),
                  title: const Text('Eliminar del dispositivo', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(context);
                    if (isFolder) {
                      await FileOperations.deleteFolder(item as FolderNode);
                    } else {
                      await FileOperations.deleteAudio(item as AudioFile);
                    }
                    await widget.homeViewModel.rescan();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(dynamic item, bool isFolder) {
    final colors = widget.appColors;
    final initialName = isFolder ? (item as FolderNode).name : (item as AudioFile).title;
    _renameController.text = initialName;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Renombrar', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _renameController,
            autofocus: true,
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              labelText: isFolder ? 'Nombre de la carpeta' : 'Título de la canción',
              labelStyle: TextStyle(color: colors.textSecondary),
              filled: true,
              fillColor: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x0D000000),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newName = _renameController.text.trim();
                if (newName.isNotEmpty) {
                  if (isFolder) {
                    await FileOperations.renameFolder(item as FolderNode, newName);
                  } else {
                    await FileOperations.renameAudio(item as AudioFile, newName);
                  }
                  await widget.homeViewModel.rescan();
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final home = widget.homeViewModel;
    final colors = widget.appColors;
    final currentNode = home.currentNode;
    final hiddenMgr = HiddenItemsManager.instance;

    if (currentNode != null && currentNode.audios.isNotEmpty) {
      FritoArtworkCache.preload(currentNode.audios.map((a) => a.id));
    }

    if (home.isLoading && currentNode == null) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Color(0xFF1DB954),
        ),
      );
    }

    if (currentNode == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_open_rounded, size: 40, color: colors.textSecondary),
            ),
            const SizedBox(height: 18),
            Text('No se encontraron archivos de música', style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Toca escanear para buscar canciones en el dispositivo', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => home.scanMusic(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text('Escanear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    // Comprobar dirección para animación direccional al entrar o salir de carpetas
    if (currentNode.path != _lastPath) {
      _isDrillingDown = currentNode.path.length >= _lastPath.length;
      _lastPath = currentNode.path;
    }

    final visibleFolders = currentNode.subfolders.values
        .where((f) => !hiddenMgr.isFolderHidden(f.path))
        .toList();

    final visibleAudios = currentNode.audios
        .where((a) => !hiddenMgr.isAudioHidden(a.path))
        .toList();

    final isRoot = currentNode.path == '/' || currentNode.path.isEmpty;

    return FritoPullRefresh(
      onRefresh: () => home.rescan(),
      appColors: colors,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 190),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetBegin = _isDrillingDown ? const Offset(0.02, 0.0) : const Offset(-0.02, 0.0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: offsetBegin, end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: ListView(
          key: ValueKey('folder_content_${currentNode.path}'),
          padding: const EdgeInsets.only(top: 48, bottom: 120),
          children: [
            // Header / Breadcrumb elegante al nivel de Biblioteca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (!isRoot) ...[
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isDrillingDown = false);
                        home.navigateUp();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                            width: 1,
                          ),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: colors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRoot ? 'Música Local' : currentNode.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${currentNode.getTotalAudioCount()} canciones disponibles',
                                style: const TextStyle(
                                  color: Color(0xFF1DB954),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sección Carpetas
            if (visibleFolders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Carpetas',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visibleFolders.length}',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...visibleFolders.map((folder) {
                final isSel = home.selectedFolderPaths.contains(folder.path);

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF1DB954)
                          : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      width: isSel ? 1.4 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (home.isSelectionMode) {
                        home.toggleFolder(folder.path);
                      } else {
                        HapticFeedback.lightImpact();
                        setState(() => _isDrillingDown = true);
                        home.navigateToFolder(folder.name);
                      }
                    },
                    onLongPress: () {
                      if (!home.isSelectionMode) {
                        HapticFeedback.mediumImpact();
                        home.enterSelectionMode(folderPath: folder.path);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1DB954).withOpacity(0.25),
                                  const Color(0xFF1DB954).withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.folder_rounded, color: Color(0xFF1DB954), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${folder.getTotalAudioCount()} canciones',
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (home.isSelectionMode)
                            Checkbox(
                              value: isSel,
                              activeColor: const Color(0xFF1DB954),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (_) => home.toggleFolder(folder.path),
                            )
                          else ...[
                            IconButton(
                              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary.withOpacity(0.7), size: 20),
                              onPressed: () => _showItemOptions(folder, true),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: colors.textSecondary.withOpacity(0.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],

            // Sección Canciones
            if (visibleAudios.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, top: 18, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Canciones',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visibleAudios.length}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...visibleAudios.map((audio) {
                final isSel = home.selectedAudioPaths.contains(audio.path);
                final isPlaying = widget.playerViewModel.currentAudio?.id == audio.id;
                final extension = audio.path.contains('.') ? audio.path.split('.').last.toUpperCase() : 'AUDIO';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? (colors.isDark ? const Color(0x881E2E24) : const Color(0xDDECF8EF))
                        : (colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPlaying
                          ? const Color(0xFF1DB954).withOpacity(0.45)
                          : isSel
                              ? const Color(0xFF1DB954)
                              : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      width: (isPlaying || isSel) ? 1.4 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      if (home.isSelectionMode) {
                        home.toggleAudio(audio.path);
                      } else {
                        HapticFeedback.lightImpact();
                        widget.playerViewModel.playAudio(audio, newQueue: visibleAudios);
                      }
                    },
                    onLongPress: () {
                      if (!home.isSelectionMode) {
                        HapticFeedback.mediumImpact();
                        home.enterSelectionMode(audioPath: audio.path);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildAlbumArt(audio),
                              if (isPlaying)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.equalizer_rounded,
                                    color: Color(0xFF1DB954),
                                    size: 24,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  audio.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isPlaying ? const Color(0xFF1DB954) : colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x15000000),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        extension,
                                        style: TextStyle(
                                          color: colors.textSecondary.withOpacity(0.8),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        audio.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_formatDuration(audio.durationMs).isNotEmpty)
                            Text(
                              _formatDuration(audio.durationMs),
                              style: TextStyle(
                                color: colors.textSecondary.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          if (home.isSelectionMode)
                            Checkbox(
                              value: isSel,
                              activeColor: const Color(0xFF1DB954),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (_) => home.toggleAudio(audio.path),
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary.withOpacity(0.7), size: 18),
                              onPressed: () => _showItemOptions(audio, false),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
