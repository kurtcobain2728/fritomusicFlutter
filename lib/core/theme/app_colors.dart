import 'dart:math';
import 'package:flutter/material.dart';

class AppColors {
  final Color background;
  final Color surface;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final String themeMode;
  final String? backgroundImageUri;

  const AppColors({
    required this.background,
    required this.surface,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    required this.themeMode,
    this.backgroundImageUri,
  });

  /// Calcula la luminancia relativa de un color según el estándar WCAG 2.1.
  /// Devuelve un valor entre 0.0 (negro puro) y 1.0 (blanco puro).
  static double calculateLuminance(Color color) {
    double linearize(double channel) {
      return (channel <= 0.04045)
          ? channel / 12.92
          : pow((channel + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = linearize(color.red / 255.0);
    final g = linearize(color.green / 255.0);
    final b = linearize(color.blue / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calcula si el texto sobre un color debería ser blanco o negro
  /// usando la ratio de contraste WCAG (mínimo 4.5:1 para texto normal).
  static Color textColorForBackground(Color bgColor) {
    final luminance = calculateLuminance(bgColor);
    return (luminance > 0.35) ? Colors.black : Colors.white;
  }

  /// Crea una versión más oscura o más clara de un color según su luminancia.
  /// Sirve para generar el color de "superficie" a partir del color predominante.
  static Color adjustColorForSurface(Color color) {
    final luminance = calculateLuminance(color);
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    if (luminance < 0.35) {
      // Color oscuro -> surface será más claro (añadir ~18% de brillo)
      return Color.fromARGB(
        255,
        ((r + 0.18).clamp(0.0, 1.0) * 255).round(),
        ((g + 0.18).clamp(0.0, 1.0) * 255).round(),
        ((b + 0.18).clamp(0.0, 1.0) * 255).round(),
      );
    } else {
      // Color claro -> surface será más oscuro (quitar ~18% de brillo)
      return Color.fromARGB(
        255,
        ((r - 0.18).clamp(0.0, 1.0) * 255).round(),
        ((g - 0.18).clamp(0.0, 1.0) * 255).round(),
        ((b - 0.18).clamp(0.0, 1.0) * 255).round(),
      );
    }
  }

  factory AppColors.resolve({
    required String themeMode,
    required Color accentColor,
    String? backgroundImageUri,
    required bool isDark,
  }) {
    if (themeMode == 'Color predominante') {
      final dominantColor = accentColor;
      final luminance = calculateLuminance(dominantColor);
      final isDominantDark = luminance <= 0.35;
      final textPrimary = textColorForBackground(dominantColor);
      final textSecondary = textPrimary.withOpacity(0.72);
      final surface = adjustColorForSurface(dominantColor);

      return AppColors(
        background: dominantColor,
        surface: surface,
        accent: textPrimary,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        isDark: isDominantDark,
        themeMode: themeMode,
        backgroundImageUri: null,
      );
    } else {
      if (backgroundImageUri != null) {
        return AppColors(
          background: Colors.transparent,
          surface: isDark ? const Color(0xAA121212) : const Color(0xAAFFFFFF),
          accent: accentColor,
          textPrimary: isDark ? Colors.white : Colors.black,
          textSecondary: isDark ? const Color(0xFFB3B3B3) : const Color(0xFF444444),
          isDark: isDark,
          themeMode: themeMode,
          backgroundImageUri: backgroundImageUri,
        );
      } else if (isDark) {
        return AppColors(
          background: const Color(0xFF121212),
          surface: const Color(0xFF1A1A1A),
          accent: accentColor,
          textPrimary: Colors.white,
          textSecondary: const Color(0xFFB3B3B3),
          isDark: true,
          themeMode: themeMode,
          backgroundImageUri: null,
        );
      } else {
        return AppColors(
          background: const Color(0xFFF5F5F5),
          surface: const Color(0xFFFFFFFF),
          accent: accentColor,
          textPrimary: Colors.black,
          textSecondary: const Color(0xFF444444),
          isDark: false,
          themeMode: themeMode,
          backgroundImageUri: null,
        );
      }
    }
  }
}
