import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../data/models/streamable_track.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/player_provider.dart';
import '../../providers/stream_provider.dart';
import '../components/youtube_logout_modal.dart';
import '../../utils/image_utils.dart';
import 'stream_home_screen.dart';

enum StreamTab { canciones, artistas, playlists }

class StreamScreen extends StatefulWidget {
  final StreamProvider streamViewModel;
  final PlayerProvider playerViewModel;
  final Function(String) onNavigateToArtist;
  final Function(String) onNavigateToAlbum;
  final VoidCallback onNavigateToLogin;
  final VoidCallback onNavigateToPlaylists;
  final Function(String) onNavigateToPlaylistDetail;
  final VoidCallback onNavigateToFavoriteArtists;
  final VoidCallback? onNavigateToFollowedArtists;
  final VoidCallback onNavigateToAllArtists;
  final AppColors appColors;

  const StreamScreen({
    super.key,
    required this.streamViewModel,
    required this.playerViewModel,
    required this.onNavigateToArtist,
    required this.onNavigateToAlbum,
    required this.onNavigateToLogin,
    required this.onNavigateToPlaylists,
    required this.onNavigateToPlaylistDetail,
    required this.onNavigateToFavoriteArtists,
    this.onNavigateToFollowedArtists,
    required this.onNavigateToAllArtists,
    required this.appColors,
  });

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final loginMgr = YouTubeLoginManager.instance;
    loginMgr.addListener(_onLoginChanged);
    if (loginMgr.isLoggedIn && (loginMgr.accountAvatar.isEmpty || loginMgr.accountName.isEmpty)) {
      loginMgr.fetchAccountInfo();
    }
  }

  void _onLoginChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    YouTubeLoginManager.instance.removeListener(_onLoginChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
    final stream = context.watch<StreamProvider>();
    final loginMgr = YouTubeLoginManager.instance;
    final isYtLoggedIn = loginMgr.isLoggedIn;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Stream',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isYtLoggedIn) ...[
                    if (widget.onNavigateToFollowedArtists != null)
                      IconButton(
                        icon: Icon(Icons.people_alt_rounded, color: colors.textPrimary, size: 24),
                        tooltip: 'Artistas que sigues',
                        onPressed: widget.onNavigateToFollowedArtists,
                      ),
                    IconButton(
                      icon: Icon(Icons.format_list_bulleted, color: colors.textPrimary, size: 24),
                      tooltip: 'Listas',
                      onPressed: widget.onNavigateToPlaylists,
                    ),
                  ],
                  if (isYtLoggedIn) ...[
                    IconButton(
                      icon: const Icon(Icons.star, color: Color(0xFFFFD700), size: 24),
                      tooltip: 'Artistas favoritos',
                      onPressed: widget.onNavigateToFavoriteArtists,
                    ),
                    if (widget.onNavigateToFollowedArtists != null)
                      IconButton(
                        icon: Icon(Icons.people_alt_rounded, color: colors.textPrimary, size: 24),
                        tooltip: 'Artistas que sigues',
                        onPressed: widget.onNavigateToFollowedArtists,
                      ),
                    IconButton(
                      icon: Icon(Icons.format_list_bulleted, color: colors.textPrimary, size: 24),
                      tooltip: 'Listas',
                      onPressed: widget.onNavigateToPlaylists,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: colors.textPrimary, size: 22),
                      tooltip: 'Actualizar Stream',
                      onPressed: () => stream.loadHomeContent(forceRefresh: true),
                    ),
                    GestureDetector(
                      onTap: () {
                        YouTubeLogoutModal.show(
                          context: context,
                          appColors: colors,
                          onAccountsChanged: () {
                            if (mounted) setState(() {});
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: loginMgr.accountAvatar.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: loginMgr.accountAvatar,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.account_circle,
                                    color: Color(0xFFFF0000),
                                    size: 32,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.account_circle,
                                color: Color(0xFFFF0000),
                                size: 32,
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (!isYtLoggedIn)
              Expanded(
                child: StreamLoginPrompt(
                  onLoginYt: widget.onNavigateToLogin,
                  appColors: colors,
                ),
              )
            else ...[
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: colors.textSecondary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14),
                          cursorColor: const Color(0xFF1DB954),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar canciones, artistas...',
                            hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (text) {
                            _searchDebounce?.cancel();
                            stream.search(text);
                          },
                          onChanged: (text) {
                            _searchDebounce?.cancel();
                            if (text.trim().isEmpty) {
                              stream.clearSearch();
                            } else {
                              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                                stream.search(text);
                              });
                            }
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            stream.clearSearch();
                            setState(() {});
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF333333),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.clear, color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Playback Error Banner
              if (stream.playbackError != null)
                GestureDetector(
                  onTap: () => stream.clearPlaybackError(),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D1010),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'No se pudo reproducir: ${stream.playbackError}. Toca para cerrar.',
                            style: const TextStyle(color: Color(0xFFEF9A9A), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Contenido Principal
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (stream.isSearching) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                      );
                    }

                    if (stream.errorMessage != null) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              stream.errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DB954),
                              ),
                              onPressed: () => stream.search(_searchController.text),
                              child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    }

                    if (stream.searchResults == null && _searchController.text.trim().isEmpty) {
                      return StreamHomeScreen(
                        homeShelves: stream.homeShelves,
                        homePage: stream.homePage,
                        explorePage: stream.explorePage,
                        isLoading: stream.isLoadingHome,
                        recentlyPlayed: stream.recentlyPlayed,
                        appColors: colors,
                        onPlaySong: (song, queue) => stream.playArtistSong(
                          song,
                          widget.playerViewModel,
                          queueSongs: queue,
                        ),
                        onAlbumClick: widget.onNavigateToAlbum,
                        onArtistClick: widget.onNavigateToArtist,
                        onSeeAllArtists: widget.onNavigateToAllArtists,
                        onRefresh: () => stream.loadHomeContent(forceRefresh: true),
                      );
                    }

                    // Resultados con pestañas
                    return Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            tabs: const [
                              Tab(text: 'Canciones'),
                              Tab(text: 'Artistas'),
                              Tab(text: 'Playlists'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Canciones
                              Builder(
                                builder: (context) {
                                  final results = stream.searchResults ?? [];
                                  if (results.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.music_off_rounded, color: colors.textSecondary.withOpacity(0.4), size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No se encontraron canciones',
                                            style: TextStyle(color: colors.textSecondary, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                                    itemCount: results.length,
                                    itemBuilder: (context, i) {
                                      final track = results[i];
                                      return StreamTrackItem(
                                        track: track,
                                        appColors: colors,
                                        onClick: () => stream.playTrack(
                                          track,
                                          widget.playerViewModel,
                                          queue: results,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Artistas
                              Builder(
                                builder: (context) {
                                  final artists = stream.artistResults ?? [];
                                  if (artists.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person_off_rounded, color: colors.textSecondary.withOpacity(0.4), size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No se encontraron artistas',
                                            style: TextStyle(color: colors.textSecondary, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                                    itemCount: artists.length,
                                    itemBuilder: (context, i) {
                                      final artist = artists[i];
                                      return StreamArtistItem(
                                        artist: artist,
                                        appColors: colors,
                                        onClick: () => widget.onNavigateToArtist(artist.id),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Playlists
                              Builder(
                                builder: (context) {
                                  final playlists = stream.playlistResults ?? [];
                                  if (playlists.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.queue_music_rounded, color: colors.textSecondary.withOpacity(0.4), size: 48),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No se encontraron listas de reproducción',
                                            style: TextStyle(color: colors.textSecondary, fontSize: 15),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    padding: const EdgeInsets.only(top: 8, bottom: 120),
                                    itemCount: playlists.length,
                                    itemBuilder: (context, i) {
                                      final pl = playlists[i];
                                      return StreamPlaylistItem(
                                        playlist: pl,
                                        appColors: colors,
                                        onClick: () => widget.onNavigateToPlaylistDetail(pl.id),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StreamTrackItem extends StatelessWidget {
  final StreamableTrack track;
  final VoidCallback onClick;
  final AppColors appColors;

  const StreamTrackItem({
    super.key,
    required this.track,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appColors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onClick();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                  child: Builder(
                    builder: (_) {
                      final thumb = track.thumbnailUrl.isNotEmpty
                          ? track.thumbnailUrl
                          : (track.videoId.isNotEmpty ? 'https://i.ytimg.com/vi/${track.videoId}/hqdefault.jpg' : '');
                      if (thumb.isNotEmpty) {
                        return CachedNetworkImage(
                          imageUrl: thumb.resize(width: 120),
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.music_note_rounded,
                            color: appColors.accent,
                          ),
                        );
                      }
                      return Icon(
                        Icons.music_note_rounded,
                        color: appColors.accent,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${track.artist}${track.album != null ? " • ${track.album}" : ""}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreamArtistItem extends StatelessWidget {
  final ArtistItem artist;
  final VoidCallback onClick;
  final AppColors appColors;

  const StreamArtistItem({
    super.key,
    required this.artist,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appColors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onClick();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipOval(
                child: Container(
                  width: 50,
                  height: 50,
                  color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                  child: artist.thumbnail != null && artist.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: artist.thumbnail!.resize(width: 120),
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            color: appColors.textSecondary,
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: appColors.textSecondary,
                        ),
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
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1DB954),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'Artista en Stream',
                          style: TextStyle(
                            color: appColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: appColors.isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded, color: appColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreamPlaylistItem extends StatelessWidget {
  final PlaylistItem playlist;
  final VoidCallback onClick;
  final AppColors appColors;

  const StreamPlaylistItem({
    super.key,
    required this.playlist,
    required this.onClick,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [playlist.author?.name, playlist.songCountText]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : 'Playlist';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appColors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          onClick();
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 50,
                  height: 50,
                  color: appColors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                  child: playlist.thumbnail != null && playlist.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: playlist.thumbnail!.resize(width: 120),
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.format_list_bulleted_rounded,
                            color: appColors.textSecondary,
                            size: 24,
                          ),
                        )
                      : Icon(
                          Icons.format_list_bulleted_rounded,
                          color: appColors.textSecondary,
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
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: appColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: appColors.isDark ? const Color(0x22FFFFFF) : const Color(0x10000000),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_right_rounded, color: appColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreamLoginPrompt extends StatelessWidget {
  final VoidCallback onLoginYt;
  final AppColors appColors;

  const StreamLoginPrompt({
    super.key,
    required this.onLoginYt,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000).withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF0000).withOpacity(0.35),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF0000), size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              'Inicia sesión con YT',
              style: TextStyle(
                color: appColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conéctate a tu cuenta para sincronizar tus listas, canciones favoritas y disfrutar de streaming ilimitado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: appColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onLoginYt();
                },
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
                label: const Text(
                  'Iniciar con YT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF0000),
                  elevation: 3,
                  shadowColor: const Color(0xFFFF0000).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
