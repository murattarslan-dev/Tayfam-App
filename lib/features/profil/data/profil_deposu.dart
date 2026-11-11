import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Profil ve hesap uçları (ADR-0018 §2). Yalnızca üretilmiş uç sınıflarını
/// kullanır; bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class ProfilDeposu {
  ProfilDeposu(ApiTransport istemci)
    : _me = MeApi(istemci),
      _users = UsersApi(istemci);

  final MeApi _me;
  final UsersApi _users;

  /// `GET /v1/me/account`: referans kodu ve katılım geçmişi görünürlüğü.
  Future<Account> hesap() => _me.getAccount();

  /// `PATCH /v1/me/account`.
  Future<Account> gorunurlukDegistir(ActivityVisibility gorunurluk) =>
      _me.updateAccount(body: AccountUpdate(activityVisibility: gorunurluk));

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

  /// `GET /v1/users/{user_id}/profile`'ın `self` alanı: [kullaniciId]
  /// oturumdaki kullanıcının kendisi mi.
  Future<bool> kendisiMi(String kullaniciId) async =>
      (await _users.getUserProfile(userId: kullaniciId)).self;

  /// `DELETE /v1/me` (204). Son 10 dakikada Google ile giriş yapılmamışsa
  /// `reauthentication-required`.
  Future<void> hesabiSil() => _me.deleteAccount();
}

/// Profil uçlarının deposu.
final profilDeposuProvider = Provider<ProfilDeposu>(
  (ref) => ProfilDeposu(ref.watch(apiClientProvider)),
  name: 'profilDeposuProvider',
);
