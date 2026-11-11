import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sistem paylaşım sayfasına verilecek dosyalar için uygulamanın geçici
/// klasörü (ADR-0022; ADR-0006'ya dar istisna).
///
/// Paylaşım sayfası yalnızca dosya yolu kabul ettiği için içerik paylaşım
/// süresince bu klasöre yazılır ve paylaşım biter bitmez (başarısız olsa
/// da) [temizle] ile silinir. Uygulama paylaşım sırasında kapanırsa
/// artık dosya bir sonraki açılışta [artikGeciciDosyalariTemizle] ile
/// silinir.
///
/// - Klasör uygulamanın kendi geçici dizinindedir (Android'de
///   `code_cache`, iOS'ta sandbox `tmp`); başka uygulamalar okuyamaz.
/// - Android'de `share_plus` paylaşılan dosyanın bir kopyasını
///   `cache/share_plus/` altına koyar ve onu bir sonraki paylaşımda siler;
///   alıcı uygulama kopyayı paylaşımdan sonra da okuyabileceği için kopya
///   hemen silinmez, açılış temizliğinde ([paylasimKopyalari]) silinir.
/// - Dosya adı içerik taşımaz; yollar log'a yazılmaz.
final class GeciciDosyalar {
  GeciciDosyalar({required this.klasor, this.paylasimKopyalari});

  /// Cihazın gerçek geçici dizini. Web'de kullanılmaz (`dart:io` yok).
  factory GeciciDosyalar.cihaz() {
    // kural-istisnası: diske-yazma — ADR-0022: uygulamanın kendi geçici dizini
    final sistem = Directory.systemTemp;
    return GeciciDosyalar(
      // kural-istisnası: diske-yazma — ADR-0022: paylaşım için geçici klasör; paylaşımdan sonra silinir
      klasor: Directory('${sistem.path}${Platform.pathSeparator}$klasorAdi'),
      paylasimKopyalari: Platform.isAndroid
          ? _sharePlusKopyalari(sistem)
          : null,
    );
  }

  /// Uygulamanın geçici klasörünün adı.
  static const String klasorAdi = 'tayfam_paylasim';

  /// Paylaşılacak dosyaların klasörü.
  final Directory klasor;

  /// Android'de `share_plus`'ın kopyaları (`<veri>/cache/share_plus`);
  /// yalnızca açılış temizliğinde silinir.
  final Directory? paylasimKopyalari;

  /// Android'de `Directory.systemTemp` uygulamanın `code_cache` dizinidir
  /// (Flutter gömücüsü); `share_plus` kopyaları kardeş `cache` dizinindedir.
  static Directory _sharePlusKopyalari(Directory sistem) {
    final ayrac = Platform.pathSeparator;
    final veri = sistem.parent.path;
    // kural-istisnası: diske-yazma — ADR-0022: yalnızca silmek için share_plus kopya klasörü
    return Directory('$veri${ayrac}cache${ayrac}share_plus');
  }

  /// [icerik]'i klasördeki [dosyaAdi]'na yazar; klasörde başka dosya
  /// bırakmaz. [dosyaAdi] yalnızca güvenli karakterlerden oluşur.
  Future<File> yaz(String dosyaAdi, Uint8List icerik) async {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(dosyaAdi) ||
        dosyaAdi.startsWith('.')) {
      throw ArgumentError('Geçersiz dosya adı');
    }
    await temizle();
    await klasor.create(recursive: true);
    final yol = '${klasor.path}${Platform.pathSeparator}$dosyaAdi';
    // kural-istisnası: diske-yazma — ADR-0022: paylaşılacak dosya; paylaşımdan sonra silinir
    final dosya = File(yol);
    // kural-istisnası: diske-yazma — ADR-0022: paylaşılacak dosya; paylaşımdan sonra silinir
    await dosya.writeAsBytes(icerik, flush: true);
    return dosya;
  }

  /// Uygulamanın geçici klasörünü siler. Silinemezse sessizce geçer
  /// (sistem geçici dizini kendisi de temizler).
  Future<void> temizle() => _sil(klasor);

  /// Açılış temizliği: geçici klasör ve (Android'de) `share_plus`
  /// kopyaları.
  Future<void> acilistaTemizle() async {
    await temizle();
    final kopyalar = paylasimKopyalari;
    if (kopyalar != null) await _sil(kopyalar);
  }

  static Future<void> _sil(Directory klasor) async {
    try {
      if (await klasor.exists()) await klasor.delete(recursive: true);
    } on FileSystemException {
      // Silinemezse bir sonraki açılışta yeniden denenir.
    }
  }
}

/// Uygulama açılırken önceki oturumdan kalmış paylaşım dosyalarını siler
/// (ADR-0022). Web'de bir şey yapmaz. Hata fırlatmaz.
Future<void> artikGeciciDosyalariTemizle() async {
  if (kIsWeb) return;
  try {
    await GeciciDosyalar.cihaz().acilistaTemizle();
  } on Object {
    // Açılışı hiçbir koşulda engellemez.
  }
}

/// Uygulamanın geçici dosyaları. Web'de okunmaz (paylaşım yok).
final geciciDosyalarProvider = Provider<GeciciDosyalar>(
  (ref) => GeciciDosyalar.cihaz(),
  name: 'geciciDosyalarProvider',
);
