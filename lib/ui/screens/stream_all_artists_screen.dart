import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../providers/stream_provider.dart';

class StreamAllArtistsScreen extends StatefulWidget {
  final StreamProvider streamViewModel;
  final ValueChanged<String> onArtistClick;
  final VoidCallback onBack;
  final AppColors? appColors;

  const StreamAllArtistsScreen({
    super.key,
    required this.streamViewModel,
    required this.onArtistClick,
    required this.onBack,
    this.appColors,
  });

  @override
  State<StreamAllArtistsScreen> createState() => _StreamAllArtistsScreenState();
}

class _StreamAllArtistsScreenState extends State<StreamAllArtistsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.streamViewModel.paginatedArtists.isEmpty) {
        widget.streamViewModel.initPaginatedArtists();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      widget.streamViewModel.loadMoreArtists();
    }
  }

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

    // Observar artistas paginados del ViewModel (descubrimiento infinito)
    return AnimatedBuilder(
      animation: widget.streamViewModel,
      builder: (context, _) {
        final artists = widget.streamViewModel.paginatedArtists.isNotEmpty
            ? widget.streamViewModel.paginatedArtists
            : widget.streamViewModel.homeShelves
                .expand((s) => s.items)
                .whereType<ArtistItem>()
                .where((a) => a.thumbnail != null && a.thumbnail!.isNotEmpty)
                .fold<List<ArtistItem>>([], (acc, a) {
                  if (!acc.any((item) => item.id == a.id)) acc.add(a);
                  return acc;
                });

        final isRefreshing = widget.streamViewModel.isRefreshingArtists;
        final isLoadingMore = widget.streamViewModel.isLoadingMoreArtists;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Center(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onBack();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: colors.textPrimary),
                ),
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Artistas para ti',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (artists.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${artists.length} artistas recomendados',
                      style: const TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.streamViewModel.refreshRecommendedArtists();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: isRefreshing
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1DB954),
                                ),
                              ),
                            )
                          : Icon(Icons.refresh_rounded, size: 20, color: colors.textPrimary),
                    ),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                height: 1,
              ),
            ),
          ),
          body: isRefreshing && artists.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF1DB954),
                  ),
                )
              : artists.isEmpty
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0x991E1E22) : const Color(0xE6F5F5F7),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_search_rounded, color: Color(0xFF1DB954), size: 36),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Descubriendo artistas para ti',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Conectando con tus preferencias para encontrar los mejores artistas recomendados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: () => widget.streamViewModel.refreshRecommendedArtists(),
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                              label: const Text(
                                'Reintentar',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF1DB954),
                      backgroundColor: colors.surface,
                      onRefresh: () => widget.streamViewModel.refreshRecommendedArtists(),
                      child: GridView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.69,
                        ),
                        itemCount: artists.length + (isLoadingMore ? 3 : 0),
                        itemBuilder: (context, index) {
                          if (index >= artists.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Color(0xFF1DB954),
                                  ),
                                ),
                              ),
                            );
                          }

                          final artist = artists[index];
                          return InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onArtistClick(artist.id);
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Avatar del artista con halo degradado y sombra suave
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFF1DB954).withOpacity(0.65),
                                        colors.isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(colors.isDark ? 0.4 : 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: artist.thumbnail!,
                                            width: 85,
                                            height: 85,
                                            fit: BoxFit.cover,
                                            fadeInDuration: Duration.zero,
                                            errorWidget: (_, __, ___) => Container(
                                              width: 85,
                                              height: 85,
                                              color: colors.surface,
                                              child: Icon(Icons.person_rounded, color: colors.textSecondary, size: 36),
                                            ),
                                          )
                                        : Container(
                                            width: 85,
                                            height: 85,
                                            color: colors.surface,
                                            child: Icon(Icons.person_rounded, color: colors.textSecondary, size: 36),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Nombre del artista
                                Text(
                                  artist.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Etiqueta discreta de artista
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: colors.isDark ? const Color(0x22FFFFFF) : const Color(0x11000000),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Artista',
                                    style: TextStyle(
                                      color: colors.textSecondary.withOpacity(0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }
}

