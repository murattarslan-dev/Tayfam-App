import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/medya/jpeg.dart';

import 'sahteler.dart';

/// [b]'de SOI'den sonra bir APPn segmentinin başladığı yerler.
List<int> _segmentler(Uint8List b, int isaretci) {
  final bulunan = <int>[];
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    if (m == 0xDA || m == 0xD9) break;
    if (m == isaretci) bulunan.add(i);
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return bulunan;
}

void main() {
  for (final ilerlemeli in [false, true]) {
    group(ilerlemeli ? 'ilerlemeli JPEG' : 'temel JPEG', () {
      final ham = ornekJpeg(ilerlemeli: ilerlemeli);

      test('örnekte metadata gerçekten var (testin kendisi sağlam)', () {
        for (final isaret in metadataIsaretleri) {
          expect(baytlardaVar(ham, isaret), isTrue, reason: isaret);
        }
        expect(
          () => jpegDenetle(ham),
          throwsA(
            isA<JpegHatasi>().having((h) => h.neden, 'neden', 'metadata'),
          ),
        );
      });

      test('temizlenen dosyada hiçbir metadata baytı yok', () {
        final temiz = jpegTemizle(ham);
        for (final isaret in metadataIsaretleri) {
          expect(baytlardaVar(temiz, isaret), isFalse, reason: isaret);
        }
        // APP1 (EXIF/XMP), APP13 (IPTC) segmenti kalmadı.
        expect(_segmentler(temiz, 0xE1), isEmpty);
        expect(_segmentler(temiz, 0xED), isEmpty);
        // ICC profili kalır (renk), JFIF küçük resmi silinmiştir.
        expect(_segmentler(temiz, 0xE2), hasLength(1));
        final jfif = _segmentler(temiz, 0xE0).single;
        expect(temiz.sublist(jfif + 2, jfif + 4), [0x00, 0x10]);
        expect(temiz.sublist(jfif + 16, jfif + 18), [0x00, 0x00]);
        // EOI'de biter; ikinci resim (ve sonek) atılmıştır.
        expect(temiz.sublist(temiz.length - 2), [0xFF, 0xD9]);
        var soi = 0;
        for (var i = 0; i + 1 < temiz.length; i++) {
          if (temiz[i] == 0xFF && temiz[i + 1] == 0xD8) soi++;
        }
        expect(soi, 1);
      });

      test('temizlenen dosya sunucunun kuralından geçer', () {
        final temiz = jpegTemizle(ham);
        expect(jpegDenetle(temiz), const JpegOlculeri(64, 48));
        // İkinci kez temizlemek bir şey değiştirmez.
        expect(jpegTemizle(temiz), temiz);
      });

      test('tarama verisi aynen korunur', () {
        final temiz = jpegTemizle(ham);
        int sos(Uint8List b) {
          for (var i = 2; i + 1 < b.length; i++) {
            if (b[i] == 0xFF && b[i + 1] == 0xDA) return i;
          }
          return -1;
        }

        final hamSos = sos(ham);
        final temizSos = sos(temiz);
        final uzunluk = temiz.length - 2 - temizSos;
        expect(
          temiz.sublist(temizSos, temizSos + uzunluk),
          ham.sublist(hamSos, hamSos + uzunluk),
        );
      });
    });
  }

  group('jpegDenetle', () {
    final temiz = jpegTemizle(ornekJpeg());

    test('EOI sonrası bayt reddedilir', () {
      final ekli = Uint8List.fromList([...temiz, 0x00]);
      expect(() => jpegDenetle(ekli), throwsA(isA<JpegHatasi>()));
    });

    test('JPEG olmayan ve kesik dosya reddedilir', () {
      expect(
        () => jpegDenetle(Uint8List.fromList('RIFF0000WEBP'.codeUnits)),
        throwsA(isA<JpegHatasi>()),
      );
      expect(
        () => jpegDenetle(Uint8List.sublistView(temiz, 0, temiz.length ~/ 2)),
        throwsA(isA<JpegHatasi>()),
      );
      expect(
        () => jpegTemizle(Uint8List.sublistView(temiz, 0, 40)),
        throwsA(isA<JpegHatasi>()),
      );
    });

    test('yorum (COM) segmenti metadata sayılır', () {
      final yorumlu = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xFE, 0x00, 0x04, 0x41, 0x42, //
        ...temiz.sublist(2),
      ]);
      expect(
        () => jpegDenetle(yorumlu),
        throwsA(isA<JpegHatasi>().having((h) => h.neden, 'neden', 'metadata')),
      );
      expect(jpegDenetle(jpegTemizle(yorumlu)), const JpegOlculeri(64, 48));
    });
  });
}
