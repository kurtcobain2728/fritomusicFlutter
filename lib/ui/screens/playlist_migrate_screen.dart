import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repository/playlist_repository.dart';
import '../../data/repository/youtube_login_manager.dart';
import '../../providers/online_library_provider.dart';
import '../../services/playlist_migrator_service.dart';
import 'youtube_login_screen.dart';

class PlaylistMigrateScreen extends StatefulWidget {
  final PlaylistRepository playlistRepository;
  final OnlineLibraryProvider? onlineLibraryProvider;
  final VoidCallback onBack;
  final VoidCallback? onPlaylistsUpdated;
  final AppColors appColors;

  const PlaylistMigrateScreen({
    super.key,
    required this.playlistRepository,
    this.onlineLibraryProvider,
    required this.onBack,
    this.onPlaylistsUpdated,
    required this.appColors,
  });

  @override
  State<PlaylistMigrateScreen> createState() => _PlaylistMigrateScreenState();
}

class _PlaylistMigrateScreenState extends State<PlaylistMigrateScreen> {
  final TextEditingController _urlController = TextEditingController();
  final PlaylistMigratorService _migratorService = PlaylistMigratorService.instance;

  bool _isAnalyzing = false;
  bool _isMigrating = false;
  String? _errorMessage;

  MigratedPlaylist? _parsedPlaylist;

  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _currentProgressSong = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
        _errorMessage = null;
      });
      // Analizar automáticamente al pegar
      _analyzeUrl();
    }
  }

  Future<void> _analyzeUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa o pega el enlace de una lista de reproducción.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _parsedPlaylist = null;
    });

    try {
      final result = await _migratorService.parsePlaylistUrl(url);
      if (mounted) {
        setState(() {
          _parsedPlaylist = result;
          _isAnalyzing = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isAnalyzing = false;
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeLoginScreen(
          appColors: widget.appColors,
          onBack: () => Navigator.pop(context),
          onLoginSuccess: () {
            Navigator.pop(context);
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    final colors = widget.appColors;
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
                color: const Color(0xFFFF0000).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_circle_outlined, color: Color(0xFFFF0000), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Inicia sesión con YT',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Para importar tu playlist de streaming a FritoMusic, necesitas conectar tu cuenta de YouTube para guardarla en tu biblioteca.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: colors.textSecondary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF0000),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openLogin();
            },
            icon: const Icon(Icons.login_rounded, size: 18, color: Colors.white),
            label: const Text('Iniciar con YT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _startMigration() async {
    final playlist = _parsedPlaylist;
    if (playlist == null || _isMigrating) return;

    final isLoggedIn = YouTubeLoginManager.instance.isLoggedIn;
    if (!isLoggedIn) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _isMigrating = true;
      _progressCurrent = 0;
      _progressTotal = playlist.tracks.length;
      _currentProgressSong = 'Buscando canciones en YouTube...';
    });

    try {
      // 1. Resolver canciones en YouTube
      await _migratorService.resolveTracksWithYouTube(
        playlist,
        onProgress: (current, total, currentSong) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal = total;
              _currentProgressSong = currentSong;
            });
          }
        },
      );

      // 2. Guardar directamente en la cuenta de YouTube (sin guardar en locales)
      setState(() {
        _currentProgressSong = 'Guardando lista en tu cuenta de YouTube...';
      });
      final ytPlaylistId = await _migratorService.syncToYouTubeAccount(playlist);

      widget.onlineLibraryProvider?.loadOnlinePlaylists();
      widget.onPlaylistsUpdated?.call();

      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
        HapticFeedback.heavyImpact();
        _showSuccessDialog(playlist.title, playlist.tracks.length, ytSynced: ytPlaylistId != null);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _errorMessage = 'Error durante la migración: $e';
        });
      }
    }
  }

  void _showSuccessDialog(String title, int count, {bool ytSynced = false}) {
    final colors = widget.appColors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: colors.isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF1DB954).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1DB954).withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 44),
                ),
                const SizedBox(height: 20),
                Text(
                  '¡Lista Importada con Éxito!',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Se guardó "$title" con $count canciones en tu cuenta de YouTube y FritoMusic.',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onBack();
                    },
                    child: const Text(
                      'Listo, ver mis Listas',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'Spotify':
        return const Color(0xFF1DB954);
      case 'Apple Music':
        return const Color(0xFFFA243C);
      case 'Deezer':
        return const Color(0xFFA238FF);
      case 'YouTube Music':
        return const Color(0xFFFF0000);
      case 'SoundCloud':
        return const Color(0xFFFF5500);
      case 'Tidal':
        return const Color(0xFF00FFFF);
      default:
        return const Color(0xFF1DB954);
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'Spotify':
        return Icons.graphic_eq_rounded;
      case 'Apple Music':
        return Icons.apple_rounded;
      case 'Deezer':
        return Icons.equalizer_rounded;
      case 'YouTube Music':
        return Icons.play_circle_fill_rounded;
      case 'SoundCloud':
        return Icons.cloud_queue_rounded;
      case 'Tidal':
        return Icons.waves_rounded;
      default:
        return Icons.queue_music_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;
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
          'Migrar Playlist',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de plataformas soportadas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DB954).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF1DB954), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Pega el enlace de tu playlist',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Copia el link de compartir de cualquier lista pública en tu servicio y trátela a FritoMusic al instante.',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlatformBadge('Spotify', const Color(0xFF1DB954)),
                      _buildPlatformBadge('Apple Music', const Color(0xFFFA243C)),
                      _buildPlatformBadge('Deezer', const Color(0xFFA238FF)),
                      _buildPlatformBadge('YouTube', const Color(0xFFFF0000)),
                      _buildPlatformBadge('SoundCloud', const Color(0xFFFF5500)),
                      _buildPlatformBadge('Tidal', const Color(0xFF00CED1)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Input URL con botón Pegar
            Container(
              decoration: BoxDecoration(
                color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.link_rounded, color: colors.textSecondary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'https://open.spotify.com/playlist/...',
                        hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 13),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _analyzeUrl(),
                    ),
                  ),
                  if (_urlController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear_rounded, color: colors.textSecondary, size: 18),
                      onPressed: () {
                        _urlController.clear();
                        setState(() {
                          _parsedPlaylist = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                  // Botón Pegar
                  GestureDetector(
                    onTap: _pasteFromClipboard,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.35)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.content_paste_rounded, color: Color(0xFF1DB954), size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Pegar',
                            style: TextStyle(
                              color: Color(0xFF1DB954),
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Botón Analizar
            if (_parsedPlaylist == null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  onPressed: _isAnalyzing ? null : _analyzeUrl,
                  child: _isAnalyzing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Analizar Playlist',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),

            // DETALLES DE LA PLAYLIST ANALIZADA
            if (_parsedPlaylist != null) ...[
              const SizedBox(height: 10),
              _buildPlaylistPreviewCard(_parsedPlaylist!, colors),

              const SizedBox(height: 18),

              // Destino de la lista
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.isDark ? const Color(0x6618181C) : const Color(0xC8F6F6F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isYtLoggedIn
                        ? const Color(0xFFFF0000).withOpacity(0.3)
                        : (colors.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFFFF0000),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isYtLoggedIn ? 'Destino: Tu biblioteca de YouTube' : 'Conecta tu cuenta de YouTube',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isYtLoggedIn
                                ? 'La lista se creará en tu cuenta de YT y aparecerá en FritoMusic.'
                                : 'Inicia sesión con YT para que la lista se guarde en tu cuenta.',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isYtLoggedIn)
                      GestureDetector(
                        onTap: _openLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0000),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Conectar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 22),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Progreso de Migración
              if (_isMigrating) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Importando lista...',
                            style: TextStyle(
                              color: Color(0xFF1DB954),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_progressCurrent / $_progressTotal',
                            style: const TextStyle(
                              color: Color(0xFF1DB954),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressTotal > 0 ? (_progressCurrent / _progressTotal) : null,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          color: const Color(0xFF1DB954),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentProgressSong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Botón Guardar Lista
              if (!_isMigrating)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      elevation: 4,
                      shadowColor: const Color(0xFF1DB954).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    ),
                    onPressed: _startMigration,
                    icon: const Icon(Icons.download_done_rounded, color: Colors.white, size: 22),
                    label: Text(
                      'Importar ${_parsedPlaylist!.tracks.length} Canciones a FritoMusic',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Lista de canciones
              Text(
                'Canciones encontradas (${_parsedPlaylist!.tracks.length})',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),

              ..._parsedPlaylist!.tracks.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final track = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.isDark ? const Color(0x4418181C) : const Color(0xC8F6F6F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '$index',
                        style: TextStyle(
                          color: colors.textSecondary.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                                color: colors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.music_note_rounded,
                        color: colors.textSecondary.withOpacity(0.5),
                        size: 18,
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        name,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPlaylistPreviewCard(MigratedPlaylist playlist, AppColors colors) {
    final platformColor = _getPlatformColor(playlist.platform);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.isDark ? const Color(0x881E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: platformColor.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: platformColor.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portada
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 80,
              height: 80,
              color: platformColor.withOpacity(0.15),
              child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: playlist.coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(_getPlatformIcon(playlist.platform), color: platformColor, size: 36),
                    )
                  : Icon(_getPlatformIcon(playlist.platform), color: platformColor, size: 36),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge de plataforma
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: platformColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPlatformIcon(playlist.platform), color: platformColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        playlist.platform,
                        style: TextStyle(
                          color: platformColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  playlist.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Por ${playlist.author} • ${playlist.tracks.length} canciones',
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
        ],
      ),
    );
  }
}
