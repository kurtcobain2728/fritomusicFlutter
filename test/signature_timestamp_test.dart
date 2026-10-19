import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:musicfrito_flutter/data/network/yt/signature_timestamp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  group('SignatureTimestampService', () {
    test('currentSts retorna fallback valido > 15000', () {
      final service = SignatureTimestampService.instance;
      expect(service.currentSts, greaterThan(15000));
    });

    test('getSignatureTimestamp obtiene timestamp dinámico o fallback seguro', () async {
      final service = SignatureTimestampService.instance;
      final sts = await service.getSignatureTimestamp();
      expect(sts, greaterThan(15000));
    });
  });
}
