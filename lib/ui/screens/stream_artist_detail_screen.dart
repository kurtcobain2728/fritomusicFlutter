import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/favorite_artists_manager.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/bencho_carousel.dart';
import 'youtube_login_screen.dart';

class StreamArtistDetailScreen extends StatefulWidget {
  final String artistId;
  final StreamProvider streamViewModel;
  final PlayerProvider playerViewModel;
  final ValueChanged<String> onNavigateToAlbum;
  final ValueChanged<String> onNavigateToArtist;
  final VoidCallback onBack;
  final AppColors? appColors;

  const StreamArtistDetailScreen({
    super.key,
    required this.artistId,
    required this.streamViewModel,
    required this.playerViewModel,
    required this.onNavigateToAlbum,
    required this.onNavigateToArtist,
    required this.onBack,
    this.appColors,
  });

  @override
  State<StreamArtistDetailScreen> createState() => _StreamArtistDetailScreenState();
}

class _StreamArtistDetailScreenState extends State<StreamArtistDetailScreen> {
  final FavoriteArtistsManager _favManager = FavoriteArtistsManager.instance;

  @override
  void initState() {
    super.initState();
    widget.streamViewModel.loadArtist(widget.artistId);
    _favManager.addListener(_onFavChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && YouTubeLoginManager.instance.isLoggedIn) {
        final onlineLib = context.read<OnlineLibraryProvider>();
        if (onlineLib.subscribedArtists.isEmpty && !onlineLib.isLoadingSubscribed) {
          onlineLib.loadSubscribedArtists();
        }
      }
    });
  }

  @override
  void dispose() {
    _favManager.removeListener(_onFavChange);
    super.dispose();
  }

  void _onFavChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final stream = widget.streamViewModel;
    final artistData = stream.selectedArtist;

    final fallbackColors = const AppColors(
      background: Color(0xFF121212),
      surface: Color(0xFF1A1A1A),
      accent: Color(0xFF1DB954),
      textPrimary: Colors.white,
      textSecondary: Color(0xFFB3B3B3),
      isDark: true,
      themeMode: 'Oscuro',
    );
    final colors = widget.appColors ?? fallbackColors;

    if (stream.isLoadingDetail || artistData == null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary),
            onPressed: widget.onBack,
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
    }

    final artist = artistData.artist;
    final isFav = _favManager.isFavorite(widget.artistId);
    final onlineLib = context.watch<OnlineLibraryProvider>();
    final isYtLoggedIn = YouTubeLoginManager.instance.isLoggedIn;
    final isSubscribed = onlineLib.isSubscribed(artist.id);

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // Immersive Hero Header Sliver
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colors.background,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onBack();
              },
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSubscribed
                        ? const Color(0xFFFF0000).withOpacity(0.2)
                        : Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSubscribed
                          ? const Color(0xFFFF0000).withOpacity(0.6)
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Icon(
                    isSubscribed ? Icons.subscriptions_rounded : Icons.subscriptions_outlined,
                    color: isSubscribed ? const Color(0xFFFF0000) : Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: isSubscribed ? 'Suscrito' : 'Suscribirse',
                onPressed: () => _handleToggleSubscribe(artist, colors, onlineLib, isYtLoggedIn, isSubscribed),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFav
                          ? Colors.amber.withOpacity(0.5)
                          : Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Icon(
                    isFav ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFav ? Colors.amber : Colors.white,
                    size: 22,
                  ),
                ),
                tooltip: isFav ? 'En favoritos' : 'Añadir a favoritos',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _favManager.toggleFavorite(artist);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              title: Text(
                artist.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(0, 2)),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (artist.thumbnail != null && artist.thumbnail!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: artist.thumbnail!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: colors.surface),
                    )
                  else
                    Container(color: colors.surface),

                  // Gradiente cinemático oscuro
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          colors.background.withOpacity(0.85),
                          colors.background,
                        ],
                        stops: const [0.0, 0.35, 0.8, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fila de información del canal y botón de Suscribirse
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          artist.subscriberCountText != null && artist.subscriberCountText!.isNotEmpty
                              ? artist.subscriberCountText!
                              : (isSubscribed ? 'Canal suscrito' : 'Canal oficial de YouTube'),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSubscribeButton(artist, colors, onlineLib, isYtLoggedIn, isSubscribed),
                ],
              ),
            ),
          ),

          // Botones de acción rápida: Reproducir todo & Aleatorio
          if (artistData.topSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          final track = artistData.topSongs.first.toStreamableTrack();
                          stream.playStreamableTrack(track, widget.playerViewModel);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF22C55E).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Reproducir todo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (artistData.topSongs.isNotEmpty) {
                          final shuffled = List.of(artistData.topSongs)..shuffle();
                          final track = shuffled.first.toStreamableTrack();
                          stream.playStreamableTrack(track, widget.playerViewModel);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x0F000000),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Icon(Icons.shuffle_rounded, color: colors.textPrimary, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Canciones Populares con tarjetas Bencho Glass
          if (artistData.topSongs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      'Canciones más escuchadas',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${artistData.topSongs.length}',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final song = artistData.topSongs[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        stream.playStreamableTrack(song.toStreamableTrack(), widget.playerViewModel);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            // Posición en el ranking
                            SizedBox(
                              width: 26,
                              child: Text(
                                '${index + 1}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: index < 3 ? const Color(0xFF1DB954) : colors.textSecondary.withOpacity(0.6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Miniatura
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl: song.thumbnail ?? '',
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(Icons.music_note_rounded, color: colors.accent),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Título y detalles
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    song.artistNames,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Botón de play individual
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF1DB954), size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: artistData.topSongs.length,
              ),
            ),
          ],

          // Álbumes en Carrusel 3D Orbital Bencho
          if (artistData.albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: BenchoAlbumCarousel(
                title: 'Álbumes',
                albums: artistData.albums,
                appColors: colors,
                onAlbumClick: (browseId) => widget.onNavigateToAlbum(browseId),
              ),
            ),
          ],

          // Artistas Similares en Carrusel 3D Orbital Bencho
          if (artistData.relatedArtists.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: BenchoArtistCarousel(
                title: 'Artistas similares',
                artists: artistData.relatedArtists,
                appColors: colors,
                onArtistClick: (id) => widget.onNavigateToArtist(id),
              ),
            ),
          ],

          // Sobre el artista (Biografía e Información)
          SliverToBoxAdapter(
            child: _ArtistBioSection(
              artistName: artist.title,
              initialBio: artistData.description,
              appColors: colors,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Future<void> _handleToggleSubscribe(
    ArtistItem artist,
    AppColors colors,
    OnlineLibraryProvider onlineLib,
    bool isYtLoggedIn,
    bool isSubscribed,
  ) async {
    HapticFeedback.mediumImpact();
    if (!isYtLoggedIn) {
      _showLoginPrompt(artist, colors, onlineLib);
      return;
    }

    final wasSubscribed = isSubscribed;
    await onlineLib.toggleSubscribeArtist(artist);
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                wasSubscribed ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wasSubscribed
                      ? 'Te has desuscrito de ${artist.title}'
                      : '¡Te has suscrito a ${artist.title}!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: wasSubscribed ? const Color(0xFF2C2C2E) : const Color(0xFFE50914),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  Widget _buildSubscribeButton(
    ArtistItem artist,
    AppColors colors,
    OnlineLibraryProvider onlineLib,
    bool isYtLoggedIn,
    bool isSubscribed,
  ) {
    return GestureDetector(
      onTap: () => _handleToggleSubscribe(artist, colors, onlineLib, isYtLoggedIn, isSubscribed),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSubscribed
              ? (colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))
              : const Color(0xFFFF0000),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSubscribed
                ? (colors.isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12))
                : const Color(0xFFFF0000),
            width: 1.2,
          ),
          boxShadow: isSubscribed
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFFF0000).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSubscribed ? Icons.check_rounded : Icons.subscriptions_rounded,
              size: 16,
              color: isSubscribed ? colors.textPrimary : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              isSubscribed ? 'Suscrito' : 'Suscribirse',
              style: TextStyle(
                color: isSubscribed ? colors.textPrimary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginPrompt(ArtistItem artist, AppColors colors, OnlineLibraryProvider onlineLib) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.subscriptions_rounded, color: Color(0xFFFF0000), size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  'Suscríbete a ${artist.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión con tu cuenta de YouTube para suscribirte a este artista y sincronizarlo en tus "Artistas que sigues".',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF0000),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => YouTubeLoginScreen(
                            appColors: colors,
                            onBack: () => Navigator.pop(context),
                            onLoginSuccess: () {
                              Navigator.pop(context);
                              onlineLib.loadSubscribedArtists(forceRefresh: true);
                              onlineLib.subscribeArtist(artist);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('¡Te has suscrito a ${artist.title}!'),
                                    backgroundColor: const Color(0xFFE50914),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text(
                      'Iniciar sesión en YouTube',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Ahora no', style: TextStyle(color: colors.textSecondary)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Sección "Sobre el artista" con soporte para descripción y fallback a Wikipedia
class _ArtistBioSection extends StatefulWidget {
  final String artistName;
  final String? initialBio;
  final AppColors appColors;

  const _ArtistBioSection({
    required this.artistName,
    required this.initialBio,
    required this.appColors,
  });

  @override
  State<_ArtistBioSection> createState() => _ArtistBioSectionState();
}

class _ArtistBioSectionState extends State<_ArtistBioSection> {
  String? _bioText;
  bool _isLoading = false;
  bool _isExpanded = false;
  bool _isFromWiki = false;

  @override
  void initState() {
    super.initState();
    _bioText = widget.initialBio;
    if (_bioText == null || _bioText!.trim().isEmpty) {
      _loadWikipediaBio();
    }
  }

  Future<void> _loadWikipediaBio() async {
    setState(() => _isLoading = true);
    final bio = await _fetchWikipediaBio(widget.artistName);
    if (mounted) {
      setState(() {
        _bioText = bio;
        _isLoading = false;
        if (bio != null) _isFromWiki = true;
      });
    }
  }

  Future<String?> _fetchWikipediaBio(String name) async {
    final cleanName = name
        .replaceAll(RegExp(r'\s*-\s*topic\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*vevo\b', caseSensitive: false), '')
        .trim();
    if (cleanName.isEmpty) return null;

    Future<String?> queryWiki(String lang, String title) async {
      try {
        final encoded = Uri.encodeComponent(title.replaceAll(' ', '_'));
        final url = Uri.parse('https://$lang.wikipedia.org/api/rest_v1/page/summary/$encoded');
        final res = await http.get(url, headers: {
          'User-Agent': 'FritoMusic/1.0 (Android; contact@frito.music)',
        }).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final extract = data['extract'] as String?;
          if (extract != null && extract.trim().isNotEmpty) {
            return extract.trim();
          }
        }
      } catch (_) {}
      return null;
    }

    return await queryWiki('es', cleanName) ??
        await queryWiki('es', '$cleanName (banda)') ??
        await queryWiki('es', '$cleanName (músico)') ??
        await queryWiki('en', cleanName) ??
        await queryWiki('en', '$cleanName (band)') ??
        await queryWiki('en', '$cleanName (musician)');
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
            ),
            const SizedBox(width: 14),
            Text(
              'Cargando información sobre ${widget.artistName}...',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_bioText == null || _bioText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Sobre ${widget.artistName}',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              if (_isFromWiki)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x15000000),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Wikipedia',
                    style: TextStyle(
                      color: colors.textSecondary.withOpacity(0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _bioText!,
                  maxLines: _isExpanded ? null : 4,
                  overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isExpanded = !_isExpanded);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Leer menos' : 'Leer más',
                        style: const TextStyle(
                          color: Color(0xFF1DB954),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF1DB954),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
