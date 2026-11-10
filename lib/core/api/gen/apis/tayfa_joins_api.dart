// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `tayfa-joins` olan uçlar.
final class TayfaJoinsApi {
  const TayfaJoinsApi(this._transport);

  final ApiTransport _transport;

  /// Katılım koduyla tayfaya katılır
  ///
  /// Tayfa açık katılımlıysa üyelik hemen etkin olur, onaylıysa bekler.
  /// Bozuk, bilinmeyen, yenilenmiş kod ve banlı olduğunuz tayfa aynı
  /// cevabı alır (`invalid-join-code`). IP başına (gateway) ve kullanıcı
  /// başına (core) deneme sınırı vardır.
  ///
  /// `POST /v1/tayfa-joins`
  Future<Membership> joinByCode({required JoinByCodeRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfa-joins',
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return Membership.fromJson(jsonObject(response, 'joinByCode'));
  }
}
