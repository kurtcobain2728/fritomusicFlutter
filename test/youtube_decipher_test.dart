import 'package:flutter_test/flutter_test.dart';
import 'package:musicfrito_flutter/data/network/yt/youtube_decipher_service.dart';

void main() {
  group('YouTubeDecipherService', () {
    test('decipherFormat extrae formato con URL directa', () {
      final service = YouTubeDecipherService.instance;
      final format = {
        'itag': 140,
        'mimeType': 'audio/mp4; codecs="mp4a.40.2"',
        'url': 'https://rr1---sn.googlevideo.com/videoplayback?expire=123',
      };
      final result = service.decipherFormat(format, poToken: 'test_pot');
      expect(result, contains('https://rr1---sn.googlevideo.com/videoplayback?expire=123'));
      expect(result, contains('pot=test_pot'));
    });

    test('decipherFormat desempaqueta formato con signatureCipher', () {
      final service = YouTubeDecipherService.instance;
      final cipherStr = 'url=https%3A%2F%2Frr2---sn.googlevideo.com%2Fvideoplayback%3Fexpire%3D456&s=SIG12345&sp=sig';
      final format = {
        'itag': 251,
        'mimeType': 'audio/webm; codecs="opus"',
        'signatureCipher': cipherStr,
      };
      final result = service.decipherFormat(format);
      expect(result, isNotNull);
      expect(result, contains('https://rr2---sn.googlevideo.com/videoplayback?expire=456'));
      expect(result, contains('sig=SIG12345'));
    });

    test('extractBestAudioStream selecciona el formato de mayor bitrate', () {
      final service = YouTubeDecipherService.instance;
      final streamingData = {
        'adaptiveFormats': [
          {
            'itag': 249,
            'mimeType': 'audio/webm; codecs="opus"',
            'bitrate': 50000,
            'url': 'https://stream.invalid/50k',
          },
          {
            'itag': 251,
            'mimeType': 'audio/webm; codecs="opus"',
            'bitrate': 160000,
            'url': 'https://stream.invalid/160k',
          },
        ]
      };
      final best = service.extractBestAudioStream(streamingData);
      expect(best, equals('https://stream.invalid/160k'));
    });
  });
}
