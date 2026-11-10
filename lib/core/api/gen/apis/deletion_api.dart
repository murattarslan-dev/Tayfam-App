// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `deletion` olan uçlar.
final class DeletionApi {
  const DeletionApi(this._transport);

  final ApiTransport _transport;

  /// Tayfayı 72 saat sonra silinmek üzere işaretler (yönetici)
  ///
  /// Silinene kadar tayfa salt okunurdur; herhangi bir yönetici iptal edebilir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/deletion`
  Future<Deletion> requestTayfaDeletion({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/deletion',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Deletion.fromJson(jsonObject(response, 'requestTayfaDeletion'));
  }

  /// Bekleyen silmeyi iptal eder (yönetici)
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/deletion`
  Future<void> cancelTayfaDeletion({required String tayfaId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/deletion',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
