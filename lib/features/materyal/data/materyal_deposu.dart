import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/materials_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Materyal listesinin sayfa boyutu (sözleşme: en çok 50).
const int materyalSayfaBoyutu = 20;

/// Materyal kütüphanesi uçları (Tayfam-Api ADR-0040 §3, #261). Yalnızca
/// üretilmiş uç sınıfını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005). Başlık ve bağlantı içeriktir; log'a yazılmaz.
final class MateryalDeposu {
  MateryalDeposu(ApiTransport istemci) : _api = MaterialsApi(istemci);

  final MaterialsApi _api;

  /// `GET …/materials`: görünen materyaller, en yeni önce. Süzgeçler
  /// sunucuda uygulanır; [sayfaToken] yalnızca aynı süzgeçle geçerlidir.
  /// Sayfayla birlikte `caller_can_add` döner.
  Future<({Sayfa<Material> sayfa, bool ekleyebilir})> materyaller(
    String tayfaId, {
    MaterialKind? tur,
    String? dersAnahtari,
    String? konuAnahtari,
    bool benim = false,
    String? sayfaToken,
  }) async {
    final liste = await _api.listMaterials(
      tayfaId: tayfaId,
      kind: tur,
      subjectKey: dersAnahtari,
      topicKey: konuAnahtari,
      mine: benim ? true : null,
      pageSize: materyalSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (
      sayfa: (ogeler: liste.materials, sonraki: liste.nextPageToken),
      ekleyebilir: liste.callerCanAdd,
    );
  }

  /// `GET …/materials/{id}`.
  Future<Material> materyal(String tayfaId, String materyalId) =>
      _api.getMaterial(tayfaId: tayfaId, materialId: materyalId);

  /// `POST …/materials`: kendi materyalini ekler.
  Future<Material> ekle(String tayfaId, MaterialCreateRequest istek) =>
      _api.createMaterial(tayfaId: tayfaId, body: istek);

  /// `PUT …/materials/{id}`: başlık, bağlantı ya da fotoğraflar ve
  /// etiketler birlikte yazılır; listede olmayan fotoğraf silinir.
  Future<Material> duzenle(
    String tayfaId,
    String materyalId,
    MaterialUpdateRequest istek,
  ) => _api.updateMaterial(
    tayfaId: tayfaId,
    materialId: materyalId,
    body: istek,
  );

  /// `DELETE …/materials/{id}`: siler (yazarı) ya da kaldırır (moderatör).
  /// Geri alınamaz.
  Future<void> sil(String tayfaId, String materyalId) =>
      _api.deleteMaterial(tayfaId: tayfaId, materialId: materyalId);
}

/// Materyal deposu; testlerde sahte taşımayla kurulur.
final materyalDeposuProvider = Provider<MateryalDeposu>(
  (ref) => MateryalDeposu(ref.watch(apiClientProvider)),
  name: 'materyalDeposuProvider',
);
