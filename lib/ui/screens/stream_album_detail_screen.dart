import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/album_download_quality_bottom_sheet.dart';
import '../../services/download_service.dart';

class StreamAlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final StreamProvider streamViewModel;
  final PlayerProvider playerViewModel;
  final VoidCallback onBack;
  final AppColors? appColors;

  const StreamAlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.streamViewModel,
    required this.playerViewModel,
    required this.onBack,
    this.appColors,
  });

  @override
  State<StreamAlbumDetailScreen> createState() => _StreamAlbumDetailScreenState();
}

class _StreamAlbumDetailScreenState extends State<StreamAlbumDetailScreen> {
  @override
  void initState() {
    super.initState();
    widget.streamViewModel.loadAlbum(widget.albumId);
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.streamViewModel;
    final albumData = stream.selectedAlbum;

    final fallbackColors = const AppColors(
      background: Color(0xFF121212),
      surface: Color(0xFF1A1A1A),
      accent: Color(0xFF1DB954),
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB3B3B3),
      isDark: true,
      themeMode: 'Oscuro',
    );
    final colors = widget.appColors ?? fallbackColors;

    if (stream.isLoadingDetail || albumData == null) {
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

    final album = albumData.album;
    final songs = albumData.songs;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: widget.onBack,
        ),
        title: Text(album.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 120),
        children: [
          // Album Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: album.thumbnail ?? '',
                      width: 180,
                      height: 180,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: colors.surface),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  album.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  album.artistNames,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${songs.length} canciones',
                  style: TextStyle(color: colors.textSecondary.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: colors.accent),
                      icon: Icon(Icons.play_arrow, color: AppColors.textColorForBackground(colors.accent)),
                      label: Text('Reproducir', style: TextStyle(color: AppColors.textColorForBackground(colors.accent))),
                      onPressed: () {
                        if (songs.isNotEmpty) {
                          stream.playStreamableTrack(songs.first.toStreamableTrack(), widget.playerViewModel);
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(backgroundColor: colors.surface),
                      icon: Icon(Icons.download, color: colors.accent),
                      label: Text('Descargar', style: TextStyle(color: colors.textPrimary)),
                      onPressed: () {
                        AlbumDownloadQualityBottomSheet.show(
                          context: context,
                          albumTitle: album.title,
                          artist: album.artistNames,
                          songCount: songs.length,
                          onConfirm: (quality) {
                            for (final song in songs) {
                              DownloadService.instance.enqueueDownload(
                                videoId: song.id,
                                title: song.title,
                                artist: song.artistNames,
                                album: album.title,
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
          const SizedBox(height: 24),
          // Lista de canciones
          ...songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              leading: SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
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
                    album: album.title,
                    thumbnailUrl: song.thumbnail,
                  );
                },
              ),
              onTap: () => stream.playStreamableTrack(song.toStreamableTrack(), widget.playerViewModel),
            );
          }),
        ],
      ),
    );
  }
}
