/// Platformun bütünlük kanıtı sağlayıcısı (istemci ADR-0023 §3).
///
/// Android'de Play Integrity (standard request), web geliştirme
/// derlemesinde ve iOS'ta (App Attest iOS sürümüne kalır) yoktur.
abstract interface class ButunlukSaglayici {
  /// Token sağlayıcısını önceden hazırlar (Android:
  /// `prepareIntegrityToken`). Hata fırlatmaz; hazırlık başarısızsa ilk
  /// [token] çağrısı yeniden dener.
  Future<void> hazirla();

  /// [istekOzeti]'ne (base64url, dolgusuz, 43 karakter) bağlı bütünlük
  /// token'ı. Platform desteklemiyorsa `null`; alınamazsa
  /// [ButunlukHatasi].
  Future<String?> token(String istekOzeti);
}

/// Bütünlük token'ı alınamamasının türü. Kotlin köprüsündeki
/// `ButunlukHatasiTuru` adlarıyla aynıdır; mesaj taşınmaz.
enum ButunlukHatasiTuru {
  /// Google Play Store ya da Play hizmetleri yok.
  playYok,

  /// Play Store, Play hizmetleri ya da Play Integrity API'si eski veya
  /// kullanılamıyor.
  playEski,

  /// Ağ hatası.
  ag,

  /// Google'ın istek kotası aşıldı.
  kota,

  /// Google'ın ya da istemcinin geçici hatası.
  gecici,

  /// Uygulama ya da bulut projesi yapılandırma hatası (bulut proje numarası,
  /// uygulama kimliği, istek özeti).
  yapilandirma,

  /// Token sağlayıcısı yeniden hazırlandıktan sonra da geçersiz.
  saglayiciGecersiz,

  /// Tanınmayan hata.
  bilinmeyen,
}

/// Bütünlük token'ı alınamadı. Yalnızca türü taşır; token, istek özeti ya
/// da platform mesajı yoktur.
final class ButunlukHatasi implements Exception {
  const ButunlukHatasi(this.tur);

  final ButunlukHatasiTuru tur;

  @override
  String toString() => 'ButunlukHatasi(${tur.name})';
}

/// Bütünlük kanıtı olmayan derleme (web geliştirme derlemesi, iOS): her
/// çağrı `null`.
final class OlmayanButunlukSaglayici implements ButunlukSaglayici {
  const OlmayanButunlukSaglayici();

  @override
  Future<void> hazirla() async {}

  @override
  Future<String?> token(String istekOzeti) async => null;
}
