import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class WaveformProgress extends StatefulWidget {
  final double progress; // 0.0 .. 1.0
  final ValueChanged<double> onProgressChange;
  final bool isPlaying;
  final AppColors appColors;

  const WaveformProgress({
    super.key,
    required this.progress,
    required this.onProgressChange,
    required this.isPlaying,
    required this.appColors,
  });

  @override
  State<WaveformProgress> createState() => _WaveformProgressState();
}

class _WaveformProgressState extends State<WaveformProgress> with SingleTickerProviderStateMixin {
  static const int numBars = 62;
  late final List<double> baseHeights;
  late final Ticker _ticker;
  double _phase = 0.0;
  Duration _lastElapsed = Duration.zero;

  double? _dragProgress;
  bool _isDragging = false;
  double _lastHapticProgress = -1.0;

  @override
  void initState() {
    super.initState();
    // Generar perfil realista de espectrograma de audio (graves potentes, medios armónicos y agudos sutiles)
    final random = Random(84);
    baseHeights = List.generate(numBars, (i) {
      final norm = i / (numBars - 1);
      // Curva envolvente de frecuencias maestras
      double envelope;
      if (norm < 0.25) {
        // Bajos / Sub-graves (0 - 250Hz)
        envelope = 0.55 + 0.40 * sin(norm / 0.25 * (pi / 2));
      } else if (norm < 0.75) {
        // Medios / Voces / Guitarras (250Hz - 4kHz)
        final midNorm = (norm - 0.25) / 0.50;
        envelope = 0.45 + 0.45 * sin(midNorm * pi);
      } else {
        // Agudos / Aire / Platillos (4kHz - 20kHz)
        final highNorm = (norm - 0.75) / 0.25;
        envelope = 0.35 + 0.30 * (1.0 - highNorm);
      }

      final organicVariance = (random.nextDouble() - 0.5) * 0.38;
      return (envelope + organicVariance).clamp(0.22, 0.96);
    });

    // Ticker de tiempo continuo infinito: NUNCA se reinicia ni da saltos, fluye como audio analógico real
    _ticker = createTicker((elapsed) {
      if (!widget.isPlaying) {
        _lastElapsed = elapsed;
        return;
      }
      final dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
      if (dt > 0 && dt < 0.1) {
        _phase += dt * 2.8; // Flujo constante y suave en tiempo real
        if (_phase > 100000.0) _phase -= 100000.0; // Prevenir desbordamiento de coma flotante
        if (mounted) setState(() {});
      }
    });

    if (widget.isPlaying) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant WaveformProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      if (_ticker.isActive) {
        _ticker.stop();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _triggerHapticIfNeeded(double current) {
    if ((current - _lastHapticProgress).abs() > 0.05) {
      _lastHapticProgress = current;
      HapticFeedback.selectionClick();
    }
  }

  void _startDrag(Offset localPos, double width) {
    if (width <= 0) return;
    HapticFeedback.lightImpact();
    final val = (localPos.dx / width).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _dragProgress = val;
    });
    _triggerHapticIfNeeded(val);
  }

  void _updateDrag(Offset localPos, double width) {
    if (width <= 0 || !_isDragging) return;
    final val = (localPos.dx / width).clamp(0.0, 1.0);
    setState(() {
      _dragProgress = val;
    });
    _triggerHapticIfNeeded(val);
  }

  void _finishDrag() {
    if (_dragProgress != null) {
      HapticFeedback.mediumImpact();
      widget.onProgressChange(_dragProgress!);
      setState(() {
        _isDragging = false;
        _dragProgress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayProgress = _dragProgress ?? widget.progress;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _startDrag(d.localPosition, width),
          onHorizontalDragUpdate: (d) => _updateDrag(d.localPosition, width),
          onHorizontalDragEnd: (_) => _finishDrag(),
          onHorizontalDragCancel: () => setState(() {
            _isDragging = false;
            _dragProgress = null;
          }),
          onTapDown: (d) {
            HapticFeedback.selectionClick();
            final val = (d.localPosition.dx / width).clamp(0.0, 1.0);
            widget.onProgressChange(val);
          },
          child: Container(
            height: 48,
            width: double.infinity,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size(width, 48),
              painter: _SpectrogramPainter(
                numBars: numBars,
                baseHeights: baseHeights,
                displayProgress: displayProgress,
                phase: _phase,
                isPlaying: widget.isPlaying,
                isDragging: _isDragging,
                appColors: widget.appColors,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  final int numBars;
  final List<double> baseHeights;
  final double displayProgress;
  final double phase;
  final bool isPlaying;
  final bool isDragging;
  final AppColors appColors;

  _SpectrogramPainter({
    required this.numBars,
    required this.baseHeights,
    required this.displayProgress,
    required this.phase,
    required this.isPlaying,
    required this.isDragging,
    required this.appColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;

    const gap = 2.4;
    final totalGaps = (numBars - 1) * gap;
    final barWidth = ((width - totalGaps) / numBars).clamp(2.0, 6.0);
    final centerY = height / 2.0;

    // Gradiente esmeralda / cian luminoso para las barras reproducidas
    final playedGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF34D399), // Menta brillante
        Color(0xFF10B981), // Esmeralda vibrante
        Color(0xFF06B6D4), // Cian eléctrico
        Color(0xFF10B981),
        Color(0xFF34D399),
      ],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    );

    // Color translúcido frosted glass para la porción no reproducida
    final unplayedColor = appColors.isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.black.withOpacity(0.14);

    final unplayedCapColor = appColors.isDark
        ? Colors.white.withOpacity(0.30)
        : Colors.black.withOpacity(0.24);

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    final unplayedCapPaint = Paint()
      ..color = unplayedCapColor
      ..style = PaintingStyle.fill;

    // 1. Dibujar línea central tenue de referencia espectral (DAW baseline)
    final baselinePaint = Paint()
      ..color = Colors.white.withOpacity(appColors.isDark ? 0.05 : 0.03)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, centerY), Offset(width, centerY), baselinePaint);

    // 2. Dibujar cada columna de frecuencias del espectrograma
    for (int i = 0; i < numBars; i++) {
      final x = i * (barWidth + gap);
      final barNorm = (i + 0.5) / numBars;
      final isPlayed = barNorm <= displayProgress;

      // Dinámica de oscilación de frecuencias en tiempo continuo infinito (cero cortes ni reinicios)
      double dynamicMultiplier = 1.0;
      if (isPlaying) {
        if (i < 15) {
          // Bajos: pulsación rítmica continua y profunda (bombo / bajo)
          dynamicMultiplier += sin(phase * 0.9 + i * 0.18) * 0.28;
        } else if (i < 42) {
          // Medios: modulación armónica suave (voces / melodía)
          dynamicMultiplier += sin(phase * 1.4 + i * 0.25) * 0.22 + cos(phase * 0.7 + i * 0.12) * 0.08;
        } else {
          // Agudos: brillo continuo de alta frecuencia (platillos / aire)
          dynamicMultiplier += sin(phase * 2.1 + i * 0.45) * 0.16;
        }

        // Resonancia cerca de la cabeza de reproducción (aura viva continua)
        final distToPlayhead = (barNorm - displayProgress).abs();
        if (distToPlayhead < 0.08) {
          final proximityFactor = (1.0 - (distToPlayhead / 0.08));
          dynamicMultiplier += sin(phase * 2.8) * 0.18 * proximityFactor;
        }
      }

      final rawBarHeight = height * baseHeights[i] * dynamicMultiplier;
      final barHeight = rawBarHeight.clamp(height * 0.16, height * 0.88);
      final topY = centerY - (barHeight / 2.0);

      final barRect = Rect.fromLTWH(x, topY, barWidth, barHeight);
      final rrect = RRect.fromRectAndRadius(barRect, Radius.circular(barWidth / 2.0));

      if (isPlayed) {
        final playedShader = playedGradient.createShader(barRect);
        final playedPaint = Paint()
          ..shader = playedShader
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, playedPaint);
      } else {
        canvas.drawRRect(rrect, unplayedPaint);

        // Puntas destacadas para dar textura de espectro analógico
        final capHeight = (barWidth * 0.9).clamp(2.0, 4.0);
        final topCapRect = Rect.fromLTWH(x, topY, barWidth, capHeight);
        final bottomCapRect = Rect.fromLTWH(x, topY + barHeight - capHeight, barWidth, capHeight);

        canvas.drawRRect(
          RRect.fromRectAndRadius(topCapRect, Radius.circular(barWidth / 2.0)),
          unplayedCapPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bottomCapRect, Radius.circular(barWidth / 2.0)),
          unplayedCapPaint,
        );
      }
    }

    // 3. Indicador de aguja láser y cursor táctil (The Scrubber Playhead)
    final thumbX = (displayProgress * width).clamp(2.0, width - 2.0);

    // Resplandor vertical láser de precisión
    final laserPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(isDragging ? 0.95 : 0.75)
      ..strokeWidth = isDragging ? 3.0 : 2.2
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF10B981).withOpacity(isDragging ? 0.45 : 0.25)
      ..strokeWidth = isDragging ? 8.0 : 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // Trazar resplandor y línea vertical
    canvas.drawLine(Offset(thumbX, 3), Offset(thumbX, height - 3), glowPaint);
    canvas.drawLine(Offset(thumbX, 4), Offset(thumbX, height - 4), laserPaint);

    // Cápsula central del cursor (Pill Handle)
    final pillWidth = isDragging ? 18.0 : 13.0;
    final pillHeight = isDragging ? 26.0 : 20.0;
    final pillRect = Rect.fromCenter(
      center: Offset(thumbX, centerY),
      width: pillWidth,
      height: pillHeight,
    );
    final pillRRect = RRect.fromRectAndRadius(pillRect, Radius.circular(pillWidth / 2.0));

    // Sombra del cursor
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawRRect(pillRRect.shift(const Offset(0, 2)), shadowPaint);

    // Cuerpo blanco esmeralda del cursor
    final cursorPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRRect(pillRRect, cursorPaint);

    // Borde brillante con aura esmeralda
    final borderPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDragging ? 2.2 : 1.6;
    canvas.drawRRect(pillRRect, borderPaint);

    // Pequeño grip / ranura central táctil en el cursor
    final gripPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(thumbX, centerY - 3),
      Offset(thumbX, centerY + 3),
      gripPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) {
    return oldDelegate.displayProgress != displayProgress ||
        oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.isDragging != isDragging ||
        oldDelegate.appColors != appColors;
  }
}
