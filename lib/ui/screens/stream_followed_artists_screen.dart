import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/online_library_provider.dart';
import 'youtube_login_screen.dart';

class StreamFollowedArtistsScreen extends StatefulWidget {
  final ValueChanged<String> onArtistClick;
  final VoidCallback onBack;
  final AppColors? appColors;

  const StreamFollowedArtistsScreen({
    super.key,
    required this.onArtistClick,
    required this.onBack,
    this.appColors,
  });

  @override
  State<StreamFollowedArtistsScreen> createState() => _StreamFollowedArtistsScreenState();
}

class _StreamFollowedArtistsScreenState extends State<StreamFollowedArtistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (YouTubeLoginManager.instance.isLoggedIn) {
        context.read<OnlineLibraryProvider>().loadSubscribedArtists();
      }
    });
  }

  void _openYtLogin(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeLoginScreen(
          appColors: colors,
          onBack: () => Navigator.pop(context),
          onLoginSuccess: () {
            Navigator.pop(context);
            context.read<OnlineLibraryProvider>().loadSubscribedArtists(forceRefresh: true);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildArtistCard(ArtistItem artist, AppColors colors) {
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
          widget.onArtistClick(artist.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 52,
                  height: 52,
                  color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                  child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: artist.thumbnail!,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(Icons.person_rounded, color: colors.accent, size: 28),
                        )
                      : Icon(Icons.person_rounded, color: colors.accent, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist.subscriberCountText ?? 'Artista suscrito',
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
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(AppColors colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colors.isDark ? const Color(0x4418181C) : const Color(0xA0F6F6F8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF0000).withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.35), width: 1.5),
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF0000), size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                'Artistas de YT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Inicia sesión con tu cuenta de YT para ver tus artistas suscritos y sus canales oficiales.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openYtLogin(context, colors);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF0000),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.login_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Iniciar con YT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors, OnlineLibraryProvider onlineLib) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFFF0000).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, color: Color(0xFFFF0000), size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            'Sin artistas aún',
            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'No se encontraron artistas suscritos en tu cuenta de YT.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              onlineLib.loadSubscribedArtists(forceRefresh: true);
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Recargar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors ??
        const AppColors(
          background: Color(0xFF121212),
          surface: Color(0xFF1A1A1A),
          accent: Color(0xFF1DB954),
          textPrimary: Colors.white,
          textSecondary: Color(0xFFB3B3B3),
          isDark: true,
          themeMode: 'Oscuro',
        );

    final onlineLib = context.watch<OnlineLibraryProvider>();
    final isYtLoggedIn = YouTubeLoginManager.instance.isLoggedIn;
    final ytArtists = onlineLib.subscribedArtists;
    final isLoadingYt = onlineLib.isLoadingSubscribed;

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
          'Artistas que sigues',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          if (isYtLoggedIn)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                  ),
                ),
                child: Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 18),
              ),
              tooltip: 'Actualizar',
              onPressed: () {
                HapticFeedback.lightImpact();
                onlineLib.loadSubscribedArtists(forceRefresh: true);
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: !isYtLoggedIn
          ? _buildLoginCard(colors)
          : isLoadingYt && ytArtists.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0000)))
              : ytArtists.isEmpty
                  ? _buildEmptyState(colors, onlineLib)
                  : RefreshIndicator(
                      color: const Color(0xFFFF0000),
                      onRefresh: () async => onlineLib.loadSubscribedArtists(forceRefresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: ytArtists.length,
                        itemBuilder: (context, i) => _buildArtistCard(ytArtists[i], colors),
                      ),
                    ),
    );
  }
}
