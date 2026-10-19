import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData buildTheme(AppColors appColors) {
    final colorScheme = appColors.isDark
        ? ColorScheme.dark(
            primary: appColors.accent,
            onPrimary: AppColors.textColorForBackground(appColors.accent),
            secondary: appColors.accent,
            onSecondary: AppColors.textColorForBackground(appColors.accent),
            surface: appColors.surface,
            onSurface: appColors.textPrimary,
            background: appColors.background,
            onBackground: appColors.textPrimary,
          )
        : ColorScheme.light(
            primary: appColors.accent,
            onPrimary: AppColors.textColorForBackground(appColors.accent),
            secondary: appColors.accent,
            onSecondary: AppColors.textColorForBackground(appColors.accent),
            surface: appColors.surface,
            onSurface: appColors.textPrimary,
            background: appColors.background,
            onBackground: appColors.textPrimary,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: appColors.isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: appColors.background,
      canvasColor: appColors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: appColors.textPrimary),
        titleTextStyle: TextStyle(
          color: appColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        systemOverlayStyle: appColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: appColors.surface,
        selectedItemColor: appColors.accent,
        unselectedItemColor: appColors.textSecondary,
        elevation: 8,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: appColors.accent,
        inactiveTrackColor: appColors.textSecondary.withOpacity(0.3),
        thumbColor: appColors.accent,
        overlayColor: appColors.accent.withOpacity(0.2),
        trackHeight: 4,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: appColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: appColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: appColors.textSecondary,
          fontSize: 14,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: appColors.surface,
        modalBackgroundColor: appColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: appColors.textSecondary),
        bodyLarge: TextStyle(color: appColors.textPrimary),
        bodyMedium: TextStyle(color: appColors.textSecondary),
        bodySmall: TextStyle(color: appColors.textSecondary.withOpacity(0.8)),
      ),
    );
  }
}
