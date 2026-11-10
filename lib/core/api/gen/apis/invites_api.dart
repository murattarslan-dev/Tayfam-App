// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `invites` olan uçlar.
final class InvitesApi {
  const InvitesApi(this._transport);

  final ApiTransport _transport;

  /// Geçerli davet linkleri, yeniden eskiye (en fazla 100)
  ///
  /// Yönetici tayfanın bütün linklerini, diğer üyeler yalnızca kendi
  /// açtıklarını görür. Token hiçbir zaman dönmez.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/invites`
  Future<InviteList> listInvites({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invites',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
    );
    return InviteList.fromJson(jsonObject(response, 'listInvites'));
  }

  /// Davet linki açar
  ///
  /// `token` yalnızca bu yanıtta, bir kez döner; sunucu onu bir daha
  /// gösteremez. İstemci linki `https://tayfam.app/davet#<token>` gibi
  /// token'ı fragment'ta taşıyan bir biçimde paylaşır (fragment sunucuya
  /// ve `Referer`'a gitmez) ve gövdeyle `/v1/invite-previews`,
  /// `/v1/invite-joins` uçlarına gönderir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/invites`
  Future<CreatedInvite> createInvite({
    required String tayfaId,
    required InviteCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invites',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return CreatedInvite.fromJson(jsonObject(response, 'createInvite'));
  }

  /// Davet linkini hemen geçersiz kılar
  ///
  /// Kendi açtığınız linki, yöneticiyseniz tayfanın her linkini. Zaten
  /// iptal edilmiş bir link için de başarılıdır. Salt okunur tayfada da
  /// çalışır.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/invites/{invite_id}`
  Future<void> revokeInvite({
    required String tayfaId,
    required String inviteId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invites/{invite_id}',
      pathParams: {'tayfa_id': tayfaId, 'invite_id': inviteId},
      expect: ResponseKind.none,
    );
  }
}
