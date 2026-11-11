import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/answers_api.dart';
import 'package:tayfam/core/api/gen/apis/questions_api.dart';
import 'package:tayfam/core/api/gen/apis/tags_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Soru ve cevap listelerinde bir sayfada istenen kayıt sayısı (sözleşme:
/// en çok 100).
const int soruCevapSayfaBoyutu = 20;

/// Soru-cevap uçları (ADR-0018 §4): `questions`, `answers`, `tags`.
/// Yalnızca üretilmiş uç sınıflarını kullanır; bütün istekler tek
/// `ApiClient`'tan geçer (ADR-0005).
final class SoruCevapDeposu {
  SoruCevapDeposu(ApiTransport istemci)
    : _sorular = QuestionsApi(istemci),
      _cevaplar = AnswersApi(istemci),
      _etiketler = TagsApi(istemci);

  final QuestionsApi _sorular;
  final AnswersApi _cevaplar;
  final TagsApi _etiketler;

  /// `GET /v1/tayfas/{tayfa_id}/questions`. [arama] boşsa yeniden eskiye;
  /// doluysa arama sunucuda yapılır (Türkçe büyük-küçük harf duyarsız) ve
  /// en ilgiliden başlar. [etiketId] ikisini de süzer. [sayfaToken] opaktır
  /// ve yalnızca aynı arama ve etiketle geçerlidir.
  Future<Sayfa<Question>> sorular(
    String tayfaId, {
    String arama = '',
    String? etiketId,
    String? sayfaToken,
  }) async {
    final liste = await _sorular.listQuestions(
      tayfaId: tayfaId,
      q: arama.isEmpty ? null : arama,
      tagId: etiketId,
      pageSize: soruCevapSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.questions, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/tayfas/{tayfa_id}/questions/{question_id}`.
  Future<Question> soru(String tayfaId, String soruId) =>
      _sorular.getQuestion(tayfaId: tayfaId, questionId: soruId);

  /// `POST /v1/tayfas/{tayfa_id}/questions`.
  Future<Question> soruSor(String tayfaId, QuestionCreateRequest istek) =>
      _sorular.createQuestion(tayfaId: tayfaId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/questions/{question_id}`.
  Future<Question> soruDuzenle(
    String tayfaId,
    String soruId,
    QuestionUpdateRequest istek,
  ) => _sorular.updateQuestion(
    tayfaId: tayfaId,
    questionId: soruId,
    body: istek,
  );

  /// `DELETE /v1/tayfas/{tayfa_id}/questions/{question_id}`.
  Future<void> soruSil(String tayfaId, String soruId) =>
      _sorular.deleteQuestion(tayfaId: tayfaId, questionId: soruId);

  /// `POST /v1/tayfas/{tayfa_id}/questions/{question_id}/restoration`.
  /// Yönetim ekranı (moderasyon kuyruğu, ADR-0018 §8) kullanır.
  Future<Question> soruyuGeriAl(String tayfaId, String soruId) =>
      _sorular.restoreQuestion(tayfaId: tayfaId, questionId: soruId);

  /// `GET /v1/tayfas/{tayfa_id}/questions/{question_id}/answers`: faydalı
  /// oyu çoktan aza, eşitlikte eskiden yeniye.
  Future<Sayfa<Answer>> cevaplar(
    String tayfaId,
    String soruId, {
    String? sayfaToken,
  }) async {
    final liste = await _sorular.listAnswers(
      tayfaId: tayfaId,
      questionId: soruId,
      pageSize: soruCevapSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.answers, sonraki: liste.nextPageToken);
  }

  /// `POST /v1/tayfas/{tayfa_id}/questions/{question_id}/answers`.
  Future<Answer> cevapla(
    String tayfaId,
    String soruId,
    AnswerCreateRequest istek,
  ) => _sorular.createAnswer(tayfaId: tayfaId, questionId: soruId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/answers/{answer_id}`.
  Future<Answer> cevapDuzenle(
    String tayfaId,
    String cevapId,
    AnswerUpdateRequest istek,
  ) => _cevaplar.updateAnswer(tayfaId: tayfaId, answerId: cevapId, body: istek);

  /// `DELETE /v1/tayfas/{tayfa_id}/answers/{answer_id}`.
  Future<void> cevapSil(String tayfaId, String cevapId) =>
      _cevaplar.deleteAnswer(tayfaId: tayfaId, answerId: cevapId);

  /// `POST /v1/tayfas/{tayfa_id}/answers/{answer_id}/restoration`.
  /// Yönetim ekranı (moderasyon kuyruğu, ADR-0018 §8) kullanır.
  Future<Answer> cevabiGeriAl(String tayfaId, String cevapId) =>
      _cevaplar.restoreAnswer(tayfaId: tayfaId, answerId: cevapId);

  /// Cevaba faydalı oyu verir (`PUT …/vote`) ya da geri alır
  /// (`DELETE …/vote`). Kendi cevabına oyu sunucu reddeder
  /// (`own-answer-vote`).
  Future<Answer> oyla(String tayfaId, String cevapId, {required bool oy}) => oy
      ? _cevaplar.voteAnswer(tayfaId: tayfaId, answerId: cevapId)
      : _cevaplar.unvoteAnswer(tayfaId: tayfaId, answerId: cevapId);

  /// `GET /v1/tayfas/{tayfa_id}/tags`: ada göre sıralı, en çok 200.
  Future<List<Tag>> etiketler(String tayfaId) async =>
      (await _etiketler.listTags(tayfaId: tayfaId)).tags;
}

/// Soru-cevap uçlarının deposu.
final soruCevapDeposuProvider = Provider<SoruCevapDeposu>(
  (ref) => SoruCevapDeposu(ref.watch(apiClientProvider)),
  name: 'soruCevapDeposuProvider',
);
