/// Representa una línea individual de letra con su marca de tiempo en milisegundos.
class LyricLine {
  final int timestampMs;
  final String text;
  final String? translatedText;

  const LyricLine({
    required this.timestampMs,
    required this.text,
    this.translatedText,
  });

  LyricLine copyWith({
    int? timestampMs,
    String? text,
    String? translatedText,
  }) {
    return LyricLine(
      timestampMs: timestampMs ?? this.timestampMs,
      text: text ?? this.text,
      translatedText: translatedText ?? this.translatedText,
    );
  }

  Map<String, dynamic> toJson() => {
    'timestampMs': timestampMs,
    'text': text,
    if (translatedText != null) 'translatedText': translatedText,
  };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
    timestampMs: json['timestampMs'] is int ? json['timestampMs'] : int.tryParse(json['timestampMs'].toString()) ?? 0,
    text: json['text'] ?? '',
    translatedText: json['translatedText'],
  );
}

/// Representa la letra completa de una canción, ya sea sincronizada (LRC) o texto plano.
class LyricsData {
  final String title;
  final String artist;
  final List<LyricLine> lines;
  final String? plainLyrics;
  final bool isSynced;
  final String source;

  LyricsData({
    required this.title,
    required this.artist,
    this.lines = const [],
    this.plainLyrics,
    bool? isSynced,
    this.source = 'LRCLIB',
  }) : isSynced = isSynced ?? lines.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'lines': lines.map((e) => e.toJson()).toList(),
    'plainLyrics': plainLyrics,
    'isSynced': isSynced,
    'source': source,
  };

  factory LyricsData.fromJson(Map<String, dynamic> json) => LyricsData(
    title: json['title'] ?? '',
    artist: json['artist'] ?? '',
    lines: (json['lines'] as List<dynamic>?)?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    plainLyrics: json['plainLyrics'],
    isSynced: json['isSynced'],
    source: json['source'] ?? 'LRCLIB',
  );
}

/// Estados de la interfaz de usuario para la pantalla de letras.
abstract class LyricsUiState {
  const LyricsUiState();
}

class LyricsUiIdle extends LyricsUiState {
  const LyricsUiIdle();
}

class LyricsUiLoading extends LyricsUiState {
  const LyricsUiLoading();
}

class LyricsUiSuccess extends LyricsUiState {
  final LyricsData lyrics;
  const LyricsUiSuccess(this.lyrics);
}

class LyricsUiEmpty extends LyricsUiState {
  const LyricsUiEmpty();
}
