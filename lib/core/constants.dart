/// Constantes globales de FritoMusic (lado Flutter).
///
/// Nota sobre preferencias: la versión Kotlin guardaba datos en archivos XML
/// propios (`getSharedPreferences("frito_theme_prefs", ...)`). El plugin
/// `shared_preferences` de Flutter NO puede leer esos archivos: escribe en su
/// propio XML (`FlutterSharedPreferences`) con prefijo `flutter.`. Por eso
/// aquí se centralizan las claves REALES que usa la app Flutter para tener una
/// única fuente de verdad (los valores NO deben cambiar para no perder datos).
class AppConstants {
  static const String appName = 'Frito Music';

  // ---- Preferencias (SharedPreferences) ----
  static const String prefsOnboarding = 'has_completed_onboarding';
  static const String prefsThemeMode = 'theme_mode';
  static const String prefsAccentColor = 'accent_color';
  static const String prefsBackgroundImageUri = 'background_image_uri';
  static const String prefsBackgroundBlur = 'background_blur';
  static const String prefsFavoritePaths = 'favorite_paths';
  static const String prefsPlaylistsData = 'playlists_data';
  static const String prefsHiddenItems = 'saved_hidden_items';
  static const String prefsFavoriteArtists = 'saved_favorite_artists';
  static const String prefsCustomAudioTitles = 'custom_audio_titles';
  static const String prefsCustomFolderNames = 'custom_folder_names';
  static const String prefsRecentStreamSongs = 'recent_stream_songs';

  // ---- Sesión YouTube Music ----
  static const String prefsYouTubeCookie = 'cookie';
  static const String prefsYouTubeVisitorData = 'visitor_data';
  static const String prefsYouTubeDataSyncId = 'data_sync_id';
  static const String prefsYouTubeAccountName = 'account_name';
  static const String prefsYouTubeAccountEmail = 'account_email';
  static const String prefsYouTubeAccountHandle = 'account_handle';
  static const String prefsYouTubeAccountAvatar = 'account_avatar';

  // ---- Sesión Spotify ----
  static const String prefsSpotifyAccessToken = 'spotify_access_token';
  static const String prefsSpotifyRefreshToken = 'spotify_refresh_token';
  static const String prefsSpotifyUserName = 'spotify_user_name';
  static const String prefsSpotifyUserEmail = 'spotify_user_email';
  static const String prefsSpotifyUserAvatar = 'spotify_user_avatar';
  static const String prefsSpotifyCustomClientId = 'spotify_custom_client_id';
  static const String prefsSpotifyCustomRedirectUri = 'spotify_custom_redirect_uri';

  // ---- Apariencia por defecto ----
  static const int defaultAccentColor = 0xFF1DB954; // verde Frito/Spotify
  static const String defaultThemeMode = 'Oscuro';

  // ---- Canales nativos ----
  static const String platformChannel = 'com.frito.music/platform';
  static const String audioNotificationChannelId = 'com.frito.music.channel.audio';
}
