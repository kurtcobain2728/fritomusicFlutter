import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FritoPullRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final AppColors appColors;
  final bool isRefreshing;

  const FritoPullRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    required this.appColors,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: appColors.accent,
      backgroundColor: appColors.surface,
      strokeWidth: 2.5,
      child: child,
    );
  }
}
