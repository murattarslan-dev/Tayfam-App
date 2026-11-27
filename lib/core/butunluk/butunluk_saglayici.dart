import 'package:tayfam/core/api/gen/models.dart';

/// Kanıtın hangi istek için alındığı. iOS'ta giriş yeni bir App Attest
/// anahtarını onaylatır (attestation), yenileme o anahtarla imza üretir
/// (assertion); Android'de ikisi aynıdır (Tayfam-Api ADR-0022 §4).
enum ButunlukIstegi { giris, yenileme }

/// İstek gövdesine eklenecek bütünlük kanıtı: Android'de Play Integrity
/// token'ı (`integrity_token`), iOS'ta App Attest kanıtı (`app_attest`);
/// ikisinden yalnızca biri doludur. Değerleri loglanmaz.
final class IstekKaniti {
  const IstekKaniti.play(String this.integrityToken) : appAttest = null;

  const IstekKaniti.appAttest(AppAttestProof this.appAttest)
    : integrityToken = null;

  final String? integrityToken;
  final AppAttestProof? appAttest;
}

/// Platformun bütünlük kanıtı sağlayıcısı (istemci ADR-0023 §3).
///
/// Android'de Play Integrity (standard request), iOS'ta App Attest
/// (ADR-0034 §7); web geliştirme derlemesinde ve App Attest'i desteklemeyen
/// cihazda (simülatör) yoktur.
abstract interface class ButunlukSaglayici {
  /// Token sağlayıcısını önceden hazırlar (Android:
  /// `prepareIntegrityToken`). Hata fırlatmaz; hazırlık başarısızsa ilk
  /// [kanit] çağrısı yeniden dener.
  Future<void> hazirla();

  /// [istekOzeti]'ne (base64url, dolgusuz, 43 karakter) bağlı bütünlük
  /// kanıtı. Platform desteklemiyorsa `null`; alınamazsa [ButunlukHatasi].
  Future<IstekKaniti?> kanit(String istekOzeti, ButunlukIstegi istek);

  /// Giriş [kanit]'la başarıyla döndü: iOS'ta onaylanan anahtarın
  /// kimliği ancak şimdi kalıcı yazılır (sunucu anahtarı bu girişle
  /// bağladı). Android'de yapacak bir şey yoktur. Hata fırlatabilir; çağıran
  /// yutar.
  Future<void> kaydet(IstekKaniti kanit);

  /// Oturum kapanınca cihazdaki kanıt anahtarının kaydını siler (iOS: App
  /// Attest anahtar kimliği; Android'de yapacak bir şey yoktur). Hata
  /// fırlatabilir; çağıran yutar.
  Future<void> unut();
}

/// Bütünlük token'ı alınamamasının türü. Kotlin köprüsündeki
/// `ButunlukHatasiTuru` ve Swift köprüsündeki `ButunlukHatasiTuru` adlarıyla
/// aynıdır; mesaj taşınmaz.
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

  /// App Attest bu cihazda yok ya da anahtar geçersiz (iOS; örneğin
  /// uygulama yeniden kuruldu). Bir sonraki giriş yeni anahtar üretir.
  anahtarYok,

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

/// Bütünlük kanıtı olmayan derleme (web geliştirme derlemesi): her
/// çağrı `null`.
final class OlmayanButunlukSaglayici implements ButunlukSaglayici {
  const OlmayanButunlukSaglayici();

  @override
  Future<void> hazirla() async {}

  @override
  Future<IstekKaniti?> kanit(String istekOzeti, ButunlukIstegi istek) async =>
      null;

  @override
  Future<void> kaydet(IstekKaniti kanit) async {}

  @override
  Future<void> unut() async {}
}
