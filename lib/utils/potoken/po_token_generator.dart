import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import '../../data/network/innertube/innertube_client.dart';

/// Resultado de la generación de PoTokens (idéntico al de la versión Kotlin):
/// - [playerRequestPoToken]: token vinculado al video, para el cuerpo del
///   request `/player` (context.serviceIntegrityDimensions.poToken).
/// - [streamingDataPoToken]: token de sesión, para adjuntar `?pot=` a las
///   URLs de googlevideo devueltas por el cliente web.
class PoTokenResult {
  final String playerRequestPoToken;
  final String streamingDataPoToken;

  const PoTokenResult({
    required this.playerRequestPoToken,
    required this.streamingDataPoToken,
  });
}

class _CachedPoTokenEntry {
  final String playerPoToken;
  final String streamingPoToken;
  final DateTime expiresAt;

  _CachedPoTokenEntry({
    required this.playerPoToken,
    required this.streamingPoToken,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class PoTokenException implements Exception {
  final String message;
  const PoTokenException(this.message);

  @override
  String toString() => 'PoTokenException: $message';
}

/// Generador de Proof-of-Origin Tokens (YouTube BotGuard) usando un WebView
/// oculto. Port a Dart de la implementación original en Kotlin
/// (`app/src/main/java/com/frito/music/utils/potoken/`).
///
/// Flujo (idéntico al Kotlin):
/// 1. Se carga `assets/potoken/po_token.html` en un WebView oculto.
/// 2. POST a `/api/jnn/v1/Create` → challenge data → se ejecuta BotGuard en JS.
/// 3. POST a `/api/jnn/v1/GenerateIT` → integrity token (+ expiración).
/// 4. Se crea el "minter" en JS; a partir de ahí se acuñan tokens por
///    identifier (videoId / sessionId) de forma rápida y reutilizando el
///    integrity token hasta que expira.
class PoTokenGenerator {
  static final PoTokenGenerator instance = PoTokenGenerator._internal();
  factory PoTokenGenerator() => instance;
  PoTokenGenerator._internal();

  // ---- Constantes (idénticas a PoTokenWebView.kt) ----
  static const String _defaultGoogleApiKey = String.fromEnvironment(
    'GOOGLE_API_KEY',
    defaultValue: 'QUl6YVN5RHlUNVcwSmg0OUYzMFBxcXR5ZmRmN3BETEZLTEpvQW53',
  );
  static final String _googleApiKey = _defaultGoogleApiKey.startsWith('AIza')
      ? _defaultGoogleApiKey
      : utf8.decode(base64.decode(_defaultGoogleApiKey));
  static const String _requestKey = 'O43z0dpjhgX20SCx4KAo';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.3';
  static const String _jsInterface = 'PoTokenWebView';
  static const String _assetHtml = 'assets/potoken/po_token.html';
  static const Duration _generateTimeout = Duration(seconds: 4);
  static const Duration _initTimeout = Duration(seconds: 6);
  static const Duration _expirationMargin = Duration(minutes: 10);

  // ---- Estado ----
  WebViewController? _controller;
  bool _attached = false;
  DateTime? _disabledUntil; // Circuit breaker temporal en vez de flag permanente
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 4;
  static const Duration _circuitBreakerDuration = Duration(seconds: 45);
  static const Duration _tokenCacheTtl = Duration(hours: 4);

  final Map<String, _CachedPoTokenEntry> _tokenCache = {};
  String? _sessionId;
  String? _streamingPot;
  DateTime? _expiresAt;
  Future<void>? _initFuture;

  final Dio _jnnDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': userAgent,
      'Accept': 'application/json',
      'Content-Type': 'application/json+protobuf',
      'x-goog-api-key': _googleApiKey,
      'x-user-agent': 'grpc-web-javascript/0.1',
    },
  ));

  // Completers de la danza de inicialización
  Completer<void>? _loadedCompleter;
  Completer<void>? _botguardCompleter;
  Completer<void>? _minterCompleter;
  String? _botguardResponse;

  // Mint pendientes por reqId
  final Map<int, Completer<String>> _pendingMints = {};
  int _nextReqId = 0;

  /// Lo llama `PoTokenWebViewHost` cuando el widget oculto queda montado.
  void attach(WebViewController controller) {
    _controller = controller;
    _attached = true;
  }

  void detach() {
    _controller = null;
    _attached = false;
    _initFuture = null;
    _sessionId = null;
    _streamingPot = null;
  }

  bool get _isExpired {
    final expiresAt = _expiresAt;
    return expiresAt != null && DateTime.now().isAfter(expiresAt);
  }

  /// Precalienta el generador (BotGuard + minter) al arrancar la app para que
  /// el primer play no espere la inicialización de 2–5 s. Falla en silencio:
  /// el primer play reintentará la inicialización por su cuenta.
  /// Precalienta el generador (BotGuard + minter) al arrancar la app para que
  /// el primer play no espere la inicialización de 2–5 s. Falla en silencio:
  /// el primer play reintentará la inicialización por su cuenta.
  Future<void> prewarm() async {
    if (!Platform.isAndroid || _controller == null || !_attached) return;
    if (_disabledUntil != null && DateTime.now().isBefore(_disabledUntil!)) return;
    try {
      final sessionId = (await InnerTubeClient.instance.ensureVisitorData())?.trim();
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('[PoToken] Prewarm omitido: sin visitorData');
        return;
      }
      await _getWebClientPoToken('prewarm', sessionId, forceRecreate: true);
      debugPrint('[PoToken] Prewarm OK: minter listo (streamingPot en caché)');
    } catch (e) {
      debugPrint('[PoToken] Prewarm falló (se reintentará en el primer play): $e');
    }
  }

  /// Punto de entrada: devuelve los PoTokens para [videoId] vinculados a
  /// [sessionId] (dataSyncId si hay sesión, o el visitorData de invitado).
  /// Devuelve `null` (nunca lanza) si el WebView no está disponible o falla:
  /// la reproducción debe seguir funcionando sin tokens como respaldo.
  Future<PoTokenResult?> getWebClientPoToken(String videoId, String sessionId) async {
    if (!Platform.isAndroid || !_attached || _controller == null) return null;
    if (videoId.isEmpty || sessionId.isEmpty) return null;

    // 1. Verificar circuit breaker
    if (_disabledUntil != null && DateTime.now().isBefore(_disabledUntil!)) {
      debugPrint('[PoToken] En pausa por circuit breaker temporal');
      return null;
    }

    // 2. Verificar caché en memoria por videoId
    final cached = _tokenCache[videoId];
    if (cached != null && !cached.isExpired && _sessionId == sessionId) {
      return PoTokenResult(
        playerRequestPoToken: cached.playerPoToken,
        streamingDataPoToken: cached.streamingPoToken,
      );
    }

    // 3. Intento con reintento (backoff)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final result = await _getWebClientPoToken(
          videoId,
          sessionId,
          forceRecreate: attempt > 0,
        );
        if (result != null) {
          _consecutiveErrors = 0;
          _disabledUntil = null;
          _tokenCache[videoId] = _CachedPoTokenEntry(
            playerPoToken: result.playerRequestPoToken,
            streamingPoToken: result.streamingDataPoToken,
            expiresAt: DateTime.now().add(_tokenCacheTtl),
          );
          return result;
        }
      } catch (e) {
        debugPrint('[PoToken] Intento ${attempt + 1} para $videoId falló: $e');
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    _consecutiveErrors++;
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _disabledUntil = DateTime.now().add(_circuitBreakerDuration);
      debugPrint('[PoToken] Activado circuit breaker por $_circuitBreakerDuration');
    }

    return null;
  }

  Future<PoTokenResult?> _getWebClientPoToken(
    String videoId,
    String sessionId, {
    required bool forceRecreate,
  }) async {
    bool hasBeenRecreated = false;
    if (forceRecreate || _initFuture == null || _isExpired || _sessionId != sessionId) {
      _initFuture = null;
      _streamingPot = null;
      hasBeenRecreated = true;
      _initFuture = _initialize(sessionId);
    }

    try {
      await _initFuture!;
    } catch (_) {
      _initFuture = null; // próxima llamada reintentará la inicialización
      rethrow;
    }

    final streamingPot = _streamingPot;
    if (streamingPot == null) {
      if (!hasBeenRecreated) {
        return _getWebClientPoToken(videoId, sessionId, forceRecreate: true);
      }
      throw const PoTokenException('streamingPot no disponible');
    }

    try {
      final playerPot = await _mint(videoId);
      return PoTokenResult(
        playerRequestPoToken: playerPot,
        streamingDataPoToken: streamingPot,
      );
    } catch (e) {
      if (hasBeenRecreated) rethrow;
      // El minter puede haberse muerto: recrear el WebView una vez y reintentar.
      return _getWebClientPoToken(videoId, sessionId, forceRecreate: true);
    }
  }

  // ------------------------------------------------------------------
  // Inicialización: HTML → Create → BotGuard → GenerateIT → minter
  // ------------------------------------------------------------------
  Future<void> _initialize(String sessionId) async {
    final controller = _controller;
    if (controller == null) throw const PoTokenException('WebView no adjunto');

    _loadedCompleter = Completer<void>();
    _botguardCompleter = Completer<void>();
    _minterCompleter = Completer<void>();
    _botguardResponse = null;

    // 1. Cargar el HTML local con la señal de "listo" inyectada.
    final html = await rootBundle.loadString(_assetHtml);
    final injected = html.replaceFirst(
      '</script>',
      "\n$_jsInterface.postMessage(JSON.stringify({event:'loaded'}));</script>",
    );
    await controller.loadHtmlString(injected, baseUrl: 'https://www.youtube.com');
    await _loadedCompleter!.future.timeout(_initTimeout);

    // 2. Challenge de BotGuard.
    final createResponse = await _postJnn('https://www.youtube.com/api/jnn/v1/Create', [
      _requestKey,
    ]);
    final challenge = _parseChallengeData(createResponse);
    await controller.runJavaScript('''
try {
  var data = ${jsonEncode(challenge)};
  runBotGuard(data).then(function(result) {
    window.webPoSignalOutput = result.webPoSignalOutput;
    $_jsInterface.postMessage(JSON.stringify({event:'botguard_done', response: result.botguardResponse}));
  }, function(error) {
    $_jsInterface.postMessage(JSON.stringify({event:'error', message: String(error)}));
  });
} catch (error) {
  $_jsInterface.postMessage(JSON.stringify({event:'error', message: String(error)}));
}
''');
    await _botguardCompleter!.future.timeout(_initTimeout);
    final botguardResponse = _botguardResponse;
    if (botguardResponse == null || botguardResponse.isEmpty) {
      throw const PoTokenException('botguardResponse vacío');
    }

    // 3. Integrity token.
    final generateResponse = await _postJnn('https://www.youtube.com/api/jnn/v1/GenerateIT', [
      _requestKey,
      botguardResponse,
    ]);
    final integrity = _parseIntegrityTokenData(generateResponse);
    _expiresAt = DateTime.now()
        .add(Duration(seconds: integrity.seconds))
        .subtract(_expirationMargin);

    // 4. Crear el minter en JS.
    await controller.runJavaScript('''
try {
  window.integrityToken = ${integrity.tokenJs};
  createPoTokenMinter(window.webPoSignalOutput, window.integrityToken).then(function() {
    $_jsInterface.postMessage(JSON.stringify({event:'minter_created'}));
  }).catch(function(error) {
    $_jsInterface.postMessage(JSON.stringify({event:'error', message: String(error)}));
  });
} catch (error) {
  $_jsInterface.postMessage(JSON.stringify({event:'error', message: String(error)}));
}
''');
    await _minterCompleter!.future.timeout(_initTimeout);

    // 5. Token de sesión (se adjunta a las URLs de stream como ?pot=).
    _streamingPot = await _mint(sessionId);
    _sessionId = sessionId;
    debugPrint('[PoToken] Inicializado; integrity token expira en ${integrity.seconds}s');
  }

  Future<dynamic> _postJnn(String url, List<dynamic> payload) async {
    final response = await _jnnDio.post(url, data: jsonEncode(payload));
    final data = response.data;
    if (data is String) return jsonDecode(data);
    return data;
  }

  // ------------------------------------------------------------------
  // Acuñar un token por identifier (videoId o sessionId)
  // ------------------------------------------------------------------
  Future<String> _mint(String identifier) async {
    final controller = _controller;
    if (controller == null) throw const PoTokenException('WebView no adjunto');

    final reqId = ++_nextReqId;
    final completer = Completer<String>();
    _pendingMints[reqId] = completer;

    await controller.runJavaScript('''
try {
  var u8Identifier = ${_stringToU8(identifier)};
  obtainPoToken(u8Identifier).then(function(poTokenU8) {
    $_jsInterface.postMessage(JSON.stringify({event:'po_token', reqId: $reqId, u8: poTokenU8.join(',')}));
  }).catch(function(error) {
    $_jsInterface.postMessage(JSON.stringify({event:'po_token_error', reqId: $reqId, message: String(error)}));
  });
} catch (error) {
  $_jsInterface.postMessage(JSON.stringify({event:'po_token_error', reqId: $reqId, message: String(error)}));
}
''');

    try {
      return await completer.future.timeout(_generateTimeout);
    } on TimeoutException {
      _pendingMints.remove(reqId);
      throw const PoTokenException('poToken generation timed out');
    } catch (e) {
      _pendingMints.remove(reqId);
      rethrow;
    }
  }

  // ------------------------------------------------------------------
  // Mensajes JS → Dart (JavaScript channel)
  // ------------------------------------------------------------------
  void handleJsMessage(String raw) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (data['event']) {
      case 'loaded':
        _completeIfPending(_loadedCompleter);
        break;
      case 'botguard_done':
        _botguardResponse = data['response']?.toString();
        _completeIfPending(_botguardCompleter);
        break;
      case 'minter_created':
        _completeIfPending(_minterCompleter);
        break;
      case 'error':
        final message = data['message']?.toString() ?? 'Error JS desconocido';
        _consecutiveErrors++;
        if (_consecutiveErrors >= _maxConsecutiveErrors) {
          _disabledUntil = DateTime.now().add(_circuitBreakerDuration);
          debugPrint('[PoToken] Pausa temporal por errores consecutivos: $message');
        } else {
          debugPrint('[PoToken] Error en WebView ($_consecutiveErrors/$_maxConsecutiveErrors): $message');
        }
        final error = PoTokenException(message);
        _failPendingInit(error);
        break;
      case 'po_token':
        final reqId = data['reqId'];
        if (reqId is num) {
          final completer = _pendingMints.remove(reqId.toInt());
          if (completer != null && !completer.isCompleted) {
            completer.complete(data['u8']?.toString() ?? '');
          }
        }
        break;
      case 'po_token_error':
        final reqId = data['reqId'];
        if (reqId is num) {
          final completer = _pendingMints.remove(reqId.toInt());
          if (completer != null && !completer.isCompleted) {
            completer.completeError(
              PoTokenException(data['message']?.toString() ?? 'Error acuñando poToken'),
            );
          }
        }
        break;
    }
  }

  void _completeIfPending(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _failPendingInit(Object error) {
    for (final completer in [_loadedCompleter, _botguardCompleter, _minterCompleter]) {
      if (completer != null && !completer.isCompleted) completer.completeError(error);
    }
  }

  // ------------------------------------------------------------------
  // Helpers (port de JavaScriptUtil.kt)
  // ------------------------------------------------------------------

  /// Extrae del challenge crudo de `/jnn/v1/Create` los campos que necesita
  /// `runBotGuard`. Soporta respuesta "descrambleada" (+97 por byte).
  static dynamic _parseChallengeData(dynamic raw) {
    final json = raw is String ? jsonDecode(raw) : raw;
    final scrambled = json as List;

    late final List challengeData;
    if (scrambled.length > 1 && scrambled[1] is String) {
      challengeData = jsonDecode(_descramble(scrambled[1] as String)) as List;
    } else {
      challengeData = scrambled[0] as List;
    }

    return {
      'messageId': challengeData[0],
      'interpreterJavascript': {
        'privateDoNotAccessOrElseSafeScriptWrappedValue': _firstStringIn(challengeData[1]),
        'privateDoNotAccessOrElseTrustedResourceUrlWrappedValue': _firstStringIn(challengeData[2]),
      },
      'interpreterHash': challengeData[3],
      'program': challengeData[4],
      'globalName': challengeData[5],
      'clientExperimentsStateBlob': challengeData[7],
    };
  }

  /// `[integrityTokenBase64, expirationSeconds]` → token listo para JS.
  static _IntegrityTokenData _parseIntegrityTokenData(dynamic raw) {
    final json = raw is String ? jsonDecode(raw) : raw;
    final list = json as List;
    final tokenJs = _base64ToUint8Js(list[0] as String);
    final seconds = (list[1] as num).toInt();
    return _IntegrityTokenData(tokenJs: tokenJs, seconds: seconds);
  }

  static dynamic _firstStringIn(dynamic node) {
    if (node is List) {
      for (final item in node) {
        if (item is String) return item;
      }
    }
    return null;
  }

  static String _descramble(String scrambled) {
    return String.fromCharCodes(_base64ToBytes(scrambled).map((b) => (b + 97) & 0xFF));
  }

  static String _stringToU8(String value) {
    return 'new Uint8Array([${utf8.encode(value).join(',')}])';
  }

  static String _base64ToUint8Js(String base64) {
    return 'new Uint8Array([${_base64ToBytes(base64).join(',')}])';
  }

  static List<int> _base64ToBytes(String base64) {
    var normalized = base64.replaceAll('-', '+').replaceAll('_', '/').replaceAll('.', '=');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    try {
      return base64Decode(normalized);
    } catch (_) {
      throw const PoTokenException('Cannot base64 decode');
    }
  }
}

class _IntegrityTokenData {
  final String tokenJs;
  final int seconds;
  const _IntegrityTokenData({required this.tokenJs, required this.seconds});
}

/// Widget invisible que aloja el WebView usado por [PoTokenGenerator].
/// Debe montarse una sola vez en el árbol de la app (ver `app.dart`).
class PoTokenWebViewHost extends StatefulWidget {
  const PoTokenWebViewHost({super.key});

  @override
  State<PoTokenWebViewHost> createState() => _PoTokenWebViewHostState();
}

class _PoTokenWebViewHostState extends State<PoTokenWebViewHost> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(PoTokenGenerator.userAgent)
        ..setBackgroundColor(const Color(0x00000000))
        // Nada debe navegar fuera del HTML local cargado.
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.prevent,
        ))
        ..addJavaScriptChannel(
          'PoTokenWebView',
          onMessageReceived: (message) {
            PoTokenGenerator.instance.handleJsMessage(message.message);
          },
        );

      _controller = controller;
      PoTokenGenerator.instance.attach(controller);
    } catch (e) {
      debugPrint('[PoToken] WebView no disponible en este dispositivo: $e');
      _controller = null;
    }
  }

  @override
  void dispose() {
    PoTokenGenerator.instance.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    // WebView "visible" pero fuera de pantalla: algunos dispositivos Android
    // no ejecutan JS/timers en views con Visibility(visible:false); con
    // posición off-screen sí funciona y el usuario nunca lo ve.
    return Positioned(
      left: -2000,
      top: -2000,
      width: 10,
      height: 10,
      child: Opacity(
        opacity: 0.01,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
