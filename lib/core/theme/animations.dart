import 'package:flutter/animation.dart';

class AppAnimations {
  // Duraciones en milisegundos
  static const int durationFast = 180;
  static const int durationMedium = 280;
  static const int durationSlow = 420;
  static const int durationPlayer = 380;

  static const Duration fast = Duration(milliseconds: durationFast);
  static const Duration medium = Duration(milliseconds: durationMedium);
  static const Duration slow = Duration(milliseconds: durationSlow);
  static const Duration player = Duration(milliseconds: durationPlayer);

  static const Curve defaultCurve = Curves.fastOutSlowIn;
  static const Curve springCurve = Curves.easeOutCubic;
}
