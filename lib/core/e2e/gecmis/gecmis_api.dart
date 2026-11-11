import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/direct_messages_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Arşiv kaydı yazımında bir öğe: mesaj kimliği ve şifreli içerik.
typedef ArsivYazimi = ({String mesajId, Uint8List icerik});

/// Yenilemede bir cihaza paylaşım.
typedef AnahtarPaylasimi = ({String cihazId, Uint8List paket});

/// Geçmiş arşivi, eşleştirme ve anahtar yenileme uçları (Tayfam-Api
/// ADR-0018 §4–§6). Yalnızca üretilmiş uç sınıflarını kullanır; bütün
/// istekler tek `ApiClient`'tan geçer (ADR-0005). Opak baytlar standart
/// base64 ile taşınır.
final class GecmisApi {
  GecmisApi(ApiTransport istemci)
    : _me = MeApi(istemci),
      _dm = DirectMessagesApi(istemci),
      _users = UsersApi(istemci);

  final MeApi _me;
  final DirectMessagesApi _dm;
  final UsersApi _users;

  /// `POST /v1/me/e2e/history-key` (ClaimHistoryKey): yeni sürüm.
  Future<int> gecmisAnahtariAl() async =>
      (await _me.claimE2EHistoryKey()).historyKeyVersion;

  /// `POST /v1/me/e2e/archive`: kabul edilen mesaj kimlikleri.
  Future<List<String>> arsiveYaz(int surum, List<ArsivYazimi> kayitlar) async {
    final cevap = await _me.putE2EArchiveEntries(
      body: E2EArchiveWrite(
        historyKeyVersion: surum,
        entries: [
          for (final k in kayitlar)
            E2EArchiveWriteEntriesItem(
              messageId: k.mesajId,
              content: base64.encode(k.icerik),
            ),
        ],
      ),
    );
    return cevap.acceptedMessageIds;
  }

  /// `GET /v1/direct-messages/conversations/{id}/archive`: bir sayfa.
  Future<E2EArchiveEntryList> arsivSayfasi(
    String konusmaId, {
    String? sayfa,
    int sayfaBoyu = 100,
  }) => _dm.listE2EArchiveEntries(
    conversationId: konusmaId,
    pageSize: sayfaBoyu,
    pageToken: sayfa,
  );

  /// `GET /v1/users/{kendi id}/e2e/devices`: kendi cihazlarım.
  Future<List<E2EPublicDevice>> cihazlar(String kullaniciId) async =>
      (await _users.listE2EDevices(userId: kullaniciId)).devices;

  /// `POST /v1/me/e2e/history-key/rotate`.
  Future<void> anahtariYenile(int surum, List<AnahtarPaylasimi> paylasimlar) =>
      _me.rotateE2EHistoryKey(
        body: E2EHistoryKeyRotation(
          historyKeyVersion: surum,
          shares: [
            for (final p in paylasimlar)
              E2EHistoryKeyRotationSharesItem(
                deviceId: p.cihazId,
                bundle: base64.encode(p.paket),
              ),
          ],
        ),
      );

  /// `GET /v1/me/e2e/history-key-shares`: en eski önce.
  Future<List<E2EHistoryKeyShare>> paylasimlar() async =>
      (await _me.listE2EHistoryKeyShares()).shares;

  /// `POST /v1/me/e2e/history-key-shares/ack`.
  Future<void> paylasimlariOnayla(List<String> kimlikler) =>
      _me.ackE2EHistoryKeyShares(body: E2EShareAck(shareIds: kimlikler));

  /// `POST /v1/me/e2e/link-requests`.
  Future<E2ELinkRequestCreated> eslemeIstegiAc() => _me.createE2ELinkRequest();

  /// `GET /v1/me/e2e/link-requests/{id}`.
  Future<E2ELinkRequest> eslemeIstegi(String istekId) =>
      _me.getE2ELinkRequest(linkRequestId: istekId);

  /// `POST /v1/me/e2e/link-requests/{id}/answer`.
  Future<void> eslemeyiCevapla(String istekId, int surum, Uint8List cevap) =>
      _me.answerE2ELinkRequest(
        linkRequestId: istekId,
        body: E2ELinkAnswer(
          historyKeyVersion: surum,
          answer: base64.encode(cevap),
        ),
      );

  /// `POST /v1/me/e2e/link-requests/{id}/complete`.
  Future<E2EDevice> eslemeyiTamamla(String istekId) =>
      _me.completeE2ELinkRequest(linkRequestId: istekId);
}

/// Geçmiş uçlarının deposu.
final gecmisApiProvider = Provider<GecmisApi>(
  (ref) => GecmisApi(ref.watch(apiClientProvider)),
  name: 'gecmisApiProvider',
);
