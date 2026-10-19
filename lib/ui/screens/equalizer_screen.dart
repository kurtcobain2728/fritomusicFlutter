import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/player_provider.dart';
import '../../services/equalizer_service.dart';

class EqualizerScreen extends StatefulWidget {
  final PlayerProvider playerProvider;
  final VoidCallback onBack;
  final AppColors appColors;

  const EqualizerScreen({
    super.key,
    required this.playerProvider,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final EqualizerService _eq = EqualizerService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final player = widget.playerProvider.audioHandler.player;
    final sessionId = player.androidAudioSessionId;
    if (sessionId != null && sessionId > 0) {
      await _eq.init(sessionId);
    } else {
      await _eq.loadData();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final isEnabled = _eq.isEnabled;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 16),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onBack();
          },
        ),
        title: Text(
          'Ecualizador',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                // Master On/Off Glass Switch Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEnabled
                          ? const Color(0xFF1DB954).withOpacity(0.35)
                          : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                      width: 1.2,
                    ),
                    boxShadow: isEnabled
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1DB954).withOpacity(0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (isEnabled ? const Color(0xFF1DB954) : colors.textSecondary).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: isEnabled ? const Color(0xFF1DB954) : colors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activar Ecualizador',
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEnabled ? 'Procesando audio en tiempo real' : 'Apagado (audio original sin alterar)',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: isEnabled,
                        activeColor: const Color(0xFF1DB954),
                        activeTrackColor: const Color(0xFF1DB954).withOpacity(0.35),
                        onChanged: (val) async {
                          HapticFeedback.mediumImpact();
                          await _eq.setEnabled(val);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Bandas Ecualizadoras Glass Card
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    ),
                  ),
                  child: _eq.bands.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.music_note_rounded, color: colors.textSecondary.withOpacity(0.4), size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  'Reproduce una canción para inicializar el ecualizador del sistema.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: _eq.bands.map((band) {
                            final minLvl = band.minLevel.toDouble();
                            final maxLvl = band.maxLevel.toDouble();
                            final curLvl = band.currentLevel.toDouble().clamp(minLvl, maxLvl);
                            final dB = (curLvl / 100.0).round();

                            return Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isEnabled ? const Color(0xFF1DB954) : colors.textSecondary).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${dB >= 0 ? '+' : ''}${dB}dB',
                                    style: TextStyle(
                                      color: isEnabled ? const Color(0xFF1DB954) : colors.textSecondary.withOpacity(0.5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 170,
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: isEnabled ? const Color(0xFF1DB954) : colors.textSecondary.withOpacity(0.3),
                                        inactiveTrackColor: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                                        thumbColor: isEnabled ? const Color(0xFF1DB954) : colors.textSecondary.withOpacity(0.4),
                                        overlayColor: const Color(0xFF1DB954).withOpacity(0.2),
                                        trackHeight: 4,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                      ),
                                      child: Slider(
                                        value: curLvl,
                                        min: minLvl < maxLvl ? minLvl : -1500,
                                        max: minLvl < maxLvl ? maxLvl : 1500,
                                        onChanged: isEnabled
                                            ? (v) {
                                                setState(() {
                                                  band.currentLevel = v.round();
                                                });
                                                _eq.setBandLevel(band.index, v.round());
                                              }
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  band.freqLabel,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                ),

                const SizedBox(height: 24),

                // Presets Predefinidos
                if (_eq.presets.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Ajustes predefinidos',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eq.presets.map((p) {
                      final isSel = _eq.selectedPreset == p.index;
                      return GestureDetector(
                        onTap: isEnabled
                            ? () async {
                                HapticFeedback.lightImpact();
                                await _eq.usePreset(p.index);
                                setState(() {});
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF1DB954)
                                : (colors.isDark ? const Color(0x441C1C22) : const Color(0xB8FFFFFF)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0xFF1DB954)
                                  : (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                              width: 1,
                            ),
                            boxShadow: isSel
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1DB954).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            p.name,
                            style: TextStyle(
                              color: isSel ? Colors.white : (isEnabled ? colors.textPrimary : colors.textSecondary.withOpacity(0.5)),
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
    );
  }
}
