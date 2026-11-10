// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `tags` olan uçlar.
final class TagsApi {
  const TagsApi(this._transport);

  final ApiTransport _transport;

  /// Tayfanın etiketleri
  ///
  /// Ada göre sıralı, en fazla 200; her etiketin görünen soru sayısıyla.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/tags`
  Future<TagList> listTags({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/tags',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TagList.fromJson(jsonObject(response, 'listTags'));
  }

  /// Etiketi kaldırır (moderatör, yönetici)
  ///
  /// Etiket tayfadan ve tüm sorulardan kalkar; sorular kalır.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/tags/{tag_id}`
  Future<void> deleteTag({
    required String tayfaId,
    required String tagId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/tags/{tag_id}',
      pathParams: {'tayfa_id': tayfaId, 'tag_id': tagId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
