import '../network/innertube/innertube_models.dart';

/// Representa el perfil de gustos consolidado del usuario según su actividad.
class TasteProfile {
  final List<SongItem> likedSongs;
  final Set<String> likedArtistIds;
  final Set<String> likedAlbumIds;
  final Set<String> playlistSongIds;
  final List<String> recentSongIds;

  const TasteProfile({
    this.likedSongs = const [],
    this.likedArtistIds = const {},
    this.likedAlbumIds = const {},
    this.playlistSongIds = const {},
    this.recentSongIds = const [],
  });

  /// Conjunto de IDs que el usuario ya conoce/escucha frecuentemente
  /// para evitar repetirlos en las recomendaciones nuevas.
  Set<String> get knownVideoIds => {
    ...likedSongs.map((s) => s.id),
    ...playlistSongIds,
    ...recentSongIds,
  };
}

/// Representa un estante/carrusel curado del Home de Stream.
class HomeShelf {
  final String id;
  final String title;
  final List<YTItem> items;

  const HomeShelf({
    required this.id,
    required this.title,
    required this.items,
  });
}
