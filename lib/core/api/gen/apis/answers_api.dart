// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `answers` olan uçlar.
final class AnswersApi {
  const AnswersApi(this._transport);

  final ApiTransport _transport;

  /// Cevabı düzenler (yazar ya da moderatör, yönetici)
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/answers/{answer_id}`
  Future<Answer> updateAnswer({
    required String tayfaId,
    required String answerId,
    required AnswerUpdateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/answers/{answer_id}',
      pathParams: {'tayfa_id': tayfaId, 'answer_id': answerId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return Answer.fromJson(jsonObject(response, 'updateAnswer'));
  }

  /// Cevabı siler (yazar ya da moderatör, yönetici)
  ///
  /// Kendi cevabınızı silerseniz metni ve oyları hemen kaldırılır, geri
  /// alınamaz. Başkasınınkini silmek onu gizler (oylar korunur).
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/answers/{answer_id}`
  Future<void> deleteAnswer({
    required String tayfaId,
    required String answerId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/answers/{answer_id}',
      pathParams: {'tayfa_id': tayfaId, 'answer_id': answerId},
      expect: ResponseKind.none,
    );
  }

  /// Gizlenen cevabı geri alır (yönetici)
  ///
  /// Kurallar soruyu geri almadaki gibi; sorusu silinmiş cevap
  /// `answer-not-found` alır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/answers/{answer_id}/restoration`
  Future<Answer> restoreAnswer({
    required String tayfaId,
    required String answerId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/answers/{answer_id}/restoration',
      pathParams: {'tayfa_id': tayfaId, 'answer_id': answerId},
      expect: ResponseKind.json,
    );
    return Answer.fromJson(jsonObject(response, 'restoreAnswer'));
  }

  /// Cevaba faydalı oyu verir
  ///
  /// Kişi başına bir oy; zaten verdiyseniz değişmez. Kendi cevabınıza oy
  /// veremezsiniz (`own-answer-vote`).
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/answers/{answer_id}/vote`
  Future<Answer> voteAnswer({
    required String tayfaId,
    required String answerId,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/answers/{answer_id}/vote',
      pathParams: {'tayfa_id': tayfaId, 'answer_id': answerId},
      expect: ResponseKind.json,
    );
    return Answer.fromJson(jsonObject(response, 'voteAnswer'));
  }

  /// Faydalı oyunu geri alır
  ///
  /// Oy yoksa değişmez.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/answers/{answer_id}/vote`
  Future<Answer> unvoteAnswer({
    required String tayfaId,
    required String answerId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/answers/{answer_id}/vote',
      pathParams: {'tayfa_id': tayfaId, 'answer_id': answerId},
      expect: ResponseKind.json,
    );
    return Answer.fromJson(jsonObject(response, 'unvoteAnswer'));
  }
}
