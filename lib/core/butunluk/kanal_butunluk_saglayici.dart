import 'package:flutter/services.dart';

import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';

/// Play Integrity'nin bağlı olduğu Google Cloud projesinin numarası
/// (istemci ADR-0023 §3). Public bir değerdir (APK'dan okunabilir; kesin
/// kural 6); derlemede `--dart-define=TAYFAM_BULUT_PROJE_NUMARASI` ile
/// değiştirilebilir.
const int butunlukBulutProjeNumarasi = int.fromEnvironment(
  'TAYFAM_BULUT_PROJE_NUMARASI',
  defaultValue: 73439258394,
);

/// [ButunlukSaglayici]'nın Android uygulaması: `tayfam/butunluk` platform
/// kanalı üzerinden Kotlin köprüsü (`ButunlukKoprusu.kt`) ve Google'ın
/// `com.google.android.play:integrity` kütüphanesi (standard request).
///
/// Token sağlayıcısını köprü bellekte tutar. Kanal hata kodu
/// [ButunlukHatasiTuru] adıdır; mesaj ve ayrıntı taşınmaz. Hiçbir şey
/// loglanmaz.
final class KanalButunlukSaglayici implements ButunlukSaglayici {
  KanalButunlukSaglayici({
    MethodChannel? kanal,
    this._projeNumarasi = butunlukBulutProjeNumarasi,
  }) : _kanal = kanal ?? const MethodChannel(kanalAdi);

  /// Platform kanalının adı (Kotlin tarafıyla aynı).
  static const String kanalAdi = 'tayfam/butunluk';

  final MethodChannel _kanal;
  final int _projeNumarasi;

  @override
  Future<void> hazirla() async {
    try {
      await _kanal.invokeMethod<void>('hazirla', {'proje': _projeNumarasi});
    } on PlatformException {
      // İlk token isteği yeniden hazırlar.
    } on MissingPluginException {
      // Köprü yok (test ortamı).
    }
  }

  @override
  Future<String?> token(String istekOzeti) async {
    final Object? sonuc;
    try {
      sonuc = await _kanal.invokeMethod<Object?>('token', {
        'proje': _projeNumarasi,
        'istekOzeti': istekOzeti,
      });
    } on PlatformException catch (e) {
      throw ButunlukHatasi(_tur(e.code));
    } on MissingPluginException {
      return null;
    }
    if (sonuc is String && sonuc.isNotEmpty) return sonuc;
    throw const ButunlukHatasi(ButunlukHatasiTuru.bilinmeyen);
  }

  static ButunlukHatasiTuru _tur(String kod) {
    for (final t in ButunlukHatasiTuru.values) {
      if (t.name == kod) return t;
    }
    return ButunlukHatasiTuru.bilinmeyen;
  }
}
