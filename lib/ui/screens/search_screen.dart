import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../providers/home_provider.dart';
import '../../providers/player_provider.dart';

import '../components/frito_artwork_widget.dart';

class SearchScreen extends StatefulWidget {
  final HomeProvider homeViewModel;
  final PlayerProvider playerViewModel;
  final AppColors appColors;

  const SearchScreen({
    super.key,
    required this.homeViewModel,
    required this.playerViewModel,
    required this.appColors,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    setState(() {
      _query = text;
    });
    _debounceTimer?.cancel();
    if (text.isEmpty) {
      setState(() {
        _debouncedQuery = '';
      });
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() {
            _debouncedQuery = text.trim();
          });
        }
      });
    }
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '';
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

  List<AudioFile> _getSuggestedSongs(List<AudioFile> allAudios) {
    if (allAudios.isEmpty) return [];
    final seed = DateTime.now().millisecondsSinceEpoch ~/ (12 * 60 * 60 * 1000);
    final random = Random(seed);
    final copy = List<AudioFile>.from(allAudios);
    copy.shuffle(random);
    return copy.take(min(15, copy.length)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final home = context.watch<HomeProvider>();
    final player = context.watch<PlayerProvider>();
    final allAudios = home.allAudios;
    final favorites = player.favorites;

    final suggestions = _getSuggestedSongs(allAudios);
    final searchResults = _debouncedQuery.isEmpty
        ? <AudioFile>[]
        : allAudios.where((s) {
            final q = _debouncedQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q) ||
                s.album.toLowerCase().contains(q);
          }).toList();

    final displayList = _debouncedQuery.isEmpty ? suggestions : searchResults;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 48, bottom: 120),
        itemCount: displayList.length + 1 + (_debouncedQuery.isNotEmpty && searchResults.isEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscar',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Barra de Búsqueda Bencho Glass
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _query.isNotEmpty
                            ? const Color(0xFF1DB954).withOpacity(0.5)
                            : (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(colors.isDark ? 0.25 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF1DB954), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onQueryChanged,
                            style: TextStyle(color: colors.textPrimary, fontSize: 15),
                            cursorColor: const Color(0xFF1DB954),
                            decoration: InputDecoration(
                              hintText: 'Canciones, artistas o álbumes...',
                              hintStyle: TextStyle(
                                color: colors.textSecondary.withOpacity(0.7),
                                fontSize: 14.5,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _searchController.clear();
                              _onQueryChanged('');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: colors.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded, color: colors.textPrimary, size: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Encabezado de Resultados o Sugerencias
                  Row(
                    children: [
                      Text(
                        _query.isEmpty ? 'Sugerencias para ti' : 'Resultados',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _query.isEmpty ? '${suggestions.length}' : '${searchResults.length}',
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          }

          if (_debouncedQuery.isNotEmpty && searchResults.isEmpty && index == 1) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0x6618181C) : const Color(0xB8F6F6F8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.search_off_rounded, size: 30, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin resultados',
                      style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No encontramos coincidencias para "$_debouncedQuery"',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final songIndex = index - 1;
          if (songIndex >= displayList.length) return const SizedBox.shrink();
          final song = displayList[songIndex];
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
                player.playAudios(displayList, songIndex);
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

