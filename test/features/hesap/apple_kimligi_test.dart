import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/hesap/data/apple_kimligi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kanal = MethodChannel('test/apple-giris');
  final mesajci =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final cagrilar = <MethodCall>[];

  void yanitla(Object? Function(MethodCall cagri) yanit) {
    mesajci.setMockMethodCallHandler(kanal, (cagri) async {
      cagrilar.add(cagri);
      return yanit(cagri);
    });
  }

  KanalAppleKimlikSaglayici saglayici({String Function()? nonce}) =>
      KanalAppleKimlikSaglayici(kanal: kanal, nonce: nonce ?? () => 'nonce-1');

  setUp(cagrilar.clear);
  tearDown(() => mesajci.setMockMethodCallHandler(kanal, null));

  test('kanal adı Swift köprüsüyle aynı', () {
    expect(KanalAppleKimlikSaglayici.kanalAdi, 'tayfam/apple-giris');
    expect(KanalAppleKimlikSaglayici.iptalKodu, 'iptal');
  });

  test('giriş: nonce köprüye gider, token ve kod döner', () async {
    yanitla(
      (_) => {
        'idToken': 'sahte-apple-token',
        'yetkilendirmeKodu': 'sahte-kod',
        'ad': '  Deniz Örnek ',
      },
    );
    final kimlik = await saglayici().girisYap();
    expect(cagrilar.single.method, 'girisYap');
    expect(cagrilar.single.arguments, {'nonce': 'nonce-1'});
    expect(kimlik, isNotNull);
    expect(kimlik!.idToken, 'sahte-apple-token');
    expect(kimlik.nonce, 'nonce-1');
    expect(kimlik.yetkilendirmeKodu, 'sahte-kod');
    expect(kimlik.ad, 'Deniz Örnek');
  });

  test('ad yalnızca ilk yetkilendirmede gelir; yoksa null', () async {
    for (final ad in [null, '', '   ', 7]) {
      yanitla(
        (_) => {'idToken': 'token', 'yetkilendirmeKodu': 'kod', 'ad': ad},
      );
      expect((await saglayici().girisYap())!.ad, isNull);
    }
  });

  test('her deneme yeni nonce kullanır', () async {
    yanitla((_) => {'idToken': 'token', 'yetkilendirmeKodu': 'kod'});
    var sayac = 0;
    final s = saglayici(nonce: () => 'nonce-${++sayac}');
    final ilk = await s.girisYap();
    final ikinci = await s.girisYap();
    expect(ilk!.nonce, 'nonce-1');
    expect(ikinci!.nonce, 'nonce-2');
    expect(cagrilar.map((c) => c.arguments), [
      {'nonce': 'nonce-1'},
      {'nonce': 'nonce-2'},
    ]);
  });

  test('kullanıcı pencereyi kapatırsa null', () async {
    yanitla((_) => throw PlatformException(code: 'iptal'));
    expect(await saglayici().girisYap(), isNull);
  });

  test('başka köprü hatası AppleGirisHatasi', () async {
    yanitla((_) => throw PlatformException(code: 'basarisiz', message: 'x'));
    await expectLater(
      saglayici().girisYap(),
      throwsA(
        isA<AppleGirisHatasi>().having(
          (h) => h.desteklenmiyor,
          'desteklenmiyor',
          isFalse,
        ),
      ),
    );
  });

  test('köprü yoksa (Android, web) desteklenmiyor', () async {
    await expectLater(
      saglayici().girisYap(),
      throwsA(
        isA<AppleGirisHatasi>().having(
          (h) => h.desteklenmiyor,
          'desteklenmiyor',
          isTrue,
        ),
      ),
    );
  });

  test('eksik ya da bozuk yanıt reddedilir', () async {
    final yanitlar = <Object?>[
      null,
      'token',
      <String, Object?>{},
      {'idToken': 'token'},
      {'yetkilendirmeKodu': 'kod'},
      {'idToken': '', 'yetkilendirmeKodu': 'kod'},
      {'idToken': 'token', 'yetkilendirmeKodu': ''},
      {'idToken': 7, 'yetkilendirmeKodu': 'kod'},
      {
        'idToken': 'token',
        'yetkilendirmeKodu': 'k' * (KanalAppleKimlikSaglayici.enUzunKod + 1),
      },
    ];
    for (final yanit in yanitlar) {
      yanitla((_) => yanit);
      await expectLater(
        saglayici().girisYap(),
        throwsA(isA<AppleGirisHatasi>()),
        reason: '$yanit',
      );
    }
  });

  test('toString token, kod ve nonce yazmaz', () {
    const kimlik = AppleKimligi(
      idToken: 'gizli-token',
      nonce: 'gizli-nonce',
      yetkilendirmeKodu: 'gizli-kod',
      ad: 'Deniz',
    );
    expect(kimlik.toString(), 'AppleKimligi(…)');
    expect(const AppleGirisHatasi().toString(), 'AppleGirisHatasi');
  });
}
