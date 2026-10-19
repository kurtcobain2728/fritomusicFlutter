import 'package:dio/dio.dart';
import '../models/lyrics_models.dart';
import '../../utils/lrc_parser.dart';

class LyricsRepository {
  static final LyricsRepository instance = LyricsRepository._internal();
  factory LyricsRepository() => instance;
  LyricsRepository._internal();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net/api',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'FritoMusic/1.0 (Flutter; https://github.com/kurtcobain2728/FritoMusic)',
    },
  ));

  final Map<String, LyricsData> _cache = {};

  String _cleanString(String str) {
    return str
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'(official\s+video|official\s+audio|lyrics|letra|video\s+oficial)', caseSensitive: false), '')
        .trim();
  }

  /// Obtiene la letra sincronizada o plana de LRCLIB
  Future<LyricsData?> getLyrics({
    required String title,
    required String artist,
    int? durationSeconds,
    bool forceRefresh = false,
  }) async {
    final cleanT = _cleanString(title);
    final cleanA = _cleanString(artist);
    final cacheKey = '$cleanA - $cleanT';

    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // 1. Probar LRCLIB /api/get
    try {
      final params = <String, dynamic>{
        'track_name': cleanT,
        'artist_name': cleanA,
      };
      if (durationSeconds != null && durationSeconds > 0) {
        params['duration'] = durationSeconds;
      }

      final response = await _dio.get('/get', queryParameters: params);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        final syncedLyrics = data['syncedLyrics']?.toString();
        final plainLyrics = data['plainLyrics']?.toString();

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          final lines = LrcParser.parse(syncedLyrics);
          if (lines.isNotEmpty) {
            final lyrics = LyricsData(
              title: title,
              artist: artist,
              lines: lines,
              plainLyrics: plainLyrics ?? syncedLyrics,
              isSynced: true,
              source: 'LRCLIB',
            );
            _cache[cacheKey] = lyrics;
            return lyrics;
          }
        }

        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          final lyrics = LyricsData(
            title: title,
            artist: artist,
            lines: [],
            plainLyrics: plainLyrics,
            isSynced: false,
            source: 'LRCLIB',
          );
          _cache[cacheKey] = lyrics;
          return lyrics;
        }
      }
    } catch (_) {}

    // 2. Probar LRCLIB /api/search búsqueda difusa
    try {
      final response = await _dio.get('/search', queryParameters: {'q': '$cleanA $cleanT'});
      if (response.statusCode == 200 && response.data is List && (response.data as List).isNotEmpty) {
        final list = response.data as List;
        // Buscar el primer resultado con syncedLyrics
        final match = list.firstWhere(
          (item) => item['syncedLyrics'] != null && item['syncedLyrics'].toString().isNotEmpty,
          orElse: () => list.first,
        );

        final syncedLyrics = match['syncedLyrics']?.toString();
        final plainLyrics = match['plainLyrics']?.toString();

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          final lines = LrcParser.parse(syncedLyrics);
          if (lines.isNotEmpty) {
            final lyrics = LyricsData(
              title: title,
              artist: artist,
              lines: lines,
              plainLyrics: plainLyrics ?? syncedLyrics,
              isSynced: true,
              source: 'LRCLIB',
            );
            _cache[cacheKey] = lyrics;
            return lyrics;
          }
        }

        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          final lyrics = LyricsData(
            title: title,
            artist: artist,
            lines: [],
            plainLyrics: plainLyrics,
            isSynced: false,
            source: 'LRCLIB',
          );
          _cache[cacheKey] = lyrics;
          return lyrics;
        }
      }
    } catch (_) {}

    return null;
  }
}
