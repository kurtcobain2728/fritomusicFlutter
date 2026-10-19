import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/album_download_quality_bottom_sheet.dart';
import '../../services/download_service.dart';
import '../../utils/image_utils.dart';

class OnlinePlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final OnlineLibraryProvider onlineLibraryProvider;
  final StreamProvider streamProvider;
  final PlayerProvider playerProvider;
  final VoidCallback onBack;
  final AppColors appColors;

  const OnlinePlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.onlineLibraryProvider,
    required this.streamProvider,
    required this.playerProvider,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<OnlinePlaylistDetailScreen> createState() => _OnlinePlaylistDetailScreenState();
}

class _OnlinePlaylistDetailScreenState extends State<OnlinePlaylistDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.streamProvider.loadPlaylist(widget.playlistId);
  }

  void _confirmDeletePlaylist(BuildContext context, String playlistTitle) {
    final colors = widget.appColors;
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
              final success = await widget.onlineLibraryProvider.deleteOnlinePlaylist(widget.playlistId);
              widget.streamProvider.deleteUserPlaylist(widget.playlistId);
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
      listenable: widget.streamProvider,
      builder: (context, _) {
        final colors = widget.appColors;
        final stream = widget.streamProvider;
        final playlistData = stream.selectedPlaylist;

    if (stream.isLoadingDetail || playlistData == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Center(
            child: GestureDetector(
              onTap: widget.onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 16),
              ),
            ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: GestureDetector(
            onTap: widget.onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 16),
            ),
          ),
        ),
        title: Text(
          playlist.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
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
            onPressed: () => _confirmDeletePlaylist(context, playlist.title),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          // Header Glass Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.48),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: playlist.thumbnail != null && playlist.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: playlist.thumbnail!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.white.withOpacity(0.06),
                            child: Icon(Icons.playlist_play_rounded, color: colors.accent, size: 40),
                          ),
                        )
                      : Container(
                          width: 96,
                          height: 96,
                          color: Colors.white.withOpacity(0.06),
                          child: Icon(Icons.playlist_play_rounded, color: colors.accent, size: 40),
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
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${songs.length} canciones',
                        style: TextStyle(color: colors.textSecondary.withOpacity(0.8), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (songs.isNotEmpty) {
                                final queue = songs.map((s) => s.toStreamableTrack()).toList();
                                stream.playStreamableTrack(songs.first.toStreamableTrack(), widget.playerProvider, queue: queue);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.accent, const Color(0xFF10B981)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.textColorForBackground(colors.accent),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reproducir',
                                    style: TextStyle(
                                      color: AppColors.textColorForBackground(colors.accent),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.download_rounded, color: colors.accent, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Descargar',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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

          // Canciones en Glass Cards
          ...songs.map((song) {
            final track = song.toStreamableTrack();
            final queue = songs.map((s) => s.toStreamableTrack()).toList();
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surface.withOpacity(0.42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => stream.playStreamableTrack(track, widget.playerProvider, queue: queue),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                              errorWidget: (_, __, ___) => Container(
                                width: 46,
                                height: 46,
                                color: Colors.white.withOpacity(0.06),
                                child: Icon(Icons.music_note_rounded, color: colors.accent, size: 22),
                              ),
                            );
                          }
                          return Container(
                            width: 46,
                            height: 46,
                            color: Colors.white.withOpacity(0.06),
                            child: Icon(Icons.music_note_rounded, color: colors.accent, size: 22),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artistNames,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.download_rounded, color: colors.textSecondary.withOpacity(0.8), size: 18),
                      onPressed: () {
                        DownloadService.instance.enqueueDownload(
                          videoId: song.id,
                          title: song.title,
                          artist: song.artistNames,
                          thumbnailUrl: song.thumbnail,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
      },
    );
  }
}
