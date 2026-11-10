// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `questions` olan uçlar.
final class QuestionsApi {
  const QuestionsApi(this._transport);

  final ApiTransport _transport;

  /// Soruları listeler ve arar
  ///
  /// `q` yoksa yeniden eskiye; `q` varsa başlıkta ve gövdede Türkçe tam
  /// metin arama yapar (İ/ı doğru: "IŞIK" "ışık"ı, "izmir" "İzmir"i
  /// bulur) ve en ilgiliden başlar. `tag_id` ikisiyle de süzer. Arama
  /// metni gateway'de ve core'da log'a yazılmaz; `next_page_token`
  /// metni taşımaz ve yalnızca aynı `q` ve `tag_id` ile geçerlidir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/questions`
  ///
  /// [q]: Arama metni; en fazla 100 karakter, tek satır.
  ///
  /// Kısıtlar: maxLength: 100.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<QuestionList> listQuestions({
    required String tayfaId,
    String? q,
    String? tagId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (q != null) 'q': q,
        if (tagId != null) 'tag_id': tagId,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return QuestionList.fromJson(jsonObject(response, 'listQuestions'));
  }

  /// Soru sorar
  ///
  /// Etiketler adla verilir; tayfada büyük/küçük harf farkıyla (Türkçe
  /// kurallarla) aynı adlı etiket varsa o kullanılır, yoksa açılır.
  /// Tayfada en fazla 200 etiket olabilir (`tag-limit`). Aynı
  /// `client_request_id` ile tekrar gönderilen istek yeni soru açmaz,
  /// ilk soruyu döndürür.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/questions`
  Future<Question> createQuestion({
    required String tayfaId,
    required QuestionCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Question.fromJson(jsonObject(response, 'createQuestion'));
  }

  /// Tek bir soru
  ///
  /// `GET /v1/tayfas/{tayfa_id}/questions/{question_id}`
  Future<Question> getQuestion({
    required String tayfaId,
    required String questionId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Question.fromJson(jsonObject(response, 'getQuestion'));
  }

  /// Soruyu düzenler (yazar ya da moderatör, yönetici)
  ///
  /// Gövdede bulunan alanlar değişir; `tags` sorunun etiketlerini
  /// tümüyle değiştirir (boş dizi hepsini kaldırır).
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/questions/{question_id}`
  Future<Question> updateQuestion({
    required String tayfaId,
    required String questionId,
    required QuestionUpdateRequest body,
  }) async {
    final json = body.toJson();
    if (json.length < 1) {
      throw ArgumentError('QuestionUpdateRequest: en az 1 alan verilmeli');
    }
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      body: json,
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Question.fromJson(jsonObject(response, 'updateQuestion'));
  }

  /// Soruyu siler (yazar ya da moderatör, yönetici)
  ///
  /// Kendi sorunuzu silerseniz başlık, gövde ve etiketleri hemen
  /// kaldırılır, geri alınamaz. Başkasınınkini silmek onu gizler. Silinen
  /// sorunun cevapları da görünmez.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/questions/{question_id}`
  Future<void> deleteQuestion({
    required String tayfaId,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Gizlenen soruyu geri alır (yönetici)
  ///
  /// Moderatör ya da yöneticinin sildiği soru 30 gün içinde geri
  /// alınabilir; yazarın şu anki rolü sizinkinden düşük olmalıdır.
  /// Yazarın kendi sildiği ya da süresi geçen soru `question-not-found`
  /// alır. Görünen bir soru için de başarılıdır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/questions/{question_id}/restoration`
  Future<Question> restoreQuestion({
    required String tayfaId,
    required String questionId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}/restoration',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Question.fromJson(jsonObject(response, 'restoreQuestion'));
  }

  /// Sorunun cevapları
  ///
  /// Faydalı oyu çoktan aza, eşitlikte eskiden yeniye. `voted`
  /// çağıranın oyunu gösterir. Çözüm işaretleme yoktur.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/questions/{question_id}/answers`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<AnswerList> listAnswers({
    required String tayfaId,
    required String questionId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}/answers',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return AnswerList.fromJson(jsonObject(response, 'listAnswers'));
  }

  /// Soruyu cevaplar
  ///
  /// Aynı `client_request_id` ile tekrar gönderilen istek ilk cevabı
  /// döndürür. Soru sahibine bildirim gider (`answer_received`).
  ///
  /// `POST /v1/tayfas/{tayfa_id}/questions/{question_id}/answers`
  Future<Answer> createAnswer({
    required String tayfaId,
    required String questionId,
    required AnswerCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/questions/{question_id}/answers',
      pathParams: {'tayfa_id': tayfaId, 'question_id': questionId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Answer.fromJson(jsonObject(response, 'createAnswer'));
  }
}
