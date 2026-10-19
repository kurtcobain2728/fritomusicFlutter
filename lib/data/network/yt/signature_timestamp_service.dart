import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stream_client_utils.dart';

/// Servicio para obtener y cachear dinámicamente el `signatureTimestamp`
/// del reproductor (`player.js` / `base.js`) de YouTube.
class SignatureTimestampService {
  static final SignatureTimestampService instance = SignatureTimestampService._internal();
  factory SignatureTimestampService() => instance;
  SignatureTimestampService._internal();

  static const String _prefKeySts = 'yt_signature_timestamp_val';
  static const String _prefKeyTime = 'yt_signature_timestamp_time';
  static const int _fallbackSts = 20740;
  static const Duration _cacheTtl = Duration(hours: 6);

  int? _memorySts;
  DateTime? _memoryFetchedAt;
  Future<int>? _inflightFetch;

  /// Retorna el `signatureTimestamp` síncrono actual en memoria o fallback
  int get currentSts => _memorySts ?? _fallbackSts;

  /// Obtiene el `signatureTimestamp` actualizado, respetando la caché de 6 horas.
  Future<int> getSignatureTimestamp({bool forceRefresh = false}) async {
    final now = DateTime.now();

    // 1. Comprobar caché en memoria
    if (!forceRefresh &&
        _memorySts != null &&
        _memoryFetchedAt != null &&
        now.difference(_memoryFetchedAt!) < _cacheTtl) {
      return _memorySts!;
    }

    // 2. Si ya hay una petición en curso, reutilizarla
    if (_inflightFetch != null) {
      return await _inflightFetch!;
    }

    // 3. Comprobar SharedPreferences si no está en memoria
    if (!forceRefresh && _memorySts == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedSts = prefs.getInt(_prefKeySts);
        final savedTimeMs = prefs.getInt(_prefKeyTime);
        if (savedSts != null && savedTimeMs != null) {
          final savedDate = DateTime.fromMillisecondsSinceEpoch(savedTimeMs);
          if (now.difference(savedDate) < _cacheTtl) {
            _memorySts = savedSts;
            _memoryFetchedAt = savedDate;
            return savedSts;
          }
        }
      } catch (e) {
        debugPrint('[STS] Error leyendo de SharedPreferences: $e');
      }
    }

    // 4. Descargar y parsear de YouTube (con timeout rápido de 3s para no bloquear la reproducción)
    _inflightFetch = _fetchFromYouTube();
    try {
      final fetched = await _inflightFetch!.timeout(
        const Duration(seconds: 3),
        onTimeout: () => currentSts,
      );
      _memorySts = fetched;
      _memoryFetchedAt = DateTime.now();

      // Guardar en SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefKeySts, fetched);
        await prefs.setInt(_prefKeyTime, _memoryFetchedAt!.millisecondsSinceEpoch);
      } catch (_) {}

      return fetched;
    } catch (e) {
      debugPrint('[STS] Falló la obtención de STS dinámico: $e; usando fallback: $currentSts');
      return currentSts;
    } finally {
      _inflightFetch = null;
    }
  }

  Future<int> _fetchFromYouTube() async {
    debugPrint('[STS] Descargando player.js de YouTube para extraer signatureTimestamp...');

    String? jsUrl;
    final client = HttpClient();

    try {
      // Intento 1: Página embed
      try {
        final req = await client.getUrl(Uri.parse('https://www.youtube.com/embed'));
        req.headers.set('User-Agent', StreamClientUtils.safariUserAgent);
        req.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final match = RegExp(r'"jsUrl":"(/s/player/[^"]+/base\.js)"').firstMatch(body) ??
              RegExp(r'"(/s/player/[^"]+/base\.js)"').firstMatch(body) ??
              RegExp(r'(/s/player/[^"]+/base\.js)').firstMatch(body);
          if (match != null) {
            jsUrl = 'https://www.youtube.com${match.group(1)}';
          }
        }
      } catch (e) {
        debugPrint('[STS] embed page error: $e');
      }

      // Intento 2: iframe_api
      if (jsUrl == null) {
        try {
          final reqIframe = await client.getUrl(Uri.parse('https://www.youtube.com/iframe_api'));
          reqIframe.headers.set('User-Agent', StreamClientUtils.safariUserAgent);
          final respIframe = await reqIframe.close();
          if (respIframe.statusCode == 200) {
            final iframeBody = await respIframe.transform(utf8.decoder).join();
            final match = RegExp(r'player\\/([a-zA-Z0-9_\-]+)\\/').firstMatch(iframeBody) ??
                RegExp(r'player/([a-zA-Z0-9_\-]+)/').firstMatch(iframeBody);
            if (match != null) {
              final id = match.group(1);
              jsUrl = 'https://www.youtube.com/s/player/$id/player_es6.vflset/en_US/base.js';
            }
          }
        } catch (e) {
          debugPrint('[STS] iframe_api error: $e');
        }
      }

      if (jsUrl == null) {
        throw StateError('No se pudo localizar la URL de player.js');
      }

      // Descargar base.js y buscar signatureTimestamp
      final jsReq = await client.getUrl(Uri.parse(jsUrl));
      jsReq.headers.set('User-Agent', StreamClientUtils.safariUserAgent);
      final jsResp = await jsReq.close();
      if (jsResp.statusCode != 200) {
        throw StateError('Error HTTP ${jsResp.statusCode} descargando $jsUrl');
      }
      final jsContent = await jsResp.transform(utf8.decoder).join();

      final stsMatch = RegExp(r'signatureTimestamp[:\s=]+(\d{4,6})').firstMatch(jsContent) ??
          RegExp(r'sts[:\s=]+(\d{4,6})').firstMatch(jsContent);

      if (stsMatch != null) {
        final stsVal = int.tryParse(stsMatch.group(1)!);
        if (stsVal != null && stsVal > 15000) {
          debugPrint('[STS] SignatureTimestamp actualizado con éxito: $stsVal');
          return stsVal;
        }
      }

      throw StateError('No se encontró el patrón de signatureTimestamp en base.js');
    } finally {
      client.close();
    }
  }
}
