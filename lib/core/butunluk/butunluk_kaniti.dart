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
/// Hiçbir zaman hata fırlatmaz: kanıt alınamazsa (platform yok, Play ya da
/// App Attest hatası, [zamanAsimi] aşıldı) `null` döner ve istek kanıtsız gider
/// (sunucu `report` modunda bunu yalnızca sayar). Günlüğe yalnızca hata
/// türü yazılır; token, nonce, yenileme token'ı ve istek özeti yazılmaz.
final class ButunlukKaniti {
  ButunlukKaniti(
    this._saglayici, {
    this.zamanAsimi = varsayilanZamanAsimi,
    Duration? girisZamanAsimi,
    this._gunluk = varsayilanApiGunlugu,
  }) : girisZamanAsimi = girisZamanAsimi ?? zamanAsimi;

  /// Kanıt alma bu süreyi aşarsa istek kanıtsız gider.
  static const Duration varsayilanZamanAsimi = Duration(seconds: 5);

  /// iOS'ta giriş kanıtının süresi. `attestKey` Secure Enclave'de anahtar
  /// üretip Apple'ın onay sunucusuna tam bir tur gider; mobil ağda 5
  /// saniyeyi aşabilir. Giriş kullanıcının başlattığı, zaten Google ya da
  /// Apple girişini beklediği bir adımdır; 20 saniye hâlâ sınırlıdır.
  /// Süre aşılırsa giriş kanıtsız gider ve geç gelen anahtar hiçbir yere
  /// yazılmaz (kimlik ancak [girisBasarili] ile kaydedilir).
  static const Duration appAttestGirisZamanAsimi = Duration(seconds: 20);

  /// Sözleşmedeki `integrity_token` üst sınırı (`maxLength: 16384`).
  static const int enUzunToken = 16384;

  /// Sözleşmedeki App Attest sınırları (Tayfam-Api ADR-0022 §4), base64
  /// metin uzunluğu olarak: anahtar kimliği 32 bayt (44 karakter),
  /// attestation en çok 16 KiB, assertion en çok 1 KiB.
  static const int appAttestAnahtarUzunlugu = 44;
  static const int enUzunAttestation = (16384 + 2) ~/ 3 * 4;
  static const int enUzunAssertion = (1024 + 2) ~/ 3 * 4;

  final ButunlukSaglayici _saglayici;
  final ApiGunlugu _gunluk;

  /// Kanıt alma süresinin üst sınırı.
  final Duration zamanAsimi;

  /// Giriş kanıtı alma süresinin üst sınırı (iOS'ta daha uzun).
  final Duration girisZamanAsimi;

  /// `POST /v1/auth/sign-in` için, [nonce]'a bağlı kanıt.
  Future<IstekKaniti?> giris(String nonce) =>
      _al(girisBaglamasi(nonce), ButunlukIstegi.giris);

  /// `POST /v1/auth/refresh` için, [yenilemeTokeni]'nin özetine bağlı
  /// kanıt. Yenileme token'ı sağlayıcıya gitmez.
  Future<IstekKaniti?> yenileme(String yenilemeTokeni) =>
      _al(yenilemeBaglamasi(yenilemeTokeni), ButunlukIstegi.yenileme);

  /// Giriş isteği [kanit]'la başarıyla döndü. iOS'ta App Attest anahtar
  /// kimliği ancak şimdi Keychain'e yazılır: zaman aşımına uğramış ya da
  /// başarısız bir girişin anahtarı sonraki yenilemelerde kullanılmaz.
  /// Hata fırlatmaz.
  Future<void> girisBasarili(IstekKaniti? kanit) async {
    if (kanit == null || kanit.appAttest?.attestation == null) return;
    try {
      await _saglayici.kaydet(kanit).timeout(zamanAsimi);
    } on TimeoutException {
      _gunluk('bütünlük: kayıt zaman aşımı');
    } on Exception {
      _gunluk('bütünlük: kaydedilemedi');
    }
  }

  /// Oturum kapandı: cihazdaki kanıt anahtarının kaydı silinir (iOS'ta App
  /// Attest anahtar kimliği). Hata fırlatmaz; günlüğe yalnızca tür yazılır.
  Future<void> unut() async {
    try {
      await _saglayici.unut().timeout(zamanAsimi);
    } on TimeoutException {
      _gunluk('bütünlük: unutma zaman aşımı');
    } on Exception {
      _gunluk('bütünlük: unutulamadı');
    }
  }

  Future<IstekKaniti?> _al(String istekOzeti, ButunlukIstegi istek) async {
    final IstekKaniti? kanit;
    try {
      final sure = istek == ButunlukIstegi.giris ? girisZamanAsimi : zamanAsimi;
      kanit = await _saglayici.kanit(istekOzeti, istek).timeout(sure);
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
    if (kanit == null) return null;
    if (!_gecerli(kanit, istek)) {
      _gunluk('bütünlük: geçersiz token');
      return null;
    }
    return kanit;
  }

  static bool _gecerli(IstekKaniti kanit, ButunlukIstegi istek) {
    if (kanit.integrityToken case final token?) {
      return token.isNotEmpty && token.length <= enUzunToken;
    }
    final a = kanit.appAttest;
    if (a == null || a.keyId.length != appAttestAnahtarUzunlugu) return false;
    return switch (istek) {
      ButunlukIstegi.giris =>
        a.assertion == null && _sinirda(a.attestation, enUzunAttestation),
      ButunlukIstegi.yenileme =>
        a.attestation == null && _sinirda(a.assertion, enUzunAssertion),
    };
  }

  static bool _sinirda(String? deger, int enUzun) =>
      deger != null && deger.isNotEmpty && deger.length <= enUzun;
}

/// Uygulamanın bütünlük sağlayıcısı (kalıcı). Android'de Play Integrity,
/// iOS'ta App Attest köprüsü (aynı `tayfam/butunluk` kanalı, ADR-0034 §7);
/// web geliştirme derlemesinde [OlmayanButunlukSaglayici]. App Attest'i
/// desteklemeyen iOS cihazında (simülatör) köprü kanıtsız (`null`) döner.
final butunlukSaglayiciProvider = Provider<ButunlukSaglayici>(
  _butunlukSaglayiciOlustur,
  name: 'butunlukSaglayiciProvider',
);

ButunlukSaglayici _butunlukSaglayiciOlustur(Ref ref) {
  if (kIsWeb) return const OlmayanButunlukSaglayici();
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => KanalButunlukSaglayici(),
    TargetPlatform.iOS => KanalButunlukSaglayici(appAttest: true),
    _ => const OlmayanButunlukSaglayici(),
  };
}

/// Uygulama açılışında token sağlayıcısını bir kez hazırlar (istemci
/// ADR-0023 §3); kökteki `TayfamApp` izler. Hazırlık başarısızsa ilk token
/// isteği yeniden dener.
final butunlukHazirligiProvider = Provider<void>((ref) {
  unawaited(ref.watch(butunlukSaglayiciProvider).hazirla());
}, name: 'butunlukHazirligiProvider');

/// Giriş ve yenilemenin kullandığı [ButunlukKaniti] (kalıcı).
final butunlukKanitiProvider = Provider<ButunlukKaniti>(
  (ref) => ButunlukKaniti(
    ref.watch(butunlukSaglayiciProvider),
    girisZamanAsimi: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? ButunlukKaniti.appAttestGirisZamanAsimi
        : null,
  ),
  name: 'butunlukKanitiProvider',
);
