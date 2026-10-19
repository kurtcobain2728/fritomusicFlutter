import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repository/favorite_artists_manager.dart';

class StreamFavoriteArtistsScreen extends StatefulWidget {
  final ValueChanged<String> onArtistClick;
  final VoidCallback onBack;
  final AppColors? appColors;

  const StreamFavoriteArtistsScreen({
    super.key,
    required this.onArtistClick,
    required this.onBack,
    this.appColors,
  });

  @override
  State<StreamFavoriteArtistsScreen> createState() => _StreamFavoriteArtistsScreenState();
}

class _StreamFavoriteArtistsScreenState extends State<StreamFavoriteArtistsScreen> {
  final FavoriteArtistsManager _manager = FavoriteArtistsManager.instance;

  @override
  void initState() {
    super.initState();
    _manager.addListener(_refresh);
  }

  @override
  void dispose() {
    _manager.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors ?? const AppColors(
      background: Color(0xFF121212),
      surface: Color(0xFF1A1A1A),
      accent: Color(0xFF1DB954),
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB3B3B3),
      isDark: true,
      themeMode: 'Oscuro',
    );
    final artists = _manager.favoriteArtists;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: widget.onBack,
        ),
        title: Text('Artistas Favoritos', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: artists.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, color: colors.textSecondary.withOpacity(0.4), size: 64),
                  const SizedBox(height: 16),
                  Text('Aún no tienes artistas favoritos', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artist.thumbnail!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(Icons.person, color: colors.accent),
                          )
                        : Icon(Icons.person, color: colors.accent),
                  ),
                  title: Text(artist.title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () => _manager.removeFavorite(artist.id),
                  ),
                  onTap: () => widget.onArtistClick(artist.id),
                );
              },
            ),
    );
  }
}
