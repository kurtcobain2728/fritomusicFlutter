import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/lyrics_models.dart';

class SyncedLyricsView extends StatefulWidget {
  final LyricsUiState state;
  final int currentPositionMs;
  final ValueChanged<int> onSeek;
  final VoidCallback onToggleTranslate;
  final bool isTranslated;
  final AppColors appColors;

  const SyncedLyricsView({
    super.key,
    required this.state,
    required this.currentPositionMs,
    required this.onSeek,
    required this.onToggleTranslate,
    required this.isTranslated,
    required this.appColors,
  });

  @override
  State<SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends State<SyncedLyricsView> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  int _lastActiveIndex = -1;
  int _syncOffsetMs = 0; // Calibración de sincronización en ms (saltos de 500ms = 0.50s)
  bool _userScrolledManually = false;
  Timer? _autoResyncTimer;

  @override
  void didUpdateWidget(covariant SyncedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _lastActiveIndex = -1;
      _userScrolledManually = false;
      _autoResyncTimer?.cancel();
      _lineKeys.clear();
      _syncOffsetMs = 0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
    if (widget.state is LyricsUiSuccess) {
      final lyrics = (widget.state as LyricsUiSuccess).lyrics;
      if (lyrics.lines.isNotEmpty && lyrics.isSynced && !_userScrolledManually) {
        final effectivePos = widget.currentPositionMs + _syncOffsetMs;
        final activeIdx = _findActiveIndex(lyrics.lines, effectivePos);
        if (activeIdx != _lastActiveIndex && activeIdx >= 0) {
          _lastActiveIndex = activeIdx;
          _scrollToActive(activeIdx);
        }
      }
    }
  }

  int _findActiveIndex(List<LyricLine> lines, int posMs) {
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].timestampMs >= 0 && posMs >= lines[i].timestampMs) {
        return i;
      }
    }
    return 0;
  }

  void _scrollToActive(int index) {
    if (!_scrollController.hasClients) return;

    // 1. Intentar centrar exactamente el widget de la línea activa usando su GlobalKey
    final key = _lineKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        alignment: 0.38, // 38% desde la parte superior (centro visual perfecto, sin taparse con barras)
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 2. Fallback con cálculo dinámico y addPostFrameCallback para asegurar que se centre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final retryKey = _lineKeys[index];
      if (retryKey != null && retryKey.currentContext != null) {
        Scrollable.ensureVisible(
          retryKey.currentContext!,
          alignment: 0.38,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      } else {
        const estimatedHeight = 85.0;
        final target = (index * estimatedHeight) - 180.0;
        _scrollController.animateTo(
          target.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onUserScrollStart() {
    if (!_userScrolledManually) {
      setState(() => _userScrolledManually = true);
    }
    _autoResyncTimer?.cancel();
    // Tras 3.8 segundos sin tocar la pantalla, volver a sincronizar automáticamente
    _autoResyncTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && _userScrolledManually) {
        setState(() => _userScrolledManually = false);
        _scrollToActive(_lastActiveIndex);
      }
    });
  }

  @override
  void dispose() {
    _autoResyncTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;

    if (widget.state is LyricsUiLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.4),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Sincronizando letra...',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Buscando líneas en tiempo real',
                style: TextStyle(
                  color: colors.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.state is LyricsUiEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colors.surface.withOpacity(0.35),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent.withOpacity(0.12),
                  border: Border.all(color: colors.accent.withOpacity(0.25)),
                ),
                child: Icon(Icons.lyrics_outlined, color: colors.accent, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                'Sin letras disponibles',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No pudimos encontrar las letras sincronizadas para esta canción.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.state is LyricsUiSuccess) {
      final lyrics = (widget.state as LyricsUiSuccess).lyrics;
      final lines = lyrics.lines;
      final isSynced = lyrics.isSynced;

      final effectivePos = widget.currentPositionMs + _syncOffsetMs;
      final activeIdx = isSynced ? _findActiveIndex(lines, effectivePos) : -1;

      return Stack(
        children: [
          // Lista de versos con cache amplio y centrado milimétrico garantizado
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is UserScrollNotification) {
                _onUserScrollStart();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              cacheExtent: 3500.0, // Construir con antelación para que las GlobalKeys existan y se puedan centrar
              padding: const EdgeInsets.only(left: 24, right: 24, top: 80, bottom: 220),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final isActive = isSynced && index == activeIdx;
                final isPast = isSynced && index < activeIdx;

                final originalText = line.text.isEmpty ? '♪' : line.text;
                final translatedText = line.translatedText;

                return GestureDetector(
                  key: _lineKeys.putIfAbsent(index, () => GlobalKey()),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _autoResyncTimer?.cancel();
                    if (isSynced && line.timestampMs >= 0) {
                      widget.onSeek(line.timestampMs);
                      setState(() => _userScrolledManually = false);
                      _scrollToActive(index);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.symmetric(
                      vertical: isActive ? 12 : 8,
                      horizontal: isActive ? 14 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? Colors.white.withOpacity(0.14)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Línea principal (Texto original)
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: !isSynced
                                ? colors.textPrimary
                                : (isActive
                                    ? Colors.white
                                    : (isPast
                                        ? colors.textPrimary.withOpacity(0.70)
                                        : colors.textSecondary.withOpacity(0.35))),
                            fontSize: isActive ? 26 : 20,
                            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                            letterSpacing: isActive ? -0.5 : -0.2,
                            height: 1.35,
                            shadows: isActive
                                ? [
                                    BoxShadow(
                                      color: colors.accent.withOpacity(0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(originalText),
                        ),

                        // Sublínea traducida (si está activa la traducción)
                        if (widget.isTranslated &&
                            translatedText != null &&
                            translatedText.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              color: !isSynced
                                  ? const Color(0xFF6EE7B7)
                                  : (isActive
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF6EE7B7).withOpacity(0.42)),
                              fontSize: isActive ? 17 : 14,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              height: 1.3,
                            ),
                            child: Text(translatedText),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Botón flotante para re-sincronizar tras scroll manual
          if (_userScrolledManually && isSynced)
            Positioned(
              bottom: 84,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _autoResyncTimer?.cancel();
                    setState(() => _userScrolledManually = false);
                    _scrollToActive(activeIdx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.accent,
                          const Color(0xFF10B981),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: AppColors.textColorForBackground(colors.accent),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sincronizar letra',
                          style: TextStyle(
                            color: AppColors.textColorForBackground(colors.accent),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Barra inferior flotante de control Bencho (Fuente, Traducción 文A, Calibrador ±0.50s)
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildFloatingControlBar(
              colors: colors,
              source: lyrics.source,
              isSynced: isSynced,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildFloatingControlBar({
    required AppColors colors,
    required String source,
    required bool isSynced,
  }) {
    final offsetSec = _syncOffsetMs / 1000.0;
    final offsetStr = offsetSec > 0
        ? '+${offsetSec.toStringAsFixed(2)}s'
        : '${offsetSec.toStringAsFixed(2)}s';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D).withOpacity(0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chip de Fuente (ej: LRCLIB)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    source.isNotEmpty ? source : 'LRCLIB',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: Colors.white.withOpacity(0.12)),
            const SizedBox(width: 8),

            // Botón de traducción 文A
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onToggleTranslate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: widget.isTranslated
                      ? colors.accent.withOpacity(0.25)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isTranslated
                        ? colors.accent.withOpacity(0.6)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Text(
                  '文A',
                  style: TextStyle(
                    color: widget.isTranslated ? colors.accent : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Controles de calibración ±0.50s (si la letra es sincronizada)
            if (isSynced) ...[
              const SizedBox(width: 8),
              Container(width: 1, height: 18, color: Colors.white.withOpacity(0.12)),
              const SizedBox(width: 6),

              Icon(Icons.schedule_rounded, size: 14, color: Colors.white.withOpacity(0.6)),
              const SizedBox(width: 4),

              // Botón adelantar (-0.50s)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _syncOffsetMs -= 500);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.remove_rounded, size: 15, color: Colors.white.withOpacity(0.85)),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  offsetStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),

              // Botón atrasar (+0.50s)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _syncOffsetMs += 500);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.add_rounded, size: 15, color: Colors.white.withOpacity(0.85)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
