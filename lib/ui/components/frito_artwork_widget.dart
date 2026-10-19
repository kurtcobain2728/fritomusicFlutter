import 'dart:io';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/theme/app_colors.dart';

/// Gestor de caché en memoria de alta resolución para evitar cualquier titileo
class FritoArtworkCache {
  static final Map<int, Uint8List?> _memoryCache = {};
  static final Map<int, Future<Uint8List?>> _inFlight = {};
  static final OnAudioQuery _audioQuery = OnAudioQuery();

  static bool isCached(int id) => _memoryCache.containsKey(id);
  static Uint8List? get(int id) => _memoryCache[id];

  static Future<Uint8List?> loadArtwork(int id) {
    if (_memoryCache.containsKey(id)) {
      return Future.value(_memoryCache[id]);
    }
    if (_inFlight.containsKey(id)) {
      return _inFlight[id]!;
    }

    final future = _audioQuery
        .queryArtwork(
          id,
          ArtworkType.AUDIO,
          format: ArtworkFormat.JPEG,
          size: 1000,
          quality: 100,
        )
        .then((bytes) {
          _memoryCache[id] = bytes;
          _inFlight.remove(id);
          return bytes;
        })
        .catchError((_) {
          _memoryCache[id] = null;
          _inFlight.remove(id);
          return null;
        });

    _inFlight[id] = future;
    return future;
  }

  /// Precarga un lote de canciones en segundo plano
  static void preload(Iterable<int> ids) {
    for (final id in ids) {
      if (id > 0 && !_memoryCache.containsKey(id) && !_inFlight.containsKey(id)) {
        loadArtwork(id);
      }
    }
  }
}

class FritoArtworkWidget extends StatelessWidget {
  final int? audioId;
  final String? albumUri;
  final double size;
  final double borderRadius;
  final AppColors appColors;
  final IconData fallbackIcon;

  const FritoArtworkWidget({
    super.key,
    this.audioId,
    this.albumUri,
    this.size = 48,
    this.borderRadius = 8,
    required this.appColors,
    this.fallbackIcon = Icons.music_note,
  });

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: appColors.accent,
          size: size * 0.48,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = albumUri;

    // 1. URL Remota (YouTube / Streaming)
    if (uri != null && (uri.startsWith('http://') || uri.startsWith('https://'))) {
      // Optimizar resolución para carátulas grandes
      var highResUrl = uri;
      if (highResUrl.contains('googleusercontent.com') || highResUrl.contains('ytimg.com')) {
        highResUrl = highResUrl
            .replaceAll(RegExp(r'=w\d+-h\d+'), '=w800-h800')
            .replaceAll(RegExp(r'=s\d+'), '=s800');
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          imageUrl: highResUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          placeholder: (_, __) => _buildFallback(),
          errorWidget: (_, __, ___) => _buildFallback(),
        ),
      );
    }

    // 2. Archivo Local existente en disco (ej: cover.jpg, [cancion].jpg o file://...)
    if (uri != null && uri.isNotEmpty && !uri.startsWith('content://')) {
      final cleanPath = uri.startsWith('file://') ? uri.replaceFirst('file://', '') : uri;
      final file = File(cleanPath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _buildFallback(),
          ),
        );
      }
    }

    // 3. Audio local con ID mediante OnAudioQuery nativo con caché permanente (0ms delay)
    if (audioId != null && audioId! > 0) {
      final id = audioId!;

      // Si ya está en memoria RAM, lo mostramos de inmediato en 0 milisegundos sin parpadear
      if (FritoArtworkCache.isCached(id)) {
        final bytes = FritoArtworkCache.get(id);
        if (bytes != null && bytes.isNotEmpty) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (size * 2).toInt().clamp(100, 1000),
              errorBuilder: (_, __, ___) => _buildFallback(),
            ),
          );
        } else {
          return _buildFallback();
        }
      }

      // Primera carga: recupera bytes a 1000px y almacena en caché de por vida
      return FutureBuilder<Uint8List?>(
        future: FritoArtworkCache.loadArtwork(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.memory(
                snapshot.data!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: (size * 2).toInt().clamp(100, 1000),
                errorBuilder: (_, __, ___) => _buildFallback(),
              ),
            );
          }
          return _buildFallback();
        },
      );
    }

    // 4. Fallback si no hay carátula
    return _buildFallback();
  }
}
