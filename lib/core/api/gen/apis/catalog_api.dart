// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `catalog` olan uçlar.
final class CatalogApi {
  const CatalogApi(this._transport);

  final ApiTransport _transport;

  /// İlgi alanları ve aktif etkinlik türlerinin güncel tanımları
  ///
  /// `ETag` başlığı kataloğun sürümüdür (`"<catalog_version>"`). İstemci
  /// elindeki sürümü `If-None-Match` ile gönderir; katalog değişmediyse
  /// yanıt gövdesiz **304**'tür (aynı `ETag` ile). Katalog her
  /// değiştiğinde `catalog_version` artar.
  ///
  /// İlgi alanlarının hepsi döner (emekliye ayrılanlar `status: retired`
  /// ile: eski tayfalar ve profiller onları göstermeye devam eder).
  /// Türlerden yalnızca aktif olanlar, güncel sürümleriyle döner; eski bir
  /// etkinliğin tür sürümü için
  /// `GET /v1/catalog/event-types/{key}/versions/{version}`.
  ///
  /// `labels` platform sahibinin yazdığı içeriktir (dil → metin; `tr` her
  /// zaman vardır) ve düz metin olarak gösterilir. `icon` istemcinin sabit
  /// ikon setinden bir anahtardır; bilinmeyen anahtar için ilgi alanının
  /// ikonu, o da yoksa genel ikon gösterilir.
  ///
  /// `GET /v1/catalog`
  ///
  /// Koşullu istek: sunucu `304` dönerse (değişmedi) `null` döner.
  ///
  /// [ifNoneMatch]: Elinizdeki kataloğun `ETag` değeri (`"7"`).
  ///
  /// Kısıtlar: maxLength: 128.
  Future<Catalog?> getCatalog({String? ifNoneMatch}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/catalog',
      headers: {if (ifNoneMatch != null) 'If-None-Match': ifNoneMatch},
      expect: ResponseKind.json,
      authenticated: true,
    );
    if (response == null) {
      return null;
    }
    return Catalog.fromJson(jsonObject(response, 'getCatalog'));
  }

  /// Bir etkinlik türünün bir sürümü
  ///
  /// Etkinlik oluşturulduğu andaki tür sürümüne bağlıdır (`type`,
  /// `type_version`) ve o tanımla gösterilir. Güncel katalogda olmayan
  /// sürüm (tür sonradan değişti ya da emekliye ayrıldı) buradan alınır.
  /// Bir tür sürümü hiç değişmez; istemci oturum boyunca bellekte
  /// tutabilir. Bilinmeyen tür ya da sürüm `catalog-type-not-found`.
  ///
  /// `GET /v1/catalog/event-types/{key}/versions/{version}`
  ///
  /// [key]: Etkinlik türünün anahtarı (`hike`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [version]: Tür sürümü; 1 ya da büyük, yalnızca rakam.
  ///
  /// Kısıtlar: minimum: 1.
  Future<CatalogEventType> getCatalogEventTypeVersion({
    required String key,
    required int version,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/catalog/event-types/{key}/versions/{version}',
      pathParams: {'key': key, 'version': '$version'},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return CatalogEventType.fromJson(
      jsonObject(response, 'getCatalogEventTypeVersion'),
    );
  }
}
