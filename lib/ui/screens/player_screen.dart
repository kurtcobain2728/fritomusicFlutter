import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../../services/download_service.dart';
import '../components/add_to_youtube_playlist_modal.dart';
import '../components/download_quality_bottom_sheet.dart';
import '../components/synced_lyrics_view.dart';
import '../components/waveform_progress.dart';
import '../components/frito_artwork_widget.dart';

class PlayerScreen extends StatefulWidget {
  final PlayerProvider viewModel;
  final StreamProvider streamViewModel;
  final OnlineLibraryProvider onlineLibraryViewModel;
  final Function(String) onNavigateToArtist;
  final VoidCallback onClose;
  final AppColors appColors;

  const PlayerScreen({
    super.key,
    required this.viewModel,
    required this.streamViewModel,
    required this.onlineLibraryViewModel,
    required this.onNavigateToArtist,
    required this.onClose,
    required this.appColors,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyrics = false;
  double? _dragStartY;
  final TextEditingController _playlistNameController = TextEditingController();

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAlbumArt(AudioFile audio, bool isPlaying) {
    final colors = widget.appColors;
    final targetScale = isPlaying ? 1.0 : 0.92;

    return AnimatedScale(
      scale: targetScale,
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withOpacity(colors.isDark ? 0.14 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(colors.isDark ? 0.55 : 0.18),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              if (isPlaying)
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.28),
                  blurRadius: 36,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: FritoArtworkWidget(
            audioId: audio.id,
            albumUri: audio.albumUri,
            size: 340,
            borderRadius: 28,
            appColors: colors,
          ),
        ),
      ),
    );
  }

  void _showLocalPlaylistSheet(AudioFile audio) {
    final colors = widget.appColors;
    final player = widget.viewModel;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Añadir a la lista',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add, color: colors.textPrimary),
                ),
                title: Text(
                  'Crear lista de reproducción',
                  style: TextStyle(color: colors.textPrimary, fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePlaylistDialog();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: player.playlists.length,
                  itemBuilder: (context, i) {
                    final pl = player.playlists[i];
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.queue_music, color: colors.textSecondary),
                      ),
                      title: Text(pl.name, style: TextStyle(color: colors.textPrimary)),
                      subtitle: Text(
                        '${pl.audioPaths.length} canciones',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                      onTap: () {
                        player.addToPlaylist(pl.id, audio.path);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Añadido a ${pl.name}')),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreatePlaylistDialog() {
    final colors = widget.appColors;
    _playlistNameController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Nueva Lista de Reproducción',
            style: TextStyle(color: colors.textPrimary),
          ),
          content: TextField(
            controller: _playlistNameController,
            style: TextStyle(color: colors.textPrimary),
            cursorColor: colors.accent,
            decoration: InputDecoration(
              labelText: 'Nombre',
              labelStyle: TextStyle(color: colors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.textSecondary),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final name = _playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  final newPl = await widget.viewModel.createPlaylist(name);
                  final audio = widget.viewModel.currentAudio;
                  if (audio != null) {
                    await widget.viewModel.addToPlaylist(newPl.id, audio.path);
                  }
                }
                if (mounted) Navigator.pop(context);
              },
              child: Text(
                'Guardar',
                style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showYouTubePlaylistModal(String videoId) {
    widget.onlineLibraryViewModel.loadOnlinePlaylists();
    final playlists = widget.onlineLibraryViewModel.onlinePlaylists;

    AddToYouTubePlaylistModal.show(
      context: context,
      playlists: playlists,
      appColors: widget.appColors,
      onSelectPlaylist: (pl) {
        widget.streamViewModel.loadPlaylist(pl.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Añadido a ${pl.title}')),
        );
      },
      onCreateNew: () {
        _showCreatePlaylistDialog();
      },
    );
  }

  void _showDownloadSheet(AudioFile audio, String videoId) {
    DownloadQualityBottomSheet.show(
      context: context,
      title: audio.title,
      artist: audio.artist,
      appColors: widget.appColors,
      onConfirm: (quality) {
        DownloadService.instance.enqueueDownload(
          videoId: videoId,
          title: audio.title,
          artist: audio.artist,
          album: audio.album,
          thumbnailUrl: audio.albumUri,
          quality: quality,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga iniciada')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final player = context.watch<PlayerProvider>();
    final onlineLibrary = context.watch<OnlineLibraryProvider>();
    final audio = player.currentAudio;
    final isPlaying = player.isPlaying;

    if (audio == null) {
      return const SizedBox.shrink();
    }

    final isOnline = audio.path.startsWith('http');
    final videoId = player.currentVideoId;
    final isOnlineLiked = videoId != null && onlineLibrary.isLiked(videoId);
    final favIsActive = isOnline ? isOnlineLiked : player.isFavorite(audio.path);

    // Repeat Mode Icon
    IconData repeatIcon = Icons.repeat_rounded;
    if (player.loopMode == LoopMode.one) {
      repeatIcon = Icons.repeat_one_rounded;
    } else if (player.loopMode == LoopMode.all) {
      repeatIcon = Icons.repeat_rounded;
    }

    return GestureDetector(
      onVerticalDragStart: (details) {
        _dragStartY = details.globalPosition.dy;
      },
      onVerticalDragCancel: () {
        _dragStartY = null;
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final startY = _dragStartY;
        _dragStartY = null;

        final screenHeight = MediaQuery.of(context).size.height;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        // Altura de la zona de gestos del sistema Android/iOS (margen inferior para salir o cambiar de app)
        final systemGestureZoneHeight = bottomPadding > 0 ? (bottomPadding + 52.0) : 75.0;
        final isFromBottomGestureZone = startY != null && startY >= (screenHeight - systemGestureZoneHeight);

        final topPadding = MediaQuery.of(context).viewPadding.top;
        final isFromTopNotificationZone = startY != null && startY <= (topPadding > 0 ? topPadding + 16.0 : 36.0);

        if (velocity > 250) {
          if (isFromTopNotificationZone) {
            return; // No cerrar si el usuario solo está bajando la barra de notificaciones del sistema
          }
          if (_showLyrics) {
            setState(() => _showLyrics = false);
          } else {
            HapticFeedback.lightImpact();
            widget.onClose();
          }
        } else if (velocity < -250 && !_showLyrics) {
          // Si el deslizamiento inició en el borde inferior (gesto del sistema para salir de la app o ir a recientes), ignorar
          if (isFromBottomGestureZone) {
            return;
          }
          HapticFeedback.lightImpact();
          setState(() => _showLyrics = true);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            // Background Layer (Ambient Blur)
            if (colors.backgroundImageUri != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: CachedNetworkImage(
                    imageUrl: colors.backgroundImageUri!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (colors.backgroundImageUri != null)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),

            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Top Drag Indicator Pill (Bencho dismiss handle)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onClose();
                      },
                      child: Container(
                        width: 44,
                        height: 4.5,
                        margin: const EdgeInsets.only(top: 8, bottom: 12),
                        decoration: BoxDecoration(
                          color: colors.isDark
                              ? Colors.white.withOpacity(0.25)
                              : Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),

                    // Top Bar Actions & Context
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onClose();
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 28,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (isPlaying
                                            ? const Color(0xFF1DB954)
                                            : colors.accent)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isPlaying)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin:
                                              const EdgeInsets.only(right: 5),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF1DB954),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Text(
                                        'REPRODUCIENDO',
                                        style: TextStyle(
                                          color: isPlaying
                                              ? const Color(0xFF1DB954)
                                              : colors.accent,
                                          fontSize: 10,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  audio.album.isNotEmpty
                                      ? audio.album
                                      : (isOnline
                                          ? 'Streaming'
                                          : 'Colección local'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              if (isOnline && videoId != null) {
                                _showYouTubePlaylistModal(videoId);
                              } else {
                                _showLocalPlaylistSheet(audio);
                              }
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Icon(
                                isOnline
                                    ? Icons.playlist_add_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 22,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 1),

                    // Album Art
                    _buildAlbumArt(audio, isPlaying),

                    const Spacer(flex: 1),

                    // Song Title & Artist & Actions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                audio.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  HapticFeedback.lightImpact();
                                  if (audio.artist.trim().isNotEmpty) {
                                    final artistId = await widget.streamViewModel
                                        .findArtistIdByName(audio.artist);
                                    if (artistId != null) {
                                      widget.onClose();
                                      widget.onNavigateToArtist(artistId);
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text(
                                                  'No se encontró perfil para ${audio.artist}')),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colors.isDark
                                        ? Colors.white.withOpacity(0.06)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        audio.artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: colors.textSecondary.withOpacity(0.7),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOnline && videoId != null) ...[
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showDownloadSheet(audio, videoId);
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Icon(Icons.download_rounded,
                                  size: 22, color: colors.textPrimary),
                            ),
                          ),
                        ],
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (isOnline && videoId != null) {
                              onlineLibrary.likeSong(videoId, !isOnlineLiked);
                            } else {
                              player.toggleFavorite(audio.path);
                            }
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: favIsActive
                                  ? const Color(0xFFFF4757).withOpacity(0.15)
                                  : (colors.isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.05)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: favIsActive
                                    ? const Color(0xFFFF4757).withOpacity(0.4)
                                    : (colors.isDark
                                        ? Colors.white.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.06)),
                              ),
                            ),
                            child: Icon(
                              favIsActive
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 22,
                              color: favIsActive
                                  ? const Color(0xFFFF4757)
                                  : colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Waveform Progress Bar & Timestamps
                    ValueListenableBuilder<double>(
                      valueListenable: player.progressNotifier,
                      builder: (context, progressVal, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: player.positionNotifier,
                          builder: (context, posVal, _) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                WaveformProgress(
                                  progress: progressVal,
                                  onProgressChange: (newProgress) {
                                    final newPos =
                                        (newProgress * player.durationMs).toInt();
                                    player.seekTo(newPos);
                                  },
                                  isPlaying: isPlaying && !_showLyrics,
                                  appColors: colors,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(posVal),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.isDark
                                              ? Colors.white.withOpacity(0.06)
                                              : Colors.black.withOpacity(0.04),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 5,
                                              height: 5,
                                              margin: const EdgeInsets.only(
                                                  right: 5),
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? const Color(0xFF1DB954)
                                                    : colors.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(
                                              isOnline
                                                  ? 'Streaming • Alta fidelidad'
                                                  : (audio.path.contains('.')
                                                      ? audio.path
                                                          .split('.')
                                                          .last
                                                          .toUpperCase()
                                                      : "AUDIO"),
                                              style: TextStyle(
                                                color: colors.textSecondary
                                                    .withOpacity(0.85),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(player.durationMs),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),

                    const Spacer(flex: 1),

                    // Playback Controls (Bencho Glass Style)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Shuffle Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.toggleShuffle();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: player.shuffleModeEnabled
                                  ? const Color(0xFF1DB954).withOpacity(0.18)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: player.shuffleModeEnabled
                                  ? Border.all(
                                      color: const Color(0xFF1DB954)
                                          .withOpacity(0.45))
                                  : null,
                            ),
                            child: Icon(
                              Icons.shuffle_rounded,
                              size: 22,
                              color: player.shuffleModeEnabled
                                  ? const Color(0xFF1DB954)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),

                        // Skip Previous Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipToPrevious();
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.black.withOpacity(0.04),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Icon(
                              Icons.skip_previous_rounded,
                              size: 30,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),

                        // Center Play / Pause Button with Radiant Emerald Glow
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            player.playPause();
                          },
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF22C55E).withOpacity(0.42),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),

                        // Skip Next Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipToNext();
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colors.isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : Colors.black.withOpacity(0.04),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: Icon(
                              Icons.skip_next_rounded,
                              size: 30,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),

                        // Repeat Button
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.toggleRepeatMode();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: player.loopMode != LoopMode.off
                                  ? const Color(0xFF1DB954).withOpacity(0.18)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: player.loopMode != LoopMode.off
                                  ? Border.all(
                                      color: const Color(0xFF1DB954)
                                          .withOpacity(0.45))
                                  : null,
                            ),
                            child: Icon(
                              repeatIcon,
                              size: 22,
                              color: player.loopMode != LoopMode.off
                                  ? const Color(0xFF1DB954)
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 1),

                    // Bottom Lyrics Button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showLyrics = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.14),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lyrics_rounded,
                                  color: Color(0xFF10B981),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Letra en tiempo real',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 18,
                                color: colors.textSecondary.withOpacity(0.8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Lyrics Overlay Slide Up (Bencho Glassmorphism)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: const Cubic(0.16, 1.0, 0.3, 1.0),
              top: _showLyrics ? 0 : MediaQuery.of(context).size.height,
              bottom: _showLyrics ? 0 : -MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.surface.withOpacity(0.97),
                      colors.background,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Manija de arrastre Bencho
                      Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(top: 8, bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Botón circular cerrar
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _showLyrics = false);
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.12)),
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colors.textPrimary,
                                  size: 24,
                                ),
                              ),
                            ),
                            // Título con estado activo y datos de la canción
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF10B981),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Letra en tiempo real',
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Text(
                                          '${audio.title} • ${audio.artist}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.textSecondary.withOpacity(0.8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botón circular traducción
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                player.toggleLyricsTranslation();
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: player.isLyricsTranslated
                                      ? const Color(0xFF10B981).withOpacity(0.18)
                                      : Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: player.isLyricsTranslated
                                        ? const Color(0xFF10B981).withOpacity(0.4)
                                        : Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.translate_rounded,
                                  size: 18,
                                  color: player.isLyricsTranslated
                                      ? const Color(0xFF10B981)
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: player.positionNotifier,
                          builder: (context, currentPos, _) {
                            return SyncedLyricsView(
                              key: ValueKey('${audio.id}_${audio.path}'),
                              state: player.lyricsState,
                              currentPositionMs: currentPos,
                              onSeek: (pos) => player.seekTo(pos),
                              onToggleTranslate:
                                  player.toggleLyricsTranslation,
                              isTranslated: player.isLyricsTranslated,
                              appColors: colors,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
