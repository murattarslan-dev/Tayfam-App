// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `tayfas` olan uçlar.
final class TayfasApi {
  const TayfasApi(this._transport);

  final ApiTransport _transport;

  /// Etkin üyelikleriniz ve bekleyen katılım istekleriniz
  ///
  /// En yeniden eskiye. Bekleyen bir istekte yalnızca `tayfa_id` ve `name`
  /// dolu gelir; `tayfa` alanı yalnızca etkin üyelikte vardır.
  ///
  /// `GET /v1/tayfas`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<MyTayfaList> listMyTayfas({int? pageSize, String? pageToken}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MyTayfaList.fromJson(jsonObject(response, 'listMyTayfas'));
  }

  /// Yeni tayfa açar; açan kişi tek yöneticisidir
  ///
  /// Kullanıcı başına 24 saatte 1 (`tayfa-create-limit`, core) ve IP başına
  /// saatte 1 (`rate-limited`, gateway). Aynı `client_request_id` ile
  /// tekrar gönderim ilk açılan tayfayı döndürür ve yeni tayfa açmaz;
  /// aynı IP'den aynı `client_request_id` ile yapılan tekrar IP sınırına
  /// takılmaz. Bütün modüller açık başlar.
  ///
  /// `POST /v1/tayfas`
  Future<Tayfa> createTayfa({required TayfaCreateRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Tayfa.fromJson(jsonObject(response, 'createTayfa'));
  }

  /// Tayfanın tam görünümü ve sizin rolünüz
  ///
  /// Yalnızca etkin üyelere. `caller_role` istemcinin doğru işlemleri
  /// göstermesi içindir; sunucu her istekte yetkiyi yeniden kontrol eder.
  ///
  /// `GET /v1/tayfas/{tayfa_id}`
  Future<TayfaView> getTayfa({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaView.fromJson(jsonObject(response, 'getTayfa'));
  }

  /// Tayfa ayarlarını değiştirir (yönetici)
  ///
  /// Yalnızca gövdede bulunan alanlar değişir; en az bir alan gerekir.
  /// `interests` gönderilirse ilgi alanlarının tamamını değiştirir.
  /// `members_can_create_events` etkinlik açma iznini üyelere açar ya da
  /// kapatır.
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}`
  Future<Tayfa> updateTayfa({
    required String tayfaId,
    required TayfaUpdateRequest body,
  }) async {
    final json = body.toJson();
    if (json.length < 1) {
      throw ArgumentError('TayfaUpdateRequest: en az 1 alan verilmeli');
    }
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}',
      pathParams: {'tayfa_id': tayfaId},
      body: json,
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Tayfa.fromJson(jsonObject(response, 'updateTayfa'));
  }
}
