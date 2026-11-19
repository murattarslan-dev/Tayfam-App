import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/catalog_api.dart';
import 'package:tayfam/core/api/gen/models.dart';

/// Kataloğu sunucudan okuyan uçlar; testlerde sahtesi verilir.
abstract interface class KatalogDeposu {
  /// `GET /v1/catalog`. [etag] eldeki kataloğun `ETag` değeridir
  /// (`If-None-Match`); katalog değişmediyse (`304`) `null` döner.
  Future<Catalog?> oku({String? etag});

  /// `GET /v1/catalog/event-types/{key}/versions/{version}`: bir tür
  /// sürümü. Bilinmeyen tür ya da sürüm `catalog-type-not-found`.
  Future<CatalogEventType> surumOku(String anahtar, int surum);
}

final class _ApiKatalogDeposu implements KatalogDeposu {
  const _ApiKatalogDeposu(this._api);

  final CatalogApi _api;

  @override
  Future<Catalog?> oku({String? etag}) => _api.getCatalog(ifNoneMatch: etag);

  @override
  Future<CatalogEventType> surumOku(String anahtar, int surum) =>
      _api.getCatalogEventTypeVersion(key: anahtar, version: surum);
}

/// Katalog uçları (tek `ApiClient` üzerinden; ADR-0005).
final katalogDeposuProvider = Provider<KatalogDeposu>(
  (ref) => _ApiKatalogDeposu(CatalogApi(ref.watch(apiClientProvider))),
  name: 'katalogDeposuProvider',
);
