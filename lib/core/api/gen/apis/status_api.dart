// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `status` olan uçlar.
final class StatusApi {
  const StatusApi(this._transport);

  final ApiTransport _transport;

  /// Servislerin erişilebilirliği
  ///
  /// `GET /v1/status`
  ///
  /// Kimlik doğrulaması gerektirmez (`security: []`).
  Future<Status> getStatus() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/status',
      expect: ResponseKind.json,
    );
    return Status.fromJson(jsonObject(response, 'getStatus'));
  }
}
