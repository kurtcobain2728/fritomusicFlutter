import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repository/youtube_login_manager.dart';

class YouTubeLoginScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLoginSuccess;
  final AppColors appColors;

  const YouTubeLoginScreen({
    super.key,
    required this.onBack,
    required this.onLoginSuccess,
    required this.appColors,
  });

  @override
  State<YouTubeLoginScreen> createState() => _YouTubeLoginScreenState();
}

class _YouTubeLoginScreenState extends State<YouTubeLoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _status = 'Cargando acceso a Google...';
  bool _hasSavedLogin = false;

  static const MethodChannel _platformChannel = MethodChannel(AppConstants.platformChannel);

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (_hasSavedLogin) return;
            setState(() {
              _isLoading = true;
              if (url.contains('music.youtube.com')) {
                _status = 'Obteniendo sesión de YT...';
              } else if (url.contains('accounts.google.com')) {
                _status = 'Iniciando sesión con tu cuenta Google...';
              }
            });
          },
          onPageFinished: (url) async {
            if (_hasSavedLogin) return;
            setState(() => _isLoading = false);

            if (url.contains('music.youtube.com') || url.contains('youtube.com')) {
              await _checkAndExtractLogin(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(
        'https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Des%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F',
      ));
  }

  Future<void> _checkAndExtractLogin(String currentUrl) async {
    if (_hasSavedLogin) return;

    try {
      // 1. Obtener cookies nativas (incluye HttpOnly: SAPISID, SSID, etc.)
      final cookies = await _platformChannel.invokeMethod<String>(
        'getCookies',
        {'url': 'https://music.youtube.com'},
      );

      final fullCookie = cookies ?? '';
      if (fullCookie.contains('SAPISID') || fullCookie.contains('__Secure-3PAPISID')) {
        _hasSavedLogin = true;
        setState(() {
          _isLoading = true;
          _status = '¡Cuenta detectada! Conectando...';
        });

        // 2. Extraer visitorData y dataSyncId desde el config de YouTube Music
        String visitorData = '';
        String dataSyncId = '';
        try {
          final res = await _controller.runJavaScriptReturningResult('''
            (function() {
              try {
                var v = (window.yt && window.yt.config_) ? (window.yt.config_.VISITOR_DATA || '') : '';
                var d = (window.yt && window.yt.config_) ? (window.yt.config_.DATASYNC_ID || '') : '';
                return JSON.stringify({visitorData: v, dataSyncId: d});
              } catch(e) {
                return JSON.stringify({visitorData: '', dataSyncId: ''});
              }
            })()
          ''');

          if (res is String && res.isNotEmpty) {
            final unquoted = res.startsWith('"') && res.endsWith('"')
                ? jsonDecode(res) as String
                : res;
            final map = jsonDecode(unquoted) as Map<String, dynamic>;
            visitorData = map['visitorData'] ?? '';
            dataSyncId = map['dataSyncId'] ?? '';
          }
        } catch (_) {}

        await YouTubeLoginManager.instance.saveLogin(
          cookie: fullCookie,
          visitorData: visitorData,
          dataSyncId: dataSyncId,
        );

        await YouTubeLoginManager.instance.fetchAccountInfo();

        if (mounted) {
          widget.onLoginSuccess();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.appColors;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBack,
        ),
        title: const Text('Iniciar sesión en YT', style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: colors.accent),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
