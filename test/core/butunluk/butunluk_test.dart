import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/core/butunluk/butunluk_kaniti.dart';
import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';
import 'package:tayfam/core/butunluk/kanal_butunluk_saglayici.dart';

/// İsteği kaydeden, sonucu testin belirlediği sağlayıcı. [sonuc] bir Play
/// token'ı döner.
final class _SahteSaglayici implements ButunlukSaglayici {
  _SahteSaglayici(this.sonuc);

  final Future<String?> Function() sonuc;
  final List<String> ozetler = [];

  @override
  Future<void> hazirla() async {}

  @override
  Future<IstekKaniti?> kanit(String istekOzeti, ButunlukIstegi istek) async {
    ozetler.add(istekOzeti);
    final token = await sonuc();
    return token == null ? null : IstekKaniti.play(token);
  }

  /// Kaç kez unutulduğu; [unutmaHatasi] verilirse fırlatılır.
  int unutma = 0;
  Exception? unutmaHatasi;

  /// Kaydedilen kanıtlar.
  final List<IstekKaniti> kaydedilen = [];

  @override
  Future<void> kaydet(IstekKaniti kanit) async => kaydedilen.add(kanit);

  @override
  Future<void> unut() async {
    unutma++;
    if (unutmaHatasi case final hata?) throw hata;
  }
}

/// Sabit bir App Attest kanıtı dönen sağlayıcı.
final class _SahteAppAttest implements ButunlukSaglayici {
  _SahteAppAttest(this.kanitDegeri);

  final AppAttestProof kanitDegeri;

  @override
  Future<void> hazirla() async {}

  @override
  Future<IstekKaniti?> kanit(String istekOzeti, ButunlukIstegi istek) async =>
      IstekKaniti.appAttest(kanitDegeri);

  @override
  Future<void> kaydet(IstekKaniti kanit) async {}

  @override
  Future<void> unut() async {}
}

/// 32 baytlık anahtar kimliğinin base64 metni (44 karakter).
final String _anahtar = '${'A' * 43}=';

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
      expect((await kanit.giris('n'))?.integrityToken, 'kanit');
      expect(saglayici.ozetler, [girisBaglamasi('n')]);
    });

    test('yenileme kanıtına token değil özetin özeti gider', () async {
      final saglayici = _SahteSaglayici(() async => 'kanit');
      final kanit = ButunlukKaniti(saglayici, gunluk: (_) {});
      expect((await kanit.yenileme('yenileme-1'))?.integrityToken, 'kanit');
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

    test('App Attest: girişte attestation, yenilemede assertion', () async {
      final giris = AppAttestProof(keyId: _anahtar, attestation: 'YXR0');
      final yenileme = AppAttestProof(keyId: _anahtar, assertion: 'YXM=');
      final g = ButunlukKaniti(_SahteAppAttest(giris), gunluk: (_) {});
      final y = ButunlukKaniti(_SahteAppAttest(yenileme), gunluk: (_) {});
      expect((await g.giris('n'))?.appAttest, giris);
      expect((await y.yenileme('t'))?.appAttest, yenileme);
      // Yanlış aşamanın kanıtı gönderilmez.
      expect(await g.yenileme('t'), isNull);
      expect(await y.giris('n'), isNull);
    });

    test('iOS girişi daha uzun bekler; yenileme süresi değişmez', () async {
      final saglayici = _SahteSaglayici(
        () => Future.delayed(const Duration(milliseconds: 50), () => 'kanit'),
      );
      final kanit = ButunlukKaniti(
        saglayici,
        zamanAsimi: const Duration(milliseconds: 10),
        girisZamanAsimi: const Duration(seconds: 5),
        gunluk: (_) {},
      );
      expect((await kanit.giris('n'))?.integrityToken, 'kanit');
      expect(await kanit.yenileme('t'), isNull);
      expect(
        ButunlukKaniti(saglayici).girisZamanAsimi,
        ButunlukKaniti.varsayilanZamanAsimi,
      );
      expect(
        ButunlukKaniti.appAttestGirisZamanAsimi,
        const Duration(seconds: 20),
      );
    });

    test('anahtar yalnızca başarılı App Attest girişinde kaydedilir', () async {
      final saglayici = _SahteSaglayici(() async => null);
      final kanit = ButunlukKaniti(saglayici, gunluk: (_) {});
      final giris = IstekKaniti.appAttest(
        AppAttestProof(keyId: _anahtar, attestation: 'YXR0'),
      );
      await kanit.girisBasarili(null);
      await kanit.girisBasarili(const IstekKaniti.play('kanit'));
      await kanit.girisBasarili(
        IstekKaniti.appAttest(AppAttestProof(keyId: _anahtar, assertion: 'x')),
      );
      expect(saglayici.kaydedilen, isEmpty);
      await kanit.girisBasarili(giris);
      expect(saglayici.kaydedilen, [giris]);
    });

    test('unut sağlayıcıya gider; hata yutulur', () async {
      final saglayici = _SahteSaglayici(() async => null);
      final gunluk = <String>[];
      final kanit = ButunlukKaniti(saglayici, gunluk: gunluk.add);
      await kanit.unut();
      expect(saglayici.unutma, 1);
      saglayici.unutmaHatasi = const ButunlukHatasi(ButunlukHatasiTuru.ag);
      await kanit.unut();
      expect(saglayici.unutma, 2);
      expect(gunluk, ['bütünlük: unutulamadı']);
    });

    test('App Attest: sınır dışı kanıt gönderilmez', () async {
      final gunluk = <String>[];
      for (final kanitDegeri in [
        const AppAttestProof(keyId: 'kisa', attestation: 'YXR0'),
        AppAttestProof(keyId: _anahtar, attestation: ''),
        AppAttestProof(
          keyId: _anahtar,
          attestation: 'A' * (ButunlukKaniti.enUzunAttestation + 1),
        ),
        AppAttestProof(keyId: _anahtar, attestation: 'YXR0', assertion: 'YXM='),
      ]) {
        final kanit = ButunlukKaniti(
          _SahteAppAttest(kanitDegeri),
          gunluk: gunluk.add,
        );
        expect(await kanit.giris('n'), isNull);
      }
      expect(gunluk.toSet(), {'bütünlük: geçersiz token'});
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
      final ios = KanalButunlukSaglayici(kanal: kanal, appAttest: true);
      expect(await ios.kanit('ozet', ButunlukIstegi.giris), isNull);
    });

    test('Android: kanit Play token\'ıdır', () async {
      yanitla((_) => 'kanit');
      final saglayici = KanalButunlukSaglayici(kanal: kanal, projeNumarasi: 7);
      final k = await saglayici.kanit('ozet', ButunlukIstegi.yenileme);
      expect(k?.integrityToken, 'kanit');
      expect(k?.appAttest, isNull);
      expect(cagrilar.single.method, 'token');
    });

    test('iOS: istek ve istek özeti gider, kanıt aşamaya göre', () async {
      yanitla((_) => {'keyId': _anahtar, 'veri': 'YXR0'});
      final saglayici = KanalButunlukSaglayici(kanal: kanal, appAttest: true);
      final g = await saglayici.kanit('ozet', ButunlukIstegi.giris);
      expect(
        g?.appAttest,
        AppAttestProof(keyId: _anahtar, attestation: 'YXR0'),
      );
      final y = await saglayici.kanit('ozet', ButunlukIstegi.yenileme);
      expect(y?.appAttest, AppAttestProof(keyId: _anahtar, assertion: 'YXR0'));
      expect(cagrilar.map((c) => c.method), ['appAttest', 'appAttest']);
      expect(cagrilar.first.arguments, {
        'istek': 'giris',
        'istekOzeti': 'ozet',
      });
      expect(cagrilar.last.arguments, {
        'istek': 'yenileme',
        'istekOzeti': 'ozet',
      });
    });

    test('iOS: hazırlık köprüye gitmez; desteklenmeyen cihazda null', () async {
      yanitla((_) => null);
      final saglayici = KanalButunlukSaglayici(kanal: kanal, appAttest: true);
      await saglayici.hazirla();
      expect(cagrilar, isEmpty);
      expect(await saglayici.kanit('ozet', ButunlukIstegi.giris), isNull);
    });

    test('kaydet: iOS kimliği köprüye verir, Android vermez', () async {
      yanitla((_) => null);
      final kanit = IstekKaniti.appAttest(
        AppAttestProof(keyId: _anahtar, attestation: 'YXR0'),
      );
      await KanalButunlukSaglayici(kanal: kanal).kaydet(kanit);
      expect(cagrilar, isEmpty);
      await KanalButunlukSaglayici(kanal: kanal, appAttest: true).kaydet(kanit);
      expect(cagrilar.single.method, 'appAttestKaydet');
      expect(cagrilar.single.arguments, {'keyId': _anahtar});
    });

    test('unut: iOS köprüye gider, Android gitmez', () async {
      yanitla((_) => null);
      await KanalButunlukSaglayici(kanal: kanal).unut();
      expect(cagrilar, isEmpty);
      await KanalButunlukSaglayici(kanal: kanal, appAttest: true).unut();
      expect(cagrilar.single.method, 'appAttestUnut');
      expect(cagrilar.single.arguments, isNull);
    });

    test('iOS: hata kodu türe, bozuk sonuç bilinmeyene eşlenir', () async {
      final saglayici = KanalButunlukSaglayici(kanal: kanal, appAttest: true);
      yanitla((_) => throw PlatformException(code: 'anahtarYok'));
      await expectLater(
        saglayici.kanit('ozet', ButunlukIstegi.yenileme),
        throwsA(
          isA<ButunlukHatasi>().having(
            (h) => h.tur,
            'tur',
            ButunlukHatasiTuru.anahtarYok,
          ),
        ),
      );
      for (final bozuk in <Object>[
        'metin',
        {'keyId': _anahtar},
        {'keyId': '', 'veri': 'YXR0'},
        {'keyId': _anahtar, 'veri': ''},
      ]) {
        yanitla((_) => bozuk);
        await expectLater(
          saglayici.kanit('ozet', ButunlukIstegi.giris),
          throwsA(isA<ButunlukHatasi>()),
        );
      }
    });

    test('hata metninde değer yok', () {
      expect(
        const ButunlukHatasi(ButunlukHatasiTuru.kota).toString(),
        'ButunlukHatasi(kota)',
      );
    });
  });
}
