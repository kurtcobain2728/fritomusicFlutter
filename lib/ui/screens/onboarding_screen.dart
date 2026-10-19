import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/home_provider.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final AppColors appColors;

  const OnboardingScreen({
    super.key,
    required this.onFinish,
    required this.appColors,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar con indicador y botón Omitir
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.music_note_rounded, color: colors.accent, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Frito Music',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < 4)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        widget.onFinish();
                      },
                      child: Text(
                        'Omitir',
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 36),
                ],
              ),
            ),

            // Contenido de las páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (page) {
                  HapticFeedback.selectionClick();
                  setState(() => _currentPage = page);
                },
                children: [
                  // 1. Bienvenida
                  _buildPage(
                    icon: Icons.graphic_eq_rounded,
                    tagText: '¡BIENVENIDO!',
                    title: 'Frito Music',
                    subtitle: 'Tu reproductor personal con streaming ilimitado, letras sincronizadas en tiempo real y sin interrupciones.',
                    features: ['🎧 Audio Hi-Fi', '✨ Sin Anuncios', '🚀 Stream & Local'],
                    buttonText: 'Comenzar',
                    accentColor: colors.accent,
                    onButtonTap: _nextPage,
                  ),
                  // 2. Notificaciones
                  _buildPage(
                    icon: Icons.notifications_active_rounded,
                    tagText: 'PERMISO RECOMENDADO',
                    title: 'Control en segundo plano',
                    subtitle: 'Permite notificaciones para controlar tu música cómodamente desde la barra de estado y pantalla de bloqueo.',
                    features: ['📲 Notificación activa', '🔒 Pantalla de bloqueo', '⏯️ Acceso rápido'],
                    buttonText: 'Conceder permiso',
                    accentColor: const Color(0xFF38BDF8),
                    onButtonTap: () async {
                      await Permission.notification.request();
                      _nextPage();
                    },
                  ),
                  // 3. Almacenamiento audio (Música Local)
                  _buildPage(
                    icon: Icons.folder_special_rounded,
                    tagText: 'ACCESO LOCAL',
                    title: 'Acceso a tu música local',
                    subtitle: 'Escanea y reproduce todas las canciones, álbumes y carpetas guardadas en la memoria de tu dispositivo.',
                    features: ['📂 Explorador de carpetas', '🏷️ Metadatos y carátulas', '⚡ Escaneo ultra rápido'],
                    buttonText: 'Conceder permiso',
                    accentColor: const Color(0xFF10B981),
                    onButtonTap: () async {
                      // Solo aquí se dispara el diálogo del sistema para audio/almacenamiento
                      var audioStatus = await Permission.audio.request();
                      if (!audioStatus.isGranted) {
                        final storageStatus = await Permission.storage.request();
                        if (storageStatus.isGranted) {
                          audioStatus = PermissionStatus.granted;
                        }
                      }
                      if (audioStatus.isPermanentlyDenied) {
                        openAppSettings();
                      }
                      if (context.mounted && audioStatus.isGranted) {
                        context.read<HomeProvider>().rescan(requestPermissionIfNeeded: true);
                      }
                      _nextPage();
                    },
                  ),
                  // 4. Gestión completa (Descargas)
                  _buildPage(
                    icon: Icons.download_for_offline_rounded,
                    tagText: 'DESCARGAS OFFLINE',
                    title: 'Descargas en tu dispositivo',
                    subtitle: 'Guarda tus canciones favoritas en alta calidad directamente en tu almacenamiento para escucharlas sin internet.',
                    features: ['💾 Carpeta Música/FritoMusic', '📴 Reproducción offline', '🎯 Calidad original'],
                    buttonText: 'Conceder permiso',
                    accentColor: const Color(0xFFA855F7),
                    onButtonTap: () async {
                      var status = await Permission.manageExternalStorage.request();
                      if (!status.isGranted) {
                        final storageStatus = await Permission.storage.request();
                        if (storageStatus.isGranted) {
                          status = PermissionStatus.granted;
                        }
                      }
                      _nextPage();
                    },
                  ),
                  // 5. Final
                  _buildPage(
                    icon: Icons.check_circle_rounded,
                    tagText: 'EXPERIENCIA LISTA',
                    title: '¡Todo listo para escuchar!',
                    subtitle: 'Comienza a disfrutar de una experiencia sonora moderna, fluida y con el mejor diseño.',
                    features: ['🔥 Todo configurado', '🎶 Millones de canciones', '💎 Disfruta Frito Music'],
                    buttonText: 'Empezar a escuchar',
                    accentColor: colors.accent,
                    onButtonTap: widget.onFinish,
                  ),
                ],
              ),
            ),

            // Indicador de Paginación animado
            Padding(
              padding: const EdgeInsets.only(bottom: 24, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isSelected = _currentPage == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isSelected ? 28 : 8,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accent
                          : (colors.isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.black.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colors.accent.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String tagText,
    required String title,
    required String subtitle,
    required List<String> features,
    required String buttonText,
    required Color accentColor,
    required VoidCallback onButtonTap,
  }) {
    final colors = widget.appColors;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono animado con anillos concéntricos luminosos
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final pulse = _pulseAnimation.value;
                final floatY = _floatAnimation.value;

                return Transform.translate(
                  offset: Offset(0, floatY),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Anillo exterior brillante
                      Container(
                        width: 130 + (pulse * 14),
                        height: 130 + (pulse * 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.05 + (pulse * 0.04)),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.12 + (pulse * 0.1)),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Anillo interior
                      Container(
                        width: 104 + (pulse * 8),
                        height: 104 + (pulse * 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.12 + (pulse * 0.08)),
                        ),
                      ),
                      // Contenedor principal del Icono con sombra
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor,
                              Color.lerp(accentColor, Colors.black, 0.25) ?? accentColor,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.45),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 40),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Tarjeta Glassmorphic con contenido
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              decoration: BoxDecoration(
                color: colors.isDark
                    ? const Color(0x6618181E)
                    : const Color(0xF0FFFFFF),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: colors.isDark ? 0.35 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge / Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tagText,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Título principal
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtítulo explicativo
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Chips de características
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: features.map((feat) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Text(
                          feat,
                          style: TextStyle(
                            color: colors.textPrimary.withValues(alpha: 0.9),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botón principal de acción
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  shadowColor: Colors.transparent,
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onButtonTap();
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
