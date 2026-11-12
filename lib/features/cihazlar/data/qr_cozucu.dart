import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:zxing2/qrcode.dart';

/// Kameranın tek bir karesinin parlaklık (Y) düzlemi.
///
/// YUV 4:2:0 (Android `YUV_420_888`, iOS NV12) ve NV21 karelerinde ilk
/// düzlem parlaklıktır; QR çözmek için renk gerekmez. Kare yalnızca
/// bellekte, çözülene kadar tutulur; diske yazılmaz, gönderilmez.
@immutable
final class ParlaklikKaresi {
  /// [satirBaytlari] < [genislik] ya da [baytlar] kareyi kapsamıyorsa
  /// [ArgumentError] atar.
  ParlaklikKaresi({
    required this.baytlar,
    required this.genislik,
    required this.yukseklik,
    required this.satirBaytlari,
  }) {
    if (!_gecerli(baytlar, genislik, yukseklik, satirBaytlari)) {
      throw ArgumentError('Parlaklık düzlemi kareyi kapsamıyor.');
    }
  }

  /// Ölçüler tutarsızsa null döner (atmaz).
  static ParlaklikKaresi? olustur({
    required Uint8List baytlar,
    required int genislik,
    required int yukseklik,
    required int satirBaytlari,
  }) => _gecerli(baytlar, genislik, yukseklik, satirBaytlari)
      ? ParlaklikKaresi(
          baytlar: baytlar,
          genislik: genislik,
          yukseklik: yukseklik,
          satirBaytlari: satirBaytlari,
        )
      : null;

  static bool _gecerli(
    Uint8List baytlar,
    int genislik,
    int yukseklik,
    int satirBaytlari,
  ) =>
      genislik > 0 &&
      yukseklik > 0 &&
      satirBaytlari >= genislik &&
      baytlar.length >= satirBaytlari * (yukseklik - 1) + genislik;

  final Uint8List baytlar;
  final int genislik;
  final int yukseklik;

  /// Bir satırın bellekteki bayt sayısı (satır sonu dolgusu dahil).
  final int satirBaytlari;
}

/// [kare]'deki QR kodunun metni; QR yoksa ya da okunamıyorsa null.
///
/// Yalnızca QR biçimi aranır (ZXing `QRCodeReader`). Saf Dart; `compute`
/// ile ayrı isolate'ta çalıştırılabilir. Metin burada doğrulanmaz;
/// ayrıştırma ve doğrulama eşleştirme servisinde yapılır.
String? qrMetniCoz(ParlaklikKaresi kare) {
  final bitmap = BinaryBitmap(HybridBinarizer(_ParlaklikKaynagi(kare)));
  try {
    return QRCodeReader().decode(bitmap).text;
  } on ReaderException {
    return null;
  }
}

/// [ParlaklikKaresi]'ni ZXing'in parlaklık kaynağına uyarlar.
final class _ParlaklikKaynagi extends LuminanceSource {
  _ParlaklikKaynagi(this._kare) : super(_kare.genislik, _kare.yukseklik);

  final ParlaklikKaresi _kare;

  @override
  Int8List getRow(int y, Int8List? row) {
    if (y < 0 || y >= height) {
      throw ArgumentError.value(y, 'y');
    }
    final satir = (row == null || row.length < width) ? Int8List(width) : row;
    final bas = y * _kare.satirBaytlari;
    satir.setRange(
      0,
      width,
      Int8List.sublistView(_kare.baytlar, bas, bas + width),
    );
    return satir;
  }

  @override
  Int8List getMatrix() {
    final matris = Int8List(width * height);
    for (var y = 0; y < height; y++) {
      final bas = y * _kare.satirBaytlari;
      matris.setRange(
        y * width,
        (y + 1) * width,
        Int8List.sublistView(_kare.baytlar, bas, bas + width),
      );
    }
    return matris;
  }
}
