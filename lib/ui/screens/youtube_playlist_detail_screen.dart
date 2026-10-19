import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/album_download_quality_bottom_sheet.dart';
import '../../services/download_service.dart';
import '../../utils/image_utils.dart';

class YouTubePlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final StreamProvider streamViewModel;
  final PlayerProvider playerViewModel;
  final VoidCallback onBack;
  final AppColors? appColors;

  const YouTubePlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.streamViewModel,
    required this.playerViewModel,
    required this.onBack,
    this.appColors,
  });

  @override
  State<YouTubePlaylistDetailScreen> createState() => _YouTubePlaylistDetailScreenState();
}

class _YouTubePlaylistDetailScreenState extends State<YouTubePlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.streamViewModel.loadPlaylist(widget.playlistId);
  }

  void _confirmDeletePlaylist(BuildContext context, String playlistTitle, AppColors colors) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Eliminar lista?',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Se eliminará "$playlistTitle" de tu cuenta de YouTube y de FritoMusic. Esta acción no se puede deshacer.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              OnlineLibraryProvider? onlineLib;
              try {
                onlineLib = context.read<OnlineLibraryProvider>();
              } catch (_) {}
              final success = await widget.streamViewModel.deleteUserPlaylist(widget.playlistId);
              onlineLib?.deleteOnlinePlaylist(widget.playlistId);
              if (success) {
                HapticFeedback.heavyImpact();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Se eliminó "$playlistTitle" de YouTube y FritoMusic'),
                    backgroundColor: const Color(0xFF1E1E24),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                widget.onBack();
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo eliminar la lista de YouTube'),
                    backgroundColor: Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.white),
            label: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.streamViewModel,
      builder: (context, _) {
        final stream = widget.streamViewModel;
        final playlistData = stream.selectedPlaylist;

        const fallbackColors = AppColors(
          background: Color(0xFF121212),
          surface: Color(0xFF1A1A1A),
          accent: Color(0xFF1DB954),
          textPrimary: Colors.white,
          textSecondary: Color(0xFFB3B3B3),
          isDark: true,
          themeMode: 'Oscuro',
        );
        final colors = widget.appColors ?? fallbackColors;

    if (stream.isLoadingDetail || playlistData == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colors.textPrimary),
            onPressed: widget.onBack,
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
    }

    final playlist = playlistData.playlist;
    final songs = playlistData.songs;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: widget.onBack,
        ),
        title: Text(playlist.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            ),
            tooltip: 'Eliminar lista',
            onPressed: () => _confirmDeletePlaylist(context, playlist.title, colors),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: playlist.thumbnail != null && playlist.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: playlist.thumbnail!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: colors.surface),
                        )
                      : Container(
                          width: 90,
                          height: 90,
                          color: colors.surface,
                          child: Icon(Icons.playlist_play, color: colors.accent, size: 40),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${songs.length} canciones',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: colors.accent),
                            icon: Icon(Icons.play_arrow, color: AppColors.textColorForBackground(colors.accent)),
                            onPressed: () {
                              if (songs.isNotEmpty) {
                                final queue = songs.map((s) => s.toStreamableTrack()).toList();
                                stream.playStreamableTrack(songs.first.toStreamableTrack(), widget.playerViewModel, queue: queue);
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(backgroundColor: colors.surface),
                            icon: Icon(Icons.download, color: colors.accent),
                            onPressed: () {
                              AlbumDownloadQualityBottomSheet.show(
                                context: context,
                                albumTitle: playlist.title,
                                artist: 'YT',
                                songCount: songs.length,
                                onConfirm: (quality) {
                                  for (final song in songs) {
                                    DownloadService.instance.enqueueDownload(
                                      videoId: song.id,
                                      title: song.title,
                                      artist: song.artistNames,
                                      thumbnailUrl: song.thumbnail,
                                      quality: quality,
                                    );
                                  }
                                },
                                appColors: colors,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...songs.map((song) {
            final track = song.toStreamableTrack();
            final queue = songs.map((s) => s.toStreamableTrack()).toList();
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Builder(
                  builder: (_) {
                    final thumb = (song.thumbnail != null && song.thumbnail!.isNotEmpty)
                        ? song.thumbnail!
                        : (song.id.isNotEmpty ? 'https://i.ytimg.com/vi/${song.id}/hqdefault.jpg' : '');
                    if (thumb.isNotEmpty) {
                      return CachedNetworkImage(
                        imageUrl: thumb.resize(width: 100),
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) => Icon(Icons.music_note, color: colors.accent),
                      );
                    }
                    return Icon(Icons.music_note, color: colors.accent);
                  },
                ),
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                song.artistNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              trailing: IconButton(
                icon: Icon(Icons.download_outlined, color: colors.textSecondary, size: 20),
                onPressed: () {
                  DownloadService.instance.enqueueDownload(
                    videoId: song.id,
                    title: song.title,
                    artist: song.artistNames,
                    thumbnailUrl: song.thumbnail,
                  );
                },
              ),
              onTap: () => stream.playStreamableTrack(track, widget.playerViewModel, queue: queue),
            );
          }),
        ],
      ),
    );
      },
    );
  }
}
