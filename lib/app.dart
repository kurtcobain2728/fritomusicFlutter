import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'core/theme/app_colors.dart';
import 'data/models/playlist.dart';
import 'providers/home_provider.dart';
import 'providers/online_library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/stream_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/components/bottom_nav_bar.dart';
import 'ui/components/home_selection_bottom_bar.dart';
import 'ui/components/mini_player.dart';
import 'ui/screens/appearance_screen.dart';
import 'ui/screens/donations_screen.dart';
import 'ui/screens/downloads_manager_screen.dart';
import 'ui/screens/equalizer_screen.dart';
import 'ui/screens/favorites_screen.dart';
import 'ui/screens/hidden_items_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/more_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/online_playlist_detail_screen.dart';
import 'ui/screens/player_screen.dart';
import 'ui/screens/playlist_detail_screen.dart';
import 'ui/screens/playlist_migrate_screen.dart';
import 'ui/screens/playlists_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/stream_album_detail_screen.dart';
import 'ui/screens/stream_all_artists_screen.dart';
import 'ui/screens/stream_artist_detail_screen.dart';
import 'ui/screens/stream_favorite_artists_screen.dart';
import 'ui/screens/stream_followed_artists_screen.dart';
import 'ui/screens/stream_playlists_screen.dart';
import 'ui/screens/stream_screen.dart';
import 'ui/screens/youtube_login_screen.dart';
import 'utils/potoken/po_token_generator.dart';
import 'ui/screens/youtube_playlist_detail_screen.dart';
import 'services/stream_error_bus.dart';

class StreamNavEntry {
  final String screen;
  final String? artistId;
  final String? albumId;
  final String? playlistId;

  const StreamNavEntry({
    required this.screen,
    this.artistId,
    this.albumId,
    this.playlistId,
  });
}

class FritoMusicApp extends StatelessWidget {
  const FritoMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Frito Music',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const MainContainerScreen(),
    );
  }
}

class MainContainerScreen extends StatefulWidget {
  const MainContainerScreen({super.key});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen> {
  bool _hasCheckedOnboarding = false;
  bool _showOnboarding = false;

  String _currentTab = 'inicio';
  String? _currentSubScreen;
  bool _showPlayerScreen = false;
  bool _showYouTubeLogin = false;

  Playlist? _selectedPlaylist;
  String? _selectedStreamArtistId;
  String? _selectedStreamAlbumId;
  String? _selectedStreamPlaylistId;

  final List<StreamNavEntry> _streamNavStack = [];
  int _lastBackPressTime = 0;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    StreamErrorBus.ultimoError.addListener(_onStreamError);
    // Precalienta el generador PoToken para que el primer play no espere 2–5 s.
    unawaited(PoTokenGenerator.instance.prewarm());
  }

  void _onStreamError() {
    final msg = StreamErrorBus.ultimoError.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
      ),
    );
    StreamErrorBus.clear();
  }

  @override
  void dispose() {
    StreamErrorBus.ultimoError.removeListener(_onStreamError);
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(AppConstants.prefsOnboarding) ?? false;
      if (mounted) {
        setState(() {
          _showOnboarding = !completed;
          _hasCheckedOnboarding = true;
        });
      }
    } catch (e) {
      debugPrint('Error comprobando onboarding: $e');
      if (mounted) {
        setState(() {
          _showOnboarding = false;
          _hasCheckedOnboarding = true;
        });
      }
    }
  }

  void _pushStreamScreen(StreamNavEntry entry) {
    setState(() {
      _streamNavStack.add(entry);
      _currentSubScreen = entry.screen;
      if (entry.artistId != null) _selectedStreamArtistId = entry.artistId;
      if (entry.albumId != null) _selectedStreamAlbumId = entry.albumId;
      if (entry.playlistId != null) _selectedStreamPlaylistId = entry.playlistId;
    });
  }

  bool _popStreamScreen() {
    if (_streamNavStack.isNotEmpty) {
      _streamNavStack.removeLast();
    }
    if (_streamNavStack.isNotEmpty) {
      final prev = _streamNavStack.last;
      setState(() {
        _currentSubScreen = prev.screen;
        _selectedStreamArtistId = prev.artistId;
        _selectedStreamAlbumId = prev.albumId;
        _selectedStreamPlaylistId = prev.playlistId;
      });
      return true;
    } else {
      setState(() {
        _currentSubScreen = null;
        _selectedStreamArtistId = null;
        _selectedStreamAlbumId = null;
        _selectedStreamPlaylistId = null;
      });
      return false;
    }
  }

  bool _handleBackPress(HomeProvider home, StreamProvider stream) {
    if (_showPlayerScreen) {
      setState(() => _showPlayerScreen = false);
      return false;
    }

    if (_showYouTubeLogin) {
      setState(() => _showYouTubeLogin = false);
      return false;
    }

    if (_currentSubScreen == 'playlist_detail') {
      setState(() {
        _currentSubScreen = 'listas';
        _selectedPlaylist = null;
      });
      return false;
    }

    if (_currentSubScreen != null && _currentSubScreen!.startsWith('stream_')) {
      if (!_popStreamScreen()) {
        setState(() => _currentSubScreen = null);
      }
      return false;
    }

    if (_currentSubScreen == 'online_playlist_detail') {
      setState(() {
        _currentSubScreen = 'listas';
        _selectedStreamPlaylistId = null;
      });
      return false;
    }

    if (_currentSubScreen != null) {
      setState(() => _currentSubScreen = null);
      return false;
    }

    if (_currentTab == 'stream' && (stream.searchResults != null || stream.isSearching)) {
      stream.clearSearch();
      return false;
    }

    if (_currentTab == 'inicio' &&
        home.currentNode != null &&
        home.currentNode!.path != '/' &&
        home.currentNode!.path.isNotEmpty) {
      home.navigateUp();
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackPressTime < 2000) {
      SystemNavigator.pop();
      return true;
    } else {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presiona atrás de nuevo para salir'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
  }

  Widget _buildSubScreen(AppColors appColors) {
    final home = context.watch<HomeProvider>();
    final player = context.watch<PlayerProvider>();
    final stream = context.watch<StreamProvider>();
    final onlineLib = context.watch<OnlineLibraryProvider>();
    final theme = context.watch<ThemeProvider>();

    switch (_currentSubScreen) {
      case 'favoritos':
        return FavoritesScreen(
          homeProvider: home,
          playerProvider: player,
          onlineLibraryProvider: onlineLib,
          streamProvider: stream,
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'listas':
        return PlaylistsScreen(
          playerProvider: player,
          onlineLibraryProvider: onlineLib,
          appColors: appColors,
          onNavigateToOnlinePlaylist: (playlistId) {
            setState(() {
              _selectedStreamPlaylistId = playlistId;
              _currentSubScreen = 'online_playlist_detail';
            });
          },
          onBack: () => setState(() => _currentSubScreen = null),
          onPlaylistClick: (playlist) {
            setState(() {
              _selectedPlaylist = playlist;
              _currentSubScreen = 'playlist_detail';
            });
          },
        );
      case 'playlist_detail':
        if (_selectedPlaylist != null) {
          return PlaylistDetailScreen(
            playlist: _selectedPlaylist!,
            homeProvider: home,
            playerProvider: player,
            appColors: appColors,
            onBack: () => setState(() {
              _currentSubScreen = 'listas';
              _selectedPlaylist = null;
            }),
          );
        }
        return const SizedBox.shrink();
      case 'ecualizador':
        return EqualizerScreen(
          playerProvider: player,
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'apariencia':
        return AppearanceScreen(
          themeProvider: theme,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'donaciones':
        return DonationsScreen(
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'gestor_descargas':
        return DownloadsManagerScreen(
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'ocultos':
        return HiddenItemsScreen(
          homeProvider: home,
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
        );
      case 'migrar':
        return PlaylistMigrateScreen(
          playlistRepository: player.playlistRepository,
          onlineLibraryProvider: onlineLib,
          appColors: appColors,
          onBack: () => setState(() => _currentSubScreen = null),
          onPlaylistsUpdated: () {
            onlineLib.loadOnlinePlaylists();
            stream.loadUserPlaylists();
          },
        );
      case 'stream_artist_detail':
        if (_selectedStreamArtistId != null) {
          return StreamArtistDetailScreen(
            artistId: _selectedStreamArtistId!,
            streamViewModel: stream,
            playerViewModel: player,
            appColors: appColors,
            onNavigateToAlbum: (albumId) => _pushStreamScreen(
              StreamNavEntry(screen: 'stream_album_detail', albumId: albumId),
            ),
            onNavigateToArtist: (relatedId) => _pushStreamScreen(
              StreamNavEntry(screen: 'stream_artist_detail', artistId: relatedId),
            ),
            onBack: () => _popStreamScreen(),
          );
        }
        return const SizedBox.shrink();
      case 'stream_album_detail':
        if (_selectedStreamAlbumId != null) {
          return StreamAlbumDetailScreen(
            albumId: _selectedStreamAlbumId!,
            streamViewModel: stream,
            playerViewModel: player,
            appColors: appColors,
            onBack: () => _popStreamScreen(),
          );
        }
        return const SizedBox.shrink();
      case 'stream_playlists':
        return StreamPlaylistsScreen(
          streamViewModel: stream,
          appColors: appColors,
          onPlaylistClick: (playlistId) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_playlist_detail', playlistId: playlistId),
          ),
          onBack: () => _popStreamScreen(),
        );
      case 'stream_playlist_detail':
        if (_selectedStreamPlaylistId != null) {
          return YouTubePlaylistDetailScreen(
            playlistId: _selectedStreamPlaylistId!,
            streamViewModel: stream,
            playerViewModel: player,
            appColors: appColors,
            onBack: () => _popStreamScreen(),
          );
        }
        return const SizedBox.shrink();
      case 'online_playlist_detail':
        if (_selectedStreamPlaylistId != null) {
          return OnlinePlaylistDetailScreen(
            playlistId: _selectedStreamPlaylistId!,
            onlineLibraryProvider: onlineLib,
            streamProvider: stream,
            playerProvider: player,
            appColors: appColors,
            onBack: () => setState(() {
              _currentSubScreen = 'listas';
              _selectedStreamPlaylistId = null;
            }),
          );
        }
        return const SizedBox.shrink();
      case 'stream_favorite_artists':
        return StreamFavoriteArtistsScreen(
          appColors: appColors,
          onArtistClick: (id) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_artist_detail', artistId: id),
          ),
          onBack: () => _popStreamScreen(),
        );
      case 'stream_followed_artists':
        return StreamFollowedArtistsScreen(
          appColors: appColors,
          onArtistClick: (id) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_artist_detail', artistId: id),
          ),
          onBack: () => _popStreamScreen(),
        );
      case 'stream_all_artists':
        return StreamAllArtistsScreen(
          streamViewModel: stream,
          appColors: appColors,
          onArtistClick: (id) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_artist_detail', artistId: id),
          ),
          onBack: () => _popStreamScreen(),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTabContent(AppColors appColors) {
    final home = context.watch<HomeProvider>();
    final player = context.read<PlayerProvider>();
    final stream = context.watch<StreamProvider>();
    final hasCurrentAudio = context.select<PlayerProvider, bool>((p) => p.currentAudio != null);

    switch (_currentTab) {
      case 'inicio':
        return HomeScreen(
          homeViewModel: home,
          playerViewModel: player,
          isPlayerOpen: _showPlayerScreen || hasCurrentAudio,
          appColors: appColors,
        );
      case 'biblioteca':
        return LibraryScreen(
          homeViewModel: home,
          playerViewModel: player,
          appColors: appColors,
        );
      case 'buscar':
        return SearchScreen(
          homeViewModel: home,
          playerViewModel: player,
          appColors: appColors,
        );
      case 'stream':
        return StreamScreen(
          streamViewModel: stream,
          playerViewModel: player,
          appColors: appColors,
          onNavigateToArtist: (id) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_artist_detail', artistId: id),
          ),
          onNavigateToAlbum: (albumId) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_album_detail', albumId: albumId),
          ),
          onNavigateToLogin: () => setState(() => _showYouTubeLogin = true),
          onNavigateToPlaylists: () => _pushStreamScreen(
            const StreamNavEntry(screen: 'stream_playlists'),
          ),
          onNavigateToPlaylistDetail: (playlistId) => _pushStreamScreen(
            StreamNavEntry(screen: 'stream_playlist_detail', playlistId: playlistId),
          ),
          onNavigateToFavoriteArtists: () => _pushStreamScreen(
            const StreamNavEntry(screen: 'stream_favorite_artists'),
          ),
          onNavigateToFollowedArtists: () => _pushStreamScreen(
            const StreamNavEntry(screen: 'stream_followed_artists'),
          ),
          onNavigateToAllArtists: () => _pushStreamScreen(
            const StreamNavEntry(screen: 'stream_all_artists'),
          ),
        );
      case 'mas':
        return MoreScreen(
          favoritesCount: player.favorites.length,
          playlistsCount: player.playlists.length,
          appColors: appColors,
          onNavigateToFavorites: () => setState(() => _currentSubScreen = 'favoritos'),
          onNavigateToPlaylists: () => setState(() => _currentSubScreen = 'listas'),
          onNavigateToMigrate: () => setState(() => _currentSubScreen = 'migrar'),
          onNavigateToEqualizer: () => setState(() => _currentSubScreen = 'ecualizador'),
          onNavigateToAppearance: () => setState(() => _currentSubScreen = 'apariencia'),
          onNavigateToDonations: () => setState(() => _currentSubScreen = 'donaciones'),
          onNavigateToDownloadsManager: () => setState(() => _currentSubScreen = 'gestor_descargas'),
          onNavigateToHidden: () => setState(() => _currentSubScreen = 'ocultos'),
        );
      default:
        return HomeScreen(
          homeViewModel: home,
          playerViewModel: player,
          isPlayerOpen: _showPlayerScreen || player.currentAudio != null,
          appColors: appColors,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCheckedOnboarding) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final theme = context.watch<ThemeProvider>();
    final home = context.watch<HomeProvider>();
    final player = context.watch<PlayerProvider>();
    final stream = context.watch<StreamProvider>();
    final onlineLib = context.watch<OnlineLibraryProvider>();
    final appColors = theme.appColors;

    if (_showOnboarding) {
      return OnboardingScreen(
        appColors: appColors,
        onFinish: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(AppConstants.prefsOnboarding, true);
          setState(() => _showOnboarding = false);
          home.rescan();
        },
      );
    }

    final isSelectionMode = home.isSelectionMode;
    final selectedCount = home.selectedFolderPaths.length + home.selectedAudioPaths.length;

    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _handleBackPress(home, stream),
      child: Scaffold(
        backgroundColor: appColors.backgroundImageUri != null
            ? Colors.black.withOpacity(0.4)
            : appColors.background,
        body: Stack(
          children: [
            // WebView oculto (fuera de pantalla) que genera PoTokens para
            // streaming estable de YouTube
            const PoTokenWebViewHost(),

            // Global Background Image (if configured in Appearance)
            if (appColors.backgroundImageUri != null) ...[
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: theme.backgroundBlur,
                    sigmaY: theme.backgroundBlur,
                  ),
                  child: appColors.backgroundImageUri!.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: appColors.backgroundImageUri!,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(appColors.backgroundImageUri!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
            ],

            // Main Scaffold / Content
            if (_showYouTubeLogin)
              YouTubeLoginScreen(
                appColors: appColors,
                onBack: () => setState(() => _showYouTubeLogin = false),
                onLoginSuccess: () {
                  setState(() => _showYouTubeLogin = false);
                  stream.loadHomeContent(forceRefresh: true);
                  onlineLib.loadOnlinePlaylists();
                },
              )
            else
              Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey('screen_${_currentSubScreen ?? _currentTab}'),
                        child: _currentSubScreen != null
                            ? _buildSubScreen(appColors)
                            : _buildTabContent(appColors),
                      ),
                    ),
                  ),

                  // MiniPlayer & Bottom Bar
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating MiniPlayer with smooth morphing transition
                      if (player.currentAudio != null)
                        AnimatedSlide(
                          offset: _showPlayerScreen
                              ? const Offset(0, 0.35)
                              : Offset.zero,
                          duration: const Duration(milliseconds: 320),
                          curve: const Cubic(0.16, 1.0, 0.3, 1.0),
                          child: AnimatedOpacity(
                            opacity: _showPlayerScreen ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: IgnorePointer(
                              ignoring: _showPlayerScreen,
                              child: MiniPlayer(
                                appColors: appColors,
                                onClick: () {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _showPlayerScreen = true);
                                },
                                onSwipeUp: () {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _showPlayerScreen = true);
                                },
                              ),
                            ),
                          ),
                        ),

                      // Selection Bar or Normal Bottom Bar
                      if (_currentSubScreen == null && isSelectionMode)
                        HomeSelectionBottomBar(
                          selectedCount: selectedCount,
                          appColors: appColors,
                          onCancel: () => home.exitSelectionMode(),
                          onHideSelected: () => home.hideSelected(),
                          onDeleteSelected: () => home.requestDeleteMultiple(),
                        )
                      else if (_currentSubScreen == null)
                        BottomNavBar(
                          currentTab: _currentTab,
                          appColors: appColors,
                          onTabSelected: (tab) {
                            home.exitSelectionMode();
                            setState(() => _currentTab = tab);
                          },
                        ),
                    ],
                  ),
                ],
              ),

            // Fullscreen Player Overlay with Slide Animation & Morphing Corner Radius
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: const Cubic(0.16, 1.0, 0.3, 1.0),
              top: _showPlayerScreen ? 0 : MediaQuery.of(context).size.height,
              bottom: _showPlayerScreen ? 0 : -MediaQuery.of(context).size.height,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_showPlayerScreen ? 0 : 32),
                ),
                child: PlayerScreen(
                  viewModel: player,
                  streamViewModel: stream,
                  onlineLibraryViewModel: onlineLib,
                  appColors: appColors,
                  onNavigateToArtist: (id) {
                    setState(() => _showPlayerScreen = false);
                    _pushStreamScreen(
                      StreamNavEntry(screen: 'stream_artist_detail', artistId: id),
                    );
                  },
                  onClose: () => setState(() => _showPlayerScreen = false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
