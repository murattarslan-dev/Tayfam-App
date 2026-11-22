// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `materials` olan uçlar.
final class MaterialsApi {
  const MaterialsApi(this._transport);

  final ApiTransport _transport;

  /// Materyal kütüphanesi
  ///
  /// Görünen materyaller, en yeni önce. `kind`, `subject_key`,
  /// `topic_key` ve `mine=true` (yalnızca çağıranınkiler) süzer;
  /// emekliye ayrılmış etiketle de süzülür. `next_page_token` yalnızca
  /// aynı süzgeçlerle geçerlidir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/materials`
  ///
  /// [subjectKey]: Ders anahtarı (`GET /v1/catalog` → `study_tags`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [topicKey]: Konu anahtarı.
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<MaterialList> listMaterials({
    required String tayfaId,
    MaterialKind? kind,
    String? subjectKey,
    String? topicKey,
    bool? mine,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/materials',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (kind != null) 'kind': kind.wire,
        if (subjectKey != null) 'subject_key': subjectKey,
        if (topicKey != null) 'topic_key': topicKey,
        if (mine != null) 'mine': '$mine',
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MaterialList.fromJson(jsonObject(response, 'listMaterials'));
  }

  /// Materyal ekler
  ///
  /// `link`: `url` zorunlu, fotoğraf yok. Bağlantı yalnızca `https`,
  /// kullanıcı bilgisi yok, IP adresi değil alan adı (Türkçe karakterli
  /// alan adı punycode olarak), 443 dışında port yok, boşluk ve görünmez
  /// karakter yok; sunucu normalleştirir (en fazla 500 karakter).
  /// Engelli alan adı `blocked-link`. `note_photo`: 1–3 fotoğraf
  /// (çağıranın bu tayfa için hazır `material_note` yüklemeleri), `url`
  /// yok. Ders zorunlu, konu isteğe bağlı ve o dersin altında; emekli
  /// etiket seçilemez. Aynı `client_request_id` ile tekrar gönderim aynı
  /// materyali döndürür. Üye başına en fazla 200 materyal
  /// (`material-limit`). Susturulmuş üye ekleyemez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/materials`
  Future<Material> createMaterial({
    required String tayfaId,
    required MaterialCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/materials',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Material.fromJson(jsonObject(response, 'createMaterial'));
  }

  /// Materyal
  ///
  /// Silinmiş, engelli alan adına bağlanan ya da bilinmeyen materyal
  /// `material-not-found`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/materials/{material_id}`
  ///
  /// [materialId]: Materyal kütüphanesindeki materyalin kimliği (`Material.id`).
  Future<Material> getMaterial({
    required String tayfaId,
    required String materialId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/materials/{material_id}',
      pathParams: {'tayfa_id': tayfaId, 'material_id': materialId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Material.fromJson(jsonObject(response, 'getMaterial'));
  }

  /// Kendi materyalini düzenler (yazarı)
  ///
  /// Başlık, bağlantı ya da fotoğraflar ve etiketler birlikte yazılır
  /// (kısmi güncelleme yok); türü değişmez. Listede olmayan fotoğraf
  /// silinir. Değişmeyen etiket emekliye ayrılmış olsa da kalır.
  /// Çağıranın olmayan materyal `material-not-found`. Susturulmuş üye
  /// düzenleyemez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/materials/{material_id}`
  ///
  /// [materialId]: Materyal kütüphanesindeki materyalin kimliği (`Material.id`).
  Future<Material> updateMaterial({
    required String tayfaId,
    required String materialId,
    required MaterialUpdateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/materials/{material_id}',
      pathParams: {'tayfa_id': tayfaId, 'material_id': materialId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Material.fromJson(jsonObject(response, 'updateMaterial'));
  }

  /// Materyali siler (yazarı) ya da kaldırır (moderatör)
  ///
  /// Yazarın silmesinde fotoğraflar hemen silinir; moderatörün
  /// kaldırması materyali gizler. İkisi de geri alınamaz; materyal 30
  /// gün sonra kalıcı silinir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/materials/{material_id}`
  ///
  /// [materialId]: Materyal kütüphanesindeki materyalin kimliği (`Material.id`).
  Future<void> deleteMaterial({
    required String tayfaId,
    required String materialId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/materials/{material_id}',
      pathParams: {'tayfa_id': tayfaId, 'material_id': materialId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
