import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import '../../core/theme/app_colors.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/stream_provider.dart';
import 'youtube_login_screen.dart';

class StreamPlaylistsScreen extends StatefulWidget {
  final StreamProvider streamViewModel;
  final ValueChanged<String> onPlaylistClick;
  final VoidCallback? onBack;
  final AppColors? appColors;

  const StreamPlaylistsScreen({
    super.key,
    required this.streamViewModel,
    required this.onPlaylistClick,
    this.onBack,
    this.appColors,
  });

  @override
  State<StreamPlaylistsScreen> createState() => _StreamPlaylistsScreenState();
}

class _StreamPlaylistsScreenState extends State<StreamPlaylistsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.streamViewModel.loadFeaturedPlaylists();
      if (YouTubeLoginManager.instance.isLoggedIn) {
        widget.streamViewModel.loadUserPlaylists();
        context.read<OnlineLibraryProvider>().loadOnlinePlaylists();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openLogin(BuildContext context, AppColors colors) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeLoginScreen(
          appColors: colors,
          onBack: () => Navigator.pop(context),
          onLoginSuccess: () {
            Navigator.pop(context);
            widget.streamViewModel.loadUserPlaylists();
            context.read<OnlineLibraryProvider>().loadOnlinePlaylists();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _showDeletePlaylistDialog(BuildContext context, PlaylistItem playlist) {
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

    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Eliminar lista?',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Se eliminará "${playlist.title}" de tu cuenta de YouTube y de FritoMusic. Esta acción no se puede deshacer.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final onlineLib = context.read<OnlineLibraryProvider>();
              final success = await widget.streamViewModel.deleteUserPlaylist(playlist.id);
              onlineLib.deleteOnlinePlaylist(playlist.id);
              if (success) {
                HapticFeedback.heavyImpact();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Se eliminó "${playlist.title}" de YouTube y FritoMusic'),
                    backgroundColor: const Color(0xFF1E1E24),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('No se pudo eliminar la lista de YouTube'),
                    backgroundColor: Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.white),
            label: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistGrid(
    List<PlaylistItem> playlists,
    AppColors colors, {
    String emptyText = 'No hay listas disponibles',
    VoidCallback? onReload,
    ValueChanged<PlaylistItem>? onPlaylistLongPress,
  }) {
    if (playlists.isEmpty) {
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954), size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
              ),
              if (onReload != null) ...[
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onReload();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1DB954),
                      borderRadius: BorderRadius.circular(18),
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
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Actualizar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Container(
          decoration: BoxDecoration(
            color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onPlaylistClick(playlist.id);
            },
            onLongPress: onPlaylistLongPress != null
                ? () {
                    onPlaylistLongPress(playlist);
                  }
                : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: playlist.thumbnail != null && playlist.thumbnail!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: playlist.thumbnail!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              errorWidget: (_, __, ___) => Container(
                                color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                                child: const Center(
                                  child: Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954), size: 36),
                                ),
                              ),
                            )
                          : Container(
                              color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                              child: const Center(
                                child: Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954), size: 36),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    playlist.songCountText ?? (playlist.author?.name ?? 'Lista de reproducción'),
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
          ),
        );
      },
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
    final streamVM = widget.streamViewModel;
    final isLoggedIn = YouTubeLoginManager.instance.isLoggedIn;

    // Listas de usuario consolidadas
    final userPlaylists = streamVM.userPlaylists.isNotEmpty
        ? streamVM.userPlaylists
        : onlineLib.onlinePlaylists;

    final isLoadingUserPlaylists = (streamVM.isLoadingPlaylists && streamVM.userPlaylists.isEmpty) ||
        (onlineLib.isLoadingPlaylists && onlineLib.onlinePlaylists.isEmpty);

    // Listas destacadas consolidadas
    final featuredPlaylists = streamVM.featuredPlaylists.isNotEmpty
        ? streamVM.featuredPlaylists
        : onlineLib.featuredPlaylists;

    final isLoadingFeatured = streamVM.isLoadingFeatured && featuredPlaylists.isEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null
            ? IconButton(
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
                  widget.onBack!();
                },
              )
            : null,
        title: Text(
          'Listas de Reproducción',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
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
              widget.streamViewModel.loadFeaturedPlaylists(forceRefresh: true);
              if (isLoggedIn) {
                widget.streamViewModel.loadUserPlaylists();
                onlineLib.loadOnlinePlaylists();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
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
                Tab(text: userPlaylists.isEmpty ? 'YT' : 'YT (${userPlaylists.length})'),
                Tab(text: featuredPlaylists.isEmpty ? 'Destacadas' : 'Destacadas (${featuredPlaylists.length})'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pestaña 1: YT (Mis Listas de YouTube)
          if (!isLoggedIn)
            Center(
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
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión con tu cuenta de Google / YT para sincronizar todas tus listas de reproducción guardadas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: () => _openLogin(context, colors),
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
            )
          else if (isLoadingUserPlaylists && userPlaylists.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            )
          else if (userPlaylists.isEmpty)
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: colors.isDark ? const Color(0x4418181C) : const Color(0xA0F6F6F8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954), size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No encontramos listas creadas en tu cuenta de YT',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 18),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.streamViewModel.loadUserPlaylists();
                            onlineLib.loadOnlinePlaylists();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954),
                              borderRadius: BorderRadius.circular(18),
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
                                Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Actualizar',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (featuredPlaylists.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Listas populares recomendadas',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...featuredPlaylists.take(8).map((p) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: p.thumbnail != null && p.thumbnail!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: p.thumbnail!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      fadeInDuration: Duration.zero,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                                        child: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954)),
                                      ),
                                    )
                                  : Container(
                                      width: 48,
                                      height: 48,
                                      color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                                      child: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954)),
                                    ),
                            ),
                            title: Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            subtitle: p.songCountText != null
                                ? Text(
                                    p.songCountText!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                  )
                                : null,
                            trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onPlaylistClick(p.id);
                            },
                          ),
                        )),
                  ],
                ],
              ),
            )
          else
            _buildPlaylistGrid(
              userPlaylists,
              colors,
              emptyText: 'No tienes listas en tu cuenta de YT',
              onReload: () {
                widget.streamViewModel.loadUserPlaylists();
                onlineLib.loadOnlinePlaylists();
              },
              onPlaylistLongPress: (p) => _showDeletePlaylistDialog(context, p),
            ),

          // Pestaña 2: Destacadas
          if (isLoadingFeatured && featuredPlaylists.isEmpty)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DB954)),
            )
          else
            _buildPlaylistGrid(
              featuredPlaylists,
              colors,
              emptyText: 'No hay listas destacadas disponibles en este momento',
              onReload: () => widget.streamViewModel.loadFeaturedPlaylists(forceRefresh: true),
            ),
        ],
      ),
    );
  }
}
