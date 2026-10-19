import '../data/models/lyrics_models.dart';

class LrcParser {
  static final RegExp _timeTagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  static final RegExp _syllableTagRegex = RegExp(r'<(\d{1,2}:\d{2}(?:\.\d{1,3})?|\d+)>');
  static final RegExp _karaokeTagRegex = RegExp(r'\{[^}]*\}');
  static final RegExp _metadataTagRegex = RegExp(r'^\[(ti|ar|al|by|offset|re|ve|length):.*\]', caseSensitive: false);

  /// Parsea una cadena de texto en formato LRC a una lista ordenada de LyricLine.
  static List<LyricLine> parse(String lrcContent) {
    if (lrcContent.trim().isEmpty) return [];

    final result = <LyricLine>[];
    final lines = lrcContent.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_metadataTagRegex.hasMatch(trimmed)) continue;

      final allMatches = _timeTagRegex.allMatches(trimmed).toList();
      if (allMatches.isEmpty) continue;

      var text = trimmed
          .replaceAll(_timeTagRegex, '')
          .replaceAll(_syllableTagRegex, '')
          .replaceAll(_karaokeTagRegex, '')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&apos;', "'")
          .trim();

      if (text.isEmpty) continue;

      for (final match in allMatches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionStr = match.group(3) ?? '';

        int millis = 0;
        if (fractionStr.length == 1) {
          millis = (int.tryParse(fractionStr) ?? 0) * 100;
        } else if (fractionStr.length == 2) {
          millis = (int.tryParse(fractionStr) ?? 0) * 10;
        } else if (fractionStr.length == 3) {
          millis = int.tryParse(fractionStr) ?? 0;
        }

        final timestampMs = minutes * 60000 + seconds * 1000 + millis;
        result.add(LyricLine(timestampMs: timestampMs, text: text));
      }
    }

    result.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    return result;
  }
}
