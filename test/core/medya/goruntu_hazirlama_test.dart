import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';

import 'sahteler.dart';

/// HEIC kabının ilk baytları (sahte; çözme sahte kodlayıcıda).
Uint8List _heic() => Uint8List.fromList([
  0, 0, 0, 0x18, ...'ftypheic'.codeUnits, 0, 0, 0, 0, //
  ...'mif1heic'.codeUnits,
]);

Future<(HazirGoruntu, SahteKodlayici)> _hazirla(
  JpegOlculeri olcu, {
  bool donuk = false,
  Uint8List? kaynak,
}) async {
  final k = kaynak ?? ornekJpeg();
  final kodlayici = SahteKodlayici(
    kaynak: k,
    kaynakOlcusu: olcu,
    donuk: donuk,
  );
  final sonuc = await GoruntuHazirlayici(kodlayici).hazirla(k);
  return (sonuc, kodlayici);
}

void _metadataYok(HazirGoruntu g) {
  for (final b in [g.tam, g.onizleme]) {
    for (final isaret in metadataIsaretleri) {
      expect(baytlardaVar(b, isaret), isFalse, reason: isaret);
    }
    jpegDenetle(b);
  }
}

void main() {
  group('boyut ve oran', () {
    test('12 MP yatay: 1600×1200 ve 400×300', () async {
      final (g, k) = await _hazirla(const JpegOlculeri(4032, 3024));
      expect(g.tamOlcu, const JpegOlculeri(1600, 1200));
      expect(g.onizlemeOlcu, const JpegOlculeri(400, 300));
      expect(jpegDenetle(g.tam), g.tamOlcu);
      expect(jpegDenetle(g.onizleme), g.onizlemeOlcu);
      // Yoklama 1/8, tam 1/2 alt örneklemeyle (uzun kenar ≥ 1600 kalır).
      expect(k.cagrilar.map((c) => c.ornekleme), [8, 2, 1]);
      expect(k.cagrilar[1].minGenislik, tamUzunKenar);
      expect(k.cagrilar[2].kaynakMi, isFalse);
      expect(k.cagrilar[2].yonuUygula, isFalse);
    });

    test('EXIF yönü 90°: dikey çıktı 1200×1600 ve 300×400', () async {
      final (g, k) = await _hazirla(
        const JpegOlculeri(4032, 3024),
        donuk: true,
      );
      expect(g.tamOlcu, const JpegOlculeri(1200, 1600));
      expect(g.onizlemeOlcu, const JpegOlculeri(300, 400));
      expect(k.cagrilar[1].minYukseklik, tamUzunKenar);
      expect(k.cagrilar[1].yonuUygula, isTrue);
    });

    test('küçük resim büyütülmez', () async {
      final (g, _) = await _hazirla(const JpegOlculeri(300, 200));
      expect(g.tamOlcu, const JpegOlculeri(300, 200));
      expect(g.onizlemeOlcu, const JpegOlculeri(300, 200));
    });

    test('yuvarlamalı oran sunucunun ±1 px kuralına uyar', () async {
      final (g, _) = await _hazirla(const JpegOlculeri(3000, 2001));
      expect(g.tamOlcu.uzunKenar, tamUzunKenar);
      expect(g.onizlemeOlcu.uzunKenar, onizlemeUzunKenar);
      expect(oranTutuyor(g.onizlemeOlcu, g.tamOlcu), isTrue);
    });

    test('oranTutuyor sunucunun kuralıdır', () {
      const tam = JpegOlculeri(1600, 1200);
      expect(oranTutuyor(const JpegOlculeri(400, 300), tam), isTrue);
      expect(oranTutuyor(const JpegOlculeri(400, 299), tam), isTrue);
      expect(oranTutuyor(const JpegOlculeri(400, 290), tam), isFalse);
      expect(oranTutuyor(const JpegOlculeri(1601, 1200), tam), isFalse);
      expect(
        oranTutuyor(
          const JpegOlculeri(400, 266),
          const JpegOlculeri(1600, 1067),
        ),
        isTrue,
      );
    });

    test('orneklemeHesapla', () {
      expect(orneklemeHesapla(4032, 1600), 2);
      expect(orneklemeHesapla(8000, 1600), 4);
      expect(orneklemeHesapla(1600, 1600), 1);
      expect(orneklemeHesapla(500, 1600), 1);
    });
  });

  group('metadata', () {
    for (final ilerlemeli in [false, true]) {
      test(
        'kodlayıcı metadata bıraksa da çıktı temiz '
        '(${ilerlemeli ? 'ilerlemeli' : 'temel'})',
        () async {
          final k = ornekJpeg(ilerlemeli: ilerlemeli);
          final (g, _) = await _hazirla(
            const JpegOlculeri(4032, 3024),
            kaynak: k,
          );
          _metadataYok(g);
        },
      );
    }

    test('HEIC kaynağı platform kodlayıcısıyla JPEG olur', () async {
      final (g, k) = await _hazirla(
        const JpegOlculeri(3024, 4032),
        kaynak: _heic(),
      );
      expect(g.tamOlcu, const JpegOlculeri(1200, 1600));
      expect(k.cagrilar.first.kaynakMi, isTrue);
      _metadataYok(g);
    });
  });

  group('hatalar', () {
    test('çözülemeyen dosya: okunamadı', () async {
      final k = ornekJpeg();
      final kodlayici = SahteKodlayici(
        kaynak: k,
        kaynakOlcusu: const JpegOlculeri(10, 10),
        hata: platformHatasi(),
      );
      await expectLater(
        GoruntuHazirlayici(kodlayici).hazirla(k),
        throwsA(
          isA<GoruntuHatasi>().having(
            (h) => h.tur,
            'tur',
            GoruntuHatasiTuru.okunamadi,
          ),
        ),
      );
    });

    test('boş ve çok büyük kaynak', () async {
      final kodlayici = SahteKodlayici(
        kaynak: Uint8List(0),
        kaynakOlcusu: const JpegOlculeri(10, 10),
      );
      final hazirlayici = GoruntuHazirlayici(kodlayici);
      await expectLater(
        hazirlayici.hazirla(Uint8List(0)),
        throwsA(isA<GoruntuHatasi>()),
      );
      await expectLater(
        hazirlayici.hazirla(Uint8List(kaynakEnCokBayt + 1)),
        throwsA(
          isA<GoruntuHatasi>().having(
            (h) => h.tur,
            'tur',
            GoruntuHatasiTuru.cokBuyuk,
          ),
        ),
      );
      expect(kodlayici.cagrilar, isEmpty);
    });
  });
}
