// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `garage` olan uçlar.
final class GarageApi {
  const GarageApi(this._transport);

  final ApiTransport _transport;

  /// Tayfanın garajı
  ///
  /// Bu tayfada görünen araçlar, en yeni önce. `owner_user_id` tek bir
  /// üyeninkileri süzer; `next_page_token` yalnızca aynı süzgeçle
  /// geçerlidir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/garage`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<TayfaGarage> listTayfaGarage({
    required String tayfaId,
    String? ownerUserId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/garage',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (ownerUserId != null) 'owner_user_id': ownerUserId,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaGarage.fromJson(jsonObject(response, 'listTayfaGarage'));
  }

  /// Garajınızı bu tayfada gösterir ya da gizler
  ///
  /// Göstermek susturulmuş üyeye kapalıdır (`muted`); gizlemek her etkin
  /// üyeye açıktır. Seçim yapılmamışsa varsayılan ilgi alanına göredir
  /// (`automotive`).
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/garage/visibility`
  Future<GarageVisibility> setGarageVisibility({
    required String tayfaId,
    required GarageVisibility body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/garage/visibility',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return GarageVisibility.fromJson(
      jsonObject(response, 'setGarageVisibility'),
    );
  }

  /// Aracı kaldırır (moderatör)
  ///
  /// İçerik moderasyonu: bu tayfada görünen araç her yerde gizlenir ve
  /// 30 gün sonra kalıcı silinir; geri alınamaz. Bu tayfada görünmeyen
  /// araç `garage-vehicle-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/garage/{garage_vehicle_id}`
  ///
  /// [garageVehicleId]: Üye garajındaki aracın kimliği (`GarageVehicle.id`).
  Future<void> removeTayfaGarageVehicle({
    required String tayfaId,
    required String garageVehicleId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/garage/{garage_vehicle_id}',
      pathParams: {'tayfa_id': tayfaId, 'garage_vehicle_id': garageVehicleId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
