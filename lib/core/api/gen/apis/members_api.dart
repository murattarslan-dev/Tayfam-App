// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `members` olan uçlar.
final class MembersApi {
  const MembersApi(this._transport);

  final ApiTransport _transport;

  /// Üyeleri listeler
  ///
  /// `status=active` (varsayılan) her etkin üyeye açıktır; `status=banned`
  /// yalnızca moderatör ve yöneticiye. Sıra: rol (yönetici önce), katılma
  /// zamanı. Katılım istekleri için `/join-requests`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/members`
  ///
  /// [status]: Kısıtlar: varsayılan (sunucu): `active`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<MemberList> listMembers({
    required String tayfaId,
    ListMembersStatus? status,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (status != null) 'status': status.wire,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MemberList.fromJson(jsonObject(response, 'listMembers'));
  }

  /// Etkin bir üyenin rolünü değiştirir (yönetici)
  ///
  /// Hedefin rolü sizinkinden düşük olmalı, yeni rol sizinkinden yüksek
  /// olamaz (`role-hierarchy`). Kendi rolünüzü düşürebilirsiniz; son
  /// yönetici düşüremez (`last-admin`).
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/members/{user_id}`
  Future<Membership> changeMemberRole({
    required String tayfaId,
    required String userId,
    required RoleUpdate body,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members/{user_id}',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'changeMemberRole'));
  }

  /// Etkin bir üyeyi tayfadan çıkarır (moderatör, yönetici)
  ///
  /// Çıkarılan kişi daha sonra tekrar katılabilir. Kendiniz için `/membership`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/members/{user_id}`
  Future<void> removeMember({
    required String tayfaId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members/{user_id}',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Üyeyi belirli bir zamana kadar susturur (moderatör, yönetici)
  ///
  /// Tekrar susturmak bitiş zamanını değiştirir. En fazla 30 gün.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/members/{user_id}/mute`
  Future<Membership> muteMember({
    required String tayfaId,
    required String userId,
    required MuteRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members/{user_id}/mute',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'muteMember'));
  }

  /// Susturmayı hemen bitirir (moderatör, yönetici)
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/members/{user_id}/mute`
  Future<Membership> unmuteMember({
    required String tayfaId,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members/{user_id}/mute',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'unmuteMember'));
  }

  /// Etkin ya da bekleyen bir üyeyi banlar (moderatör, yönetici)
  ///
  /// Banlanan kişi kodla ya da davetle tekrar katılamaz.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/members/{user_id}/ban`
  Future<void> banMember({
    required String tayfaId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/members/{user_id}/ban',
      pathParams: {'tayfa_id': tayfaId, 'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
