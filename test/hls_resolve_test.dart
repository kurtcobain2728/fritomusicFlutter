import 'package:flutter_test/flutter_test.dart';
import 'package:musicfrito_flutter/data/network/yt/stream_client_utils.dart';

void main() {
  group('HLS Detection and Headers', () {
    test('isHlsUrl detecta URLs HLS correctamente', () {
      expect(StreamClientUtils.isHlsUrl('https://manifest.googlevideo.com/api/manifest/hls_variant/expire/123/id/abc'), isTrue);
      expect(StreamClientUtils.isHlsUrl('https://example.com/stream.m3u8'), isTrue);
      expect(StreamClientUtils.isHlsUrl('https://rr1---sn.googlevideo.com/videoplayback?expire=123'), isFalse);
    });

    test('resolveRequestProfile para HLS usa safariUserAgent', () {
      final profile = StreamClientUtils.resolveRequestProfile('https://manifest.googlevideo.com/api/manifest/hls_variant/expire/123');
      expect(profile.userAgent, equals(StreamClientUtils.safariUserAgent));
      expect(profile.requiresPlaybackProbeRanges, isFalse);
    });
  });
}
