import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

class NavItem {
  final String id;
  final String label;
  final IconData selectedIcon;
  final IconData unselectedIcon;

  const NavItem(
    this.id,
    this.label,
    this.selectedIcon, {
    IconData? unselectedIcon,
  }) : unselectedIcon = unselectedIcon ?? selectedIcon;
}

class _IndicatorBounds {
  final double left;
  final double right;
  const _IndicatorBounds(this.left, this.right);
}

/// Barra de navegación flotante con estética Glassmorphism inspirada en GlassIconBar (bencho.dev).
/// Incorpora el indicador elástico bifásico:
/// - Fase 1 (Stretch/Dilate): El borde frontal salta hacia adelante estirando la cápsula a través de las casillas.
/// - Fase 2 (Settle/Bounce): La cola alcanza al objetivo contrayéndose con un rebote elástico suave (overshoot).
class BottomNavBar extends StatefulWidget {
  final String currentTab;
  final ValueChanged<String> onTabSelected;
  final AppColors appColors;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.appColors,
  });

  static const List<NavItem> navItems = [
    NavItem('inicio', 'Inicio', Icons.home_rounded, unselectedIcon: Icons.home_outlined),
    NavItem('biblioteca', 'Biblioteca', Icons.library_music_rounded, unselectedIcon: Icons.library_music_outlined),
    NavItem('stream', 'Stream', Icons.play_circle_filled_rounded, unselectedIcon: Icons.play_circle_outline_rounded),
    NavItem('buscar', 'Buscar', Icons.search_rounded, unselectedIcon: Icons.search_rounded),
    NavItem('mas', 'Más', Icons.grid_view_rounded, unselectedIcon: Icons.grid_view_outlined),
  ];

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _fromIndex = 0;
  int _toIndex = 0;
  double? _interruptedLeft;
  double? _interruptedRight;

  @override
  void initState() {
    super.initState();
    final initialIndex = _getIndex(widget.currentTab);
    _fromIndex = initialIndex;
    _toIndex = initialIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTab != oldWidget.currentTab) {
      final newIndex = _getIndex(widget.currentTab);
      if (newIndex != _toIndex) {
        _startAnimation(newIndex);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _getIndex(String tab) {
    final idx = BottomNavBar.navItems.indexWhere((it) => it.id == tab);
    return idx >= 0 ? idx : 0;
  }

  void _startAnimation(int targetIndex, {double? currentSlotWidth}) {
    if (currentSlotWidth != null && _controller.isAnimating) {
      final currentBounds = _computeBounds(currentSlotWidth);
      _interruptedLeft = currentBounds.left;
      _interruptedRight = currentBounds.right;
    } else {
      _interruptedLeft = null;
      _interruptedRight = null;
    }

    _fromIndex = _toIndex;
    _toIndex = targetIndex;
    _controller.forward(from: 0.0);
  }

  void _onItemTapped(String id, int index, double slotWidth) {
    if (index != _toIndex) {
      HapticFeedback.lightImpact();
      _startAnimation(index, currentSlotWidth: slotWidth);
      widget.onTabSelected(id);
    }
  }

  _IndicatorBounds _computeBounds(double slotWidth) {
    if (_controller.value >= 1.0 && _interruptedLeft == null) {
      return _IndicatorBounds(_toIndex * slotWidth, (_toIndex + 1) * slotWidth);
    }

    final t = _controller.value;
    final startLeft = _interruptedLeft ?? (_fromIndex * slotWidth);
    final startRight = _interruptedRight ?? ((_fromIndex + 1) * slotWidth);
    final destLeft = _toIndex * slotWidth;
    final destRight = (_toIndex + 1) * slotWidth;

    if (destRight > startRight) {
      // Movimiento hacia la derecha:
      // Borde líder (derecho) se adelanta rápido dilatando la cápsula
      const leadCurve = Interval(0.0, 0.62, curve: Curves.easeOutCubic);
      // Borde seguidor (izquierdo) se retrasa y contrae con amortiguación elástica
      const trailCurve = Interval(0.18, 1.0, curve: Curves.easeOutBack);

      final leadProgress = leadCurve.transform(t);
      final trailProgress = trailCurve.transform(t);

      final r = lerpDouble(startRight, destRight, leadProgress) ?? destRight;
      final l = lerpDouble(startLeft, destLeft, trailProgress) ?? destLeft;
      return _IndicatorBounds(l, r);
    } else if (destLeft < startLeft) {
      // Movimiento hacia la izquierda:
      // Borde líder (izquierdo) se adelanta rápido dilatando la cápsula hacia la izquierda
      const leadCurve = Interval(0.0, 0.62, curve: Curves.easeOutCubic);
      // Borde seguidor (derecho) se retrasa y contrae con amortiguación elástica
      const trailCurve = Interval(0.18, 1.0, curve: Curves.easeOutBack);

      final leadProgress = leadCurve.transform(t);
      final trailProgress = trailCurve.transform(t);

      final l = lerpDouble(startLeft, destLeft, leadProgress) ?? destLeft;
      final r = lerpDouble(startRight, destRight, trailProgress) ?? destRight;
      return _IndicatorBounds(l, r);
    } else {
      return _IndicatorBounds(destLeft, destRight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final isDark = colors.isDark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, max(8.0, bottomInset)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.45 : 0.14),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            if (isDark)
              BoxShadow(
                color: colors.accent.withOpacity(0.06),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: isDark ? const Color(0xCC151518) : const Color(0xE8FFFFFF),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.13)
                      : Colors.black.withOpacity(0.08),
                  width: 1.2,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth;
                  final slotWidth = trackWidth / BottomNavBar.navItems.length;

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final bounds = _computeBounds(slotWidth);
                      const padH = 3.0;
                      final indLeft = bounds.left + padH;
                      final indWidth = max(28.0, bounds.right - bounds.left - (padH * 2));

                      return Stack(
                        children: [
                          // ── Indicador elástico bifásico (bencho.dev glass pill) ──
                          Positioned(
                            left: indLeft,
                            top: 0,
                            bottom: 0,
                            width: indWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : colors.accent.withOpacity(0.14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.16)
                                      : colors.accent.withOpacity(0.24),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accent.withOpacity(isDark ? 0.20 : 0.12),
                                    blurRadius: 10,
                                    spreadRadius: -1,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ── Casillas de iconos y etiquetas ──
                          Row(
                            children: List.generate(BottomNavBar.navItems.length, (i) {
                              final item = BottomNavBar.navItems[i];
                              final isSelected = widget.currentTab == item.id;

                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _onItemTapped(item.id, i, slotWidth),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.14 : 1.0,
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutBack,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 220),
                                          transitionBuilder: (child, anim) => FadeTransition(
                                            opacity: anim,
                                            child: ScaleTransition(scale: anim, child: child),
                                          ),
                                          child: Icon(
                                            isSelected ? item.selectedIcon : item.unselectedIcon,
                                            key: ValueKey('${item.id}_$isSelected'),
                                            color: isSelected
                                                ? colors.accent
                                                : colors.textSecondary.withOpacity(0.55),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 220),
                                        style: TextStyle(
                                          color: isSelected
                                              ? colors.accent
                                              : colors.textSecondary.withOpacity(0.60),
                                          fontSize: 10,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          letterSpacing: isSelected ? 0.2 : 0.0,
                                        ),
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
