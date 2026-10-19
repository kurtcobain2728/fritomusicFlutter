import 'package:flutter/services.dart';
import '../core/constants.dart';

class EqualizerBand {
  final int index;
  final int centerFreqHz;
  final int minLevel;
  final int maxLevel;
  int currentLevel;

  EqualizerBand({
    required this.index,
    required this.centerFreqHz,
    required this.minLevel,
    required this.maxLevel,
    required this.currentLevel,
  });

  factory EqualizerBand.fromMap(Map<dynamic, dynamic> map) {
    return EqualizerBand(
      index: map['index'] as int? ?? 0,
      centerFreqHz: map['centerFreqHz'] as int? ?? 1000,
      minLevel: map['minLevel'] as int? ?? -1000,
      maxLevel: map['maxLevel'] as int? ?? 1000,
      currentLevel: map['currentLevel'] as int? ?? 0,
    );
  }

  String get freqLabel {
    if (centerFreqHz >= 1000) {
      final khz = centerFreqHz / 1000.0;
      return khz == khz.roundToDouble() ? '${khz.toInt()} kHz' : '${khz.toStringAsFixed(1)} kHz';
    }
    return '$centerFreqHz Hz';
  }
}

class EqualizerPreset {
  final int index;
  final String name;

  EqualizerPreset({required this.index, required this.name});

  factory EqualizerPreset.fromMap(Map<dynamic, dynamic> map) {
    return EqualizerPreset(
      index: map['index'] as int? ?? -1,
      name: map['name'] as String? ?? '',
    );
  }
}

class EqualizerService {
  static const MethodChannel _channel = MethodChannel(AppConstants.platformChannel);

  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  bool isEnabled = false;
  int selectedPreset = -1;
  List<EqualizerBand> bands = [];
  List<EqualizerPreset> presets = [];

  Future<void> init(int audioSessionId) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'initEqualizer',
        {'audioSessionId': audioSessionId},
      );
      if (res != null) {
        _parseData(res);
      }
    } catch (_) {}
  }

  Future<void> loadData() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getEqualizerData');
      if (res != null) {
        _parseData(res);
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEqualizerEnabled', {'enabled': enabled});
      isEnabled = enabled;
    } catch (_) {}
  }

  Future<void> setBandLevel(int bandIndex, int level) async {
    try {
      await _channel.invokeMethod('setBandLevel', {
        'bandIndex': bandIndex,
        'level': level,
      });
      selectedPreset = -1;
      final band = bands.firstWhere((b) => b.index == bandIndex, orElse: () => bands[0]);
      band.currentLevel = level;
    } catch (_) {}
  }

  Future<void> usePreset(int presetIndex) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'usePreset',
        {'presetIndex': presetIndex},
      );
      if (res != null) {
        _parseData(res);
      }
    } catch (_) {}
  }

  void _parseData(Map<dynamic, dynamic> data) {
    isEnabled = data['isEnabled'] as bool? ?? false;
    selectedPreset = data['selectedPreset'] as int? ?? -1;

    final rawBands = data['bands'] as List<dynamic>? ?? [];
    bands = rawBands.map((b) => EqualizerBand.fromMap(b as Map<dynamic, dynamic>)).toList();

    final rawPresets = data['presets'] as List<dynamic>? ?? [];
    presets = rawPresets.map((p) => EqualizerPreset.fromMap(p as Map<dynamic, dynamic>)).toList();
  }
}
