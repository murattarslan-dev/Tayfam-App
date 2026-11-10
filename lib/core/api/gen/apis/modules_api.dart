// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `modules` olan uçlar.
final class ModulesApi {
  const ModulesApi(this._transport);

  final ApiTransport _transport;

  /// Bir modülü açar ya da kapatır (yönetici)
  ///
  /// Mevcut değeri tekrar vermek başarılıdır ve bir şey değiştirmez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/modules/{module}`
  Future<void> setTayfaModule({
    required String tayfaId,
    required Module module,
    required ModuleUpdate body,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/modules/{module}',
      pathParams: {'tayfa_id': tayfaId, 'module': module.wire},
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
