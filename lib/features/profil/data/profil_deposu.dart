import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Profil ve hesap uçları (ADR-0018 §2). Yalnızca üretilmiş uç sınıflarını
/// kullanır; bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class ProfilDeposu {
  ProfilDeposu(ApiTransport istemci) : _me = MeApi(istemci);

  final MeApi _me;

  /// `GET /v1/me/account`: kimlik, görünen ad, referans kodu, görünürlük
  /// ayarları ve tanıtım bilgileri.
  Future<Account> hesap() => _me.getAccount();

  /// `PATCH /v1/me/account`.
  Future<Account> gorunurlukDegistir(ActivityVisibility gorunurluk) =>
      _me.updateAccount(body: AccountUpdate(activityVisibility: gorunurluk));

  /// `PATCH /v1/me/account`: görünen ad, doğum günü görünürlüğü ve profil
  /// tamamlama alanları (issue #184–#186). Gövdedeki alanlar değişir;
  /// sunucu güncel hesabı döndürür.
  Future<Account> guncelle(AccountUpdate degisiklik) =>
      _me.updateAccount(body: degisiklik);

  /// `POST /v1/me/profile-prompt/snooze`: profil tamamlama formu 7 gün
  /// istenmez ("Daha sonra doldur"; erteleme sunucuda tutulur).
  Future<void> ertele() => _me.snoozeProfilePrompt();

  /// `POST /v1/me/referral-code`: yeni kod; eskisi hemen geçersiz olur.
  Future<String> yeniReferansKodu() async =>
      (await _me.rotateReferralCode()).referralCode;

  /// `GET /v1/me/sessions`: en son kullanılan önce.
  Future<List<DeviceSession>> oturumlar() async =>
      (await _me.listSessions()).sessions;

  /// `DELETE /v1/me/sessions/{session_id}` (başka bir cihazın oturumu).
  Future<void> oturumuKapat(String oturumId) =>
      _me.revokeSession(sessionId: oturumId);

  /// `POST /v1/me/sessions/sign-out-others`: kapatılan oturum sayısı.
  Future<int> digerOturumlariKapat() async =>
      (await _me.revokeOtherSessions()).revokedCount;

  /// `PUT /v1/me/avatar`: hazır `avatar` yüklemesini avatar yapar; yeni
  /// avatarın kimliğini döndürür. Eski avatar sunucuda silinir.
  Future<String> avatarAyarla(String uploadId) async {
    final yanit = await _me.putAvatar(body: AvatarRequest(uploadId: uploadId));
    return yanit.avatarUploadId;
  }

  /// `DELETE /v1/me/avatar` (dosya silinir).
  Future<void> avatariKaldir() => _me.deleteAvatar();

  /// [kullaniciId] oturumdaki kullanıcının kendisi mi:
  /// `GET /v1/me/account`'un `user_id` alanıyla karşılaştırılır
  /// (Tayfam-Api #150; profil ucunun `self` alanına dolaylı başvuru yok).
  Future<bool> kendisiMi(String kullaniciId) async =>
      (await _me.getAccount()).userId == kullaniciId;

  /// `GET /v1/me/social-settings`: "Profilleme" ve "Beni önerme"
  /// (Tayfam-Api ADR-0030 §5); hiç değiştirilmediyse varsayılanlar.
  Future<SocialSettings> sosyalAyarlar() => _me.getSocialSettings();

  /// `PATCH /v1/me/social-settings`: verilen alanlar değişir; güncel
  /// ayarlar döner.
  Future<SocialSettings> sosyalAyarlariDegistir(SocialSettingsUpdate d) =>
      _me.updateSocialSettings(body: d);

  /// `DELETE /v1/me` (204). Son 10 dakikada sağlayıcıyla giriş
  /// yapılmamışsa `reauthentication-required`.
  ///
  /// [appleKodu], silmeden önceki Apple girişinin yetkilendirme kodudur ve
  /// yalnızca gövdede gider (Tayfam-Api ADR-0045 §4): sunucu onunla
  /// kullanıcının Apple token'larını iptal eder, sonra hesabı siler. Apple
  /// hesabında kod yoksa ya da reddedilirse yine
  /// `reauthentication-required`. Google hesabında verilmez; gövde
  /// gönderilmez.
  Future<void> hesabiSil({String? appleKodu}) => _me.deleteAccount(
    body: appleKodu == null
        ? null
        : DeleteAccountRequest(appleAuthorizationCode: appleKodu),
  );
}

/// Profil uçlarının deposu.
final profilDeposuProvider = Provider<ProfilDeposu>(
  (ref) => ProfilDeposu(ref.watch(apiClientProvider)),
  name: 'profilDeposuProvider',
);
