import 'package:flutter/services.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';

/// Play Integrity'nin bağlı olduğu Google Cloud projesinin numarası
/// (istemci ADR-0023 §3). Public bir değerdir (APK'dan okunabilir; kesin
/// kural 6); derlemede `--dart-define=TAYFAM_BULUT_PROJE_NUMARASI` ile
/// değiştirilebilir.
const int butunlukBulutProjeNumarasi = int.fromEnvironment(
  'TAYFAM_BULUT_PROJE_NUMARASI',
  defaultValue: 73439258394,
);

/// [ButunlukSaglayici]'nın platform kanalı uygulaması (`tayfam/butunluk`).
///
/// - Android: Kotlin köprüsü (`ButunlukKoprusu.kt`) ve Google'ın
///   `com.google.android.play:integrity` kütüphanesi (standard request).
///   Token sağlayıcısını köprü bellekte tutar.
/// - iOS ([appAttest]): Swift köprüsü (`ButunlukKoprusu.swift`) ve
///   `DCAppAttestService`. Girişte yeni anahtar üretilip onaylatılır,
///   yenilemede o anahtarla imza üretilir; anahtar kimliği Keychain'dedir
///   (ADR-0023 iOS notu). `clientDataHash` = SHA-256(istek özeti metni)
///   köprüde hesaplanır. Desteklemeyen cihazda (simülatör) köprü `null`
///   döner.
///
/// Kanal hata kodu [ButunlukHatasiTuru] adıdır; mesaj ve ayrıntı taşınmaz.
/// Hiçbir şey loglanmaz.
final class KanalButunlukSaglayici implements ButunlukSaglayici {
  KanalButunlukSaglayici({
    MethodChannel? kanal,
    this._projeNumarasi = butunlukBulutProjeNumarasi,
    this.appAttest = false,
  }) : _kanal = kanal ?? const MethodChannel(kanalAdi);

  /// Platform kanalının adı (Kotlin ve Swift tarafıyla aynı).
  static const String kanalAdi = 'tayfam/butunluk';

  final MethodChannel _kanal;
  final int _projeNumarasi;

  /// iOS köprüsü (App Attest) mı.
  final bool appAttest;

  @override
  Future<IstekKaniti?> kanit(String istekOzeti, ButunlukIstegi istek) async {
    if (!appAttest) {
      final t = await token(istekOzeti);
      return t == null ? null : IstekKaniti.play(t);
    }
    final Object? sonuc;
    try {
      sonuc = await _kanal.invokeMethod<Object?>('appAttest', {
        'istek': istek.name,
        'istekOzeti': istekOzeti,
      });
    } on PlatformException catch (e) {
      throw ButunlukHatasi(_tur(e.code));
    } on MissingPluginException {
      return null;
    }
    if (sonuc == null) return null;
    if (sonuc is! Map<Object?, Object?>) {
      throw const ButunlukHatasi(ButunlukHatasiTuru.bilinmeyen);
    }
    final keyId = sonuc['keyId'];
    final veri = sonuc['veri'];
    if (keyId is String && keyId.isNotEmpty && veri is String) {
      if (veri.isNotEmpty) {
        final kanit = istek == ButunlukIstegi.giris
            ? AppAttestProof(keyId: keyId, attestation: veri)
            : AppAttestProof(keyId: keyId, assertion: veri);
        return IstekKaniti.appAttest(kanit);
      }
    }
    throw const ButunlukHatasi(ButunlukHatasiTuru.bilinmeyen);
  }

  @override
  Future<void> hazirla() async {
    if (appAttest) return; // App Attest'in hazırlığı yok.
    try {
      await _kanal.invokeMethod<void>('hazirla', {'proje': _projeNumarasi});
    } on PlatformException {
      // İlk token isteği yeniden hazırlar.
    } on MissingPluginException {
      // Köprü yok (test ortamı).
    }
  }

  /// Android: [istekOzeti]'ne bağlı Play Integrity token'ı.
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
