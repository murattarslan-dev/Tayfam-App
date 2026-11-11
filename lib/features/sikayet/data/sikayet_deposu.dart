import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/announcements_api.dart';
import 'package:tayfam/core/api/gen/apis/answers_api.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/polls_api.dart';
import 'package:tayfam/core/api/gen/apis/questions_api.dart';
import 'package:tayfam/core/api/gen/apis/reports_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Moderasyon kuyruğunda bir sayfada istenen şikâyet sayısı (sözleşme: en
/// çok 100).
const int kuyrukSayfaBoyutu = 30;

/// Kuyrukta şikâyet edilen içeriğin kısa önizlemesi: başlık ya da soru
/// metni. İçerik artık görünmüyorsa (silinmiş, iptal edilmiş değil)
/// [gorunmuyor] `true`'dur.
typedef HedefOnizlemesi = ({String? baslik, bool gorunmuyor});

/// Şikâyet ve tayfa moderasyonu uçları (ADR-0018 §8). Yalnızca üretilmiş
/// uç sınıflarını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005).
///
/// Birebir mesaj şikâyetindeki mesaj metni ([birebirMesajiSikayetEt])
/// yalnızca istek gövdesinde gider; burada saklanmaz ve log'a yazılmaz
/// (kesin kural 3).
final class SikayetDeposu {
  SikayetDeposu(ApiTransport istemci)
    : _sikayetler = ReportsApi(istemci),
      _ben = MeApi(istemci),
      _duyurular = AnnouncementsApi(istemci),
      _etkinlikler = EventsApi(istemci),
      _sorular = QuestionsApi(istemci),
      _cevaplar = AnswersApi(istemci),
      _anketler = PollsApi(istemci);

  final ReportsApi _sikayetler;
  final MeApi _ben;
  final AnnouncementsApi _duyurular;
  final EventsApi _etkinlikler;
  final QuestionsApi _sorular;
  final AnswersApi _cevaplar;
  final PollsApi _anketler;

  /// `POST /v1/tayfas/{tayfa_id}/reports`. Aynı hedefin ikinci şikâyeti
  /// ilk şikâyeti döndürür (`200`); yeni kayıt açılmaz.
  Future<MyReport> tayfadaSikayetEt(
    String tayfaId,
    ReportCreateRequest istek,
  ) => _sikayetler.createReport(tayfaId: tayfaId, body: istek);

  /// `POST /v1/me/reports`: birebir mesaj şikâyeti; yalnızca platforma
  /// gider, hiçbir tayfanın kuyruğuna düşmez.
  Future<MyReport> birebirMesajiSikayetEt(ReportCreateRequest istek) =>
      _ben.createDirectMessageReport(body: istek);

  /// `GET /v1/tayfas/{tayfa_id}/reports`: açık kuyruk öncelik sırasıyla,
  /// sonuçlananlar son çözülen önce.
  Future<Sayfa<ModerationReport>> kuyruk(
    String tayfaId, {
    required bool acik,
    String? sayfaToken,
  }) async {
    final liste = await _sikayetler.listTayfaReports(
      tayfaId: tayfaId,
      status: acik
          ? ListTayfaReportsStatus.open
          : ListTayfaReportsStatus.resolved,
      pageSize: kuyrukSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.reports, sonraki: liste.nextPageToken);
  }

  /// `POST …/reports/{report_id}/resolution`. Çözüm, içeriğin ya da
  /// üyeliğin kendi uçlarıyla önceden yapılmış işleme bağlanır; işlem
  /// yoksa sunucu `report-action-missing` döndürür.
  Future<ModerationReport> sonuclandir(
    String tayfaId,
    String sikayetId,
    ModerationReportResolution sonuc,
  ) => _sikayetler.resolveReport(
    tayfaId: tayfaId,
    reportId: sikayetId,
    body: ReportResolveRequest(resolution: _cozum(sonuc)),
  );

  /// Şikâyet edilen içeriği moderatör olarak siler (duyuru, soru, cevap,
  /// anket). Başka türler için [ArgumentError].
  Future<void> icerigiKaldir(
    String tayfaId,
    ReportTargetType tur,
    String id,
  ) => switch (tur) {
    ReportTargetType.announcement => _duyurular.deleteAnnouncement(
      tayfaId: tayfaId,
      announcementId: id,
    ),
    ReportTargetType.question => _sorular.deleteQuestion(
      tayfaId: tayfaId,
      questionId: id,
    ),
    ReportTargetType.answer => _cevaplar.deleteAnswer(
      tayfaId: tayfaId,
      answerId: id,
    ),
    ReportTargetType.poll => _anketler.deletePoll(tayfaId: tayfaId, pollId: id),
    _ => throw ArgumentError.value(tur.name, 'tur'),
  };

  /// Moderasyonla gizlenen içeriği geri alır (`…/restoration`; duyuru,
  /// soru, cevap). 30 gün içinde ve yazarın rolü sizinkinden düşükse;
  /// görünen içerik için de başarılıdır. Başka türler için
  /// [ArgumentError].
  Future<void> geriAl(String tayfaId, ReportTargetType tur, String id) async {
    switch (tur) {
      case ReportTargetType.announcement:
        await _duyurular.restoreAnnouncement(
          tayfaId: tayfaId,
          announcementId: id,
        );
      case ReportTargetType.question:
        await _sorular.restoreQuestion(tayfaId: tayfaId, questionId: id);
      case ReportTargetType.answer:
        await _cevaplar.restoreAnswer(tayfaId: tayfaId, answerId: id);
      default:
        throw ArgumentError.value(tur.name, 'tur');
    }
  }

  /// Şikâyet edilen içeriğin önizlemesi (duyuru, etkinlik, soru, anket).
  /// Okunamayan tür için `null`. İçerik bulunamıyorsa (`*-not-found`)
  /// çağıran [HedefOnizlemesi.gorunmuyor] ile gösterir.
  Future<String?> onizlemeBasligi(
    String tayfaId,
    ReportTargetType tur,
    String id,
  ) async => switch (tur) {
    ReportTargetType.announcement => (await _duyurular.getAnnouncement(
      tayfaId: tayfaId,
      announcementId: id,
    )).title,
    ReportTargetType.event => (await _etkinlikler.getEvent(
      tayfaId: tayfaId,
      eventId: id,
    )).title,
    ReportTargetType.question => (await _sorular.getQuestion(
      tayfaId: tayfaId,
      questionId: id,
    )).title,
    ReportTargetType.poll => (await _anketler.getPoll(
      tayfaId: tayfaId,
      pollId: id,
    )).question,
    _ => null,
  };

  static ReportResolveRequestResolution _cozum(
    ModerationReportResolution sonuc,
  ) => switch (sonuc) {
    ModerationReportResolution.contentRemoved =>
      ReportResolveRequestResolution.contentRemoved,
    ModerationReportResolution.memberSanctioned =>
      ReportResolveRequestResolution.memberSanctioned,
    ModerationReportResolution.dismissed =>
      ReportResolveRequestResolution.dismissed,
    ModerationReportResolution.unknown => throw ArgumentError.value(
      sonuc.name,
      'sonuc',
    ),
  };
}

/// Şikâyet deposu; testte sahte taşımayla override edilir.
final sikayetDeposuProvider = Provider<SikayetDeposu>(
  (ref) => SikayetDeposu(ref.watch(apiClientProvider)),
  name: 'sikayetDeposuProvider',
);
