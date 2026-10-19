import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../data/models/playlist.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Playlist playlist;
  final HomeProvider homeProvider;
  final PlayerProvider playerProvider;
  final VoidCallback onBack;
  final AppColors appColors;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.homeProvider,
    required this.playerProvider,
    required this.onBack,
    required this.appColors,
  });

  Widget _buildAlbumArt(String? albumUri) {
    if (albumUri == null || albumUri.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(Icons.music_note_rounded, color: appColors.accent, size: 24),
      );
    }
    if (albumUri.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: albumUri,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(Icons.music_note_rounded, color: appColors.accent),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(albumUri),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.music_note_rounded, color: appColors.accent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allAudios = homeProvider.allAudios;
    final playlistAudios = allAudios.where((a) => playlist.audioPaths.contains(a.path)).toList();

    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Center(
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: appColors.textPrimary, size: 16),
            ),
          ),
        ),
        title: Text(
          playlist.name,
          style: TextStyle(
            color: appColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: playlistAudios.isEmpty
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: appColors.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: appColors.accent.withOpacity(0.12),
                        border: Border.all(color: appColors.accent.withOpacity(0.3)),
                      ),
                      child: Icon(Icons.queue_music_rounded, color: appColors.accent, size: 36),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Esta lista está vacía',
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Agrega canciones desde tu biblioteca para escucharlas aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: appColors.textSecondary.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Glass Header con botones Play / Shuffle
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: appColors.surface.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: appColors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: appColors.accent.withOpacity(0.25)),
                        ),
                        child: Text(
                          '${playlistAudios.length} canciones',
                          style: TextStyle(
                            color: appColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Botón Aleatorio
                      GestureDetector(
                        onTap: () {
                          final shuffled = List<AudioFile>.from(playlistAudios)..shuffle();
                          if (shuffled.isNotEmpty) {
                            playerProvider.playAudio(shuffled.first, newQueue: shuffled);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shuffle_rounded, color: appColors.textPrimary, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Aleatorio',
                                style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón Reproducir Todo
                      GestureDetector(
                        onTap: () {
                          if (playlistAudios.isNotEmpty) {
                            playerProvider.playAudio(playlistAudios.first, newQueue: playlistAudios);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [appColors.accent, const Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: appColors.accent.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                color: AppColors.textColorForBackground(appColors.accent),
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reproducir',
                                style: TextStyle(
                                  color: AppColors.textColorForBackground(appColors.accent),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de canciones Bencho Cards
                ...playlistAudios.map((audio) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: appColors.surface.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => playerProvider.playAudio(audio, newQueue: playlistAudios),
                      child: Row(
                        children: [
                          _buildAlbumArt(audio.albumUri),
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
                                    color: appColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  audio.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: appColors.textSecondary.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline_rounded,
                              color: Colors.redAccent.withOpacity(0.7),
                              size: 18,
                            ),
                            onPressed: () => playerProvider.playlistRepository.removeFromPlaylist(playlist.id, audio.path),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
