import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as kripto;
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';

import '../signal/sahte_signal_motoru.dart';

Uint8List _jpeg([int n = 5000]) =>
    Uint8List.fromList([for (var i = 0; i < n; i++) (i * 7) % 256]);

void main() {
  late SahteSignalMotoru motor;
  late EkSifreleyici sifreleyici;

  setUp(() {
    motor = SahteSignalMotoru();
    sifreleyici = EkSifreleyici(motor);
  });

  test(
    'biçim: 0x01 ‖ nonce(12) ‖ şifreli ‖ etiket(16); özet SHA-256(blob)',
    () async {
      final duz = _jpeg();
      final ek = await sifreleyici.sifrele(duz);
      expect(ek.blob[0], ekBicimSurumu);
      expect(ek.blob.length, duz.length + ekEkBayt);
      expect(ek.anahtar, hasLength(ekAnahtarUzunlugu));
      expect(ek.ozet, kripto.sha256.convert(ek.blob).bytes);
      expect(motor.cagrilar, ['aes256GcmSifrele']);
      // Düz metin blob'da açıkça yok (sahte motor baytları ters çevirir).
      expect(
        ek.blob.sublist(1 + ekNonceUzunlugu, 1 + ekNonceUzunlugu + 8),
        isNot(duz.sublist(0, 8)),
      );
      expect(ek.toString(), 'SifreliEk(${ek.blob.length})');
    },
  );

  test('gidiş-dönüş: doğru anahtar ve özetle aynı görüntü', () async {
    final duz = _jpeg();
    final ek = await sifreleyici.sifrele(duz);
    final cozulen = await sifreleyici.coz(
      blob: ek.blob,
      anahtar: ek.anahtar,
      ozet: ek.ozet,
    );
    expect(cozulen, duz);
  });

  test('her ek yeni anahtar ve nonce alır (Random.secure)', () async {
    final a = await sifreleyici.sifrele(_jpeg());
    final b = await sifreleyici.sifrele(_jpeg());
    expect(a.anahtar, isNot(b.anahtar));
    expect(a.blob.sublist(1, 13), isNot(b.blob.sublist(1, 13)));
    expect(a.ozet, isNot(b.ozet));
  });

  test('yanlış özet reddedilir ve blob hiç çözülmez', () async {
    final ek = await sifreleyici.sifrele(_jpeg());
    motor.cagrilar.clear();
    final yanlis = Uint8List.fromList(ek.ozet)..[0] ^= 1;
    await expectLater(
      sifreleyici.coz(blob: ek.blob, anahtar: ek.anahtar, ozet: yanlis),
      throwsA(isA<EkDogrulanamadi>()),
    );
    expect(motor.cagrilar, isEmpty);
  });

  test('değiştirilmiş blob (özet tutmaz) reddedilir', () async {
    final ek = await sifreleyici.sifrele(_jpeg());
    final bozuk = Uint8List.fromList(ek.blob)..[40] ^= 0x80;
    await expectLater(
      sifreleyici.coz(blob: bozuk, anahtar: ek.anahtar, ozet: ek.ozet),
      throwsA(isA<EkDogrulanamadi>()),
    );
  });

  test('blob ve özet birlikte değiştirilse de GCM etiketi reddeder', () async {
    final ek = await sifreleyici.sifrele(_jpeg());
    final bozuk = Uint8List.fromList(ek.blob)..[40] ^= 0x80;
    await expectLater(
      sifreleyici.coz(blob: bozuk, anahtar: ek.anahtar, ozet: ekOzeti(bozuk)),
      throwsA(isA<EkDogrulanamadi>()),
    );
  });

  test('yanlış anahtar reddedilir', () async {
    final ek = await sifreleyici.sifrele(_jpeg());
    final baska = Uint8List.fromList(ek.anahtar)..[5] ^= 1;
    await expectLater(
      sifreleyici.coz(blob: ek.blob, anahtar: baska, ozet: ek.ozet),
      throwsA(isA<EkDogrulanamadi>()),
    );
  });

  test('biçim ve uzunluk denetimleri', () async {
    final ek = await sifreleyici.sifrele(_jpeg());
    // Sürüm baytı farklı (özet de buna göre).
    final surum = Uint8List.fromList(ek.blob)..[0] = 2;
    await expectLater(
      sifreleyici.coz(blob: surum, anahtar: ek.anahtar, ozet: ekOzeti(surum)),
      throwsA(isA<EkDogrulanamadi>()),
    );
    final kisa = Uint8List(ekEkBayt);
    await expectLater(
      sifreleyici.coz(blob: kisa, anahtar: ek.anahtar, ozet: ekOzeti(kisa)),
      throwsA(isA<EkDogrulanamadi>()),
    );
    await expectLater(
      sifreleyici.coz(blob: ek.blob, anahtar: Uint8List(16), ozet: ek.ozet),
      throwsA(isA<EkDogrulanamadi>()),
    );
    await expectLater(
      sifreleyici.coz(blob: ek.blob, anahtar: ek.anahtar, ozet: Uint8List(31)),
      throwsA(isA<EkDogrulanamadi>()),
    );
  });

  test('10 MiB sınırı: boş ya da büyük görüntü şifrelenmez', () async {
    expect(() => sifreleyici.sifrele(Uint8List(0)), throwsArgumentError);
    expect(
      () => sifreleyici.sifrele(Uint8List(ekEnCokBayt - ekEkBayt + 1)),
      throwsArgumentError,
    );
    final sinirda = await sifreleyici.sifrele(
      Uint8List(ekEnCokBayt - ekEkBayt),
    );
    expect(sinirda.blob.length, ekEnCokBayt);
  });

  test('rastgele kaynak verilebilir (test), varsayılan Random.secure', () {
    expect(EkSifreleyici(motor, rastgele: Random(1)), isNotNull);
  });
}
