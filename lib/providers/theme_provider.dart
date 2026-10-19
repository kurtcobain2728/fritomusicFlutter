import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyThemeMode = AppConstants.prefsThemeMode;
  static const String _keyAccentColor = AppConstants.prefsAccentColor;
  static const String _keyBackgroundImageUri = AppConstants.prefsBackgroundImageUri;
  static const String _keyBackgroundBlur = AppConstants.prefsBackgroundBlur;

  String _themeMode = AppConstants.defaultThemeMode;
  int _accentColorValue = AppConstants.defaultAccentColor;
  String? _backgroundImageUri;
  double _backgroundBlur = 0.0;

  String get themeMode => _themeMode;
  Color get accentColor => Color(_accentColorValue);
  int get accentColorValue => _accentColorValue;
  String? get backgroundImageUri => _backgroundImageUri;
  double get backgroundBlur => _backgroundBlur;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = prefs.getString(_keyThemeMode) ?? AppConstants.defaultThemeMode;
    _accentColorValue = prefs.getInt(_keyAccentColor) ?? AppConstants.defaultAccentColor;
    _backgroundImageUri = prefs.getString(_keyBackgroundImageUri);
    _backgroundBlur = prefs.getDouble(_keyBackgroundBlur) ?? 0.0;
    notifyListeners();
  }

  bool isDarkThemeActive() {
    switch (_themeMode) {
      case 'Claro':
        return false;
      case 'Oscuro':
        return true;
      case 'Automático':
        final hour = DateTime.now().hour;
        return hour >= 18 || hour < 6;
      case 'Color predominante':
        return false;
      default:
        return true;
    }
  }

  AppColors get appColors => AppColors.resolve(
        themeMode: _themeMode,
        accentColor: accentColor,
        backgroundImageUri: _backgroundImageUri,
        isDark: isDarkThemeActive(),
      );

  ThemeData get themeData => AppTheme.buildTheme(appColors);

  Future<void> setThemeMode(String mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<void> setAccentColor(int colorValue) async {
    _accentColorValue = colorValue;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAccentColor, colorValue);
  }

  Future<void> setBackgroundImage(String? uri) async {
    _backgroundImageUri = uri;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (uri != null) {
      await prefs.setString(_keyBackgroundImageUri, uri);
    } else {
      await prefs.remove(_keyBackgroundImageUri);
    }
  }

  Future<void> setBackgroundBlur(double blur) async {
    _backgroundBlur = blur;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBackgroundBlur, blur);
  }
}
