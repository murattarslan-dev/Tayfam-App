// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `membership` olan uçlar.
final class MembershipApi {
  const MembershipApi(this._transport);

  final ApiTransport _transport;

  /// Tayfadan ayrılır ya da bekleyen katılım isteğini geri çeker
  ///
  /// Salt okunur tayfada da çalışır. Son yönetici ayrılamaz
  /// (`last-admin`). Banlanmış üyelik bırakılamaz (`tayfa-not-found`).
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/membership`
  Future<void> leaveTayfa({required String tayfaId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/membership',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
