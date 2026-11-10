// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `invite-joins` olan uçlar.
final class InviteJoinsApi {
  const InviteJoinsApi(this._transport);

  final ApiTransport _transport;

  /// Davet linkiyle tayfaya katılır
  ///
  /// Tayfa açık katılımlıysa ya da linki açan kişi şu an moderatör veya
  /// yöneticiyse üyelik hemen etkin olur; değilse bekler. IP başına sınır
  /// vardır.
  ///
  /// `POST /v1/invite-joins`
  Future<Membership> joinByInvite({required InviteTokenRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/invite-joins',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'joinByInvite'));
  }
}
