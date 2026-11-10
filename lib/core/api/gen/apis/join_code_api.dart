// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `join-code` olan uçlar.
final class JoinCodeApi {
  const JoinCodeApi(this._transport);

  final ApiTransport _transport;

  /// Katılım kodunu yeniler (yönetici); eski kod hemen geçersiz olur
  ///
  /// Mevcut kod `GET /v1/tayfas/{tayfa_id}` yanıtında yalnızca yöneticiye
  /// döner.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/join-code`
  Future<JoinCode> rotateJoinCode({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/join-code',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return JoinCode.fromJson(jsonObject(response, 'rotateJoinCode'));
  }
}
