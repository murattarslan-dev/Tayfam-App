import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/features/cihazlar/data/qr_cozucu.dart';

import '../../core/e2e/gecmis/sahteler.dart';
import 'qr_karesi.dart';

String _eslemeMetni() => EslemeQr(
  istekId: istekId,
  cihazId: cihazB,
  kimlikAnahtari: kimlik(2),
  kod: Uint8List.fromList(List.generate(16, (i) => 200 + i)),
).kodla();

ParlaklikKaresi _kare(String metin, {int olcek = 4}) {
  final d = qrParlaklikDuzlemi(metin, olcek: olcek);
  return ParlaklikKaresi(
    baytlar: d.baytlar,
    genislik: d.genislik,
    yukseklik: d.yukseklik,
    satirBaytlari: d.satirBaytlari,
  );
}

void main() {
  test('eşleştirme QR\'ı satır dolgulu parlaklık düzleminden çözülür', () {
    final metin = _eslemeMetni();
    expect(qrMetniCoz(_kare(metin)), metin);
  });

  test('küçük modüllü (3 piksel) QR da çözülür', () {
    final metin = _eslemeMetni();
    expect(qrMetniCoz(_kare(metin, olcek: 3)), metin);
  });

  test('QR olmayan kare null verir', () {
    final bos = Uint8List(320 * 240)..fillRange(0, 320 * 240, 0xF0);
    final kare = ParlaklikKaresi(
      baytlar: bos,
      genislik: 320,
      yukseklik: 240,
      satirBaytlari: 320,
    );
    expect(qrMetniCoz(kare), isNull);
  });

  test('tutarsız ölçüler reddedilir', () {
    final baytlar = Uint8List(100);
    expect(
      ParlaklikKaresi.olustur(
        baytlar: baytlar,
        genislik: 10,
        yukseklik: 11,
        satirBaytlari: 10,
      ),
      isNull,
    );
    expect(
      ParlaklikKaresi.olustur(
        baytlar: baytlar,
        genislik: 10,
        yukseklik: 5,
        satirBaytlari: 8,
      ),
      isNull,
    );
    expect(
      ParlaklikKaresi.olustur(
        baytlar: baytlar,
        genislik: 0,
        yukseklik: 5,
        satirBaytlari: 8,
      ),
      isNull,
    );
    expect(
      () => ParlaklikKaresi(
        baytlar: baytlar,
        genislik: 10,
        yukseklik: 11,
        satirBaytlari: 10,
      ),
      throwsArgumentError,
    );
    // Son satırın dolgusu olmayabilir.
    expect(
      ParlaklikKaresi.olustur(
        baytlar: baytlar,
        genislik: 10,
        yukseklik: 9,
        satirBaytlari: 11,
      ),
      isNotNull,
    );
  });
}
