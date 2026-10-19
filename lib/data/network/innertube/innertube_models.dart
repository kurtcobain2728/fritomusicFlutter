import '../../models/streamable_track.dart';

abstract class YTItem {
  final String id;
  final String title;
  final String? thumbnail;
  final bool explicit;
  final String shareLink;

  const YTItem({
    required this.id,
    required this.title,
    this.thumbnail,
    this.explicit = false,
    required this.shareLink,
  });

  Map<String, dynamic> toJson();
}

class Artist {
  final String name;
  final String? id;

  const Artist({
    required this.name,
    this.id,
  });

  Map<String, dynamic> toJson() => {'name': name, 'id': id};

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    name: json['name'] ?? '',
    id: json['id'],
  );
}

class Album {
  final String name;
  final String id;

  const Album({
    required this.name,
    required this.id,
  });

  Map<String, dynamic> toJson() => {'name': name, 'id': id};

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    name: json['name'] ?? '',
    id: json['id'] ?? '',
  );
}

class SongItem extends YTItem {
  final List<Artist> artists;
  final Album? album;
  final int? duration;
  final String? musicVideoType;
  final int? chartPosition;
  final String? chartChange;
  final String? setVideoId;

  const SongItem({
    required super.id,
    required super.title,
    required this.artists,
    this.album,
    this.duration,
    this.musicVideoType,
    this.chartPosition,
    this.chartChange,
    required String super.thumbnail,
    super.explicit = false,
    this.setVideoId,
    String? shareLink,
  }) : super(
         shareLink: shareLink ?? 'https://music.youtube.com/watch?v=$id',
       );

  String get artistNames => artists.map((a) => a.name).join(', ');

  /// Filtro estricto para asegurar que es una canción real y no un video general de YouTube (vlog, gameplay, podcast, etc.)
  bool get isRealMusicTrack {
    // 1. Excluir contenido marcado por YouTube como Video de Usuario (UGC)
    if (musicVideoType == 'MUSIC_VIDEO_TYPE_UGC') return false;

    // 2. Duración típica de canciones: entre 30 segundos y 15 minutos (900s)
    final dur = duration;
    if (dur != null && (dur < 30 || dur > 900)) return false;

    // 3. Debe tener al menos un artista con nombre válido y no desconocido
    if (artists.isEmpty || artists.every((a) => a.name.trim().isEmpty || a.name.toLowerCase() == 'desconocido')) {
      return false;
    }

    // 4. Palabras clave en el título que delatan que es un video general y no una pista musical
    final lowerTitle = title.toLowerCase();
    const nonMusicKeywords = [
      'podcast', 'episodio', 'episode', 'gameplay', 'walkthrough',
      'reacción', 'reaction', 'tutorial', 'unboxing', 'review',
      'detrás de cámaras', 'behind the scenes', 'entrevista', 'interview',
      'making of', 'vlog', 'documental', 'documentary', 'compilación',
      'compilation', 'funny moments', 'capítulo', 'chapter', 'tiktok',
      'noticias', 'noticiero', 'stream highlight', 'directo', 'livestream',
    ];
    for (final kw in nonMusicKeywords) {
      if (lowerTitle.contains(kw)) return false;
    }

    // 5. Nombres de canal o artistas que no son musicales
    final lowerArtists = artistNames.toLowerCase();
    const nonMusicArtistKeywords = ['podcast', 'gaming', 'channel', 'canal', 'noticias', 'news', 'clips', 'tv'];
    for (final kw in nonMusicArtistKeywords) {
      if (lowerArtists.contains(kw)) return false;
    }

    return true;
  }

  StreamableTrack toStreamableTrack() => StreamableTrack(
    videoId: id,
    title: title,
    artist: artistNames,
    album: album?.name,
    durationMs: (duration ?? 0) * 1000,
    thumbnailUrl: thumbnail ?? '',
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'song',
    'id': id,
    'title': title,
    'artists': artists.map((a) => a.toJson()).toList(),
    'album': album?.toJson(),
    'duration': duration,
    'thumbnail': thumbnail,
    'explicit': explicit,
  };

  factory SongItem.fromJson(Map<String, dynamic> json) => SongItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    artists: (json['artists'] as List<dynamic>?)
            ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    album: json['album'] != null ? Album.fromJson(json['album'] as Map<String, dynamic>) : null,
    duration: json['duration'] is int ? json['duration'] : int.tryParse(json['duration'].toString()),
    thumbnail: json['thumbnail'] ?? '',
    explicit: json['explicit'] ?? false,
    shareLink: json['shareLink'],
  );
}

class AlbumItem extends YTItem {
  final String browseId;
  final String playlistId;
  final List<Artist>? artists;
  final int? year;
  final String? description;

  const AlbumItem({
    required this.browseId,
    required this.playlistId,
    required super.title,
    this.artists,
    this.year,
    required String super.thumbnail,
    super.explicit = false,
    this.description,
    String? shareLink,
  }) : super(
         id: browseId,
         shareLink: shareLink ?? 'https://music.youtube.com/playlist?list=$playlistId',
       );

  String get artistNames => artists?.map((a) => a.name).join(', ') ?? '';

  @override
  Map<String, dynamic> toJson() => {
    'type': 'album',
    'browseId': browseId,
    'playlistId': playlistId,
    'title': title,
    'artists': artists?.map((a) => a.toJson()).toList(),
    'year': year,
    'thumbnail': thumbnail,
    'explicit': explicit,
    'description': description,
  };

  factory AlbumItem.fromJson(Map<String, dynamic> json) => AlbumItem(
    browseId: json['browseId'] ?? json['id'] ?? '',
    playlistId: json['playlistId'] ?? '',
    title: json['title'] ?? '',
    artists: (json['artists'] as List<dynamic>?)
        ?.map((e) => Artist.fromJson(e as Map<String, dynamic>))
        .toList(),
    year: json['year'] is int ? json['year'] : int.tryParse(json['year']?.toString() ?? ''),
    thumbnail: json['thumbnail'] ?? '',
    explicit: json['explicit'] ?? false,
    description: json['description'],
  );
}

class PlaylistItem extends YTItem {
  final Artist? author;
  final String? songCountText;
  final bool isEditable;

  const PlaylistItem({
    required super.id,
    required super.title,
    this.author,
    this.songCountText,
    super.thumbnail,
    this.isEditable = false,
    String? shareLink,
  }) : super(
         explicit: false,
         shareLink: shareLink ?? 'https://music.youtube.com/playlist?list=$id',
       );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'playlist',
    'id': id,
    'title': title,
    'author': author?.toJson(),
    'songCountText': songCountText,
    'thumbnail': thumbnail,
    'isEditable': isEditable,
  };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    author: json['author'] != null ? Artist.fromJson(json['author'] as Map<String, dynamic>) : null,
    songCountText: json['songCountText'],
    thumbnail: json['thumbnail'],
    isEditable: json['isEditable'] ?? false,
  );
}

class ArtistItem extends YTItem {
  final String? channelId;
  final String? subscriberCountText;

  const ArtistItem({
    required super.id,
    required super.title,
    super.thumbnail,
    this.channelId,
    this.subscriberCountText,
    String? shareLink,
  }) : super(
         explicit: false,
         shareLink: shareLink ?? 'https://music.youtube.com/channel/$id',
       );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'artist',
    'id': id,
    'title': title,
    'thumbnail': thumbnail,
    'channelId': channelId,
    'subscriberCountText': subscriberCountText,
  };

  factory ArtistItem.fromJson(Map<String, dynamic> json) => ArtistItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    thumbnail: json['thumbnail'],
    channelId: json['channelId'],
    subscriberCountText: json['subscriberCountText'],
  );
}

class ArtistPageData {
  final ArtistItem artist;
  final List<SongItem> topSongs;
  final List<AlbumItem> albums;
  final List<AlbumItem> singles;
  final List<ArtistItem> relatedArtists;
  final String? description;

  const ArtistPageData({
    required this.artist,
    this.topSongs = const [],
    this.albums = const [],
    this.singles = const [],
    this.relatedArtists = const [],
    this.description,
  });
}

class AlbumPageData {
  final AlbumItem album;
  final List<SongItem> songs;
  final int? totalDurationMs;

  const AlbumPageData({
    required this.album,
    this.songs = const [],
    this.totalDurationMs,
  });
}

class PlaylistPageData {
  final PlaylistItem playlist;
  final List<SongItem> songs;

  const PlaylistPageData({
    required this.playlist,
    this.songs = const [],
  });
}

class HomePageSection {
  final String title;
  final List<YTItem> items;

  const HomePageSection({
    required this.title,
    this.items = const [],
  });
}

class HomePage {
  final List<HomePageSection> sections;

  const HomePage({
    this.sections = const [],
  });
}

class ExplorePage {
  final List<AlbumItem> newReleaseAlbums;

  const ExplorePage({
    this.newReleaseAlbums = const [],
  });
}

