import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// JPEG'in başlığından okunan ölçüler.
@immutable
final class JpegOlculeri {
  const JpegOlculeri(this.genislik, this.yukseklik);

  final int genislik;
  final int yukseklik;

  /// En uzun kenar.
  int get uzunKenar => genislik > yukseklik ? genislik : yukseklik;

  @override
  bool operator ==(Object other) =>
      other is JpegOlculeri &&
      other.genislik == genislik &&
      other.yukseklik == yukseklik;

  @override
  int get hashCode => Object.hash(genislik, yukseklik);

  @override
  String toString() => 'JpegOlculeri($genislik×$yukseklik)';
}

/// JPEG ayrıştırılamadı ya da kurala uymuyor (ADR-0021 §3). Mesajda dosya
/// içeriği yoktur.
final class JpegHatasi implements Exception {
  const JpegHatasi(this.neden);

  /// Kısa makine kodu: `jpeg_degil`, `bozuk`, `metadata`.
  final String neden;

  @override
  String toString() => 'JpegHatasi($neden)';
}

// İşaretçiler (ITU T.81, Tablo B.1).
const int _soi = 0xD8;
const int _eoi = 0xD9;
const int _sos = 0xDA;
const int _app0 = 0xE0;
const int _app2 = 0xE2;
const int _app14 = 0xEE;
const int _com = 0xFE;

bool _sofMu(int m) => switch (m) {
  0xC0 || 0xC1 || 0xC2 || 0xC3 || 0xC5 || 0xC6 || 0xC7 => true,
  0xC9 || 0xCA || 0xCB || 0xCD || 0xCE || 0xCF => true,
  _ => false,
};

/// Uzunluğu olmayan işaretçiler: TEM ve RSTn.
bool _uzunluksuz(int m) => m == 0x01 || (m >= 0xD0 && m <= 0xD7);

bool _onEkli(Uint8List b, int bas, int son, String onEk) {
  if (son - bas < onEk.length) return false;
  for (var i = 0; i < onEk.length; i++) {
    if (b[bas + i] != onEk.codeUnitAt(i)) return false;
  }
  return true;
}

/// Görüntü verisi için gereken segmentler kalır, geri kalan her şey atılır:
///
/// - Kalan: DQT, DHT, DAC, DRI, DNL, SOFn, SOS ve tarama verisi; renk için
///   ICC profili (`APP2 "ICC_PROFILE"`) ve Adobe dönüşüm bilgisi
///   (`APP14 "Adobe"`). JFIF (`APP0 "JFIF"`) yalnızca küçük resmi
///   (thumbnail) olmadan yeniden yazılır.
/// - Atılan: bütün öteki uygulama segmentleri (EXIF ve GPS, XMP,
///   genişletilmiş XMP, MPF, IPTC/Photoshop, JFXX küçük resmi, üretici
///   segmentleri), yorumlar (COM), ayrılmış JPGn işaretçileri ve EOI'den
///   sonraki her bayt (MPF ikinci resmi, "motion photo" videosu,
///   sondaki eklemeler).
///
/// Bozuk ya da JPEG olmayan girdi [JpegHatasi] fırlatır. Piksel verisine
/// dokunulmaz; yalnızca segmentler seçilir (kayıpsız).
Uint8List jpegTemizle(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != _soi) {
    throw const JpegHatasi('jpeg_degil');
  }
  final cikti = BytesBuilder(copy: false)..add(const [0xFF, _soi]);
  var sofVar = false;
  var taramaVar = false;
  var i = 2;
  while (true) {
    if (i >= b.length || b[i] != 0xFF) throw const JpegHatasi('bozuk');
    // Dolgu baytları (FF FF …).
    while (i + 1 < b.length && b[i + 1] == 0xFF) {
      i++;
    }
    if (i + 1 >= b.length) throw const JpegHatasi('bozuk');
    final m = b[i + 1];
    if (m == _eoi) {
      if (!sofVar || !taramaVar) throw const JpegHatasi('bozuk');
      cikti.add(const [0xFF, _eoi]);
      return cikti.takeBytes();
    }
    if (m == _soi || m == 0x00) throw const JpegHatasi('bozuk');
    if (_uzunluksuz(m)) {
      cikti.add([0xFF, m]);
      i += 2;
      continue;
    }
    if (i + 4 > b.length) throw const JpegHatasi('bozuk');
    final n = (b[i + 2] << 8) | b[i + 3];
    final son = i + 2 + n;
    if (n < 2 || son > b.length) throw const JpegHatasi('bozuk');
    final govdeBas = i + 4;
    switch (m) {
      case _app0:
        // JFIF: sürüm, birim ve yoğunluk kalır; küçük resim (Xthumbnail,
        // Ythumbnail ve pikselleri) atılır.
        if (_onEkli(b, govdeBas, son, 'JFIF\u0000') && n >= 16) {
          cikti
            ..add(const [0xFF, _app0, 0x00, 0x10])
            ..add(Uint8List.sublistView(b, govdeBas, govdeBas + 12))
            ..add(const [0x00, 0x00]);
        }
      case _app2:
        if (_onEkli(b, govdeBas, son, 'ICC_PROFILE\u0000')) {
          cikti.add(Uint8List.sublistView(b, i, son));
        }
      case _app14:
        if (_onEkli(b, govdeBas, son, 'Adobe')) {
          cikti.add(Uint8List.sublistView(b, i, son));
        }
      case _com:
        break;
      case final x when x >= 0xE0 && x <= 0xEF:
        break; // Diğer bütün APPn: metadata.
      case final x when x >= 0xF0 && x <= 0xFD:
        break; // JPGn: ayrılmış.
      default:
        if (_sofMu(m)) {
          if (sofVar || n < 8) throw const JpegHatasi('bozuk');
          sofVar = true;
        }
        cikti.add(Uint8List.sublistView(b, i, son));
    }
    i = son;
    if (m == _sos) {
      if (!sofVar) throw const JpegHatasi('bozuk');
      taramaVar = true;
      // Tarama verisi: bir sonraki gerçek işaretçiye kadar (FF 00 doldurma
      // ve RSTn verinin parçasıdır).
      var j = i;
      while (true) {
        if (j + 1 >= b.length) throw const JpegHatasi('bozuk');
        if (b[j] == 0xFF) {
          final s = b[j + 1];
          if (s == 0x00 || (s >= 0xD0 && s <= 0xD7)) {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      cikti.add(Uint8List.sublistView(b, i, j));
      i = j;
    }
  }
}

/// [b]'nin sunucunun denetimini geçeceğini doğrular ve ölçülerini döndürür
/// (Tayfam-Api ADR-0020 §2'deki denetimin aynısı, daha sıkı):
///
/// - `FF D8 FF` ile başlar, `FF D9` ile biter, sonrasında bayt yoktur;
/// - ilk SOS'a kadar tek bir SOFn vardır ve ölçüler sıfır değildir;
/// - dosyanın hiçbir yerinde (ilerleyen taramalar arası dahil) JFIF, ICC
///   ve Adobe dışında APPn ya da COM segmenti yoktur.
///
/// Kurala uymayan dosya [JpegHatasi] fırlatır (`metadata` ya da `bozuk`).
JpegOlculeri jpegDenetle(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != _soi || b[2] != 0xFF) {
    throw const JpegHatasi('jpeg_degil');
  }
  if (b[b.length - 2] != 0xFF || b[b.length - 1] != _eoi) {
    throw const JpegHatasi('bozuk');
  }
  JpegOlculeri? olcu;
  var i = 2;
  while (true) {
    if (i + 1 >= b.length || b[i] != 0xFF) throw const JpegHatasi('bozuk');
    final m = b[i + 1];
    if (m == 0xFF) {
      i++;
      continue;
    }
    if (m == _eoi) {
      if (i + 2 != b.length || olcu == null) throw const JpegHatasi('bozuk');
      return olcu;
    }
    if (m == _soi || m == 0x00) throw const JpegHatasi('bozuk');
    if (_uzunluksuz(m)) {
      i += 2;
      continue;
    }
    if (i + 4 > b.length) throw const JpegHatasi('bozuk');
    final n = (b[i + 2] << 8) | b[i + 3];
    final son = i + 2 + n;
    if (n < 2 || son > b.length) throw const JpegHatasi('bozuk');
    final g = i + 4;
    final izinli = switch (m) {
      _app0 => _onEkli(b, g, son, 'JFIF\u0000'),
      _app2 => _onEkli(b, g, son, 'ICC_PROFILE\u0000'),
      _app14 => _onEkli(b, g, son, 'Adobe'),
      _com => false,
      final x when x >= 0xE0 && x <= 0xEF => false,
      _ => true,
    };
    if (!izinli) throw const JpegHatasi('metadata');
    if (_sofMu(m)) {
      if (olcu != null || n < 8) throw const JpegHatasi('bozuk');
      final y = (b[g + 1] << 8) | b[g + 2];
      final x = (b[g + 3] << 8) | b[g + 4];
      if (x == 0 || y == 0) throw const JpegHatasi('bozuk');
      olcu = JpegOlculeri(x, y);
    }
    i = son;
    if (m == _sos) {
      if (olcu == null) throw const JpegHatasi('bozuk');
      var j = i;
      while (true) {
        if (j + 1 >= b.length) throw const JpegHatasi('bozuk');
        if (b[j] == 0xFF) {
          final s = b[j + 1];
          if (s == 0x00 || (s >= 0xD0 && s <= 0xD7)) {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      i = j;
    }
  }
}
