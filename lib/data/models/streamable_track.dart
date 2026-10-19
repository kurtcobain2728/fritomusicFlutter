import 'audio_file.dart';

class StreamableTrack {
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final String thumbnailUrl;

  const StreamableTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    required this.durationMs,
    required this.thumbnailUrl,
  });

  AudioFile toAudioFile(String streamUrl) => AudioFile(
    id: videoId.hashCode,
    title: title,
    artist: artist,
    path: streamUrl.isNotEmpty ? streamUrl : 'yt://$videoId',
    durationMs: durationMs,
    sizeBytes: 0,
    albumUri: thumbnailUrl,
    album: album ?? '',
    dateAdded: DateTime.now().millisecondsSinceEpoch,
  );

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'thumbnailUrl': thumbnailUrl,
  };

  factory StreamableTrack.fromJson(Map<String, dynamic> json) => StreamableTrack(
    videoId: json['videoId'] ?? '',
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    album: json['album'],
    durationMs: json['durationMs'] is int ? json['durationMs'] : int.tryParse(json['durationMs'].toString()) ?? 0,
    thumbnailUrl: json['thumbnailUrl'] ?? '',
  );
}
