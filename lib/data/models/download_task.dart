enum DownloadStatus {
  enqueued,
  running,
  complete,
  failed,
  canceled,
  paused,
}

class DownloadTask {
  final String taskId;
  final String videoId;
  final String title;
  final String artist;
  final String? album;
  final String? thumbnailUrl;
  final String savePath;
  final int progress; // 0..100
  final DownloadStatus status;
  final String quality; // "320kbps", "160kbps", "128kbps", "lossless"

  const DownloadTask({
    required this.taskId,
    required this.videoId,
    required this.title,
    required this.artist,
    this.album,
    this.thumbnailUrl,
    required this.savePath,
    this.progress = 0,
    this.status = DownloadStatus.enqueued,
    this.quality = '320kbps',
  });

  DownloadTask copyWith({
    String? taskId,
    String? videoId,
    String? title,
    String? artist,
    String? album,
    String? thumbnailUrl,
    String? savePath,
    int? progress,
    DownloadStatus? status,
    String? quality,
  }) => DownloadTask(
    taskId: taskId ?? this.taskId,
    videoId: videoId ?? this.videoId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    savePath: savePath ?? this.savePath,
    progress: progress ?? this.progress,
    status: status ?? this.status,
    quality: quality ?? this.quality,
  );

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'videoId': videoId,
    'title': title,
    'artist': artist,
    'album': album,
    'thumbnailUrl': thumbnailUrl,
    'savePath': savePath,
    'progress': progress,
    'status': status.name,
    'quality': quality,
  };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
    taskId: json['taskId'] ?? '',
    videoId: json['videoId'] ?? '',
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    album: json['album'],
    thumbnailUrl: json['thumbnailUrl'],
    savePath: json['savePath'] ?? '',
    progress: json['progress'] ?? 0,
    status: DownloadStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DownloadStatus.enqueued,
    ),
    quality: json['quality'] ?? '320kbps',
  );
}
