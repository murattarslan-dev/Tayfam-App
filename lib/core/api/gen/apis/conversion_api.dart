// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `conversion` olan uçlar.
final class ConversionApi {
  const ConversionApi(this._transport);

  final ApiTransport _transport;

  /// Anlık tayfayı kalıcı tayfaya dönüştürür ("Bu ekiple tayfa kur")
  ///
  /// Yalnızca anlık tayfanın yöneticisi (organizatör; hesabı silindiyse
  /// devralan yönetici), tayfa salt okunur değilken (ADR-0032). Dönüşmüş
  /// tayfada tekrar istek, bir şey değiştirmeden tayfayı döndürür. Ad, ilgi alanları, açıklama ve katılım
  /// politikası tayfa açmadaki kurallarla verilir; bütün modüller açılır,
  /// üyeler, etkinlik ve kanal kalır. Dönüştürme tayfa açma sayılır:
  /// kullanıcı başına 24 saatte 1 (`tayfa-create-limit`) ve IP başına
  /// saatte 1 (`rate-limited`). Kalıcı tayfada `permission-denied`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/conversion`
  Future<Tayfa> convertInstantTayfa({
    required String tayfaId,
    required TayfaConvertRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/conversion',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Tayfa.fromJson(jsonObject(response, 'convertInstantTayfa'));
  }
}
