import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/polls_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Anket listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int anketSayfaBoyutu = 20;

/// Oy verenler listesinde bir sayfada istenen kayıt sayısı.
const int oyVerenSayfaBoyutu = 50;

/// Anket uçları (ADR-0018 §5). Yalnızca üretilmiş uç sınıfını kullanır;
/// bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
///
/// Oy verenler ucu ([oyVerenler]) yalnızca açık (gizli olmayan) anket için
/// çağrılır; bu denetim çağıran notifier'dadır (kesin kural 7).
final class AnketDeposu {
  AnketDeposu(ApiTransport istemci) : _api = PollsApi(istemci);

  final PollsApi _api;

  /// `GET /v1/tayfas/{tayfa_id}/polls`: yeniden eskiye; [etkinlikId]
  /// verilirse yalnızca o etkinliğin anketleri. [sayfaToken] opaktır.
  Future<Sayfa<Poll>> sayfa(
    String tayfaId, {
    String? etkinlikId,
    String? sayfaToken,
  }) async {
    final liste = await _api.listPolls(
      tayfaId: tayfaId,
      eventId: etkinlikId,
      pageSize: anketSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.polls, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/tayfas/{tayfa_id}/polls/{poll_id}`.
  Future<Poll> getir(String tayfaId, String anketId) =>
      _api.getPoll(tayfaId: tayfaId, pollId: anketId);

  /// `POST /v1/tayfas/{tayfa_id}/polls`.
  Future<Poll> olustur(String tayfaId, PollCreateRequest istek) =>
      _api.createPoll(tayfaId: tayfaId, body: istek);

  /// `PUT …/vote`: oyu verir ya da değiştirir.
  Future<Poll> oyVer(String tayfaId, String anketId, List<String> secenekler) =>
      _api.votePoll(
        tayfaId: tayfaId,
        pollId: anketId,
        body: PollVoteRequest(optionIds: secenekler),
      );

  /// `DELETE …/vote`: oyu geri çeker.
  Future<Poll> oyuGeriCek(String tayfaId, String anketId) =>
      _api.withdrawPollVote(tayfaId: tayfaId, pollId: anketId);

  /// `POST …/closure`: anketi erken kapatır.
  Future<Poll> kapat(String tayfaId, String anketId) =>
      _api.closePoll(tayfaId: tayfaId, pollId: anketId);

  /// `GET …/options/{option_id}/voters`: en eski oy önce.
  Future<Sayfa<PollVoter>> oyVerenler(
    String tayfaId,
    String anketId,
    String secenekId, {
    String? sayfaToken,
  }) async {
    final liste = await _api.listPollVoters(
      tayfaId: tayfaId,
      pollId: anketId,
      optionId: secenekId,
      pageSize: oyVerenSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.voters, sonraki: liste.nextPageToken);
  }
}

/// Anket uçlarının deposu.
final anketDeposuProvider = Provider<AnketDeposu>(
  (ref) => AnketDeposu(ref.watch(apiClientProvider)),
  name: 'anketDeposuProvider',
);
