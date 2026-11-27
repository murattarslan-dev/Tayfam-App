import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/push/firebase_push_platformu.dart';
import 'package:tayfam/core/push/push_platformu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirebasePushPlatformu yerel kanal (istemci ADR-0019, iOS notu)', () {
    late List<String> cagrilar;

    setUp(() {
      cagrilar = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bildirimKanali, (call) async {
            cagrilar.add(call.method);
            return call.method == 'ayarlariAc' ? true : null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bildirimKanali, null);
    });

    for (final hedef in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('${hedef.name}: ayarlar yerel kanaldan açılır', () async {
        debugDefaultTargetPlatformOverride = hedef;
        expect(await FirebasePushPlatformu().ayarlariAc(), isTrue);
        expect(cagrilar, ['ayarlariAc']);
      });
    }

    test('başka platformda kanal çağrılmaz', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(await FirebasePushPlatformu().ayarlariAc(), isFalse);
      expect(cagrilar, isEmpty);
    });

    test('iOS: bildirim kanalları kurulmaz (Android\'e özgü)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await FirebasePushPlatformu().kanallariKur(const [
        BildirimKanali(
          id: 'tayfam_general',
          ad: 'Genel',
          aciklama: 'Genel bildirimler',
          yuksekOncelik: false,
        ),
      ]);
      expect(cagrilar, isEmpty);
    });

    test('yerel taraf yoksa ayarlar açılamaz, hata fırlamaz', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(bildirimKanali, null);
      expect(await FirebasePushPlatformu().ayarlariAc(), isFalse);
    });
  });
}
