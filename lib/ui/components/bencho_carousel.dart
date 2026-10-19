import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../utils/image_utils.dart';

/// Carrusel 3D orbital tipo tornamesa inspirado en Carousel de bencho.dev.
/// Las tarjetas giran en un anillo cilíndrico en el espacio 3D:
/// - x = sin(th) * orbit
/// - y = -(1 - f) * lean (las tarjetas del fondo se elevan para crear perspectiva desde arriba)
/// - scale = lerp(depthScale, 1.0, f)
/// - rotY = -sin(th) * 22° (orientación cilíndrica hacia la cámara)
/// - rotZ = ángulo orgánico único por tarjeta
class BenchoCarousel extends StatefulWidget {
  final List<SongItem> songs;
  final Function(SongItem song, List<SongItem> allSongs) onPlaySong;
  final AppColors appColors;
  final String? title;

  const BenchoCarousel({
    super.key,
    required this.songs,
    required this.onPlaySong,
    required this.appColors,
    this.title,
  });

  @override
  State<BenchoCarousel> createState() => _BenchoCarouselState();
}

class _BenchoCarouselState extends State<BenchoCarousel> with TickerProviderStateMixin {
  static const double _cardW = 150.0;
  static const double _cardH = 210.0;
  static const double _orbit = 112.0;
  static const double _lean = 26.0;
  static const double _backScale = 0.68;
  static const double _pull = 150.0; // Píxeles de arrastre para avanzar 1 tarjeta
  static const List<double> _cardAngles = [-3.8, 2.4, -1.8, 3.2, 1.2];

  double _turn = 0.0;
  late AnimationController _glideController;
  Animation<double>? _glideAnimation;

  late AnimationController _bobController;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  double _dragStartTurn = 0.0;
  DateTime _lastDragTime = DateTime.now();
  double _lastDragX = 0.0;
  double _dragVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );

    // Animación de respiración / flotación sutil en reposo (como en bencho.dev)
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
  }

  @override
  void dispose() {
    _glideController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  int get _currentIndex => _turn.round().clamp(0, max(0, widget.songs.length - 1));

  void _glideTo(int targetIndex) {
    if (widget.songs.isEmpty) return;
    final clampedTarget = targetIndex.clamp(0, widget.songs.length - 1).toDouble();
    _glideController.stop();

    final start = _turn;
    _glideAnimation = Tween<double>(begin: start, end: clampedTarget).animate(
      CurvedAnimation(parent: _glideController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _turn = _glideAnimation!.value;
        });
      });

    _glideController.forward(from: 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _glideController.stop();
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartTurn = _turn;
    _lastDragX = details.localPosition.dx;
    _lastDragTime = DateTime.now();
    _dragVelocity = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final now = DateTime.now();
    final dt = now.difference(_lastDragTime).inMilliseconds;
    if (dt > 0) {
      final dx = details.localPosition.dx - _lastDragX;
      _dragVelocity = (dx / dt) * 1000.0; // px/seg
      _lastDragX = details.localPosition.dx;
      _lastDragTime = now;
    }

    final totalDx = details.localPosition.dx - _dragStartX;
    final rawTurn = _dragStartTurn - (totalDx / _pull);
    final maxTurn = (widget.songs.length - 1).toDouble();

    // Resistencia elástica en los extremos
    double clamped;
    if (rawTurn < 0) {
      clamped = rawTurn * 0.28;
    } else if (rawTurn > maxTurn) {
      clamped = maxTurn + (rawTurn - maxTurn) * 0.28;
    } else {
      clamped = rawTurn;
    }

    setState(() {
      _turn = clamped;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final maxIndex = widget.songs.length - 1;
    if (maxIndex <= 0) {
      _glideTo(0);
      return;
    }

    final v = details.primaryVelocity ?? _dragVelocity;
    // Llevar hacia el objetivo con inercia según la velocidad del swipe
    final carry = (-v / 750.0).clamp(-2.0, 2.0);
    final target = (_turn + carry).round().clamp(0, maxIndex);

    HapticFeedback.selectionClick();
    _glideTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final songs = widget.songs;
    if (songs.isEmpty) return const SizedBox.shrink();

    final colors = widget.appColors;
    final currentSong = songs[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title!,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${_currentIndex + 1} de ${songs.length}',
                  style: TextStyle(
                    color: colors.textSecondary.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // ── Escenario del Carrusel 3D Orbital ──
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedBuilder(
            animation: _bobController,
            builder: (context, _) {
              final bobProgress = _bobController.value * 2 * pi;

              // Identificar tarjetas visibles (dentro de un radio de +-2.3 alrededor del frente)
              final visibleCards = <_CardRenderData>[];

              for (int i = 0; i < songs.length; i++) {
                final diff = i - _turn;
                if (diff.abs() > 2.3) continue; // Ocultar tarjetas en la parte posterior oculta

                // th = ángulo alrededor de la tornamesa circular (paso de 5 tarjetas por revolución)
                final th = diff * ((2 * pi) / 5.0);
                final f = ((cos(th) + 1.0) / 2.0).clamp(0.0, 1.0); // 1.0 frente, 0.0 fondo

                final x = sin(th) * _orbit;
                final y = -(1.0 - f) * _lean;
                final s = _backScale + (1.0 - _backScale) * f;
                final rotY = -sin(th) * 24.0 * (pi / 180.0);
                final naturalAngle = _cardAngles[i % _cardAngles.length];

                // Flotación / balanceo orgánico en reposo
                final bobY = _isDragging ? 0.0 : sin(bobProgress + i * 1.3) * 3.2;
                final bobAngle = _isDragging ? 0.0 : cos(bobProgress + i * 1.3) * 0.6;
                final rotZ = (naturalAngle + bobAngle) * (pi / 180.0);

                visibleCards.add(_CardRenderData(
                  index: i,
                  song: songs[i],
                  x: x,
                  y: y + bobY,
                  scale: s,
                  rotY: rotY,
                  rotZ: rotZ,
                  f: f,
                ));
              }

              // Ordenar de atrás hacia adelante para pintar correctamente en el Stack
              visibleCards.sort((a, b) => a.f.compareTo(b.f));

              return SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: visibleCards.map((data) {
                    final isFront = (data.index - _turn).abs() < 0.45;

                    return Positioned(
                      key: ValueKey('song_card_${data.song.id}_${data.index}'),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012) // Perspectiva 3D auténtica
                          ..translate(data.x, data.y, 0.0)
                          ..scale(data.scale)
                          ..rotateY(data.rotY)
                          ..rotateZ(data.rotZ),
                        child: GestureDetector(
                          onTap: () {
                            if (isFront) {
                              widget.onPlaySong(data.song, songs);
                            } else {
                              HapticFeedback.lightImpact();
                              _glideTo(data.index);
                            }
                          },
                          child: _buildCardItem(data.song, data.f, isFront, colors),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Tarjeta de Información y Controles de la Canción Frontal ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x991E1E22) : const Color(0xE6F5F5F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Botón de salto hacia atrás
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  color: _currentIndex > 0 ? colors.textPrimary : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex - 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),

                // Metadatos de la canción enfocada
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentSong.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.artists.map((a) => a.name).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Botón de reproducir canción enfocada
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onPlaySong(currentSong, songs);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Botón de salto hacia adelante
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  color: _currentIndex < songs.length - 1
                      ? colors.textPrimary
                      : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex < songs.length - 1
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex + 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCardItem(SongItem song, double f, bool isFront, AppColors colors) {
    final rawThumb = (song.thumbnail != null && song.thumbnail!.isNotEmpty)
        ? song.thumbnail!
        : (song.id.isNotEmpty ? 'https://i.ytimg.com/vi/${song.id}/hqdefault.jpg' : '');

    // Sombra proporcional a la cercanía con la cámara (más profunda y suave al frente)
    final shadowBlur = 8.0 + (18.0 * f);
    final shadowOffset = 4.0 + (8.0 * f);
    final shadowOpacity = (0.18 + (0.35 * f)).clamp(0.0, 0.6);

    return Container(
      width: _cardW,
      height: _cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
          if (isFront)
            BoxShadow(
              color: const Color(0xFF1DB954).withOpacity(0.20),
              blurRadius: 20,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Portada de la canción
            Builder(
              builder: (_) {
                if (rawThumb.isNotEmpty) {
                  return CachedNetworkImage(
                    imageUrl: rawThumb.resize(width: 400),
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1C1C1E),
                      child: Icon(Icons.music_note, color: colors.textSecondary, size: 48),
                    ),
                  );
                }
                return Container(
                  color: const Color(0xFF1C1C1E),
                  child: Icon(Icons.music_note, color: colors.textSecondary, size: 48),
                );
              },
            ),

            // Viñeta y degradado inferior con metadatos
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Brillo de borde de cristal / bisel refractario (car-sheen de bencho.dev)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12 * f + 0.06),
                    width: isFront ? 1.4 : 1.0,
                  ),
                ),
              ),
            ),

            // Botón central de play en la tarjeta frontal
            if (isFront)
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),

            // Título en la base de la tarjeta
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    song.artists.map((a) => a.name).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardRenderData {
  final int index;
  final SongItem song;
  final double x;
  final double y;
  final double scale;
  final double rotY;
  final double rotZ;
  final double f;

  _CardRenderData({
    required this.index,
    required this.song,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotY,
    required this.rotZ,
    required this.f,
  });
}

/// Carrusel 3D orbital tipo tornamesa para Artistas recomendado.
class BenchoArtistCarousel extends StatefulWidget {
  final List<ArtistItem> artists;
  final ValueChanged<String> onArtistClick;
  final VoidCallback? onSeeAllArtists;
  final AppColors appColors;
  final String? title;

  const BenchoArtistCarousel({
    super.key,
    required this.artists,
    required this.onArtistClick,
    this.onSeeAllArtists,
    required this.appColors,
    this.title,
  });

  @override
  State<BenchoArtistCarousel> createState() => _BenchoArtistCarouselState();
}

class _BenchoArtistCarouselState extends State<BenchoArtistCarousel> with TickerProviderStateMixin {
  static const double _cardW = 150.0;
  static const double _cardH = 210.0;
  static const double _orbit = 112.0;
  static const double _lean = 26.0;
  static const double _backScale = 0.68;
  static const double _pull = 150.0;
  static const List<double> _cardAngles = [-3.8, 2.4, -1.8, 3.2, 1.2];

  double _turn = 0.0;
  late AnimationController _glideController;
  Animation<double>? _glideAnimation;

  late AnimationController _bobController;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  double _dragStartTurn = 0.0;
  DateTime _lastDragTime = DateTime.now();
  double _lastDragX = 0.0;
  double _dragVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
  }

  @override
  void dispose() {
    _glideController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  int get _currentIndex {
    if (widget.artists.isEmpty) return 0;
    return _turn.round().clamp(0, widget.artists.length - 1);
  }

  void _glideTo(int targetIndex) {
    if (widget.artists.isEmpty) return;
    final clamped = targetIndex.clamp(0, widget.artists.length - 1).toDouble();
    if ((_turn - clamped).abs() < 0.001) return;

    _glideController.stop();
    final startTurn = _turn;
    _glideAnimation = Tween<double>(begin: startTurn, end: clamped).animate(
      CurvedAnimation(
        parent: _glideController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    )..addListener(() {
        setState(() {
          _turn = _glideAnimation!.value;
        });
      });

    _glideController.forward(from: 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _glideController.stop();
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartTurn = _turn;
    _lastDragX = details.localPosition.dx;
    _lastDragTime = DateTime.now();
    _dragVelocity = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final now = DateTime.now();
    final dt = now.difference(_lastDragTime).inMilliseconds;
    if (dt > 0) {
      final dx = details.localPosition.dx - _lastDragX;
      _dragVelocity = (dx / dt) * 1000.0;
      _lastDragX = details.localPosition.dx;
      _lastDragTime = now;
    }

    final totalDx = details.localPosition.dx - _dragStartX;
    final rawTurn = _dragStartTurn - (totalDx / _pull);
    final maxTurn = (widget.artists.length - 1).toDouble();

    double clamped;
    if (rawTurn < 0) {
      clamped = rawTurn * 0.28;
    } else if (rawTurn > maxTurn) {
      clamped = maxTurn + (rawTurn - maxTurn) * 0.28;
    } else {
      clamped = rawTurn;
    }

    setState(() {
      _turn = clamped;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final maxIndex = widget.artists.length - 1;
    if (maxIndex <= 0) {
      _glideTo(0);
      return;
    }

    const velocityThreshold = 280.0;
    int target = _turn.round();

    if (_dragVelocity.abs() > velocityThreshold) {
      final carry = (_dragVelocity < 0 ? 1 : -1) * (_dragVelocity.abs() > 900 ? 2 : 1);
      target = (_turn + carry * 0.7).round();
    }

    target = target.clamp(0, maxIndex);
    _glideTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final artists = widget.artists;
    if (artists.isEmpty) return const SizedBox.shrink();

    final colors = widget.appColors;
    final currentArtist = artists[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title ?? 'Artistas para ti',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.onSeeAllArtists != null) ...[
                GestureDetector(
                  onTap: widget.onSeeAllArtists,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF1DB954).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver todo',
                          style: TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: Color(0xFF1DB954),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${_currentIndex + 1} de ${artists.length}',
                style: TextStyle(
                  color: colors.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── Escenario 3D Orbital ──
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedBuilder(
            animation: _bobController,
            builder: (context, _) {
              final bobProgress = _bobController.value * 2 * pi;
              final visibleCards = <_ArtistCardRenderData>[];

              for (int i = 0; i < artists.length; i++) {
                final diff = i - _turn;
                if (diff.abs() > 2.3) continue;

                final th = diff * ((2 * pi) / 5.0);
                final f = ((cos(th) + 1.0) / 2.0).clamp(0.0, 1.0);

                final x = sin(th) * _orbit;
                final y = -(1.0 - f) * _lean;
                final s = _backScale + (1.0 - _backScale) * f;
                final rotY = -sin(th) * 24.0 * (pi / 180.0);
                final naturalAngle = _cardAngles[i % _cardAngles.length];

                final bobY = _isDragging ? 0.0 : sin(bobProgress + i * 1.3) * 3.2;
                final bobAngle = _isDragging ? 0.0 : cos(bobProgress + i * 1.3) * 0.6;
                final rotZ = (naturalAngle + bobAngle) * (pi / 180.0);

                visibleCards.add(_ArtistCardRenderData(
                  index: i,
                  artist: artists[i],
                  x: x,
                  y: y + bobY,
                  scale: s,
                  rotY: rotY,
                  rotZ: rotZ,
                  f: f,
                ));
              }

              visibleCards.sort((a, b) => a.f.compareTo(b.f));

              return SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: visibleCards.map((data) {
                    final isFront = (data.index - _turn).abs() < 0.45;

                    return Positioned(
                      key: ValueKey('artist_card_${data.artist.id}_${data.index}'),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..translate(data.x, data.y, 0.0)
                          ..scale(data.scale)
                          ..rotateY(data.rotY)
                          ..rotateZ(data.rotZ),
                        child: GestureDetector(
                          onTap: () {
                            if (isFront) {
                              HapticFeedback.mediumImpact();
                              widget.onArtistClick(data.artist.id);
                            } else {
                              HapticFeedback.lightImpact();
                              _glideTo(data.index);
                            }
                          },
                          child: _buildArtistCardItem(data.artist, data.f, isFront, colors),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Deck de Información y Controles del Artista Frontal ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x991E1E22) : const Color(0xE6F5F5F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  color: _currentIndex > 0 ? colors.textPrimary : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex - 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentArtist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DB954),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Artista recomendado',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 12,
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
                    HapticFeedback.mediumImpact();
                    widget.onArtistClick(currentArtist.id);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  color: _currentIndex < artists.length - 1
                      ? colors.textPrimary
                      : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex < artists.length - 1
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex + 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildArtistCardItem(ArtistItem artist, double f, bool isFront, AppColors colors) {
    final rawThumb = (artist.thumbnail != null && artist.thumbnail!.isNotEmpty)
        ? artist.thumbnail!
        : '';

    final shadowBlur = 8.0 + (18.0 * f);
    final shadowOffset = 4.0 + (8.0 * f);
    final shadowOpacity = (0.18 + (0.35 * f)).clamp(0.0, 0.6);

    return Container(
      width: _cardW,
      height: _cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
          if (isFront)
            BoxShadow(
              color: const Color(0xFF1DB954).withOpacity(0.25),
              blurRadius: 22,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Builder(
              builder: (_) {
                if (rawThumb.isNotEmpty) {
                  return CachedNetworkImage(
                    imageUrl: rawThumb.resize(width: 400),
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1C1C1E),
                      child: Icon(Icons.person, color: colors.textSecondary, size: 48),
                    ),
                  );
                }
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                    ),
                  ),
                  child: Icon(Icons.person, color: colors.textSecondary, size: 48),
                );
              },
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12 * f + 0.06),
                    width: isFront ? 1.4 : 1.0,
                  ),
                ),
              ),
            ),

            if (isFront)
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ARTISTA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistCardRenderData {
  final int index;
  final ArtistItem artist;
  final double x;
  final double y;
  final double scale;
  final double rotY;
  final double rotZ;
  final double f;

  _ArtistCardRenderData({
    required this.index,
    required this.artist,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotY,
    required this.rotZ,
    required this.f,
  });
}

/// Carrusel 3D orbital tipo tornamesa para Álbumes (Bencho.dev style)
class BenchoAlbumCarousel extends StatefulWidget {
  final List<AlbumItem> albums;
  final ValueChanged<String> onAlbumClick;
  final AppColors appColors;
  final String? title;

  const BenchoAlbumCarousel({
    super.key,
    required this.albums,
    required this.onAlbumClick,
    required this.appColors,
    this.title,
  });

  @override
  State<BenchoAlbumCarousel> createState() => _BenchoAlbumCarouselState();
}

class _BenchoAlbumCarouselState extends State<BenchoAlbumCarousel> with TickerProviderStateMixin {
  static const double _cardW = 150.0;
  static const double _cardH = 210.0;
  static const double _orbit = 112.0;
  static const double _lean = 26.0;
  static const double _backScale = 0.68;
  static const double _pull = 150.0;
  static const List<double> _cardAngles = [-3.8, 2.4, -1.8, 3.2, 1.2];

  double _turn = 0.0;
  late AnimationController _glideController;
  Animation<double>? _glideAnimation;

  late AnimationController _bobController;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  double _dragStartTurn = 0.0;
  DateTime _lastDragTime = DateTime.now();
  double _lastDragX = 0.0;
  double _dragVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    _glideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4800),
    )..repeat();
  }

  @override
  void dispose() {
    _glideController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  int get _currentIndex {
    if (widget.albums.isEmpty) return 0;
    return _turn.round().clamp(0, widget.albums.length - 1);
  }

  void _glideTo(int targetIndex) {
    if (widget.albums.isEmpty) return;
    final clamped = targetIndex.clamp(0, widget.albums.length - 1).toDouble();
    if ((_turn - clamped).abs() < 0.001) return;

    _glideController.stop();
    final startTurn = _turn;
    _glideAnimation = Tween<double>(begin: startTurn, end: clamped).animate(
      CurvedAnimation(
        parent: _glideController,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      ),
    )..addListener(() {
        setState(() {
          _turn = _glideAnimation!.value;
        });
      });

    _glideController.forward(from: 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _glideController.stop();
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartTurn = _turn;
    _lastDragX = details.localPosition.dx;
    _lastDragTime = DateTime.now();
    _dragVelocity = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final now = DateTime.now();
    final dt = now.difference(_lastDragTime).inMilliseconds;
    if (dt > 0) {
      final dx = details.localPosition.dx - _lastDragX;
      _dragVelocity = (dx / dt) * 1000.0;
      _lastDragX = details.localPosition.dx;
      _lastDragTime = now;
    }

    final totalDx = details.localPosition.dx - _dragStartX;
    final rawTurn = _dragStartTurn - (totalDx / _pull);
    final maxTurn = (widget.albums.length - 1).toDouble();

    double clamped;
    if (rawTurn < 0) {
      clamped = rawTurn * 0.28;
    } else if (rawTurn > maxTurn) {
      clamped = maxTurn + (rawTurn - maxTurn) * 0.28;
    } else {
      clamped = rawTurn;
    }

    setState(() {
      _turn = clamped;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
    final maxIndex = widget.albums.length - 1;
    if (maxIndex <= 0) {
      _glideTo(0);
      return;
    }

    const velocityThreshold = 280.0;
    int target = _turn.round();

    if (_dragVelocity.abs() > velocityThreshold) {
      final carry = (_dragVelocity < 0 ? 1 : -1) * (_dragVelocity.abs() > 900 ? 2 : 1);
      target = (_turn + carry * 0.7).round();
    }

    target = target.clamp(0, maxIndex);
    _glideTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final albums = widget.albums;
    if (albums.isEmpty) return const SizedBox.shrink();

    final colors = widget.appColors;
    final currentAlbum = albums[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      widget.title ?? 'Álbumes',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${albums.length}',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_currentIndex + 1} de ${albums.length}',
                style: TextStyle(
                  color: colors.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── Escenario 3D Orbital Centrado ──
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedBuilder(
            animation: _bobController,
            builder: (context, _) {
              final bobProgress = _bobController.value * 2 * pi;
              final visibleCards = <_AlbumCardRenderData>[];

              for (int i = 0; i < albums.length; i++) {
                final diff = i - _turn;
                if (diff.abs() > 2.3) continue;

                final th = diff * ((2 * pi) / 5.0);
                final f = ((cos(th) + 1.0) / 2.0).clamp(0.0, 1.0);

                final x = sin(th) * _orbit;
                final y = -(1.0 - f) * _lean;
                final s = _backScale + (1.0 - _backScale) * f;
                final rotY = -sin(th) * 24.0 * (pi / 180.0);
                final naturalAngle = _cardAngles[i % _cardAngles.length];

                final bobY = _isDragging ? 0.0 : sin(bobProgress + i * 1.3) * 3.2;
                final bobAngle = _isDragging ? 0.0 : cos(bobProgress + i * 1.3) * 0.6;
                final rotZ = (naturalAngle + bobAngle) * (pi / 180.0);

                visibleCards.add(_AlbumCardRenderData(
                  index: i,
                  album: albums[i],
                  x: x,
                  y: y + bobY,
                  scale: s,
                  rotY: rotY,
                  rotZ: rotZ,
                  f: f,
                ));
              }

              visibleCards.sort((a, b) => a.f.compareTo(b.f));

              return SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: visibleCards.map((data) {
                    final isFront = (data.index - _turn).abs() < 0.45;

                    return Positioned(
                      key: ValueKey('album_card_${data.album.browseId}_${data.index}'),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..translate(data.x, data.y, 0.0)
                          ..scale(data.scale)
                          ..rotateY(data.rotY)
                          ..rotateZ(data.rotZ),
                        child: GestureDetector(
                          onTap: () {
                            if (isFront) {
                              HapticFeedback.mediumImpact();
                              widget.onAlbumClick(data.album.browseId);
                            } else {
                              HapticFeedback.lightImpact();
                              _glideTo(data.index);
                            }
                          },
                          child: _buildAlbumCardItem(data.album, data.f, isFront, colors),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // ── Deck de Información y Controles del Álbum Frontal ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x991E1E22) : const Color(0xE6F5F5F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  color: _currentIndex > 0 ? colors.textPrimary : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex > 0
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex - 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentAlbum.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DB954),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentAlbum.year != null ? 'Álbum • ${currentAlbum.year}' : 'Álbum',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
                    HapticFeedback.mediumImpact();
                    widget.onAlbumClick(currentAlbum.browseId);
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1DB954), Color(0xFF10B981)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  color: _currentIndex < albums.length - 1
                      ? colors.textPrimary
                      : colors.textSecondary.withOpacity(0.3),
                  onPressed: _currentIndex < albums.length - 1
                      ? () {
                          HapticFeedback.lightImpact();
                          _glideTo(_currentIndex + 1);
                        }
                      : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAlbumCardItem(AlbumItem album, double f, bool isFront, AppColors colors) {
    final rawThumb = (album.thumbnail != null && album.thumbnail!.isNotEmpty)
        ? album.thumbnail!
        : '';

    final shadowBlur = 8.0 + (18.0 * f);
    final shadowOffset = 4.0 + (8.0 * f);
    final shadowOpacity = (0.18 + (0.35 * f)).clamp(0.0, 0.6);

    return Container(
      width: _cardW,
      height: _cardH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(shadowOpacity),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
          if (isFront)
            BoxShadow(
              color: const Color(0xFF1DB954).withOpacity(0.25),
              blurRadius: 22,
              spreadRadius: 1.5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (rawThumb.isNotEmpty)
              CachedNetworkImage(
                imageUrl: rawThumb.resize(width: 400),
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF1C1C1E),
                  child: Icon(Icons.album_rounded, color: colors.textSecondary, size: 48),
                ),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                  ),
                ),
                child: Icon(Icons.album_rounded, color: colors.textSecondary, size: 48),
              ),

            // Gradiente cinemático inferior
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),

            // Borde Bencho
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isFront
                        ? const Color(0xFF1DB954).withOpacity(0.8)
                        : Colors.white.withOpacity(0.12 * f + 0.06),
                    width: isFront ? 1.4 : 1.0,
                  ),
                ),
              ),
            ),

            // Botón interactivo central cuando está al frente
            if (isFront)
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withOpacity(0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),

            // Información inferior sobre la tarjeta
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      album.year != null ? '${album.year} • ÁLBUM' : 'ÁLBUM',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumCardRenderData {
  final int index;
  final AlbumItem album;
  final double x;
  final double y;
  final double scale;
  final double rotY;
  final double rotZ;
  final double f;

  _AlbumCardRenderData({
    required this.index,
    required this.album,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotY,
    required this.rotZ,
    required this.f,
  });
}

