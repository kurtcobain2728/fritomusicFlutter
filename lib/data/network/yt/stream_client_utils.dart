class StreamRequestProfile {
  final String requestedClientName;
  final String requestedClientVersion;
  final String userAgent;
  final String? origin;
  final String? referer;
  final bool requiresPlaybackProbeRanges;

  const StreamRequestProfile({
    required this.requestedClientName,
    required this.requestedClientVersion,
    required this.userAgent,
    this.origin,
    this.referer,
    this.requiresPlaybackProbeRanges = false,
  });

  Map<String, String> get headers {
    final map = <String, String>{
      'User-Agent': userAgent,
    };
    if (origin != null) map['Origin'] = origin!;
    if (referer != null) map['Referer'] = referer!;
    return map;
  }
}

class StreamClientUtils {
  static const String safariUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.5 Safari/605.1.15,gzip(gfe)';

  static bool isHlsUrl(String url) {
    return url.contains('/manifest/hls_') || url.contains('.m3u8');
  }

  static bool isYouTubeMediaHost(String host) {
    return host.endsWith('googlevideo.com') ||
        host.endsWith('googleusercontent.com') ||
        host.endsWith('youtube.com') ||
        host.endsWith('youtube-nocookie.com') ||
        host.endsWith('ytimg.com');
  }

  /// Adjunta el PoToken de streaming (`?pot=`) a una URL de googlevideo
  /// obtenida del cliente web (WEB/WEB_REMIX). Sin él, el cliente web
  /// rechaza la reproducción (403) o entrega una URL de vida muy corta.
  static String appendPoToken(String url, String poToken) {
    if (url.contains('pot=')) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}pot=$poToken';
  }

  static StreamRequestProfile resolveRequestProfile(String url) {
    try {
      if (isHlsUrl(url)) {
        return const StreamRequestProfile(
          requestedClientName: 'WEB',
          requestedClientVersion: '2.20260708.00.00',
          userAgent: safariUserAgent,
          origin: 'https://www.youtube.com',
          referer: 'https://www.youtube.com/',
          requiresPlaybackProbeRanges: false,
        );
      }

      final uri = Uri.parse(url);
      final c = uri.queryParameters['c']?.toUpperCase() ?? 'IOS';

      if (c.startsWith('ANDROID_VR')) {
        return const StreamRequestProfile(
          requestedClientName: 'ANDROID_VR',
          requestedClientVersion: '1.43.32',
          userAgent:
              'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
        );
      } else if (c.startsWith('IOS')) {
        return const StreamRequestProfile(
          requestedClientName: 'IOS',
          requestedClientVersion: '21.03.1',
          userAgent: 'com.google.ios.youtube/21.03.1 (iPhone16,2; U; CPU iOS 18_2 like Mac OS X;)',
        );
      } else if (c.startsWith('TVHTML5')) {
        return const StreamRequestProfile(
          requestedClientName: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
          requestedClientVersion: '2.0',
          userAgent:
              'Mozilla/5.0 (PlayStation; PlayStation 4/12.02) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15',
          origin: 'https://www.youtube.com',
          referer: 'https://www.youtube.com/tv',
          requiresPlaybackProbeRanges: true,
        );
      } else if (c.startsWith('WEB')) {
        return const StreamRequestProfile(
          requestedClientName: 'WEB_REMIX',
          requestedClientVersion: '1.20260213.01.00',
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0',
          origin: 'https://music.youtube.com',
          referer: 'https://music.youtube.com/',
          requiresPlaybackProbeRanges: true,
        );
      } else {
        return const StreamRequestProfile(
          requestedClientName: 'ANDROID_VR',
          requestedClientVersion: '1.43.32',
          userAgent:
              'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
        );
      }
    } catch (_) {
      return const StreamRequestProfile(
        requestedClientName: 'ANDROID_VR',
        requestedClientVersion: '1.43.32',
        userAgent:
            'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
      );
    }
  }
}
