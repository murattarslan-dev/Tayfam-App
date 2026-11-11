import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/medya/jpeg.dart';

/// `full` varyantının en uzun kenarı (Tayfam-Api ADR-0020 §1).
const int tamUzunKenar = 1600;

/// `preview` varyantının en uzun kenarı.
const int onizlemeUzunKenar = 400;

/// Varyant başına en çok bayt (sözleşme: 10 MiB).
const int varyantEnCokBayt = 10 * 1024 * 1024;

/// Okunacak kaynağın en çok boyutu; daha büyüğü belleğe alınmaz.
const int kaynakEnCokBayt = 40 * 1024 * 1024;

/// Platform kodlayıcısı: kaynak görüntüyü (HEIC, JPEG, PNG, WebP) çözer,
/// isteğe göre EXIF yönünü piksellere uygular, oranı koruyarak küçültür
/// ve JPEG kodlar (ADR-0021 §2).
///
/// Ölçek kuralı `flutter_image_compress`'inkidir: ölçek
/// `max(1, min(g / minGenislik, y / minYukseklik))`; görüntü hiçbir zaman
/// büyütülmez. [ornekleme] Android'de çözerken alt örneklemedir (bellek);
/// iOS onu yok sayar.
abstract interface class GoruntuKodlayici {
  Future<Uint8List> jpegKodla(
    Uint8List kaynak, {
    required int minGenislik,
    required int minYukseklik,
    required int kalite,
    required bool yonuUygula,
    int ornekleme = 1,
  });
}

/// `flutter_image_compress` ile platform kodlayıcıları (Android: Bitmap,
/// iOS: UIImage/ImageIO). EXIF hiçbir zaman kopyalanmaz (`keepExif: false`);
/// yine de çıktı [jpegTemizle]'den geçer.
final class PlatformGoruntuKodlayici implements GoruntuKodlayici {
  const PlatformGoruntuKodlayici();

  @override
  Future<Uint8List> jpegKodla(
    Uint8List kaynak, {
    required int minGenislik,
    required int minYukseklik,
    required int kalite,
    required bool yonuUygula,
    int ornekleme = 1,
  }) => FlutterImageCompress.compressWithList(
    kaynak,
    minWidth: minGenislik,
    minHeight: minYukseklik,
    quality: kalite,
    inSampleSize: ornekleme,
    autoCorrectionAngle: yonuUygula,
    format: CompressFormat.jpeg,
    keepExif: false,
  );
}

/// Uygulamanın görüntü kodlayıcısı; testlerde sahtesi verilir.
final goruntuKodlayiciProvider = Provider<GoruntuKodlayici>(
  (ref) => const PlatformGoruntuKodlayici(),
  name: 'goruntuKodlayiciProvider',
);

/// Hazırlamanın neden olmadığı.
enum GoruntuHatasiTuru {
  /// Dosya okunamadı ya da desteklenmeyen biçimde.
  okunamadi,

  /// Kaynak dosya çok büyük ([kaynakEnCokBayt]).
  cokBuyuk,

  /// Çıktı kurala uymadı (oran, ölçü, metadata, boyut). Beklenmez; olursa
  /// dosya gönderilmez.
  islenemedi,
}

/// Fotoğraf hazırlanamadı. Mesajda dosya içeriği yoktur.
final class GoruntuHatasi implements Exception {
  const GoruntuHatasi(this.tur);

  final GoruntuHatasiTuru tur;

  @override
  String toString() => 'GoruntuHatasi(${tur.name})';
}

/// Yüklemeye hazır iki varyant: ikisi de JPEG, metadata'sız, yönü
/// piksellerde (ADR-0021 §2–3).
@immutable
final class HazirGoruntu {
  const HazirGoruntu({
    required this.tam,
    required this.onizleme,
    required this.tamOlcu,
    required this.onizlemeOlcu,
  });

  final Uint8List tam;
  final Uint8List onizleme;
  final JpegOlculeri tamOlcu;
  final JpegOlculeri onizlemeOlcu;
}

/// Önizleme tam varyantla aynı oranda mı (sunucunun kuralı: en çok ±1 px
/// yuvarlama farkı; `|pg·ty − py·tg| ≤ max(tg, ty)`) ve ondan büyük değil
/// mi.
bool oranTutuyor(JpegOlculeri onizleme, JpegOlculeri tam) {
  if (onizleme.genislik > tam.genislik || onizleme.yukseklik > tam.yukseklik) {
    return false;
  }
  final fark =
      onizleme.genislik * tam.yukseklik - onizleme.yukseklik * tam.genislik;
  return fark.abs() <= tam.uzunKenar;
}

/// [uzunKenar] uzunluğunda kaynağı en az [hedef] px'te tutan en büyük
/// ikinin kuvveti alt örnekleme (Android'de bellek için).
@visibleForTesting
int orneklemeHesapla(int uzunKenar, int hedef) {
  var o = 1;
  while (uzunKenar ~/ (o * 2) >= hedef && o < 64) {
    o *= 2;
  }
  return o;
}

/// Fotoğrafı yüklemeye hazırlar (ADR-0021 §2):
///
/// 1. **Yoklama:** kaynak 1/8 alt örneklemeyle, ölçeklenmeden ve yönü
///    uygulanarak kodlanır; ölçülerinden yönelim (yatay/dikey) ve yaklaşık
///    boyut okunur.
/// 2. **Tam:** kaynak, yönelime göre uzun kenar [tamUzunKenar] olacak
///    şekilde (küçükse olduğu gibi) yönü uygulanarak kodlanır.
/// 3. **Önizleme:** tam varyanttan, uzun kenar [onizlemeUzunKenar].
/// 4. Her çıktı [jpegTemizle]'den geçer ve [jpegDenetle] ile sunucunun
///    kuralına göre denetlenir; ölçüler, oran ve boyut tutmazsa hiçbir şey
///    gönderilmez.
///
/// Bütün ara veriler bellektedir; diske bir şey yazılmaz.
final class GoruntuHazirlayici {
  const GoruntuHazirlayici(this._kodlayici);

  final GoruntuKodlayici _kodlayici;

  /// Yoklama alt örneklemesi.
  static const int yoklamaOrneklemesi = 8;

  /// "Ölçekleme yok" için kodlayıcıya verilen en küçük ölçü (ölçek 1'e
  /// sıkışır).
  static const int olceksiz = 100000;

  Future<HazirGoruntu> hazirla(Uint8List kaynak) async {
    if (kaynak.isEmpty) throw const GoruntuHatasi(GoruntuHatasiTuru.okunamadi);
    if (kaynak.length > kaynakEnCokBayt) {
      throw const GoruntuHatasi(GoruntuHatasiTuru.cokBuyuk);
    }

    final yoklama = _denetle(
      _temizle(
        await _kodla(
          kaynak,
          minGenislik: olceksiz,
          minYukseklik: olceksiz,
          kalite: 10,
          yonuUygula: true,
          ornekleme: yoklamaOrneklemesi,
        ),
      ),
    );
    final yatay = yoklama.genislik >= yoklama.yukseklik;
    // Android'de gerçek uzun kenar yaklaşık 8 katıdır (alt sınır); iOS alt
    // örneklemeyi yok saydığı için orada değer zaten gerçek boyuttur ve
    // örnekleme de yok sayılır.
    final ornekleme = orneklemeHesapla(
      yoklama.uzunKenar * yoklamaOrneklemesi,
      tamUzunKenar,
    );

    final tamHam = await _kodla(
      kaynak,
      minGenislik: yatay ? tamUzunKenar : 1,
      minYukseklik: yatay ? 1 : tamUzunKenar,
      kalite: 85,
      yonuUygula: true,
      ornekleme: ornekleme,
    );
    final tam = _temizle(tamHam);
    final tamOlcu = _denetle(tam);

    final onizlemeHam = await _kodla(
      tam,
      minGenislik: yatay ? onizlemeUzunKenar : 1,
      minYukseklik: yatay ? 1 : onizlemeUzunKenar,
      kalite: 80,
      yonuUygula: false,
    );
    final onizleme = _temizle(onizlemeHam);
    final onizlemeOlcu = _denetle(onizleme);

    if (tamOlcu.uzunKenar > tamUzunKenar ||
        onizlemeOlcu.uzunKenar > onizlemeUzunKenar ||
        !oranTutuyor(onizlemeOlcu, tamOlcu) ||
        tam.length > varyantEnCokBayt ||
        onizleme.length > varyantEnCokBayt) {
      throw const GoruntuHatasi(GoruntuHatasiTuru.islenemedi);
    }
    return HazirGoruntu(
      tam: tam,
      onizleme: onizleme,
      tamOlcu: tamOlcu,
      onizlemeOlcu: onizlemeOlcu,
    );
  }

  Future<Uint8List> _kodla(
    Uint8List kaynak, {
    required int minGenislik,
    required int minYukseklik,
    required int kalite,
    required bool yonuUygula,
    int ornekleme = 1,
  }) async {
    try {
      return await _kodlayici.jpegKodla(
        kaynak,
        minGenislik: minGenislik,
        minYukseklik: minYukseklik,
        kalite: kalite,
        yonuUygula: yonuUygula,
        ornekleme: ornekleme,
      );
    } on Exception {
      // PlatformException (çözülemeyen ya da desteklenmeyen dosya) dahil.
      throw const GoruntuHatasi(GoruntuHatasiTuru.okunamadi);
    }
  }

  static Uint8List _temizle(Uint8List b) {
    try {
      return jpegTemizle(b);
    } on JpegHatasi {
      throw const GoruntuHatasi(GoruntuHatasiTuru.islenemedi);
    }
  }

  static JpegOlculeri _denetle(Uint8List b) {
    try {
      return jpegDenetle(b);
    } on JpegHatasi {
      throw const GoruntuHatasi(GoruntuHatasiTuru.islenemedi);
    }
  }
}

/// Uygulamanın görüntü hazırlayıcısı.
final goruntuHazirlayiciProvider = Provider<GoruntuHazirlayici>(
  (ref) => GoruntuHazirlayici(ref.watch(goruntuKodlayiciProvider)),
  name: 'goruntuHazirlayiciProvider',
);
