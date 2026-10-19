import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../providers/theme_provider.dart';

class AppearanceScreen extends StatefulWidget {
  final ThemeProvider themeProvider;
  final VoidCallback onBack;

  const AppearanceScreen({
    super.key,
    required this.themeProvider,
    required this.onBack,
  });

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final TextEditingController _hexController = TextEditingController();

  static const List<Map<String, dynamic>> presetColors = [
    {'name': 'Verde Spotify', 'color': 0xFF1DB954},
    {'name': 'Verde Bosque', 'color': 0xFF4B5D16},
    {'name': 'Azul Petróleo', 'color': 0xFF003049},
    {'name': 'Morado Oscuro', 'color': 0xFF42164B},
    {'name': 'Rojo Granate', 'color': 0xFF54162B},
    {'name': 'Naranja Bronce', 'color': 0xFFBC430D},
    {'name': 'Rosa Empolvado', 'color': 0xFFE8BCB9},
  ];

  void _showCustomColorDialog() {
    _hexController.text = '#${widget.themeProvider.accentColorValue.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    showDialog(
      context: context,
      builder: (context) {
        final colors = widget.themeProvider.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Color Personalizado', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _hexController,
            style: TextStyle(color: colors.textPrimary),
            cursorColor: const Color(0xFF1DB954),
            decoration: InputDecoration(
              labelText: 'Código Hexadecimal',
              labelStyle: TextStyle(color: colors.textSecondary),
              hintText: '#1DB954',
              filled: true,
              fillColor: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x0D000000),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                var hex = _hexController.text.trim().replaceAll('#', '');
                if (hex.length == 6) hex = 'FF$hex';
                final val = int.tryParse(hex, radix: 16);
                if (val != null) {
                  widget.themeProvider.setAccentColor(val);
                }
                Navigator.pop(context);
              },
              child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeProvider;
    final colors = theme.appColors;

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
          'Apariencia',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // 1. Modo de Tema
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Modo de Tema',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
            ),
          ),
          _buildThemeOption(title: 'Oscuro', icon: Icons.nights_stay_rounded, mode: 'Oscuro'),
          _buildThemeOption(title: 'Claro', icon: Icons.wb_sunny_rounded, mode: 'Claro'),
          _buildThemeOption(title: 'Color predominante', icon: Icons.palette_rounded, mode: 'Color predominante'),
          _buildThemeOption(title: 'Automático', icon: Icons.smartphone_rounded, mode: 'Automático'),

          const SizedBox(height: 24),

          // 2. Fondo de Pantalla
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'Fondo de Pantalla',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: theme.backgroundImageUri == null
                ? GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      try {
                        const channel = MethodChannel(AppConstants.platformChannel);
                        final path = await channel.invokeMethod<String>('pickBackgroundImage');
                        if (path != null && path.isNotEmpty) {
                          theme.setBackgroundImage(path);
                        }
                      } catch (e) {
                        debugPrint('Error seleccionando imagen: $e');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x0F000000),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF1DB954), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Seleccionar imagen de fondo',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.image_rounded, color: Color(0xFF1DB954), size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Fondo activo',
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              theme.setBackgroundImage(null);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Quitar',
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Desenfoque de fondo', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                            theme.backgroundBlur == 0 ? 'Sin desenfoque' : '${theme.backgroundBlur.round()}px',
                            style: const TextStyle(color: Color(0xFF1DB954), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFF1DB954),
                          inactiveTrackColor: colors.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08),
                          thumbColor: const Color(0xFF1DB954),
                          overlayColor: const Color(0xFF1DB954).withOpacity(0.2),
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: theme.backgroundBlur,
                          min: 0,
                          max: 40,
                          divisions: 40,
                          onChanged: (val) => theme.setBackgroundBlur(val),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // 3. Color de Acento
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              theme.themeMode == 'Color predominante' ? 'Color Predominante' : 'Color de Acento',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                ...presetColors.map((preset) {
                  final colorVal = preset['color'] as int;
                  final isSelected = theme.accentColorValue == colorVal;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      theme.setAccentColor(colorVal);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Color(colorVal).withOpacity(0.45),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 24) : null,
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showCustomColorDialog();
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(Icons.colorize_rounded, color: colors.textPrimary, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({required String title, required IconData icon, required String mode}) {
    final theme = widget.themeProvider;
    final colors = theme.appColors;
    final isSelected = theme.themeMode == mode;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF1DB954).withOpacity(0.5)
              : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          width: isSelected ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          theme.setThemeMode(mode);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isSelected ? const Color(0xFF1DB954) : colors.textSecondary).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFF1DB954) : colors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
