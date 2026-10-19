import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/audio_file.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/home_provider.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/frito_artwork_widget.dart';
import 'youtube_login_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final HomeProvider homeProvider;
  final PlayerProvider playerProvider;
  final OnlineLibraryProvider? onlineLibraryProvider;
  final StreamProvider? streamProvider;
  final VoidCallback onBack;
  final AppColors appColors;

  const FavoritesScreen({
    super.key,
    required this.homeProvider,
    required this.playerProvider,
    this.onlineLibraryProvider,
    this.streamProvider,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (YouTubeLoginManager.instance.isLoggedIn) {
        widget.onlineLibraryProvider?.loadLikedSongs();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openYouTubeLogin(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeLoginScreen(
          appColors: colors,
          onBack: () => Navigator.pop(context),
          onLoginSuccess: () {
            Navigator.pop(context);
            widget.onlineLibraryProvider?.loadLikedSongs(forceRefresh: true);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final allAudios = widget.homeProvider.allAudios;
    final favPaths = widget.playerProvider.favorites;
    final favoriteAudios = allAudios.where((a) => favPaths.contains(a.path)).toList();

    final onlineLib = widget.onlineLibraryProvider;
    final ytLikedSongs = (onlineLib?.likedSongs ?? const <SongItem>[]).where((s) => s.isRealMusicTrack).toList();
    final isLoadingYt = onlineLib?.isLoadingLiked ?? false;
    final isYtLoggedIn = YouTubeLoginManager.instance.isLoggedIn;

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
          'Favoritos',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x0F000000),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF1DB954),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1DB954).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: colors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                Tab(text: favoriteAudios.isEmpty ? 'Locales' : 'Locales (${favoriteAudios.length})'),
                Tab(text: ytLikedSongs.isEmpty ? 'YT' : 'YT (${ytLikedSongs.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: Locales
          _buildLocalFavorites(favoriteAudios, colors),

          // Pestaña 2: YouTube
          _buildYouTubeFavorites(isYtLoggedIn, isLoadingYt, ytLikedSongs, colors),
        ],
      ),
    );
  }

  Widget _buildLocalFavorites(List<AudioFile> favoriteAudios, AppColors colors) {
    if (favoriteAudios.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
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
                  color: const Color(0xFFFF4757).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF4757), size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Sin canciones favoritas',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Toca el icono de corazón en cualquier canción local para añadirla aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4757).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFF4757), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${favoriteAudios.length} canciones',
                      style: const TextStyle(
                        color: Color(0xFFFF4757),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Botón Aleatorio Glass
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final shuffled = List<AudioFile>.from(favoriteAudios)..shuffle();
                  if (shuffled.isNotEmpty) {
                    widget.playerProvider.playAudio(shuffled.first, newQueue: shuffled);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Icon(Icons.shuffle_rounded, color: colors.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              // Botón Play All Emerald
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (favoriteAudios.isNotEmpty) {
                    widget.playerProvider.playAudio(favoriteAudios.first, newQueue: favoriteAudios);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...favoriteAudios.map((audio) {
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
                widget.playerProvider.playAudio(audio, newQueue: favoriteAudios);
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    FritoArtworkWidget(
                      audioId: audio.id,
                      albumUri: audio.albumUri,
                      size: 48,
                      borderRadius: 12,
                      appColors: colors,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audio.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            audio.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.playerProvider.toggleFavorite(audio.path);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF4757),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }



  Widget _buildYouTubeFavorites(
    bool isYtLoggedIn,
    bool isLoadingYt,
    List<SongItem> ytLikedSongs,
    AppColors colors,
  ) {
    if (!isYtLoggedIn) {
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
                    color: const Color(0xFF1DB954).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_circle_outlined, color: Color(0xFF1DB954), size: 44),
                ),
                const SizedBox(height: 18),
                Text(
                  'Conecta tu cuenta de YT',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión con tu cuenta de Google / YT para sincronizar todas tus canciones favoritas con Me Gusta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => _openYouTubeLogin(context, colors),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withOpacity(0.35),
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

    if (isLoadingYt && ytLikedSongs.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
      );
    }

    if (ytLikedSongs.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
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
                  color: const Color(0xFFFF4757).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF4757), size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Sin canciones favoritas en YT',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Las canciones a las que des "Me Gusta" en YT aparecerán aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onlineLibraryProvider?.loadLikedSongs(forceRefresh: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Actualizar',
                        style: TextStyle(
                          color: colors.textPrimary,
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
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4757).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFF4757), size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${ytLikedSongs.length} canciones',
                      style: const TextStyle(
                        color: Color(0xFFFF4757),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Botón Aleatorio Glass
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.streamProvider != null && ytLikedSongs.isNotEmpty) {
                    final shuffled = List<SongItem>.from(ytLikedSongs)..shuffle();
                    final queue = shuffled.map((s) => s.toStreamableTrack()).toList();
                    widget.streamProvider!.playStreamableTrack(
                      queue.first,
                      widget.playerProvider,
                      queue: queue,
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Icon(Icons.shuffle_rounded, color: colors.textPrimary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              // Botón Play All Emerald
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (widget.streamProvider != null && ytLikedSongs.isNotEmpty) {
                    final queue = ytLikedSongs.map((s) => s.toStreamableTrack()).toList();
                    widget.streamProvider!.playStreamableTrack(
                      queue.first,
                      widget.playerProvider,
                      queue: queue,
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1DB954).withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...ytLikedSongs.map((song) {
          final artistNames = song.artists.map((a) => a.name).join(', ');
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
                if (widget.streamProvider != null) {
                  final queue = ytLikedSongs.map((s) => s.toStreamableTrack()).toList();
                  widget.streamProvider!.playStreamableTrack(
                    song.toStreamableTrack(),
                    widget.playerProvider,
                    queue: queue,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                        child: song.thumbnail != null && song.thumbnail!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: song.thumbnail!,
                                fit: BoxFit.cover,
                                fadeInDuration: Duration.zero,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.music_note_rounded,
                                  color: colors.accent,
                                  size: 24,
                                ),
                              )
                            : Icon(
                                Icons.music_note_rounded,
                                color: colors.accent,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            artistNames.isNotEmpty ? artistNames : (song.album?.name ?? 'YT'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onlineLibraryProvider?.likeSong(song.id, false);
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF4757),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
