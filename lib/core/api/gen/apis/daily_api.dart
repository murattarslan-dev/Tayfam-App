// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `daily` olan uçlar.
final class DailyApi {
  const DailyApi(this._transport);

  final ApiTransport _transport;

  /// Günün içeriği
  ///
  /// Gün Europe/Istanbul gününe göredir ve seçim sunucudadır; o gün her
  /// üye aynı içeriği görür. O güne (o yıla ya da her yıla) sabitlenmiş
  /// içerik varsa havuz sırasında önce gelen gösterilir (`pinned`
  /// true). Yoksa sabitlenmemiş içerikler arasından sıradaki: sıra kartın
  /// açıldığı her gün bir adım ilerler, sona gelince başa döner;
  /// kimsenin açmadığı gün ilerlemez. Gösterilecek içerik yoksa `item`
  /// yoktur. Her etkin üyeye açıktır.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/daily/today`
  Future<DailyToday> getDailyToday({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/today',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyToday.fromJson(jsonObject(response, 'getDailyToday'));
  }

  /// Havuzun tamamı, sırasıyla
  ///
  /// En fazla 1000 içerik, havuz sırasıyla. `deleted=true` yalnızca
  /// yönetici ve moderatöre: son 30 günde silinenler (geri almak için),
  /// son silinen önce; başkasına `permission-denied`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/daily/items`
  Future<DailyItemList> listDailyItems({
    required String tayfaId,
    bool? deleted,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/items',
      pathParams: {'tayfa_id': tayfaId},
      query: {if (deleted != null) 'deleted': '$deleted'},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyItemList.fromJson(jsonObject(response, 'listDailyItems'));
  }

  /// Havuza içerik ekler (yönetici, moderatör)
  ///
  /// Havuzun sonuna eklenir. Aynı güne ikinci sabitleme reddedilmez:
  /// yanıtta `pin_conflict` true döner, istemci uyarır. Aynı
  /// `client_request_id` ile tekrar gönderim aynı içeriği döndürür.
  /// Havuz doluysa (1000) `daily-item-limit`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/daily/items`
  Future<DailyItemSaved> createDailyItem({
    required String tayfaId,
    required DailyItemCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/items',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyItemSaved.fromJson(jsonObject(response, 'createDailyItem'));
  }

  /// İçeriği düzenler (yönetici, moderatör)
  ///
  /// Metin, söyleyen ve sabitleme birlikte yazılır (kısmi güncelleme
  /// yok; `pin` yoksa sabitleme kalkar). Havuzdaki yeri değişmez.
  /// Havuzda olmayan içerik `daily-item-not-found`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}`
  ///
  /// [dailyItemId]: Günün içeriği havuzundaki içeriğin kimliği (`DailyItem.id`).
  Future<DailyItemSaved> updateDailyItem({
    required String tayfaId,
    required String dailyItemId,
    required DailyItemInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}',
      pathParams: {'tayfa_id': tayfaId, 'daily_item_id': dailyItemId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyItemSaved.fromJson(jsonObject(response, 'updateDailyItem'));
  }

  /// İçeriği siler (yönetici, moderatör)
  ///
  /// 30 gün içinde geri alınabilir, sonra kalıcı silinir. Havuzda
  /// olmayan içerik `daily-item-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}`
  ///
  /// [dailyItemId]: Günün içeriği havuzundaki içeriğin kimliği (`DailyItem.id`).
  Future<void> deleteDailyItem({
    required String tayfaId,
    required String dailyItemId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}',
      pathParams: {'tayfa_id': tayfaId, 'daily_item_id': dailyItemId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Silinen içeriği geri alır (yönetici, moderatör)
  ///
  /// Son 30 günde silinen içerik havuzun sonuna döner; silinmemiş
  /// içerikte bir şey değişmez. Bilinmeyen ya da 30 günden önce silinen
  /// içerik `daily-item-not-found`; havuz doluysa `daily-item-limit`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}/restore`
  ///
  /// [dailyItemId]: Günün içeriği havuzundaki içeriğin kimliği (`DailyItem.id`).
  Future<DailyItemSaved> restoreDailyItem({
    required String tayfaId,
    required String dailyItemId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/items/{daily_item_id}/restore',
      pathParams: {'tayfa_id': tayfaId, 'daily_item_id': dailyItemId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyItemSaved.fromJson(jsonObject(response, 'restoreDailyItem'));
  }

  /// Havuzun sırasını değiştirir (yönetici, moderatör)
  ///
  /// `item_ids` havuzdaki her içeriği tam bir kez, yeni sırasıyla içerir;
  /// eksik, fazla, tekrarlanan ya da bilinmeyen kimlik `invalid-request`
  /// (alan `item_ids`). Sıradaki dönüş aynı yer numarasından devam eder.
  /// Cevap yeni sıradır.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/daily/order`
  Future<DailyOrder> reorderDailyItems({
    required String tayfaId,
    required DailyOrderRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/daily/order',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DailyOrder.fromJson(jsonObject(response, 'reorderDailyItems'));
  }
}
