import 'package:dio/dio.dart';

class LyricsTranslator {
  static final Map<String, List<String>> _cache = {};
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  static String _cleanLine(String line) {
    return line
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  }

  /// Traduce una lista de líneas de letra a español ('es') mediante Google Translate GTX
  static Future<List<String>> translate(List<String> lines, {String targetLang = 'es'}) async {
    if (lines.isEmpty) return [];

    final cacheKey = '$targetLang:${lines.join("\n")}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final textToTranslate = lines.join('\n');
      final response = await _dio.post(
        'https://translate.googleapis.com/translate_a/single',
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': targetLang,
          'dt': 't',
        },
        data: 'q=${Uri.encodeQueryComponent(textToTranslate)}',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        if (list.isNotEmpty && list[0] is List) {
          final sentences = list[0] as List;
          final sb = StringBuffer();
          for (final s in sentences) {
            if (s is List && s.isNotEmpty) {
              sb.write(s[0]?.toString() ?? '');
            }
          }

          final translatedLines = sb.toString().split('\n');
          final result = List<String>.generate(lines.length, (i) {
            return _cleanLine(i < translatedLines.length ? translatedLines[i] : lines[i]);
          });

          _cache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {}

    return lines;
  }
}
