import 'dart:io';
import 'dart:typed_data';

/// RGBA piksellerini saydamlık kanalı olmayan (renk türü 2, 8 bit RGB)
/// bir PNG'ye çevirir.
///
/// App Store ekran görüntülerinde saydamlık kanalı kabul edilmez; Flutter'ın
/// `toByteData(format: png)` çıktısı her zaman RGBA'dır. Bu yüzden PNG
/// burada, standart kütüphanenin zlib'iyle yazılır (paket yok). Herhangi
/// bir piksel tam opak değilse [StateError] fırlatılır: görselde saydamlık
/// olmamalı.
Uint8List rgbPngKodla(Uint8List rgba, int genislik, int yukseklik) {
  if (rgba.length != genislik * yukseklik * 4) {
    throw ArgumentError('RGBA uzunluğu boyutla uyuşmuyor.');
  }
  final ham = Uint8List(yukseklik * (1 + genislik * 3));
  var yaz = 0;
  var oku = 0;
  for (var y = 0; y < yukseklik; y++) {
    // Satır başında süzgeç türü: 0 (yok).
    ham[yaz++] = 0;
    for (var x = 0; x < genislik; x++) {
      if (rgba[oku + 3] != 0xFF) {
        throw StateError('($x, $y) pikseli saydam; görselde saydamlık var.');
      }
      ham[yaz++] = rgba[oku];
      ham[yaz++] = rgba[oku + 1];
      ham[yaz++] = rgba[oku + 2];
      oku += 4;
    }
  }
  final baslik = ByteData(13)
    ..setUint32(0, genislik)
    ..setUint32(4, yukseklik)
    ..setUint8(8, 8) // bit derinliği
    ..setUint8(9, 2) // renk türü: RGB
    ..setUint8(10, 0) // sıkıştırma
    ..setUint8(11, 0) // süzgeç yöntemi
    ..setUint8(12, 0); // satır atlama yok
  final cikti = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _parca(cikti, 'IHDR', baslik.buffer.asUint8List());
  _parca(cikti, 'IDAT', ZLibCodec(level: 9).encoder.convert(ham));
  _parca(cikti, 'IEND', Uint8List(0));
  return cikti.toBytes();
}

void _parca(BytesBuilder cikti, String tur, List<int> veri) {
  final uzunluk = ByteData(4)..setUint32(0, veri.length);
  final turVeri = [...tur.codeUnits, ...veri];
  final crc = ByteData(4)..setUint32(0, _crc32(turVeri));
  cikti
    ..add(uzunluk.buffer.asUint8List())
    ..add(turVeri)
    ..add(crc.buffer.asUint8List());
}

final List<int> _crcTablosu = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> veri) {
  var c = 0xFFFFFFFF;
  for (final b in veri) {
    c = _crcTablosu[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// PNG'nin IHDR'den okunan genişliği, yüksekliği ve renk türü (testler
/// için).
({int genislik, int yukseklik, int renkTuru}) pngBasligi(List<int> png) {
  final b = ByteData.sublistView(Uint8List.fromList(png));
  return (
    genislik: b.getUint32(16),
    yukseklik: b.getUint32(20),
    renkTuru: b.getUint8(25),
  );
}
