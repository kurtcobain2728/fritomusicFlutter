import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' hide StreamProvider;

import 'app.dart';
import 'core/constants.dart';
import 'data/repository/favorites_repository.dart';
import 'data/repository/playlist_repository.dart';
import 'data/repository/youtube_login_manager.dart';
import 'providers/home_provider.dart';
import 'providers/online_library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/stream_provider.dart';
import 'providers/theme_provider.dart';
import 'services/audio_handler.dart';
import 'services/youtube_stream_proxy.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge transparent system navigation and status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Pre-iniciar proxy local para streaming instantáneo sin bloqueos 403 ni cortes a los 30-60s
  unawaited(YouTubeStreamProxy.instance.ensureInitialized());

  // Inicializar Background Audio Service
  final fritoHandler = FritoAudioHandler();
  try {
    await AudioService.init(
      builder: () => fritoHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: AppConstants.audioNotificationChannelId,
        androidNotificationChannelName: 'Frito Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidNotificationIcon: 'mipmap/ic_launcher',
      ),
    );
  } catch (e) {
    debugPrint('Error inicializando AudioService: $e');
  }

  final favoritesRepository = FavoritesRepository();
  final playlistRepository = PlaylistRepository();

  // Cargar credenciales y cookies de YouTube antes de construir la app
  await YouTubeLoginManager.instance.loadLogin();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(
          create: (_) => PlayerProvider(
            audioHandler: fritoHandler,
            favoritesRepository: favoritesRepository,
            playlistRepository: playlistRepository,
          ),
        ),
        ChangeNotifierProvider(create: (_) => StreamProvider()),
        ChangeNotifierProvider(create: (_) => OnlineLibraryProvider()),
      ],
      child: const FritoMusicApp(),
    ),
  );
}
