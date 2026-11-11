import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tayfam/core/e2e/signal/desteklenmeyen_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/kanal_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru_provider.dart';

Uint8List _b(List<int> l) => Uint8List.fromList(l);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kanal = MethodChannel(KanalSignalMotoru.kanalAdi);
  late List<MethodCall> cagrilar;
  late Object? Function(MethodCall) cevap;

  setUp(() {
    cagrilar = [];
    cevap = (_) => <Object?, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, (cagri) async {
          cagrilar.add(cagri);
          return cevap(cagri);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, null);
  });

  Map<Object?, Object?> arg() =>
      cagrilar.single.arguments as Map<Object?, Object?>;

  const yerel = SignalAdresi(
    ad: '8f1c2b3a-4d5e-4f60-8a7b-9c0d1e2f3a4b',
    cihazNo: 1,
  );
  const karsi = SignalAdresi(
    ad: '1a2b3c4d-5e6f-4071-8293-a4b5c6d7e8f9',
    cihazNo: 2,
  );

  group('KanalSignalMotoru', () {
    test('kimlikUret dönüşü eşlenir', () async {
      cevap = (_) => {
        'kayit': _b([1, 2]),
        'acik': _b([5, 6]),
        'kayitKimligi': 42,
      };
      final k = await KanalSignalMotoru().kimlikUret();
      expect(cagrilar.single.method, 'kimlikUret');
      expect(k.kayit, [1, 2]);
      expect(k.acikAnahtar, [5, 6]);
      expect(k.kayitKimligi, 42);
    });

    test('onAnahtarUret listeyi eşler', () async {
      cevap = (_) => {
        'anahtarlar': [
          {
            'id': 9,
            'kayit': _b([1]),
            'acik': _b([2]),
          },
          {
            'id': 10,
            'kayit': _b([3]),
            'acik': _b([4]),
          },
        ],
      };
      final l = await KanalSignalMotoru().onAnahtarUret(9, 2);
      expect(arg(), {'baslangicId': 9, 'adet': 2});
      expect(l.map((e) => e.id), [9, 10]);
      expect(l.last.acikAnahtar, [4]);
    });

    test('imzalı ve Kyber ön anahtar üretimi', () async {
      cevap = (c) => {
        'id': 3,
        'kayit': _b([1]),
        'acik': _b([2]),
        'imza': _b([3]),
        if (c.method == 'imzaliOnAnahtarUret') 'zaman': 1700000000000,
      };
      final m = KanalSignalMotoru();
      final i = await m.imzaliOnAnahtarUret(_b([7]), 3);
      expect(cagrilar.last.method, 'imzaliOnAnahtarUret');
      expect(i.zaman, 1700000000000);
      expect(i.imza, [3]);
      final k = await m.kyberOnAnahtarUret(_b([7]), 3);
      expect(cagrilar.last.method, 'kyberOnAnahtarUret');
      expect(
        cagrilar.last.arguments,
        {
          'kimlik': [7],
          'id': 3,
        },
      );
      expect(k.acikAnahtar, [2]);
    });

    test('paketIsle bütün paket alanlarını ve adresleri gönderir', () async {
      cevap = (_) => {
        'oturum': _b([9]),
      };
      final oturum = await KanalSignalMotoru().paketIsle(
        kimlik: _b([1]),
        kayitKimligi: 77,
        yerelAdres: yerel,
        adres: karsi,
        paket: OnAnahtarPaketi(
          kayitKimligi: 5,
          cihazNo: 2,
          imzaliOnAnahtarId: 7,
          imzaliOnAnahtar: _b([2]),
          imzaliOnAnahtarImzasi: _b([3]),
          kimlikAnahtari: _b([4]),
          kyberOnAnahtarId: 50,
          kyberOnAnahtar: _b([5]),
          kyberOnAnahtarImzasi: _b([6]),
        ),
      );
      expect(oturum, [9]);
      final a = arg();
      expect(a['yerelAd'], yerel.ad);
      expect(a['yerelCihaz'], 1);
      expect(a['ad'], karsi.ad);
      expect(a['cihaz'], 2);
      expect(a['kayitKimligi'], 77);
      expect(a['oturum'], isNull);
      final p = a['paket']! as Map<Object?, Object?>;
      expect(p['onAnahtarId'], isNull);
      expect(p['onAnahtar'], isNull);
      expect(p['kyberOnAnahtarId'], 50);
      expect(p['kyberOnAnahtar'], [5]);
      expect(p['imzaliOnAnahtarImzasi'], [3]);
    });

    test('sifrele tür ve yeni oturumu döner', () async {
      cevap = (_) => {
        'tur': 3,
        'sifreli': _b([8]),
        'oturum': _b([9]),
      };
      final s = await KanalSignalMotoru().sifrele(
        kimlik: _b([1]),
        kayitKimligi: 1,
        yerelAdres: yerel,
        adres: karsi,
        oturum: _b([2]),
        duz: _b([3]),
      );
      expect(cagrilar.single.method, 'sifrele');
      expect(arg()['duz'], [3]);
      expect(s.tur, SignalMesajTuru.onAnahtar);
      expect(s.sifreli, [8]);
      expect(s.yeniOturum, [9]);
    });

    test('onAnahtarMesajiIncele isteğe bağlı ön anahtarı eşler', () async {
      cevap = (_) => {
        'onAnahtarId': null,
        'imzaliId': 7,
        'gondericiKimligi': _b([1]),
        'kayitKimligi': 12,
        'tabanAnahtar': _b([2]),
      };
      final b = await KanalSignalMotoru().onAnahtarMesajiIncele(_b([0]));
      expect(b.onAnahtarId, isNull);
      expect(b.imzaliOnAnahtarId, 7);
      expect(b.tabanAnahtar, [2]);
    });

    test('coz Kyber listesini gönderir, kullanımı eşler', () async {
      cevap = (_) => {
        'duz': _b([1]),
        'oturum': _b([2]),
        'onAnahtarId': 100,
        'imzaliId': 7,
        'kyberId': 900,
        'kyberTaban': _b([3]),
        'karsiKimlik': _b([4]),
      };
      final c = await KanalSignalMotoru().coz(
        kimlik: _b([1]),
        kayitKimligi: 1,
        yerelAdres: yerel,
        adres: karsi,
        tur: 3,
        sifreli: _b([5]),
        imzaliOnAnahtar: _b([6]),
        kyberOnAnahtarlari: [
          _b([7]),
          _b([8]),
        ],
      );
      final a = arg();
      expect(a['tur'], 3);
      expect(a['onAnahtar'], isNull);
      expect(a['kyberOnAnahtarlari'], [
        [7],
        [8],
      ]);
      expect(c.duz, [1]);
      expect(c.yeniOturum, [2]);
      expect(c.kullanilanOnAnahtarId, 100);
      expect(c.kullanilanImzaliId, 7);
      expect(c.kullanilanKyberId, 900);
      expect(c.kyberTabanAnahtari, [3]);
      expect(c.karsiKimlik, [4]);
    });

    test('simetrik yapı taşları ve güvenlik kodu', () async {
      final m = KanalSignalMotoru();
      cevap = (_) => {
        'cikti': _b([1, 2]),
      };
      expect(
        await m.hkdf(girdi: _b([1]), bilgi: _b([2]), uzunluk: 2),
        [1, 2],
      );
      expect(arg(), {
        'girdi': [1],
        'tuz': null,
        'bilgi': [2],
        'uzunluk': 2,
      });

      cagrilar.clear();
      cevap = (_) => {'duz': null};
      expect(
        await m.aes256GcmCoz(
          anahtar: _b([1]),
          nonce: _b([2]),
          sifreliVeEtiket: _b([3]),
          aad: _b([4]),
        ),
        isNull,
      );
      expect(cagrilar.single.method, 'aes256GcmCoz');
      expect(arg()['sifreliVeEtiket'], [3]);

      cagrilar.clear();
      expect(
        await m.aesGcmSivCoz(
          anahtar: _b([1]),
          nonce: _b([2]),
          sifreli: _b([3]),
          aad: _b([4]),
        ),
        isNull,
      );

      cevap = (_) => {
        'sifreli': _b([9]),
      };
      expect(
        await m.aesGcmSivSifrele(
          anahtar: _b([1]),
          nonce: _b([2]),
          duz: _b([3]),
          aad: _b([4]),
        ),
        [9],
      );

      cevap = (_) => {'kod': '0' * 60};
      expect(
        await m.guvenlikKodu(
          yerelKimlikAcik: _b([1]),
          yerelTanimlayici: _b([2]),
          karsiKimlikAcik: _b([3]),
          karsiTanimlayici: _b([4]),
        ),
        hasLength(60),
      );
      expect(cagrilar.last.arguments, {
        'yerelKimlik': [1],
        'yerelTanimlayici': [2],
        'karsiKimlik': [3],
        'karsiTanimlayici': [4],
      });
    });

    test('platform hata kodu SignalHatasi türüne eşlenir', () async {
      for (final tur in SignalHatasiTuru.values) {
        cevap = (_) => throw PlatformException(code: tur.name);
        await expectLater(
          KanalSignalMotoru().onAnahtarMesajiIncele(_b([0])),
          throwsA(
            isA<SignalHatasi>().having((h) => h.tur, 'tur', tur),
          ),
        );
      }
      cevap = (_) => throw PlatformException(code: 'baska');
      await expectLater(
        KanalSignalMotoru().kimlikUret(),
        throwsA(
          isA<SignalHatasi>().having(
            (h) => h.tur,
            'tur',
            SignalHatasiTuru.bilinmeyen,
          ),
        ),
      );
    });

    test('beklenmeyen dönüş biçimi bilinmeyen hatadır', () async {
      cevap = (_) => {'kayit': 'metin'};
      await expectLater(
        KanalSignalMotoru().kimlikUret(),
        throwsA(isA<SignalHatasi>()),
      );
      cevap = (_) => null;
      await expectLater(
        KanalSignalMotoru().kimlikUret(),
        throwsA(isA<SignalHatasi>()),
      );
    });

    test('kanal yoksa UnsupportedError', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
      await expectLater(
        KanalSignalMotoru().kimlikUret(),
        throwsUnsupportedError,
      );
    });

    test('SignalHatasi metni yalnızca türü taşır', () {
      expect(
        const SignalHatasi(SignalHatasiTuru.eskiMesaj).toString(),
        'SignalHatasi(eskiMesaj)',
      );
    });
  });

  group('signalMotoruProvider', () {
    test('Android\'de platform kanalı', () {
      final kap = ProviderContainer.test();
      expect(kap.read(signalMotoruProvider), isA<KanalSignalMotoru>());
      expect(kap.read(signalDestekleniyorProvider), isTrue);
    });

    test('iOS\'ta (köprü yazılana kadar) desteklenmiyor', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final kap = ProviderContainer.test();
      final motor = kap.read(signalMotoruProvider);
      expect(motor, isA<DesteklenmeyenSignalMotoru>());
      expect(kap.read(signalDestekleniyorProvider), isFalse);
      await expectLater(motor.kimlikUret(), throwsUnsupportedError);
    });
  });
}
