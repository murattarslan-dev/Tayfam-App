import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/depo/e2e_anahtar_deposu.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';

/// Her çağrıda platform hatası veren güvenli depo (çözülemeyen Keystore
/// kaydı); silme çağrıları sayılır.
final class _BozukDepo extends Fake implements FlutterSecureStorage {
  int silme = 0;
  int hepsiniSilme = 0;

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'cozulemedi');

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'cozulemedi');

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw PlatformException(code: 'yazilamadi');

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    silme++;
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    hepsiniSilme++;
  }
}

Uint8List _b(List<int> l) => Uint8List.fromList(l);

void main() {
  group('GuvenliE2eAnahtarDeposu', () {
    test('çözülemeyen depo silinir ve boş döner; istisna sızmaz', () async {
      final bozuk = _BozukDepo();
      final depo = GuvenliE2eAnahtarDeposu(bozuk);
      expect(await depo.hepsi(), isEmpty);
      expect(bozuk.hepsiniSilme, 1);
      expect(await depo.oku('e2e.kimlik'), isNull);
      expect(bozuk.silme, 1);
      expect(await depo.yaz('e2e.kimlik', 'x'), isFalse);
    });
  });

  group('E2eDeposu', () {
    test('kayıtlar yazılır, yeniden yüklenince okunur', () async {
      final ham = BellekE2eAnahtarDeposu();
      final depo = E2eDeposu(ham);
      await depo.yukle();
      await depo.kimlikYaz(
        DepoKimligi(
          kayit: _b([1, 2]),
          acikAnahtar: _b([5, 3]),
          kayitKimligi: 7,
        ),
      );
      await depo.cihazYaz(const DepoCihazi(id: 'c1', no: 2));
      await depo.oturumYaz(
        'c9',
        DepoOturumu(cihazNo: 3, kayitKimligi: 11, kayit: _b([9])),
      );
      await depo.gorulduYaz('z1');

      final yeni = E2eDeposu(ham);
      await yeni.yukle();
      expect(yeni.kimlik?.kayitKimligi, 7);
      expect(yeni.kimlik?.acikAnahtar, [5, 3]);
      expect(yeni.cihaz?.id, 'c1');
      expect(yeni.oturum('c9')?.kayit, [9]);
      expect(yeni.gorulenZarflar, ['z1']);
      expect(ham.kayitlar.keys, everyElement(startsWith('e2e.')));
    });

    test('bozuk kayıt yok sayılır', () async {
      final depo = E2eDeposu(
        BellekE2eAnahtarDeposu({
          E2eDeposu.kimlikAnahtari: '{bozuk',
          E2eDeposu.oturumAnahtari('c1'): '{"no":"x"}',
        }),
      );
      await depo.yukle();
      expect(depo.kimlik, isNull);
      expect(depo.oturum('c1'), isNull);
    });

    test('yazılamazsa false; bellek değişmez', () async {
      final ham = BellekE2eAnahtarDeposu()..hataVer = true;
      final depo = E2eDeposu(ham);
      await depo.yukle();
      expect(await depo.cihazYaz(const DepoCihazi(id: 'c', no: 1)), isFalse);
      expect(depo.cihaz, isNull);
    });

    test('temizle: bütün kayıtlar ve bellek silinir', () async {
      final ham = BellekE2eAnahtarDeposu();
      final depo = E2eDeposu(ham);
      await depo.yukle();
      await depo.cihazYaz(const DepoCihazi(id: 'c', no: 1));
      await depo.temizle();
      expect(ham.kayitlar, isEmpty);
      expect(depo.cihaz, isNull);
    });

    test('görülen zarflardan son 500 tutulur', () async {
      final depo = E2eDeposu(BellekE2eAnahtarDeposu());
      await depo.yukle();
      for (var i = 0; i < E2eDeposu.gorulenEnCok + 5; i++) {
        await depo.gorulduYaz('z$i');
      }
      expect(depo.gorulenZarflar.length, E2eDeposu.gorulenEnCok);
      expect(depo.gorulenZarflar.first, 'z5');
    });

    test('karşı cihazı silmek oturumu ve güvenilen kimliği siler', () async {
      final depo = E2eDeposu(BellekE2eAnahtarDeposu());
      await depo.yukle();
      await depo.oturumYaz(
        'c',
        DepoOturumu(cihazNo: 1, kayitKimligi: 1, kayit: _b([1])),
      );
      await depo.karsiKimlikYaz(
        'c',
        DepoKarsiKimlik(acikAnahtar: _b([5]), kullaniciId: 'k'),
      );
      await depo.karsiCihaziSil('c');
      expect(depo.oturum('c'), isNull);
      expect(depo.karsiKimlik('c'), isNull);
    });
  });
}
