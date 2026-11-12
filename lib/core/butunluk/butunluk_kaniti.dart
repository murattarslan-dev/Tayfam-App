import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/butunluk/butunluk_baglama.dart';
import 'package:tayfam/core/butunluk/butunluk_saglayici.dart';
import 'package:tayfam/core/butunluk/kanal_butunluk_saglayici.dart';

/// Giriş ve yenileme isteklerine eklenecek bütünlük kanıtı (istemci
/// ADR-0023).
///
/// Hiçbir zaman hata fırlatmaz: kanıt alınamazsa (platform yok, Play
/// hatası, [zamanAsimi] aşıldı) `null` döner ve istek kanıtsız gider
/// (sunucu `report` modunda bunu yalnızca sayar). Günlüğe yalnızca hata
/// türü yazılır; token, nonce, yenileme token'ı ve istek özeti yazılmaz.
final class ButunlukKaniti {
  ButunlukKaniti(
    this._saglayici, {
    this.zamanAsimi = varsayilanZamanAsimi,
    this._gunluk = varsayilanApiGunlugu,
  });

  /// Kanıt alma bu süreyi aşarsa istek kanıtsız gider.
  static const Duration varsayilanZamanAsimi = Duration(seconds: 5);

  /// Sözleşmedeki `integrity_token` üst sınırı (`maxLength: 16384`).
  static const int enUzunToken = 16384;

  final ButunlukSaglayici _saglayici;
  final ApiGunlugu _gunluk;

  /// Kanıt alma süresinin üst sınırı.
  final Duration zamanAsimi;

  /// `POST /v1/auth/sign-in` için, [nonce]'a bağlı kanıt.
  Future<String?> giris(String nonce) => _al(girisBaglamasi(nonce));

  /// `POST /v1/auth/refresh` için, [yenilemeTokeni]'nin özetine bağlı
  /// kanıt. Yenileme token'ı sağlayıcıya gitmez.
  Future<String?> yenileme(String yenilemeTokeni) =>
      _al(yenilemeBaglamasi(yenilemeTokeni));

  Future<String?> _al(String istekOzeti) async {
    final String? token;
    try {
      token = await _saglayici.token(istekOzeti).timeout(zamanAsimi);
    } on TimeoutException {
      _gunluk('bütünlük: zaman aşımı');
      return null;
    } on ButunlukHatasi catch (hata) {
      _gunluk('bütünlük: ${hata.tur.name}');
      return null;
    } on Exception {
      _gunluk('bütünlük: bilinmeyen');
      return null;
    }
    if (token == null) return null;
    if (token.isEmpty || token.length > enUzunToken) {
      _gunluk('bütünlük: geçersiz token');
      return null;
    }
    return token;
  }
}

/// Uygulamanın bütünlük sağlayıcısı (kalıcı). Android'de Play Integrity
/// köprüsü; web geliştirme derlemesinde ve iOS'ta (App Attest iOS sürümüne
/// kalır) [OlmayanButunlukSaglayici].
final butunlukSaglayiciProvider = Provider<ButunlukSaglayici>(
  _butunlukSaglayiciOlustur,
  name: 'butunlukSaglayiciProvider',
);

ButunlukSaglayici _butunlukSaglayiciOlustur(Ref ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const OlmayanButunlukSaglayici();
  }
  return KanalButunlukSaglayici();
}

/// Uygulama açılışında token sağlayıcısını bir kez hazırlar (istemci
/// ADR-0023 §3); kökteki `TayfamApp` izler. Hazırlık başarısızsa ilk token
/// isteği yeniden dener.
final butunlukHazirligiProvider = Provider<void>((ref) {
  unawaited(ref.watch(butunlukSaglayiciProvider).hazirla());
}, name: 'butunlukHazirligiProvider');

/// Giriş ve yenilemenin kullandığı [ButunlukKaniti] (kalıcı).
final butunlukKanitiProvider = Provider<ButunlukKaniti>(
  (ref) => ButunlukKaniti(ref.watch(butunlukSaglayiciProvider)),
  name: 'butunlukKanitiProvider',
);
