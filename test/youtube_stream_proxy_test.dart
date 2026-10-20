import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:musicfrito_flutter/services/youtube_stream_proxy.dart';

void main() {
  group('YouTubeStreamProxy Tests', () {
    final proxy = YouTubeStreamProxy.instance;

    tearDown(() async {
      await proxy.stop();
    });

    test('ensureInitialized e inicialización de loopback server', () async {
      await proxy.ensureInitialized();
      final uri = await proxy.registerStream(
        streamUrl: 'https://rr1---sn-oxun-xx8e.googlevideo.com/videoplayback?expire=123&clen=1048576&mime=audio%2Fmp4',
        userAgent: 'test-user-agent',
      );

      expect(uri.host, equals('127.0.0.1'));
      expect(uri.path, startsWith('/stream/'));
      expect(uri.port, isPositive);
    });

    test('HEAD request responde con cabeceras correctas de 206/Partial Content y clen', () async {
      await proxy.ensureInitialized();
      const dummyUrl = 'https://rr1---sn-oxun-xx8e.googlevideo.com/videoplayback?expire=123&clen=5242880&mime=audio%2Fmp4';
      final localUri = await proxy.registerStream(
        streamUrl: dummyUrl,
        userAgent: 'test-agent',
      );

      final client = HttpClient();
      final req = await client.openUrl('HEAD', localUri);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-1000');
      final res = await req.close();

      expect(res.statusCode, equals(HttpStatus.partialContent));
      expect(res.headers.value(HttpHeaders.contentTypeHeader), equals('audio/mp4'));
      expect(res.headers.value(HttpHeaders.acceptRangesHeader), equals('bytes'));
      expect(res.headers.value(HttpHeaders.contentRangeHeader), equals('bytes 0-1000/5242880'));
      expect(res.headers.value(HttpHeaders.contentLengthHeader), equals('1001'));
      await res.drain();
      client.close();
    });
  });
}
