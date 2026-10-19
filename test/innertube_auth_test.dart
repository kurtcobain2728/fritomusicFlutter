import 'package:flutter_test/flutter_test.dart';
import 'package:musicfrito_flutter/data/network/innertube/innertube_client.dart';

void main() {
  group('InnerTubeClient Auth & Headers', () {
    test('cookieWithPlaybackDefaults inyecta SOCS y PREF', () {
      final client = InnerTubeClient.instance;
      final raw = 'SID=abc123; HSID=def456';
      final defaults = client.cookieWithPlaybackDefaults(raw);
      expect(defaults, contains('SOCS=CAI'));
      expect(defaults, contains('PREF=f2=8000000&hl=en'));
      expect(defaults, contains('SID=abc123'));
    });

    test('buildHeaders genera SAPISIDHASH y headers limpios de sesión', () {
      final client = InnerTubeClient.instance;
      client.cookie = 'SAPISID=test_sapisid; __Secure-1PAPISID=test_sec1; __Secure-3PAPISID=test_sec3';
      
      final headers = client.buildHeadersForTest(withAuth: true);
      
      expect(headers['X-Youtube-Bootstrap-Logged-In'], equals('true'));
      expect(headers['Cookie'], equals(client.cookie));
      expect(headers.containsKey('X-Goog-PageId'), isFalse);
      expect(headers.containsKey('X-Goog-AuthUser'), isFalse);
      expect(headers['Authorization'], isNotNull);
      
      final auth = headers['Authorization']!;
      expect(auth, startsWith('SAPISIDHASH '));
    });
  });
}
