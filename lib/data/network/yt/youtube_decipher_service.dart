import 'package:flutter/foundation.dart';
import 'stream_client_utils.dart';

/// Servicio para descifrado de formatos de stream de YouTube (signatureCipher, cipher)
/// y resolución de parámetros anti-estrangulamiento.
class YouTubeDecipherService {
  static final YouTubeDecipherService instance = YouTubeDecipherService._internal();
  factory YouTubeDecipherService() => instance;
  YouTubeDecipherService._internal();

  /// Desempaqueta y descifra un formato de audio de YouTube, soportando:
  /// 1. Formatos directos con campo `url`
  /// 2. Formatos cifrados con campo `signatureCipher` o `cipher`
  String? decipherFormat(Map<dynamic, dynamic> format, {String? poToken}) {
    String? rawUrl = format['url']?.toString();
    final signatureCipher = format['signatureCipher']?.toString() ?? format['cipher']?.toString();

    if ((rawUrl == null || rawUrl.isEmpty) && signatureCipher != null && signatureCipher.isNotEmpty) {
      try {
        final dummyUri = Uri.parse('https://yt-cipher.invalid/?$signatureCipher');
        final extractedUrl = dummyUri.queryParameters['url'];
        final s = dummyUri.queryParameters['s'];
        final sp = dummyUri.queryParameters['sp'] ?? 'signature';

        if (extractedUrl != null && extractedUrl.isNotEmpty) {
          rawUrl = extractedUrl;
          if (s != null && s.isNotEmpty) {
            final sep = rawUrl.contains('?') ? '&' : '?';
            rawUrl = '$rawUrl$sep$sp=$s';
          }
        }
      } catch (e) {
        debugPrint('[Decipher] Error parseando signatureCipher: $e');
      }
    }

    if (rawUrl != null && rawUrl.isNotEmpty) {
      if (poToken != null && poToken.isNotEmpty) {
        rawUrl = StreamClientUtils.appendPoToken(rawUrl, poToken);
      }
      return rawUrl;
    }

    return null;
  }

  /// Extrae el mejor formato de audio de `streamingData`, soportando tanto formatos
  /// adaptativos directos como cifrados.
  String? extractBestAudioStream(dynamic streamingData, {String? poToken}) {
    if (streamingData == null || streamingData is! Map) return null;

    final rawFormats = <dynamic>[
      if (streamingData['adaptiveFormats'] is List) ...streamingData['adaptiveFormats'],
      if (streamingData['formats'] is List) ...streamingData['formats'],
    ];

    if (rawFormats.isEmpty) return null;

    final audioFormats = rawFormats
        .whereType<Map>()
        .where((f) {
          final mime = (f['mimeType'] ?? f['mime_type'])?.toString() ?? '';
          final hasPlayable = (f['url'] != null && f['url'].toString().isNotEmpty) ||
              (f['signatureCipher'] != null && f['signatureCipher'].toString().isNotEmpty) ||
              (f['cipher'] != null && f['cipher'].toString().isNotEmpty);
          return mime.startsWith('audio/') && hasPlayable;
        })
        .toList();

    if (audioFormats.isEmpty) {
      // Fallback a formatos muxed de audio/video si no hay audio-only
      final anyPlayable = rawFormats
          .whereType<Map>()
          .where((f) =>
              (f['url'] != null && f['url'].toString().isNotEmpty) ||
              (f['signatureCipher'] != null && f['signatureCipher'].toString().isNotEmpty) ||
              (f['cipher'] != null && f['cipher'].toString().isNotEmpty))
          .toList();
      if (anyPlayable.isNotEmpty) {
        audioFormats.addAll(anyPlayable);
      } else {
        return null;
      }
    }

    // Ordenar por bitrate descendente
    audioFormats.sort((a, b) {
      final aBitrate = (a['bitrate'] ?? a['averageBitrate'] ?? 0) as num;
      final bBitrate = (b['bitrate'] ?? b['averageBitrate'] ?? 0) as num;
      return bBitrate.compareTo(aBitrate);
    });

    // Priorizar formatos con URL directa (no cifrada) para evitar 403 Forbidden
    final directFormats = audioFormats
        .where((f) => f['url'] != null && f['url'].toString().isNotEmpty)
        .toList();
    final candidateFormats = directFormats.isNotEmpty ? directFormats : audioFormats;

    for (final format in candidateFormats) {
      final url = decipherFormat(format, poToken: poToken);
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }
}
