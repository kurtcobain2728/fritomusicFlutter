import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class MoreScreen extends StatelessWidget {
  final int favoritesCount;
  final int playlistsCount;
  final VoidCallback onNavigateToFavorites;
  final VoidCallback onNavigateToPlaylists;
  final VoidCallback? onNavigateToMigrate;
  final VoidCallback onNavigateToEqualizer;
  final VoidCallback onNavigateToAppearance;
  final VoidCallback onNavigateToDonations;
  final VoidCallback onNavigateToDownloadsManager;
  final VoidCallback onNavigateToHidden;
  final AppColors appColors;

  const MoreScreen({
    super.key,
    required this.favoritesCount,
    required this.playlistsCount,
    required this.onNavigateToFavorites,
    required this.onNavigateToPlaylists,
    this.onNavigateToMigrate,
    required this.onNavigateToEqualizer,
    required this.onNavigateToAppearance,
    required this.onNavigateToDonations,
    required this.onNavigateToDownloadsManager,
    required this.onNavigateToHidden,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {
        'title': 'Favoritos',
        'subtitle': '$favoritesCount canciones',
        'icon': Icons.favorite,
        'color': const Color(0xFFFF6B6B),
        'onTap': onNavigateToFavorites,
      },
      {
        'title': 'Listas de Reproducción',
        'subtitle': '$playlistsCount listas',
        'icon': Icons.format_list_bulleted,
        'color': appColors.accent,
        'onTap': onNavigateToPlaylists,
      },
      {
        'title': 'Migrar Playlist',
        'subtitle': 'Importa de Spotify, Apple, Deezer, YT y más',
        'icon': Icons.swap_horiz_rounded,
        'color': const Color(0xFF1DB954),
        'onTap': onNavigateToMigrate ?? () {},
      },
      {
        'title': 'Ocultos',
        'subtitle': 'Ver y restaurar archivos y carpetas ocultos',
        'icon': Icons.visibility_off,
        'color': const Color(0xFF7E57C2),
        'onTap': onNavigateToHidden,
      },
      {
        'title': 'Ecualizador',
        'subtitle': 'Ajusta el sonido',
        'icon': Icons.tune,
        'color': const Color(0xFF00BCD4),
        'onTap': onNavigateToEqualizer,
      },
      {
        'title': 'Apariencia',
        'subtitle': 'Temas, colores y estilo',
        'icon': Icons.palette,
        'color': const Color(0xFF9C27B0),
        'onTap': onNavigateToAppearance,
      },
      {
        'title': 'Donaciones',
        'subtitle': 'Apoya el proyecto',
        'icon': Icons.card_giftcard,
        'color': const Color(0xFFFFC107),
        'onTap': onNavigateToDonations,
      },
      {
        'title': 'Gestor de Descargas',
        'subtitle': 'Ver estado e historial de descargas',
        'icon': Icons.download_done,
        'color': const Color(0xFF4CAF50),
        'onTap': onNavigateToDownloadsManager,
      },
    ];

    return Scaffold(
      backgroundColor: appColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 24, bottom: 100),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Más',
                    style: TextStyle(
                      color: appColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu colección personal',
                    style: TextStyle(
                      color: appColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            ...menuItems.map((item) {
              final color = item['color'] as Color;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: InkWell(
                  onTap: item['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(item['icon'] as IconData, color: color, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: TextStyle(
                                  color: appColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                style: TextStyle(
                                  color: appColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: appColors.textSecondary.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
