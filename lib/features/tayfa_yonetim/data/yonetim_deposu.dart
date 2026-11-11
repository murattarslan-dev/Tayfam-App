import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/deletion_api.dart';
import 'package:tayfam/core/api/gen/apis/invites_api.dart';
import 'package:tayfam/core/api/gen/apis/join_code_api.dart';
import 'package:tayfam/core/api/gen/apis/join_requests_api.dart';
import 'package:tayfam/core/api/gen/apis/members_api.dart';
import 'package:tayfam/core/api/gen/apis/modules_api.dart';
import 'package:tayfam/core/api/gen/apis/notification_preferences_api.dart';
import 'package:tayfam/core/api/gen/apis/tayfas_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Üye ve katılım isteği listelerinde bir sayfada istenen kayıt sayısı
/// (sözleşme: en çok 100).
const int yonetimSayfaBoyutu = 50;

/// Tayfa yönetimi uçları (ADR-0018 §1). Yalnızca üretilmiş uç sınıflarını
/// kullanır; bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
///
/// Davet token'ı yalnızca [davetOlustur]'un dönüşünde vardır; burada
/// saklanmaz ve log'a yazılmaz (kesin kural 3, 9).
final class YonetimDeposu {
  YonetimDeposu(ApiTransport istemci)
    : _tayfalar = TayfasApi(istemci),
      _moduller = ModulesApi(istemci),
      _kod = JoinCodeApi(istemci),
      _silme = DeletionApi(istemci),
      _uyeler = MembersApi(istemci),
      _istekler = JoinRequestsApi(istemci),
      _davetler = InvitesApi(istemci),
      _bildirim = NotificationPreferencesApi(istemci);

  final TayfasApi _tayfalar;
  final ModulesApi _moduller;
  final JoinCodeApi _kod;
  final DeletionApi _silme;
  final MembersApi _uyeler;
  final JoinRequestsApi _istekler;
  final InvitesApi _davetler;
  final NotificationPreferencesApi _bildirim;

  /// `PATCH /v1/tayfas/{tayfa_id}`: yalnızca gövdedeki alanlar değişir.
  Future<Tayfa> bilgileriGuncelle(String tayfaId, TayfaUpdateRequest istek) =>
      _tayfalar.updateTayfa(tayfaId: tayfaId, body: istek);

  /// `PUT /v1/tayfas/{tayfa_id}/modules/{module}`.
  Future<void> modulAyarla(
    String tayfaId,
    Module modul, {
    required bool acik,
  }) => _moduller.setTayfaModule(
    tayfaId: tayfaId,
    module: modul,
    body: ModuleUpdate(enabled: acik),
  );

  /// `POST /v1/tayfas/{tayfa_id}/join-code`: eski kod hemen geçersiz olur.
  Future<String> koduYenile(String tayfaId) async =>
      (await _kod.rotateJoinCode(tayfaId: tayfaId)).joinCode;

  /// `POST /v1/tayfas/{tayfa_id}/deletion`: silinme zamanı.
  Future<DateTime> silmeIste(String tayfaId) async =>
      (await _silme.requestTayfaDeletion(tayfaId: tayfaId)).deletionAt;

  /// `DELETE /v1/tayfas/{tayfa_id}/deletion`.
  Future<void> silmeyiIptalEt(String tayfaId) =>
      _silme.cancelTayfaDeletion(tayfaId: tayfaId);

  /// `GET /v1/tayfas/{tayfa_id}/members`: [durum] etkin ya da banlı.
  Future<Sayfa<Membership>> uyeler(
    String tayfaId, {
    required ListMembersStatus durum,
    String? sayfaToken,
  }) async {
    final liste = await _uyeler.listMembers(
      tayfaId: tayfaId,
      status: durum,
      pageSize: yonetimSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.members, sonraki: liste.nextPageToken);
  }

  /// `PATCH /v1/tayfas/{tayfa_id}/members/{user_id}`.
  Future<Membership> rolDegistir(String tayfaId, String uyeId, Role rol) =>
      _uyeler.changeMemberRole(
        tayfaId: tayfaId,
        userId: uyeId,
        body: RoleUpdate(role: rol),
      );

  /// `PUT …/members/{user_id}/mute`: [bitis]'e kadar susturur.
  Future<Membership> sustur(String tayfaId, String uyeId, DateTime bitis) =>
      _uyeler.muteMember(
        tayfaId: tayfaId,
        userId: uyeId,
        body: MuteRequest(mutedUntil: bitis.toUtc()),
      );

  /// `DELETE …/members/{user_id}/mute`.
  Future<Membership> susturmayiKaldir(String tayfaId, String uyeId) =>
      _uyeler.unmuteMember(tayfaId: tayfaId, userId: uyeId);

  /// `DELETE /v1/tayfas/{tayfa_id}/members/{user_id}`.
  Future<void> cikar(String tayfaId, String uyeId) =>
      _uyeler.removeMember(tayfaId: tayfaId, userId: uyeId);

  /// `PUT …/members/{user_id}/ban`.
  Future<void> banla(String tayfaId, String uyeId) =>
      _uyeler.banMember(tayfaId: tayfaId, userId: uyeId);

  /// `GET /v1/tayfas/{tayfa_id}/join-requests`: eskiden yeniye.
  Future<Sayfa<JoinRequest>> katilimIstekleri(
    String tayfaId, {
    String? sayfaToken,
    int sayfaBoyutu = yonetimSayfaBoyutu,
  }) async {
    final liste = await _istekler.listJoinRequests(
      tayfaId: tayfaId,
      pageSize: sayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.joinRequests, sonraki: liste.nextPageToken);
  }

  /// `POST …/join-requests/{user_id}/approval`.
  Future<Membership> istegiOnayla(String tayfaId, String uyeId) =>
      _istekler.approveJoinRequest(tayfaId: tayfaId, userId: uyeId);

  /// `DELETE …/join-requests/{user_id}`.
  Future<void> istegiReddet(String tayfaId, String uyeId) =>
      _istekler.rejectJoinRequest(tayfaId: tayfaId, userId: uyeId);

  /// `GET /v1/tayfas/{tayfa_id}/invites`: geçerli linkler, yeniden eskiye.
  Future<List<Invite>> davetler(String tayfaId) async =>
      (await _davetler.listInvites(tayfaId: tayfaId)).invites;

  /// `POST /v1/tayfas/{tayfa_id}/invites`. Dönen token yalnızca bu
  /// cevapta vardır.
  Future<CreatedInvite> davetOlustur(
    String tayfaId,
    InviteCreateRequest istek,
  ) => _davetler.createInvite(tayfaId: tayfaId, body: istek);

  /// `DELETE /v1/tayfas/{tayfa_id}/invites/{invite_id}`.
  Future<void> davetIptal(String tayfaId, String davetId) =>
      _davetler.revokeInvite(tayfaId: tayfaId, inviteId: davetId);

  /// `GET /v1/notification-preferences`.
  Future<List<NotificationPreference>> bildirimTercihleri() async =>
      (await _bildirim.listNotificationPreferences()).preferences;

  /// `PUT /v1/notification-preferences/tayfas/{tayfa_id}`: tayfayı
  /// süresiz sessize alır (`none`).
  Future<NotificationPreference> sessizeAl(String tayfaId) =>
      _bildirim.setTayfaNotificationPreference(
        tayfaId: tayfaId,
        body: const NotificationPreferenceRequest(
          level: NotificationPreferenceRequestLevel.none,
        ),
      );

  /// `DELETE /v1/notification-preferences/tayfas/{tayfa_id}`: varsayılana
  /// (`all`) döner.
  Future<void> sessizdenCikar(String tayfaId) =>
      _bildirim.resetTayfaNotificationPreference(tayfaId: tayfaId);
}

/// Tayfa yönetimi uçlarının deposu.
final yonetimDeposuProvider = Provider<YonetimDeposu>(
  (ref) => YonetimDeposu(ref.watch(apiClientProvider)),
  name: 'yonetimDeposuProvider',
);
