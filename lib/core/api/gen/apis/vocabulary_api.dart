// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `vocabulary` olan uçlar.
final class VocabularyApi {
  const VocabularyApi(this._transport);

  final ApiTransport _transport;

  /// Sözlükte arar (otomatik tamamlama)
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur). Metni ya da ona
  /// birleştirilmiş bir değerin metni `q`'yu içeren en fazla 20 değer;
  /// `q` ile başlayanlar önce. Birleştirilmiş değerler hedeflerine
  /// çözülür. `merged=true` ile bunların yerine birleştirilmiş değerler
  /// hedefleriyle döner (geri alma için).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/vocabulary/{namespace}`
  ///
  /// [namespace]: Sözlüğün ad alanı (`CatalogVocabulary.namespace`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [q]: Arama metni; en fazla 60 karakter. Boşsa ilk 20 değer.
  ///
  /// Kısıtlar: maxLength: 60.
  ///
  /// [merged]: Birleştirilmiş değerleri listeler.
  ///
  /// Kısıtlar: varsayılan (sunucu): false.
  Future<TayfaVocabularyList> listTayfaVocabulary({
    required String tayfaId,
    required String namespace,
    String? q,
    bool? merged,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/vocabulary/{namespace}',
      pathParams: {'tayfa_id': tayfaId, 'namespace': namespace},
      query: {if (q != null) 'q': q, if (merged != null) 'merged': '$merged'},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaVocabularyList.fromJson(
      jsonObject(response, 'listTayfaVocabulary'),
    );
  }

  /// Değeri başka bir değere birleştirir (moderatör, yönetici)
  ///
  /// Değeri seçen kayıtlar artık hedefi gösterir. Değer ya da hedef zaten
  /// birleştirilmişse `vocabulary-merged`; bilinmeyen değer
  /// `vocabulary-not-found`; kendisine birleştirme `invalid-request`.
  /// Salt okunur tayfada `tayfa-read-only`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/vocabulary/{namespace}/{vocabulary_id}/merge`
  ///
  /// [namespace]: Sözlüğün ad alanı (`CatalogVocabulary.namespace`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vocabularyId]: Birleştirilen değer.
  Future<TayfaVocabularyValue> mergeTayfaVocabulary({
    required String tayfaId,
    required String namespace,
    required String vocabularyId,
    required TayfaVocabularyMergeRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/vocabulary/{namespace}/{vocabulary_id}/merge',
      pathParams: {
        'tayfa_id': tayfaId,
        'namespace': namespace,
        'vocabulary_id': vocabularyId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaVocabularyValue.fromJson(
      jsonObject(response, 'mergeTayfaVocabulary'),
    );
  }

  /// Birleştirmeyi geri alır (moderatör, yönetici)
  ///
  /// Değeri seçen kayıtlar yine kendi değerini gösterir. Birleştirilmemiş
  /// değer `vocabulary-not-merged`; bilinmeyen değer
  /// `vocabulary-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/vocabulary/{namespace}/{vocabulary_id}/merge`
  ///
  /// [namespace]: Sözlüğün ad alanı (`CatalogVocabulary.namespace`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vocabularyId]: Birleştirilen değer.
  Future<void> unmergeTayfaVocabulary({
    required String tayfaId,
    required String namespace,
    required String vocabularyId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/vocabulary/{namespace}/{vocabulary_id}/merge',
      pathParams: {
        'tayfa_id': tayfaId,
        'namespace': namespace,
        'vocabulary_id': vocabularyId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
