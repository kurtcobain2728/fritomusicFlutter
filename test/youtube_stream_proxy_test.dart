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

    test('Pre-buffering progresivo en RAM entrega datos con servidor HTTP mock', () async {
      // Mock server simulando upstream de googlevideo con soporte de &range=
      final mockUpstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final dummyData = List<int>.generate(256 * 1024, (i) => i % 256); // 256 KB

      mockUpstream.listen((request) async {
        final rangeParam = request.uri.queryParameters['range'];
        int start = 0;
        int end = dummyData.length - 1;
        if (rangeParam != null && rangeParam.contains('-')) {
          final parts = rangeParam.split('-');
          start = int.tryParse(parts[0]) ?? 0;
          end = int.tryParse(parts[1]) ?? end;
        }

        if (start >= dummyData.length) {
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          await request.response.close();
          return;
        }

        final sliceEnd = (end < dummyData.length) ? end : dummyData.length - 1;
        final slice = dummyData.sublist(start, sliceEnd + 1);

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$sliceEnd/${dummyData.length}');
        request.response.headers.set(HttpHeaders.contentLengthHeader, slice.length.toString());
        request.response.add(slice);
        await request.response.close();
      });

      try {
        await proxy.ensureInitialized();
        final upstreamUrl = 'http://127.0.0.1:${mockUpstream.port}/videoplayback?expire=999&clen=${dummyData.length}&mime=audio%2Fmp4';
        final localUri = await proxy.registerStream(
          streamUrl: upstreamUrl,
          userAgent: 'test-agent',
        );

        // Cliente descargando desde el proxy local
        final client = HttpClient();
        final req = await client.getUrl(localUri);
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${dummyData.length - 1}');
        final res = await req.close();

        expect(res.statusCode, equals(HttpStatus.partialContent));
        final receivedBytes = <int>[];
        await for (final chunk in res) {
          receivedBytes.addAll(chunk);
        }

        expect(receivedBytes.length, equals(dummyData.length));
        expect(receivedBytes, equals(dummyData));
        client.close();
      } finally {
        await mockUpstream.close(force: true);
      }
    });
  });
}
