import 'dart:typed_data';

import 'package:qr/qr.dart';

/// [metin]'in QR'ını bir kamera karesinin parlaklık (Y) düzlemine çizer:
/// beyaz zemin, koyu modüller, sessiz bölge ve satır sonu dolgusu.
///
/// Dönüş: (baytlar, genişlik, yükseklik, satır baytları).
({Uint8List baytlar, int genislik, int yukseklik, int satirBaytlari})
qrParlaklikDuzlemi(
  String metin, {
  int olcek = 4,
  int sessizBolge = 4,
  int solBosluk = 24,
  int ustBosluk = 12,
  int satirDolgusu = 16,
}) {
  final goruntu = QrImage(
    QrCode(
      payload: QrPayload.fromString(metin),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );
  final adet = goruntu.moduleCount;
  final kenar = (adet + 2 * sessizBolge) * olcek;
  final genislik = kenar + 2 * solBosluk;
  final yukseklik = kenar + 2 * ustBosluk;
  final satirBaytlari = genislik + satirDolgusu;
  final baytlar = Uint8List(satirBaytlari * yukseklik)..fillRange(
    0,
    satirBaytlari * yukseklik,
    0xF0,
  );
  for (var y = 0; y < adet; y++) {
    for (var x = 0; x < adet; x++) {
      if (!goruntu.isDark(y, x)) continue;
      for (var dy = 0; dy < olcek; dy++) {
        final satir = ustBosluk + (sessizBolge + y) * olcek + dy;
        final sutun = solBosluk + (sessizBolge + x) * olcek;
        baytlar.fillRange(
          satir * satirBaytlari + sutun,
          satir * satirBaytlari + sutun + olcek,
          0x18,
        );
      }
    }
  }
  return (
    baytlar: baytlar,
    genislik: genislik,
    yukseklik: yukseklik,
    satirBaytlari: satirBaytlari,
  );
}
