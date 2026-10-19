import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';

import '../components/frito_artwork_widget.dart';

enum SortOption { title, artist, album, recent }

class LibraryScreen extends StatefulWidget {
  final HomeProvider homeViewModel;
  final PlayerProvider playerViewModel;
  final AppColors appColors;

  const LibraryScreen({
    super.key,
    required this.homeViewModel,
    required this.playerViewModel,
    required this.appColors,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  SortOption _selectedFilter = SortOption.title;

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAlbumArt(AudioFile song, bool isPlaying) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FritoArtworkWidget(
          audioId: song.id,
          albumUri: song.albumUri,
          size: 48,
          borderRadius: 12,
          appColors: widget.appColors,
        ),
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
    );
  }

  Widget _buildFilterChip(String text, SortOption option) {
    final isSelected = _selectedFilter == option;
    final colors = widget.appColors;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedFilter = option;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1DB954)
              : (colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1DB954)
                : (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final home = context.watch<HomeProvider>();
    final player = context.watch<PlayerProvider>();
    final allSongs = home.allAudios;
    final favorites = player.favorites;

    final sortedSongs = List<AudioFile>.from(allSongs);
    switch (_selectedFilter) {
      case SortOption.title:
        sortedSongs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case SortOption.artist:
        sortedSongs.sort((a, b) => a.artist.toLowerCase().compareTo(b.artist.toLowerCase()));
        break;
      case SortOption.album:
        sortedSongs.sort((a, b) => a.album.toLowerCase().compareTo(b.album.toLowerCase()));
        break;
      case SortOption.recent:
        sortedSongs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
    }

    final totalDurationMs = allSongs.fold<int>(0, (acc, s) => acc + s.durationMs);
    final hours = totalDurationMs ~/ 3600000;
    final minutes = (totalDurationMs % 3600000) ~/ 60000;

    if (sortedSongs.isNotEmpty) {
      FritoArtworkCache.preload(sortedSongs.take(50).map((s) => s.id));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 48, bottom: 120),
        itemCount: sortedSongs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu Biblioteca',
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
                          '${allSongs.length} canciones',
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$hours h $minutes min de música',
                        style: TextStyle(
                          color: colors.textSecondary.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Filtros deslizables Bencho Glass
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Título', SortOption.title),
                        const SizedBox(width: 8),
                        _buildFilterChip('Artista', SortOption.artist),
                        const SizedBox(width: 8),
                        _buildFilterChip('Álbum', SortOption.album),
                        const SizedBox(width: 8),
                        _buildFilterChip('Reciente', SortOption.recent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Botones de acción destacados
                  Row(
                    children: [
                      // Botón Aleatorio
                      GestureDetector(
                        onTap: () {
                          if (sortedSongs.isNotEmpty) {
                            HapticFeedback.lightImpact();
                            if (!player.shuffleModeEnabled) {
                              player.toggleShuffle();
                            }
                            final randomIndex = (sortedSongs.length * (DateTime.now().millisecond / 1000)).floor() % sortedSongs.length;
                            player.playAudios(sortedSongs, randomIndex);
                          }
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: player.shuffleModeEnabled
                                ? const Color(0xFF1DB954).withOpacity(0.2)
                                : (colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8)),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: player.shuffleModeEnabled
                                  ? const Color(0xFF1DB954)
                                  : (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.shuffle_rounded,
                            color: player.shuffleModeEnabled ? const Color(0xFF1DB954) : colors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Botón Reproducir Todo
                      GestureDetector(
                        onTap: () {
                          if (sortedSongs.isNotEmpty) {
                            HapticFeedback.mediumImpact();
                            player.playAudios(sortedSongs, 0);
                          }
                        },
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1DB954).withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                              SizedBox(width: 6),
                              Text(
                                'Reproducir todo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );
          }

          final songIndex = index - 1;
          final song = sortedSongs[songIndex];
          final isFavorite = favorites.contains(song.path);
          final isPlaying = player.currentAudio?.id == song.id;
          final extension = song.path.contains('.') ? song.path.split('.').last.toUpperCase() : 'AUDIO';

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
                    : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                width: isPlaying ? 1.4 : 1.0,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                player.playAudios(sortedSongs, songIndex);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    _buildAlbumArt(song, isPlaying),
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
                                  song.artist,
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
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        player.toggleFavorite(song.path);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorite ? const Color(0xFFFF4757) : colors.textSecondary.withOpacity(0.6),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_formatDuration(song.durationMs).isNotEmpty)
                      Text(
                        _formatDuration(song.durationMs),
                        style: TextStyle(
                          color: colors.textSecondary.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
