import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/player_provider.dart';
import 'frito_artwork_widget.dart';

class MiniPlayer extends StatelessWidget {
  final VoidCallback onClick;
  final VoidCallback onSwipeUp;
  final AppColors appColors;

  const MiniPlayer({
    super.key,
    required this.onClick,
    required this.onSwipeUp,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final audio = player.currentAudio;
    if (audio == null) return const SizedBox.shrink();

    final isFav = player.isFavorite(audio.path);
    final isPlaying = player.isPlaying;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onClick();
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -180) {
          HapticFeedback.mediumImpact();
          onSwipeUp();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(appColors.isDark ? 0.45 : 0.12),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
            if (isPlaying)
              BoxShadow(
                color: const Color(0xFF1DB954).withOpacity(0.22),
                blurRadius: 20,
                spreadRadius: 1.0,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: appColors.isDark
                    ? const Color(0xD817171C)
                    : const Color(0xF2F8F8FC),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isPlaying
                      ? const Color(0xFF1DB954).withOpacity(0.4)
                      : (appColors.isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08)),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador sutil de deslizamiento hacia arriba
                  Center(
                    child: Container(
                      width: 28,
                      height: 3,
                      margin: const EdgeInsets.only(top: 6, bottom: 2),
                      decoration: BoxDecoration(
                        color: appColors.isDark
                            ? Colors.white.withOpacity(0.22)
                            : Colors.black.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 8, 7),
                    child: Row(
                      children: [
                        // Carátula con bordes redondeados y ecualizador animado
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            FritoArtworkWidget(
                              audioId: audio.id,
                              albumUri: audio.albumUri,
                              size: 46,
                              borderRadius: 14,
                              appColors: appColors,
                            ),
                            if (isPlaying)
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: _MiniEqualizer(
                                    isPlaying: true,
                                    color: Color(0xFF1DB954),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Título y artista
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                audio.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isPlaying
                                      ? const Color(0xFF1DB954)
                                      : appColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (isPlaying) ...[
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.only(right: 5),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF1DB954),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                  Expanded(
                                    child: Text(
                                      audio.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: appColors.textSecondary
                                            .withOpacity(0.85),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Botón de Favorito
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.toggleFavorite(audio.path);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav
                                  ? const Color(0xFFFF4757)
                                  : appColors.textSecondary.withOpacity(0.6),
                              size: 21,
                            ),
                          ),
                        ),

                        // Botón Play / Pause estilo Bencho Emerald
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            player.playPause();
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF22C55E).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        // Botón Siguiente
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.skipToNext();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.skip_next_rounded,
                              color: appColors.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),

                        // Botón Cerrar
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            player.stopAndClear();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.close_rounded,
                              color: appColors.textSecondary.withOpacity(0.6),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Barra de progreso ultra-fina integrada en la base de la píldora
                  ValueListenableBuilder<double>(
                    valueListenable: player.progressNotifier,
                    builder: (context, progress, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final progressWidth =
                              constraints.maxWidth * progress.clamp(0.0, 1.0);
                          return Container(
                            height: 2.5,
                            width: double.infinity,
                            color: appColors.isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.06),
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: progressWidth,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        const Color(0xFF1DB954).withOpacity(0.6),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini ecualizador animado de 3 barras para el MiniPlayer
class _MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _MiniEqualizer({
    required this.isPlaying,
    required this.color,
  });

  @override
  State<_MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<_MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        final h1 =
            (0.35 + 0.65 * (0.5 + 0.5 * sin(val * 2 * pi))).clamp(0.25, 1.0);
        final h2 = (0.35 +
                0.65 * (0.5 + 0.5 * sin((val + 0.33) * 2 * pi)))
            .clamp(0.25, 1.0);
        final h3 = (0.35 +
                0.65 * (0.5 + 0.5 * sin((val + 0.66) * 2 * pi)))
            .clamp(0.25, 1.0);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1 * 16),
            const SizedBox(width: 2.5),
            _buildBar(h2 * 20),
            const SizedBox(width: 2.5),
            _buildBar(h3 * 15),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 3.5,
      height: widget.isPlaying ? height.clamp(4.0, 22.0) : 6.0,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
