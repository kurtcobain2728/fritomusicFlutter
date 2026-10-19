class AudioFile {
  final int id;
  final String title;
  final String artist;
  final String path;
  final int durationMs;
  final int sizeBytes;
  final String? albumUri;
  final String album;
  final int dateAdded;

  const AudioFile({
    required this.id,
    required this.title,
    required this.artist,
    required this.path,
    required this.durationMs,
    required this.sizeBytes,
    this.albumUri,
    required this.album,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'path': path,
    'durationMs': durationMs,
    'sizeBytes': sizeBytes,
    'albumUri': albumUri,
    'album': album,
    'dateAdded': dateAdded,
  };

  factory AudioFile.fromJson(Map<String, dynamic> json) => AudioFile(
    id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    path: json['path'] ?? '',
    durationMs: json['durationMs'] is int ? json['durationMs'] : int.tryParse(json['durationMs'].toString()) ?? 0,
    sizeBytes: json['sizeBytes'] is int ? json['sizeBytes'] : int.tryParse(json['sizeBytes'].toString()) ?? 0,
    albumUri: json['albumUri'],
    album: json['album'] ?? '',
    dateAdded: json['dateAdded'] is int ? json['dateAdded'] : int.tryParse(json['dateAdded'].toString()) ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioFile && runtimeType == other.runtimeType && id == other.id && path == other.path;

  @override
  int get hashCode => id.hashCode ^ path.hashCode;
}
