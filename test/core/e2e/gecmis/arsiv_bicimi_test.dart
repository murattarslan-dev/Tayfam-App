import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/dolgu.dart';

import '../signal/sahte_signal_motoru.dart';
import 'sahteler.dart';

final ArsivDuzMetni _duz = ArsivDuzMetni(
  gonderenId: karsiKullanici,
  olusturma: DateTime.utc(2026, 11, 11, 18, 30),
  govde: 'Yarın 9\'da buluşalım mı? 🚐',
);

void main() {
  group('dolgu', () {
    test('uzunluk her zaman 160\'ın katı ve geri alınır', () {
      for (final n in [0, 1, 158, 159, 160, 161, 400]) {
        final veri = Uint8List.fromList(List.generate(n, (i) => i & 0xff));
        final dolgulu = dolgula(veri);
        expect(dolgulu.length % dolguBlogu, 0, reason: '$n');
        expect(dolgulu.length, greaterThan(n));
        expect(dolguyuKaldir(dolgulu), veri);
      }
    });

    test('159 bayt bir blok, 160 bayt iki blok', () {
      expect(dolgula(Uint8List(159)).length, 160);
      expect(dolgula(Uint8List(160)).length, 320);
    });

    test('bozuk dolgu reddedilir', () {
      expect(dolguyuKaldir(Uint8List(0)), isNull);
      expect(dolguyuKaldir(Uint8List(159)), isNull);
      expect(dolguyuKaldir(Uint8List(160)), isNull); // işaret baytı yok
    });
  });

  group('uuidBaytlari ve AAD', () {
    test('UUID 16 bayta çevrilir', () {
      expect(
        uuidBaytlari('00010203-0405-0607-0809-0a0b0c0d0e0f'),
        List.generate(16, (i) => i),
      );
      expect(() => uuidBaytlari('yanlis'), throwsFormatException);
    });

    test('AAD: bağlam ‖ kullanıcı ‖ mesaj ‖ sürüm (u16 büyük uçlu)', () {
      final aad = arsivAad(
        kullaniciId: kullaniciId,
        mesajId: mesajId(1),
        surum: 258,
      );
      final baglam = utf8.encode(arsivBaglami);
      expect(aad.length, baglam.length + 16 + 16 + 2);
      expect(aad.sublist(0, baglam.length), baglam);
      expect(aad.sublist(aad.length - 2), [1, 2]);
      expect(
        () => arsivAad(kullaniciId: kullaniciId, mesajId: mesajId(1), surum: 0),
        throwsFormatException,
      );
    });
  });

  group('ArsivBicimi', () {
    late SahteSignalMotoru motor;
    late ArsivBicimi bicim;

    setUp(() {
      motor = SahteSignalMotoru();
      bicim = ArsivBicimi(motor);
    });

    Future<Uint8List> sifrele({int surum = 1}) => bicim.sifrele(
      gecmisAnahtari: anahtar(1),
      surum: surum,
      kullaniciId: kullaniciId,
      mesajId: mesajId(1),
      duz: _duz,
    );

    Future<ArsivDuzMetni?> coz(
      Uint8List icerik, {
      Uint8List? gecmis,
      int surum = 1,
      String kullanici = kullaniciId,
      String? mesaj,
    }) => bicim.coz(
      gecmisAnahtari: gecmis ?? anahtar(1),
      surum: surum,
      kullaniciId: kullanici,
      mesajId: mesaj ?? mesajId(1),
      icerik: icerik,
    );

    test('tur: şifrele → çöz aynı düz metni verir', () async {
      final icerik = await sifrele();
      expect(icerik[0], arsivBicimSurumu);
      final cozulen = await coz(icerik);
      expect(cozulen, isNotNull);
      expect(cozulen!.govde, _duz.govde);
      expect(cozulen.gonderenId, karsiKullanici);
      expect(cozulen.olusturma, _duz.olusturma);
    });

    test('libsignal yapı taşları kullanılır; anahtar sürüm başına bir kez '
        'türetilir', () async {
      await sifrele();
      await sifrele();
      expect(motor.cagrilar.where((c) => c == 'hkdf'), hasLength(1));
      expect(
        motor.cagrilar.where((c) => c == 'aesGcmSivSifrele'),
        hasLength(2),
      );
    });

    test('düz metin 160 bayta dolgulu: kısa ve uzun gövde aynı blok '
        'sınırına yuvarlanır', () async {
      final kisa = await sifrele();
      final uzun = await bicim.sifrele(
        gecmisAnahtari: anahtar(1),
        surum: 1,
        kullaniciId: kullaniciId,
        mesajId: mesajId(1),
        duz: ArsivDuzMetni(
          gonderenId: karsiKullanici,
          olusturma: _duz.olusturma,
          govde: 'x',
        ),
      );
      const ek = 1 + arsivNonceUzunlugu + arsivEtiketUzunlugu;
      expect((kisa.length - ek) % dolguBlogu, 0);
      expect(kisa.length, uzun.length);
    });

    test('her kayıt farklı nonce alır', () async {
      final a = await sifrele();
      final b = await sifrele();
      expect(a.sublist(1, 13), isNot(b.sublist(1, 13)));
    });

    test('AAD değişince çözülmez (mesaj, kullanıcı, sürüm)', () async {
      final icerik = await sifrele();
      expect(await coz(icerik, mesaj: mesajId(2)), isNull);
      expect(await coz(icerik, kullanici: karsiKullanici), isNull);
      bicim.unut(1);
      expect(await coz(icerik, surum: 2), isNull);
    });

    test('başka anahtarla, bozuk baytla ya da yanlış biçimle çözülmez', () async {
      final icerik = await sifrele();
      final baska = ArsivBicimi(SahteSignalMotoru());
      expect(
        await baska.coz(
          gecmisAnahtari: anahtar(2),
          surum: 1,
          kullaniciId: kullaniciId,
          mesajId: mesajId(1),
          icerik: icerik,
        ),
        isNull,
      );
      final bozuk = Uint8List.fromList(icerik)..[20] ^= 1;
      expect(await coz(bozuk), isNull);
      final surum = Uint8List.fromList(icerik)..[0] = 2;
      expect(await coz(surum), isNull);
      expect(await coz(Uint8List(10)), isNull);
    });

    test('düz metin biçimi: JSON alanları ve toString içerik yazmaz', () {
      final json =
          jsonDecode(utf8.decode(dolguyuKaldir(_duz.kodla())!))
              as Map<String, Object?>;
      expect(json, {
        'v': 1,
        'gonderen': karsiKullanici,
        'created_at': '2026-11-11T18:30:00.000Z',
        't': 'metin',
        'govde': _duz.govde,
      });
      expect(_duz.toString(), isNot(contains('buluşalım')));
      expect(ArsivDuzMetni.coz(dolgula(utf8.encode('{"v":2}'))), isNull);
    });
  });
}
