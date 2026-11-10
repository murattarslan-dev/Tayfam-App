// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `polls` olan uçlar.
final class PollsApi {
  const PollsApi(this._transport);

  final ApiTransport _transport;

  /// Anketleri listeler
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur). Yeniden eskiye.
  /// `event_id` verilirse yalnızca o etkinliğin anketleri. Tayfanın anket
  /// modülü kapalıysa `module-disabled`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/polls`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<PollList> listPolls({
    required String tayfaId,
    String? eventId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (eventId != null) 'event_id': eventId,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return PollList.fromJson(jsonObject(response, 'listPolls'));
  }

  /// Anket açar (her etkin üye)
  ///
  /// Susturulmuş üye anket açamaz (`muted`). `event_id` verilirse
  /// etkinlik aynı tayfada ve silinmemiş olmalıdır (`event-not-found`).
  ///
  /// `POST /v1/tayfas/{tayfa_id}/polls`
  Future<Poll> createPoll({
    required String tayfaId,
    required PollCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Poll.fromJson(jsonObject(response, 'createPoll'));
  }

  /// Tek bir anket, sayımlar ve kendi oyunuz
  ///
  /// `GET /v1/tayfas/{tayfa_id}/polls/{poll_id}`
  Future<Poll> getPoll({
    required String tayfaId,
    required String pollId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls/{poll_id}',
      pathParams: {'tayfa_id': tayfaId, 'poll_id': pollId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Poll.fromJson(jsonObject(response, 'getPoll'));
  }

  /// Anketi ve oylarını siler (açan; moderatör, yönetici)
  ///
  /// Geri alınamaz. Başkasının anketini silmek için anketi açanın şu anki
  /// rolü sizinkinden düşük olmalıdır (`role-hierarchy`).
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/polls/{poll_id}`
  Future<void> deletePoll({
    required String tayfaId,
    required String pollId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls/{poll_id}',
      pathParams: {'tayfa_id': tayfaId, 'poll_id': pollId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Oyunuzu verir ya da değiştirir
  ///
  /// Önceki oyunuzun yerine geçer. Tek seçimli ankette tam bir, çok seçimli
  /// ankette en az bir seçenek. Kapalı ankette `poll-closed`; susturulmuş
  /// üye oy veremez (`muted`).
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/polls/{poll_id}/vote`
  Future<Poll> votePoll({
    required String tayfaId,
    required String pollId,
    required PollVoteRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls/{poll_id}/vote',
      pathParams: {'tayfa_id': tayfaId, 'poll_id': pollId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Poll.fromJson(jsonObject(response, 'votePoll'));
  }

  /// Oyunuzu geri çeker
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/polls/{poll_id}/vote`
  Future<Poll> withdrawPollVote({
    required String tayfaId,
    required String pollId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls/{poll_id}/vote',
      pathParams: {'tayfa_id': tayfaId, 'poll_id': pollId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Poll.fromJson(jsonObject(response, 'withdrawPollVote'));
  }

  /// Açık ankette bir seçeneğe oy verenler
  ///
  /// Gizli ankette kimse, yöneticiler dahil, oy verenleri göremez:
  /// `poll-anonymous`. En eski oy önce.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/polls/{poll_id}/options/{option_id}/voters`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<PollVoterList> listPollVoters({
    required String tayfaId,
    required String pollId,
    required String optionId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/polls/{poll_id}/options/{option_id}/voters',
      pathParams: {
        'tayfa_id': tayfaId,
        'poll_id': pollId,
        'option_id': optionId,
      },
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return PollVoterList.fromJson(jsonObject(response, 'listPollVoters'));
  }

  /// Anketi erken kapatır (açan; moderatör, yönetici)
  ///
  /// Hiyerarşi silmedeki gibidir. Kapalı anket için de başarılıdır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/polls/{poll_id}/closure`
  Future<Poll> closePoll({
    required String tayfaId,
    required String pollId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/polls/{poll_id}/closure',
      pathParams: {'tayfa_id': tayfaId, 'poll_id': pollId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Poll.fromJson(jsonObject(response, 'closePoll'));
  }
}
