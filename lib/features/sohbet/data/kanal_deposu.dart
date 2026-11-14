import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/channels_api.dart';
import 'package:tayfam/core/api/gen/apis/members_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Kanal mesajlarında bir sayfada istenen kayıt sayısı.
const int mesajSayfaBoyutu = 50;

/// Kanal katılımcıları ve tayfa üyeleri listesinde bir sayfada istenen
/// kayıt sayısı (sözleşme: en çok 100).
const int kisiSayfaBoyutu = 100;

/// Kanal uçları (ADR-0018 §9). Yalnızca üretilmiş uç sınıfını kullanır;
/// bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class KanalDeposu {
  KanalDeposu(ApiTransport istemci)
    : _api = ChannelsApi(istemci),
      _uyeler = MembersApi(istemci);

  final ChannelsApi _api;
  final MembersApi _uyeler;

  /// `GET /v1/tayfas/{tayfa_id}/channels`: görebildiğin kanallar ve
  /// okunmamış sayıların; arşivlenenler sonda.
  Future<List<Channel>> kanallar(String tayfaId) async =>
      (await _api.listChannels(tayfaId: tayfaId)).channels;

  /// `POST /v1/tayfas/{tayfa_id}/channels`.
  Future<Channel> olustur(String tayfaId, ChannelCreateRequest istek) =>
      _api.createChannel(tayfaId: tayfaId, body: istek);

  /// `GET /v1/tayfas/{tayfa_id}/channels/{channel_id}`.
  Future<Channel> kanal(String tayfaId, String kanalId) =>
      _api.getChannel(tayfaId: tayfaId, channelId: kanalId);

  /// `PATCH /v1/tayfas/{tayfa_id}/channels/{channel_id}`.
  Future<Channel> guncelle(
    String tayfaId,
    String kanalId,
    ChannelUpdateRequest istek,
  ) => _api.updateChannel(tayfaId: tayfaId, channelId: kanalId, body: istek);

  /// `PUT …/archive` ya da `DELETE …/archive`.
  Future<Channel> arsivle(
    String tayfaId,
    String kanalId, {
    required bool arsivde,
  }) => arsivde
      ? _api.archiveChannel(tayfaId: tayfaId, channelId: kanalId)
      : _api.unarchiveChannel(tayfaId: tayfaId, channelId: kanalId);

  /// `GET …/messages`. [sonrakiId] verilmezse en yeni önce, [sayfaToken]
  /// eskiye doğru gider; verilirse ondan yeni mesajlar en eski önce gelir
  /// ve token yeniye doğru gider. Token opaktır.
  Future<ChannelMessageList> mesajlar(
    String tayfaId,
    String kanalId, {
    String? sayfaToken,
    String? sonrakiId,
  }) => _api.listChannelMessages(
    tayfaId: tayfaId,
    channelId: kanalId,
    pageSize: mesajSayfaBoyutu,
    pageToken: sayfaToken,
    afterMessageId: sonrakiId,
  );

  /// `POST …/messages` (WebSocket kapalıyken; aynı `client_request_id`).
  Future<ChannelMessage> gonder(
    String tayfaId,
    String kanalId,
    ChannelMessageCreateRequest istek,
  ) => _api.sendChannelMessage(
    tayfaId: tayfaId,
    channelId: kanalId,
    body: istek,
  );

  /// `DELETE …/messages/{message_id}`.
  Future<void> sil(String tayfaId, String kanalId, String mesajId) =>
      _api.deleteChannelMessage(
        tayfaId: tayfaId,
        channelId: kanalId,
        messageId: mesajId,
      );

  /// `POST …/messages/{message_id}/restoration` (yönetici).
  Future<ChannelMessage> geriAl(
    String tayfaId,
    String kanalId,
    String mesajId,
  ) => _api.restoreChannelMessage(
    tayfaId: tayfaId,
    channelId: kanalId,
    messageId: mesajId,
  );

  /// `PUT …/read`: kanalı bu mesaja kadar okundu işaretler.
  Future<void> okundu(String tayfaId, String kanalId, String mesajId) =>
      _api.markChannelRead(
        tayfaId: tayfaId,
        channelId: kanalId,
        body: ChannelReadRequest(messageId: mesajId),
      );

  /// `GET …/members`: etkinlik ya da seçili kişi kanalının kitlesi
  /// (yalnızca kimlikler, kimliğe göre sıralı; issue #183). Adlar profil
  /// ucundan okunur. [sayfaToken] opaktır.
  Future<Sayfa<String>> katilimcilar(
    String tayfaId,
    String kanalId, {
    String? sayfaToken,
  }) async {
    final liste = await _api.listChannelMembers(
      tayfaId: tayfaId,
      channelId: kanalId,
      pageSize: kisiSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.userIds, sonraki: liste.nextPageToken);
  }

  /// `POST …/members`: seçili kişi kanalına kişi ekler (yalnızca kanalı
  /// açan; kararı sunucu verir).
  Future<Channel> katilimciEkle(
    String tayfaId,
    String kanalId,
    List<String> kisiler,
  ) => _api.addChannelMembers(
    tayfaId: tayfaId,
    channelId: kanalId,
    body: ChannelMembersAddRequest(userIds: kisiler),
  );

  /// `DELETE …/members/{user_id}`: seçili kişi kanalından kişi çıkarır.
  Future<void> katilimciCikar(String tayfaId, String kanalId, String kisi) =>
      _api.removeChannelMember(
        tayfaId: tayfaId,
        channelId: kanalId,
        userId: kisi,
      );

  /// `GET /v1/tayfas/{tayfa_id}/members` (etkin üyeler): seçili kişi
  /// kanalının kişi seçicisi için. [sayfaToken] opaktır.
  Future<Sayfa<Membership>> tayfaUyeleri(
    String tayfaId, {
    String? sayfaToken,
  }) async {
    final liste = await _uyeler.listMembers(
      tayfaId: tayfaId,
      status: ListMembersStatus.active,
      pageSize: kisiSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.members, sonraki: liste.nextPageToken);
  }
}

/// Kanal uçları; testlerde sahte taşımayla verilir.
final kanalDeposuProvider = Provider<KanalDeposu>(
  (ref) => KanalDeposu(ref.watch(apiClientProvider)),
  name: 'kanalDeposuProvider',
);
