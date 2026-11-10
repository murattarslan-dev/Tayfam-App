import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';

/// Giriş, kayıt ve onay ekranlarında gösterilen hata. Her değerin bir
/// çeviri anahtarı vardır (`hesap_hata_*`); sunucunun `title` / `detail`
/// metni hiçbir yerde gösterilmez (ADR-0005 §4).
enum HesapHatasi {
  /// Bağlantı yok ya da zaman aşımı.
  baglantiYok,

  /// `rate-limited`: bekle ve tekrar dene.
  cokFazlaDeneme,

  /// Google girişi bu derlemede (web) açılamıyor.
  webDesteklenmiyor,

  /// Google girişi başlatılamadı ya da `invalid-credentials`.
  googleGirisi,

  /// `consent-outdated`: metinler ekran açıkken güncellendi.
  metinlerGuncellendi,

  /// `invalid-birth-date`.
  gecersizDogumTarihi,

  /// `invalid-display-name`.
  gecersizAd,

  /// Diğer her şey (bilinmeyen kod dahil).
  genel,
}

/// [hata]'yı ekranda gösterilecek [HesapHatasi]'na çevirir.
HesapHatasi hesapHatasiOku(Object hata) => switch (hata) {
  ApiOffline() || ApiTimeout() => HesapHatasi.baglantiYok,
  ApiProblem(type: ProblemType.rateLimited) => HesapHatasi.cokFazlaDeneme,
  ApiProblem(type: ProblemType.invalidCredentials) => HesapHatasi.googleGirisi,
  ApiProblem(type: ProblemType.consentOutdated) =>
    HesapHatasi.metinlerGuncellendi,
  ApiProblem(type: ProblemType.invalidBirthDate) =>
    HesapHatasi.gecersizDogumTarihi,
  ApiProblem(type: ProblemType.invalidDisplayName) => HesapHatasi.gecersizAd,
  GoogleGirisHatasi(desteklenmiyor: true) => HesapHatasi.webDesteklenmiyor,
  GoogleGirisHatasi() => HesapHatasi.googleGirisi,
  _ => HesapHatasi.genel,
};
