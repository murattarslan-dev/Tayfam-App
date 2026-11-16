import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/mesaj/zarf_icerigi.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';

const String _ekId = '5b6f4a1e-9c3d-4f1a-8b9e-8d7c7d0e8c4a';

EkAnahtari _ek({int boyut = 5029, int en = 1600, int boy = 1200}) => EkAnahtari(
  uploadId: _ekId,
  anahtar: Uint8List.fromList(List.filled(32, 7)),
  ozet: Uint8List.fromList(List.filled(32, 9)),
  boyut: boyut,
  genislik: en,
  yukseklik: boy,
);

BirebirIcerik? _gidisDonus(BirebirIcerik i) =>
    zarfIcerigiCoz(zarfIcerigiKodla(i));

Uint8List _ham(Map<String, Object?> json) =>
    dolguEkle(Uint8List.fromList(utf8.encode(jsonEncode(json))));

void main() {
  group('zarf içeriği (ADR-0028 §3)', () {
    test('metin, fotoğraf ve yer gidiş-dönüş', () {
      expect(
        _gidisDonus(const MetinIcerigi('Selam')),
        const MetinIcerigi('Selam'),
      );
      final foto = FotografIcerigi(_ek());
      expect(_gidisDonus(foto), foto);
      const yer = YerIcerigi(
        PaylasilanYer(enlem: 40.712345, boylam: 30.265432, ad: 'Otopark'),
      );
      expect(_gidisDonus(yer), yer);
      const adsiz = YerIcerigi(PaylasilanYer(enlem: -90, boylam: 180));
      expect(_gidisDonus(adsiz), adsiz);
    });

    test('foto: anahtar ve özet dolgusuz base64url; dolgulu', () {
      final kod = zarfIcerigiKodla(FotografIcerigi(_ek()));
      expect(kod.length % dolguBlogu, 0);
      final json =
          jsonDecode(utf8.decode(dolguKaldir(kod)!)) as Map<String, Object?>;
      final ek = json['ek']! as Map<String, Object?>;
      expect(json['v'], 1);
      expect(json['t'], 'foto');
      expect(ek['id'], _ekId);
      expect(ek['anahtar'], isNot(contains('=')));
      expect(ek.keys, {'id', 'anahtar', 'ozet', 'boyut', 'en', 'boy'});
    });

    test('geçersiz foto alanları: zarf çözülemedi (null)', () {
      Map<String, Object?> ek([Map<String, Object?> degis = const {}]) => {
        'v': 1,
        't': 'foto',
        'ek': {
          'id': _ekId,
          'anahtar': 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
          'ozet': 'CQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQk',
          'boyut': 5029,
          'en': 1600,
          'boy': 1200,
          ...degis,
        },
      };
      expect(zarfIcerigiCoz(_ham(ek())), isA<FotografIcerigi>());
      for (final bozuk in <Map<String, Object?>>[
        {'id': 'kimlik-degil'},
        {'anahtar': 'kisa'},
        {'anahtar': 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBw=='},
        {'ozet': null},
        {'boyut': 0},
        {'boyut': 10 * 1024 * 1024 + 1},
        {'boyut': '5029'},
        {'en': 0},
        {'boy': 1601},
      ]) {
        expect(zarfIcerigiCoz(_ham(ek(bozuk))), isNull, reason: '$bozuk');
      }
    });

    test('geçersiz yer: aralık dışı, sonsuz, ad sınırı, kontrol karakteri', () {
      Map<String, Object?> yer(Object? enlem, Object? boylam, [Object? ad]) => {
        'v': 1,
        't': 'yer',
        'enlem': enlem,
        'boylam': boylam,
        'ad': ?ad,
      };
      expect(zarfIcerigiCoz(_ham(yer(41, 29, 'Kadıköy'))), isA<YerIcerigi>());
      expect(zarfIcerigiCoz(_ham(yer(41, 29))), isA<YerIcerigi>());
      expect(zarfIcerigiCoz(_ham(yer(90.0001, 29))), isNull);
      expect(zarfIcerigiCoz(_ham(yer(41, -180.5))), isNull);
      expect(zarfIcerigiCoz(_ham(yer('41', 29))), isNull);
      expect(zarfIcerigiCoz(_ham(yer(41, 29, ''))), isNull);
      expect(zarfIcerigiCoz(_ham(yer(41, 29, 'a' * 121))), isNull);
      expect(zarfIcerigiCoz(_ham(yer(41, 29, 'a\nb'))), isNull);
      expect(zarfIcerigiCoz(_ham(yer(41, 29, 42))), isNull);
    });

    test('bilinmeyen tür ve sürüm çözülemez', () {
      expect(zarfIcerigiCoz(_ham({'v': 1, 't': 'video'})), isNull);
      expect(
        zarfIcerigiCoz(_ham({'v': 2, 't': 'metin', 'govde': 'x'})),
        isNull,
      );
    });

    test('toString içerik yazmaz', () {
      expect('${const MetinIcerigi('gizli metin')}', isNot(contains('gizli')));
      expect(
        '${const YerIcerigi(PaylasilanYer(enlem: 41.123, boylam: 29.456, ad: 'Ev'))}',
        isNot(anyOf(contains('41.123'), contains('Ev'))),
      );
      expect('${FotografIcerigi(_ek())}', isNot(contains(_ekId)));
    });
  });

  group('arşiv kaydı (ADR-0020 §2, ADR-0028 §3)', () {
    test('foto ve yer arşiv düz metninde gidiş-dönüş', () {
      for (final icerik in <BirebirIcerik>[
        FotografIcerigi(_ek()),
        const YerIcerigi(PaylasilanYer(enlem: 1, boylam: 2, ad: 'Yer')),
      ]) {
        final duz = ArsivDuzMetni(
          gonderenId: _ekId,
          olusturma: DateTime.utc(2026, 11, 16),
          icerik: icerik,
        );
        final cozulen = ArsivDuzMetni.coz(duz.kodla());
        expect(cozulen?.icerik, icerik);
        expect(cozulen?.gonderenId, _ekId);
      }
    });
  });

  group('yer adı', () {
    test(
      'hazırlama: kırpar, satır sonunu boşluk yapar, 120 karakterde keser',
      () {
        expect(yerAdiniHazirla('  Otopark \n girişi '), 'Otopark   girişi');
        expect(yerAdiniHazirla('   '), isNull);
        expect(yerAdiniHazirla('ç' * 130)!.runes.length, yerAdiEnCok);
        expect(yerAdiGecerli(yerAdiniHazirla('ç' * 130)!), isTrue);
      },
    );
  });
}
