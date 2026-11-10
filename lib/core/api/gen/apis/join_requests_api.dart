// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `join-requests` olan uçlar.
final class JoinRequestsApi {
  const JoinRequestsApi(this._transport);

  final ApiTransport _transport;

  /// Bekleyen katılım istekleri, eskiden yeniye (moderatör, yönetici)
  ///
  /// `GET /v1/tayfas/{tayfa_id}/join-requests`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<JoinRequestList> listJoinRequests({
    required String tayfaId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/join-requests',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
    );
    return JoinRequestList.fromJson(jsonObject(response, 'listJoinRequests'));
  }

  /// Katılım isteğini reddeder (moderatör, yönetici)
  ///
  /// Kişi daha sonra tekrar isteyebilir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/join-requests/{user_id}`
  Future<void> rejectJoinRequest({
    required String tayfaId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/join-requests/{user_id}',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.none,
    );
  }

  /// Katılım isteğini onaylar; üyelik etkin olur (moderatör, yönetici)
  ///
  /// `POST /v1/tayfas/{tayfa_id}/join-requests/{user_id}/approval`
  Future<Membership> approveJoinRequest({
    required String tayfaId,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/join-requests/{user_id}/approval',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.json,
    );
    return Membership.fromJson(jsonObject(response, 'approveJoinRequest'));
  }
}
