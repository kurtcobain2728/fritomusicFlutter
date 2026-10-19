import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/playlist.dart';
import '../../data/network/innertube/innertube_models.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/online_library_provider.dart';
import '../../providers/player_provider.dart';
import 'youtube_login_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  final PlayerProvider playerProvider;
  final OnlineLibraryProvider onlineLibraryProvider;
  final ValueChanged<Playlist> onPlaylistClick;
  final ValueChanged<String> onNavigateToOnlinePlaylist;
  final VoidCallback onBack;
  final AppColors appColors;

  const PlaylistsScreen({
    super.key,
    required this.playerProvider,
    required this.onlineLibraryProvider,
    required this.onPlaylistClick,
    required this.onNavigateToOnlinePlaylist,
    required this.onBack,
    required this.appColors,
  });

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onlineLibraryProvider.loadOnlinePlaylists();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
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
            widget.onlineLibraryProvider.loadOnlinePlaylists();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog() {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (context) {
        final colors = widget.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Nueva Lista',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            style: TextStyle(color: colors.textPrimary),
            cursorColor: const Color(0xFF1DB954),
            decoration: InputDecoration(
              labelText: 'Nombre de la lista',
              labelStyle: TextStyle(color: colors.textSecondary),
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
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isNotEmpty) {
                  await widget.playerProvider.playlistRepository.createPlaylist(name);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Crear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteOnlinePlaylistDialog(BuildContext context, PlaylistItem playlist) {
    final colors = widget.appColors;
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
              final success = await widget.onlineLibraryProvider.deleteOnlinePlaylist(playlist.id);
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

  void _showDeleteLocalPlaylistDialog(BuildContext context, Playlist playlist) {
    final colors = widget.appColors;
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
                '¿Eliminar lista local?',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Se eliminará "${playlist.name}" de tus listas locales de FritoMusic.',
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
              await widget.playerProvider.playlistRepository.deletePlaylist(playlist.id);
              HapticFeedback.heavyImpact();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Se eliminó "${playlist.name}"'),
                    backgroundColor: const Color(0xFF1E1E24),
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

  Widget _buildPlaylistItem(PlaylistItem item, AppColors colors) {
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
          widget.onNavigateToOnlinePlaylist(item.id);
        },
        onLongPress: () {
          _showDeleteOnlinePlaylistDialog(context, item);
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
                  color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x11000000),
                  child: item.thumbnail != null && item.thumbnail!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.thumbnail!,
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(Icons.queue_music_rounded, color: colors.accent, size: 24),
                        )
                      : Icon(Icons.queue_music_rounded, color: colors.accent, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.songCountText ?? (item.author != null ? item.author!.name : 'Lista de reproducción'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.playerProvider,
        widget.onlineLibraryProvider,
      ]),
      builder: (context, _) {
        final colors = widget.appColors;
        final localPlaylists = widget.playerProvider.playlists;
        final onlinePlaylists = widget.onlineLibraryProvider.onlinePlaylists;
        final featuredPlaylists = widget.onlineLibraryProvider.featuredPlaylists;
        final isLoadingOnline = widget.onlineLibraryProvider.isLoadingPlaylists;
        final isLoggedIn = YouTubeLoginManager.instance.isLoggedIn;

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
                    color: const Color(0xFF1DB954).withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.add_rounded, color: Color(0xFF1DB954), size: 20),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showCreatePlaylistDialog();
                },
                tooltip: 'Crear lista',
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
                    Tab(text: localPlaylists.isEmpty ? 'Locales' : 'Locales (${localPlaylists.length})'),
                    Tab(text: onlinePlaylists.isEmpty ? 'YT' : 'YT (${onlinePlaylists.length})'),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Pestaña 1: Locales
              localPlaylists.isEmpty
                  ? Center(
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
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1DB954).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF1DB954), size: 36),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Sin listas locales',
                              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Organiza tus canciones favoritas en colecciones personalizadas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: _showCreatePlaylistDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                                child: const Text(
                                  'Crear mi primera lista',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 120),
                      itemCount: localPlaylists.length,
                      itemBuilder: (context, index) {
                        final playlist = localPlaylists[index];
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
                              widget.onPlaylistClick(playlist);
                            },
                            onLongPress: () {
                              _showDeleteLocalPlaylistDialog(context, playlist);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1DB954).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.queue_music_rounded, color: Color(0xFF1DB954), size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${playlist.audioPaths.length} canciones',
                                          style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, color: colors.textSecondary.withOpacity(0.6), size: 20),
                                    onPressed: () {
                                      _showDeleteLocalPlaylistDialog(context, playlist);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

              // Pestaña 2: Online / YouTube Music
              if (!isLoggedIn)
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_circle_outlined, color: Color(0xFF1DB954), size: 56),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Conecta tu cuenta de YT',
                        style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inicia sesión con tu cuenta Google para ver y sincronizar todas tus listas de YT.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _openLogin(context, colors),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1DB954).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Iniciar con YT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                      if (featuredPlaylists.isNotEmpty) ...[
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Listas recomendadas de YT',
                            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...featuredPlaylists.take(8).map((item) => _buildPlaylistItem(item, colors)),
                      ],
                    ],
                  ),
                )
              else if (isLoadingOnline && onlinePlaylists.isEmpty)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1DB954)),
                )
              else if (onlinePlaylists.isEmpty)
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.playlist_play_rounded, color: colors.textSecondary.withOpacity(0.5), size: 56),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes listas creadas en YT',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => widget.onlineLibraryProvider.loadOnlinePlaylists(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: colors.isDark ? const Color(0x33FFFFFF) : const Color(0x10000000),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                          ),
                          child: Text('Actualizar listas', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      if (featuredPlaylists.isNotEmpty) ...[
                        const SizedBox(height: 36),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Listas sugeridas para ti',
                            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...featuredPlaylists.take(8).map((item) => _buildPlaylistItem(item, colors)),
                      ],
                    ],
                  ),
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.only(top: 10, bottom: 120),
                  itemCount: onlinePlaylists.length,
                  itemBuilder: (context, index) {
                    final item = onlinePlaylists[index];
                    return _buildPlaylistItem(item, colors);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
