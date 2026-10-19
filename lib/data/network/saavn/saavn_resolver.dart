import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dart_des/dart_des.dart';
import 'package:flutter/foundation.dart';

class SaavnCandidate {
  final String id;
  final String title;
  final String artist;
  final String encryptedMediaUrl;
  final String image;

  SaavnCandidate({
    required this.id,
    required this.title,
    required this.artist,
    required this.encryptedMediaUrl,
    required this.image,
  });
}

class SaavnResolvedTrack {
  final String streamUrl;
  final String bitRate;
  final String? artworkUrl;

  SaavnResolvedTrack({
    required this.streamUrl,
    required this.bitRate,
    this.artworkUrl,
  });
}

/// Resolutor de audio de alta fidelidad vía JioSaavn (320 kbps sin restricciones de cuota ni bloqueos 403).
/// Idéntico a OnlineQualityResolver.tryResolveSaavn en la versión Kotlin.
class SaavnResolver {
  static const String _desKey = '38346591';

  /// Desencripta URLs de medios de JioSaavn con cifrado DES-ECB y padding PKCS5.
  static String? decryptJioSaavnUrl(String encryptedBase64) {
    try {
      final keyBytes = utf8.encode(_desKey);
      final des = DES(key: keyBytes, mode: DESMode.ECB, paddingType: DESPaddingType.PKCS5);
      final encryptedBytes = base64.decode(encryptedBase64);
      final decryptedBytes = des.decrypt(encryptedBytes);
      return utf8.decode(decryptedBytes).trim();
    } catch (e) {
      debugPrint('[SaavnResolver] Error desencriptando URL: $e');
      return null;
    }
  }

  /// Limpia títulos típicos de YouTube (como 'Coldplay - Yellow (Official Video)') para obtener el título puro de la canción.
  static String cleanYouTubeTitle(String title) {
    var t = title;
    t = t.replaceAll(RegExp(r'\((official|video|audio|lyric|remastered|extended|version|clip|music|visualizer|live|full).*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[(official|video|audio|lyric|remastered|extended|version|clip|music|visualizer|live|full).*?\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\((feat\.|ft\.|con\s).*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\[(feat\.|ft\.|con\s).*?\]', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\b(feat\.|ft\.)\s+.*$', caseSensitive: false), '');

    // Si viene "Artista - Canción" o "Artista: Canción", separar y tomar la canción
    if (t.contains(' - ')) {
      final parts = t.split(' - ');
      if (parts.length >= 2) {
        t = parts.sublist(1).join(' - ');
      }
    } else if (t.contains(' – ')) { // en-dash
      final parts = t.split(' – ');
      if (parts.length >= 2) {
        t = parts.sublist(1).join(' – ');
      }
    } else if (t.contains(' — ')) { // em-dash
      final parts = t.split(' — ');
      if (parts.length >= 2) {
        t = parts.sublist(1).join(' — ');
      }
    } else if (t.contains(': ')) {
      final parts = t.split(': ');
      if (parts.length >= 2) {
        t = parts.sublist(1).join(': ');
      }
    }

    t = t.replaceAll('"', '').replaceAll("'", '').trim();
    return t;
  }

  /// Limpia nombres de artista generados en YouTube (como 'Queen - Topic' o 'EminemVEVO').
  static String cleanArtistName(String artist) {
    return artist
        .replaceAll('- Topic', '')
        .replaceAll('VEVO', '')
        .replaceAll(RegExp(r'\bOfficial\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bOficial\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bChannel\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String normalizeForMatching(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\(official.*?\)|\[official.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(video.*?\)|\[video.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(audio.*?\)|\[audio.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(remastered.*?\)|\[remastered.*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(feat\..*?\)|\[feat\..*?\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(ft\..*?\)|\[ft\..*?\]', caseSensitive: false), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll(RegExp(r'[^\p{L}\p{Nd}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int levenshtein(String s1, String s2) {
    final dp = List.generate(s1.length + 1, (_) => List.filled(s2.length + 1, 0));
    for (int i = 0; i <= s1.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        dp[i][j] = min(
          dp[i - 1][j] + 1,
          min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost),
        );
      }
    }
    return dp[s1.length][s2.length];
  }

  static double calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    final maxLen = max(s1.length, s2.length);
    final distance = levenshtein(s1, s2);
    return 1.0 - (distance / maxLen);
  }

  static bool isStrictCandidateMatch({
    required String candidateTitle,
    required String candidateArtist,
    required String targetTitle,
    required String targetArtist,
  }) {
    final normTargetTitle = normalizeForMatching(targetTitle);
    final normCleanSongTitle = normalizeForMatching(cleanYouTubeTitle(targetTitle));
    final normTargetArtist = normalizeForMatching(cleanArtistName(targetArtist));
    final normCandTitle = normalizeForMatching(candidateTitle);
    final normCandArtist = normalizeForMatching(candidateArtist);

    if (normTargetTitle.isEmpty || normCandTitle.isEmpty) return false;

    // Filtro anti-karaoke / covers si el original no lo es
    final isCoverOrKaraoke = normCandTitle.contains('karaoke') ||
        normCandTitle.contains('piano instrumental') ||
        normCandTitle.contains('tribute') ||
        normCandTitle.contains('originally performed by');
    final targetIsCover = normTargetTitle.contains('karaoke') || normTargetTitle.contains('tribute');
    if (isCoverOrKaraoke && !targetIsCover) return false;

    // 1. Similitud de título (probando tanto el título completo como el nombre de canción limpio)
    final titleSimRaw = calculateSimilarity(normTargetTitle, normCandTitle);
    final titleSimClean = calculateSimilarity(normCleanSongTitle, normCandTitle);
    final bestTitleSim = max(titleSimRaw, titleSimClean);

    final titleMatches = bestTitleSim >= 0.70 ||
        (normCandTitle.length >= 4 && (normTargetTitle.contains(normCandTitle) || normCleanSongTitle.contains(normCandTitle))) ||
        (normCleanSongTitle.length >= 4 && normCandTitle.contains(normCleanSongTitle));

    if (!titleMatches) return false;

    // 2. Similitud de artista
    if (normTargetArtist.isNotEmpty) {
      final targetTokens = normTargetArtist.split(' ').where((t) => t.length > 2);
      final candTokens = normCandArtist.split(' ').where((t) => t.length > 2);

      final artistSimilarity = calculateSimilarity(normTargetArtist, normCandArtist);
      final hasTokenOverlap = targetTokens.any((t) => normCandArtist.contains(t)) ||
          candTokens.any((c) => normTargetArtist.contains(c));

      final artistMatches = artistSimilarity >= 0.40 || hasTokenOverlap;
      if (!artistMatches) return false;
    }

    return true;
  }

  /// Intenta resolver la canción en JioSaavn con calidad de 320 kbps.
  /// Retorna un SaavnResolvedTrack si encuentra una coincidencia verificada.
  static Future<SaavnResolvedTrack?> resolve(String title, String artist) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);

    try {
      final cleanSong = cleanYouTubeTitle(title);
      final cleanArt = cleanArtistName(artist);
      final normSong = normalizeForMatching(cleanSong);
      final normArt = normalizeForMatching(cleanArt);

      // Prioridad de consultas ordenadas por probabilidad de coincidencia
      final queries = <String>{};
      if (normSong.isNotEmpty && normArt.isNotEmpty) {
        queries.add('$cleanSong $cleanArt');
      }
      if (normSong.isNotEmpty) {
        queries.add(cleanSong);
      }
      if (title.isNotEmpty && artist.isNotEmpty) {
        queries.add('$title $artist'.trim());
      } else if (title.isNotEmpty) {
        queries.add(title.trim());
      }

      final candidates = <SaavnCandidate>[];

      // 1. Intentar endpoint search.getResults con queries prioritarias
      for (final q in queries) {
        if (candidates.isNotEmpty) break;
        final searchUrl = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=search.getResults&q=${Uri.encodeComponent(q)}&_format=json&_marker=0&ctx=android&p=1&n=10',
        );
        try {
          final req = await client.getUrl(searchUrl);
          req.headers.set('User-Agent', 'Mozilla/5.0');
          final resp = await req.close();
          if (resp.statusCode == 200) {
            final text = await resp.transform(utf8.decoder).join();
            final json = jsonDecode(text);
            final results = json['results'] as List?;
            if (results != null) {
              for (final item in results) {
                final songId = item['id']?.toString() ?? '';
                final candTitle = item['song']?.toString() ?? item['title']?.toString() ?? '';
                final candArtist = item['primary_artists']?.toString() ?? item['singers']?.toString() ?? '';
                final encryptedUrl = item['encrypted_media_url']?.toString() ?? '';
                final image = item['image']?.toString() ?? '';
                final disabled = item['disabled']?.toString() == 'true';
                if (songId.isNotEmpty && !disabled) {
                  candidates.add(SaavnCandidate(
                    id: songId,
                    title: candTitle,
                    artist: candArtist,
                    encryptedMediaUrl: encryptedUrl,
                    image: image,
                  ));
                }
              }
            }
          }
        } catch (_) {}
      }

      // 2. Si no hubo candidatos, probar con autocomplete.get
      if (candidates.isEmpty && queries.isNotEmpty) {
        final autoUrl = Uri.parse(
          'https://www.jiosaavn.com/api.php?__call=autocomplete.get&query=${Uri.encodeComponent(queries.first)}&_format=json&_marker=0&ctx=android',
        );
        try {
          final autoReq = await client.getUrl(autoUrl);
          autoReq.headers.set('User-Agent', 'Mozilla/5.0');
          final autoResp = await autoReq.close();
          if (autoResp.statusCode == 200) {
            final autoText = await autoResp.transform(utf8.decoder).join();
            final autoJson = jsonDecode(autoText);
            final dataArray = autoJson['songs']?['data'] as List?;
            if (dataArray != null) {
              for (final item in dataArray) {
                final songId = item['id']?.toString() ?? '';
                final candTitle = item['title']?.toString() ?? '';
                final moreInfo = item['more_info'];
                final candArtist = moreInfo?['primary_artists']?.toString() ??
                    moreInfo?['singers']?.toString() ??
                    item['description']?.toString() ??
                    '';
                if (songId.isNotEmpty) {
                  candidates.add(SaavnCandidate(
                    id: songId,
                    title: candTitle,
                    artist: candArtist,
                    encryptedMediaUrl: '',
                    image: item['image']?.toString() ?? '',
                  ));
                }
              }
            }
          }
        } catch (_) {}
      }

      if (candidates.isEmpty) return null;

      // 3. Filtrar y verificar candidatos estrictamente
      for (final candidate in candidates) {
        if (isStrictCandidateMatch(
          candidateTitle: candidate.title,
          candidateArtist: candidate.artist,
          targetTitle: title,
          targetArtist: artist,
        )) {
          debugPrint('[SaavnResolver] Coincidencia verificada: ${candidate.title} por ${candidate.artist}');
          var encryptedUrl = candidate.encryptedMediaUrl;
          var artwork = candidate.image.replaceAll('150x150', '500x500');

          // Si no traía el URL cifrado, consultar song.getDetails
          if (encryptedUrl.isEmpty && candidate.id.isNotEmpty) {
            final detailsUrl = Uri.parse(
              'https://www.jiosaavn.com/api.php?__call=song.getDetails&pids=${candidate.id}&_format=json&_marker=0&ctx=android',
            );
            try {
              final dReq = await client.getUrl(detailsUrl);
              dReq.headers.set('User-Agent', 'Mozilla/5.0');
              final dResp = await dReq.close();
              if (dResp.statusCode == 200) {
                final dText = await dResp.transform(utf8.decoder).join();
                final dJson = jsonDecode(dText);
                final songObj = dJson[candidate.id];
                encryptedUrl = songObj?['encrypted_media_url']?.toString() ?? '';
                final detailImg = songObj?['image']?.toString();
                if (detailImg != null && detailImg.isNotEmpty) {
                  artwork = detailImg.replaceAll('150x150', '500x500');
                }
              }
            } catch (_) {}
          }

          if (encryptedUrl.isEmpty) continue;

          final decrypted = decryptJioSaavnUrl(encryptedUrl);
          if (decrypted == null) continue;

          // Calidad máxima 320 kbps directa (idéntico a Kotlin)
          final highQualityUrl = decrypted
              .replaceAll('_96.mp4', '_320.mp4')
              .replaceAll('_160.mp4', '_320.mp4');

          return SaavnResolvedTrack(
            streamUrl: highQualityUrl,
            bitRate: '320 kbps',
            artworkUrl: artwork.isNotEmpty ? artwork : null,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('[SaavnResolver] Error en resolución: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
