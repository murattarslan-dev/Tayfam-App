import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/invitations_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/referral_lookups_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Arkadaş, istek, engel ve davet listelerinde bir sayfada istenen kayıt
/// sayısı (sözleşme: en çok 100).
const int arkadasSayfaBoyutu = 50;

/// Arkadaşlık, engelleme, doğrudan tayfa daveti ve kişi profili uçları
/// (ADR-0018 §7). Yalnızca üretilmiş uç sınıflarını kullanır; bütün
/// istekler tek `ApiClient`'tan geçer (ADR-0005).
///
/// Referans kodu yalnızca istek gövdesinde gider (sözleşme); burada
/// saklanmaz ve log'a yazılmaz (kesin kural 3).
final class ArkadasDeposu {
  ArkadasDeposu(ApiTransport istemci)
    : _ben = MeApi(istemci),
      _referans = ReferralLookupsApi(istemci),
      _davetler = InvitationsApi(istemci),
      _kullanicilar = UsersApi(istemci);

  final MeApi _ben;
  final ReferralLookupsApi _referans;
  final InvitationsApi _davetler;
  final UsersApi _kullanicilar;

  /// `GET /v1/me/friends`.
  Future<Sayfa<Friend>> arkadaslar({String? sayfaToken}) async {
    final liste = await _ben.listFriends(
      pageSize: arkadasSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.friends, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/me/friend-requests`: gelen ya da gönderilen istekler.
  Future<Sayfa<Friend>> istekler(
    ListFriendRequestsDirection yon, {
    String? sayfaToken,
    int sayfaBoyutu = arkadasSayfaBoyutu,
  }) async {
    final liste = await _ben.listFriendRequests(
      direction: yon,
      pageSize: sayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.friends, sonraki: liste.nextPageToken);
  }

  /// `POST /v1/me/friend-requests`. Karşı tarafın isteği bekliyorsa
  /// arkadaşlık hemen kurulur (`state: friends`).
  Future<Friend> istekGonder(String kullaniciId) =>
      _ben.sendFriendRequest(body: UserRef(userId: kullaniciId));

  /// `POST /v1/me/friend-requests/{user_id}/acceptance`.
  Future<Friend> istegiKabulEt(String kullaniciId) =>
      _ben.acceptFriendRequest(userId: kullaniciId);

  /// `DELETE /v1/me/friends/{user_id}`: arkadaşlığı bitirir, gönderilen
  /// isteği geri çeker ya da gelen isteği reddeder. Karşı tarafa
  /// bildirilmez.
  Future<void> arkadasligiKaldir(String kullaniciId) =>
      _ben.removeFriendship(userId: kullaniciId);

  /// `GET /v1/me/blocks`.
  Future<Sayfa<BlockedUser>> engellenenler({String? sayfaToken}) async {
    final liste = await _ben.listBlockedUsers(
      pageSize: arkadasSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.users, sonraki: liste.nextPageToken);
  }

  /// `PUT /v1/me/blocks/{user_id}`: arkadaşlık ve bekleyen istek silinir.
  Future<void> engelle(String kullaniciId) =>
      _ben.blockUser(userId: kullaniciId);

  /// `DELETE /v1/me/blocks/{user_id}`: arkadaşlık geri gelmez.
  Future<void> engeliKaldir(String kullaniciId) =>
      _ben.unblockUser(userId: kullaniciId);

  /// `POST /v1/referral-lookups`: kod gövdededir.
  Future<ReferredUser> kodlaBul(String kod) => _referans.lookupReferralCode(
    body: ReferralLookupRequest(referralCode: kod),
  );

  /// `POST /v1/tayfas/{tayfa_id}/invitations`: arkadaşı tayfaya davet eder.
  Future<Invitation> tayfayaDavetEt(String tayfaId, String kullaniciId) =>
      _davetler.inviteFriend(
        tayfaId: tayfaId,
        body: UserRef(userId: kullaniciId),
      );

  /// `GET /v1/me/invitations`: size gelen cevaplanmamış davetler.
  Future<Sayfa<Invitation>> gelenDavetler({
    String? sayfaToken,
    int sayfaBoyutu = arkadasSayfaBoyutu,
  }) async {
    final liste = await _ben.listMyInvitations(
      pageSize: sayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.invitations, sonraki: liste.nextPageToken);
  }

  /// `POST /v1/me/invitations/{tayfa_id}/acceptance`: üyelik etkin ya da
  /// onay bekliyor.
  Future<Membership> davetiKabulEt(String tayfaId) =>
      _ben.acceptInvitation(tayfaId: tayfaId);

  /// `DELETE /v1/me/invitations/{tayfa_id}`: davet edene bildirilmez.
  Future<void> davetiReddet(String tayfaId) =>
      _ben.declineInvitation(tayfaId: tayfaId);

  /// `GET /v1/users/{user_id}/profile`.
  Future<UserProfile> profil(String kullaniciId) =>
      _kullanicilar.getUserProfile(userId: kullaniciId);

  /// `GET /v1/users/{user_id}/activity`: görünürlüğe göre; yetki yoksa boş.
  Future<Sayfa<ActivityRecord>> katilimGecmisi(
    String kullaniciId, {
    String? sayfaToken,
    int sayfaBoyutu = arkadasSayfaBoyutu,
  }) async {
    final liste = await _kullanicilar.listUserActivity(
      userId: kullaniciId,
      pageSize: sayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.records, sonraki: liste.nextPageToken);
  }
}

/// Arkadaşlık uçlarının deposu.
final arkadasDeposuProvider = Provider<ArkadasDeposu>(
  (ref) => ArkadasDeposu(ref.watch(apiClientProvider)),
  name: 'arkadasDeposuProvider',
);
