import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/core/butunluk/butunluk_kaniti.dart';
import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';
import 'package:tayfam/core/butunluk/kanal_butunluk_saglayici.dart';

/// İsteği kaydeden, sonucu testin belirlediği sağlayıcı.
final class _SahteSaglayici implements ButunlukSaglayici {
  _SahteSaglayici(this.sonuc);

  final Future<String?> Function() sonuc;
  final List<String> ozetler = [];

  @override
  Future<void> hazirla() async {}

  @override
  Future<String?> token(String istekOzeti) {
    ozetler.add(istekOzeti);
    return sonuc();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bağlama değeri (Tayfam-Api ADR-0022 §2)', () {
    // Vektörler sunucunun testleriyle aynıdır
    // (internal/identity/app/integrity/integrity_test.go).
    test('giriş: sunucu vektörü', () {
      expect(
        girisBaglamasi('n'),
        'RQikIoUgcNuXXdqIefpw7eiSKtDfUXbWostlt13jJbM',
      );
    });

    test('yenileme: sunucu vektörü (iç özet ham bayt)', () {
      expect(
        yenilemeBaglamasi('abc'),
        'MgBlpZgH50sh41IuBxeaKNHLWdypFMK37NLLu0VAWSg',
      );
    });

    test('ek vektörler (Python hashlib ile)', () {
      expect(
        girisBaglamasi('sahte-nonce-0123456789abcdef'),
        'XgAl8NCvmcxurt0x7ZlP9So9xkf8e7fc5EYE_EKp8UU',
      );
      expect(
        yenilemeBaglamasi('yenileme-1'),
        'd9ilBBP8lOsD-WD3M1zTvvS7a0PqC-zDLeeEQ8_uMek',
      );
    });

    test('dolgusuz base64url, 43 karakter; giriş ve yenileme ayrışır', () {
      final bicim = RegExp(r'^[A-Za-z0-9_-]{43}$');
      expect(bicim.hasMatch(girisBaglamasi('x')), isTrue);
      expect(bicim.hasMatch(yenilemeBaglamasi('x')), isTrue);
      expect(girisBaglamasi('n'), isNot(yenilemeBaglamasi('n')));
    });

    test('yenileme token\'ı sonuçta görünmez', () {
      expect(yenilemeBaglamasi('yenileme-1'), isNot(contains('yenileme')));
    });
  });

  group('ButunlukKaniti', () {
    test('giriş kanıtı nonce\'un bağlama değeriyle istenir', () async {
      final saglayici = _SahteSaglayici(() async => 'kanit');
      final kanit = ButunlukKaniti(saglayici, gunluk: (_) {});
      expect(await kanit.giris('n'), 'kanit');
      expect(saglayici.ozetler, [girisBaglamasi('n')]);
    });

    test('yenileme kanıtına token değil özetin özeti gider', () async {
      final saglayici = _SahteSaglayici(() async => 'kanit');
      final kanit = ButunlukKaniti(saglayici, gunluk: (_) {});
      expect(await kanit.yenileme('yenileme-1'), 'kanit');
      expect(saglayici.ozetler, [yenilemeBaglamasi('yenileme-1')]);
    });

    test('platform yoksa null', () async {
      final kanit = ButunlukKaniti(const OlmayanButunlukSaglayici());
      expect(await kanit.giris('n'), isNull);
      expect(await kanit.yenileme('t'), isNull);
    });

    test('hata türü günlüğe yazılır, null döner', () async {
      final gunluk = <String>[];
      final kanit = ButunlukKaniti(
        _SahteSaglayici(
          () async => throw const ButunlukHatasi(ButunlukHatasiTuru.ag),
        ),
        gunluk: gunluk.add,
      );
      expect(await kanit.yenileme('yenileme-1'), isNull);
      expect(gunluk, ['bütünlük: ag']);
    });

    test('zaman aşımında null; günlükte değer yok', () async {
      final gunluk = <String>[];
      final asili = Completer<String?>();
      final kanit = ButunlukKaniti(
        _SahteSaglayici(() => asili.future),
        zamanAsimi: const Duration(milliseconds: 10),
        gunluk: gunluk.add,
      );
      expect(await kanit.yenileme('yenileme-1'), isNull);
      expect(gunluk, ['bütünlük: zaman aşımı']);
      for (final satir in gunluk) {
        expect(satir, isNot(contains('yenileme-1')));
        expect(satir, isNot(contains(yenilemeBaglamasi('yenileme-1'))));
      }
    });

    test('varsayılan zaman aşımı 5 saniye', () {
      expect(
        ButunlukKaniti(const OlmayanButunlukSaglayici()).zamanAsimi,
        const Duration(seconds: 5),
      );
    });

    test('sözleşme sınırını aşan ya da boş token gönderilmez', () async {
      for (final token in ['', 'a' * (ButunlukKaniti.enUzunToken + 1)]) {
        final kanit = ButunlukKaniti(
          _SahteSaglayici(() async => token),
          gunluk: (_) {},
        );
        expect(await kanit.giris('n'), isNull);
      }
    });
  });

  group('KanalButunlukSaglayici', () {
    const kanal = MethodChannel('test/butunluk');
    final mesajci =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final cagrilar = <MethodCall>[];

    void yanitla(Object? Function(MethodCall cagri) yanit) {
      mesajci.setMockMethodCallHandler(kanal, (cagri) async {
        cagrilar.add(cagri);
        return yanit(cagri);
      });
    }

    setUp(cagrilar.clear);
    tearDown(() => mesajci.setMockMethodCallHandler(kanal, null));

    test('kanal adı Kotlin köprüsüyle aynı', () {
      expect(KanalButunlukSaglayici.kanalAdi, 'tayfam/butunluk');
      expect(butunlukBulutProjeNumarasi, 73439258394);
    });

    test('token: proje numarası ve istek özeti gider', () async {
      yanitla((_) => 'kanit');
      final saglayici = KanalButunlukSaglayici(kanal: kanal, projeNumarasi: 7);
      expect(await saglayici.token('ozet'), 'kanit');
      expect(cagrilar.single.method, 'token');
      expect(cagrilar.single.arguments, {'proje': 7, 'istekOzeti': 'ozet'});
    });

    test('hazırla: hata yutulur', () async {
      yanitla((_) => throw PlatformException(code: 'playYok'));
      final saglayici = KanalButunlukSaglayici(kanal: kanal, projeNumarasi: 7);
      await saglayici.hazirla();
      expect(cagrilar.single.method, 'hazirla');
      expect(cagrilar.single.arguments, {'proje': 7});
    });

    test('hata kodları türe eşlenir', () async {
      for (final tur in ButunlukHatasiTuru.values) {
        yanitla((_) => throw PlatformException(code: tur.name));
        final saglayici = KanalButunlukSaglayici(kanal: kanal);
        await expectLater(
          saglayici.token('ozet'),
          throwsA(isA<ButunlukHatasi>().having((h) => h.tur, 'tur', tur)),
        );
      }
    });

    test('tanınmayan kod ve boş sonuç bilinmeyen', () async {
      final saglayici = KanalButunlukSaglayici(kanal: kanal);
      yanitla((_) => throw PlatformException(code: 'baska'));
      await expectLater(
        saglayici.token('ozet'),
        throwsA(
          isA<ButunlukHatasi>().having(
            (h) => h.tur,
            'tur',
            ButunlukHatasiTuru.bilinmeyen,
          ),
        ),
      );
      yanitla((_) => '');
      await expectLater(
        saglayici.token('ozet'),
        throwsA(isA<ButunlukHatasi>()),
      );
    });

    test('köprü yoksa null', () async {
      final saglayici = KanalButunlukSaglayici(kanal: kanal);
      expect(await saglayici.token('ozet'), isNull);
      await saglayici.hazirla();
    });

    test('hata metninde değer yok', () {
      expect(
        const ButunlukHatasi(ButunlukHatasiTuru.kota).toString(),
        'ButunlukHatasi(kota)',
      );
    });
  });
}
