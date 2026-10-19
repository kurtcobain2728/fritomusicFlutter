class Playlist {
  final String id;
  final String name;
  final List<String> audioPaths;

  const Playlist({
    required this.id,
    required this.name,
    required this.audioPaths,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'audioPaths': audioPaths,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    audioPaths: (json['audioPaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
  );
}
