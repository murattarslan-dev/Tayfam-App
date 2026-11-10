// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `invitations` olan uçlar.
final class InvitationsApi {
  const InvitationsApi(this._transport);

  final ApiTransport _transport;

  /// Tayfanın cevaplanmamış doğrudan davetleri, yeniden eskiye (yönetici)
  ///
  /// `GET /v1/tayfas/{tayfa_id}/invitations`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<InvitationList> listInvitations({
    required String tayfaId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invitations',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
    );
    return InvitationList.fromJson(jsonObject(response, 'listInvitations'));
  }

  /// Arkadaşınızı tayfaya davet eder (etkin, susturulmamış üye)
  ///
  /// Yalnızca arkadaşlar (`not-friends`). Davet eden başına günde 10, tüm
  /// tayfalar birlikte (`direct-invite-limit`). Banlı ya da başvurusu
  /// bekleyen kişi `invite-not-allowed` (hangisi olduğu söylenmez).
  ///
  /// `POST /v1/tayfas/{tayfa_id}/invitations`
  Future<Invitation> inviteFriend({
    required String tayfaId,
    required UserRef body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invitations',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return Invitation.fromJson(jsonObject(response, 'inviteFriend'));
  }

  /// Cevaplanmamış bir daveti iptal eder (yönetici)
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/invitations/{user_id}`
  Future<void> cancelInvitation({
    required String tayfaId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/invitations/{user_id}',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.none,
    );
  }
}
