// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `reports` olan uçlar.
final class ReportsApi {
  const ReportsApi(this._transport);

  final ApiTransport _transport;

  /// Tayfada bir üyeyi, tayfanın kendisini ya da bir içeriği şikâyet eder
  ///
  /// Her etkin üye, susturulmuş olsa da, şikâyet edebilir. Hedef, sizin o
  /// tayfada görebildiğiniz bir şey olmalıdır: başka bir etkin üye,
  /// tayfanın kendisi (`target_id` = `tayfa_id`) ya da modülü açık,
  /// görünür bir içerik. Diğer her durumda `report-target-not-found`
  /// döner (hangi sebeple olduğu söylenmez). Kendinizi ya da kendi
  /// içeriğinizi şikâyet edemezsiniz (`invalid-request`).
  ///
  /// Aynı hedefi ikinci kez şikâyet etmek yeni kayıt açmaz; ilk şikâyetiniz
  /// `200` ile döner. Yeni şikâyet `201` döner. 24 saatte en fazla 20
  /// şikâyet (`report-limit`).
  ///
  /// Şikâyet edenin kimliği şikâyet edilen kişiye hiçbir zaman gösterilmez;
  /// tayfanın moderatörlerine ve yöneticilerine de gösterilmez. Tayfanın
  /// kendisi ve `staff_conduct` şikâyetleri yalnızca platforma gider.
  /// Birebir mesaj (`dm_message`) şikâyeti bir tayfaya ait olmadığı için
  /// bu uçta değil, `POST /v1/me/reports` ile yapılır (burada
  /// `invalid-request`). Kanal mesajları henüz şikâyet edilemez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/reports`
  Future<MyReport> createReport({
    required String tayfaId,
    required ReportCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/reports',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return MyReport.fromJson(jsonObject(response, 'createReport'));
  }

  /// Tayfanın moderasyon kuyruğu (moderatör, yönetici)
  ///
  /// `status=open` (varsayılan): önce `priority: minor_involved` ve
  /// `reason: child_safety` şikâyetler, sonra eskiden yeniye. `status=resolved`: son çözülen
  /// önce. Platforma özel şikâyetler ve sizin hakkınızdaki şikâyetler
  /// listelenmez. Şikâyet edenin kimliği yoktur. Tarafların yaşı ve doğum
  /// tarihi gösterilmez; yalnızca öncelik (ADR-0012, 2026-11-09 kararı).
  /// Susturulmuş moderatör de okur.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/reports`
  ///
  /// [status]: Kısıtlar: varsayılan (sunucu): `open`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<ModerationReportList> listTayfaReports({
    required String tayfaId,
    ListTayfaReportsStatus? status,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/reports',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (status != null) 'status': status.wire,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
    );
    return ModerationReportList.fromJson(
      jsonObject(response, 'listTayfaReports'),
    );
  }

  /// Kuyruktaki açık bir şikâyeti çözer (moderatör, yönetici)
  ///
  /// Susturulmuşken yapılamaz (`muted`). Şikâyet edilen kişinin mevcut
  /// rolü sizinkinden düşük olmalıdır (`role-hierarchy`). Çözüm, ilgili
  /// içeriğin ya da üyeliğin kendi uçlarıyla önceden yapılmış işleme
  /// bağlanır:
  /// - `content_removed`: içerik artık görünmüyor (silinmiş; etkinlikte
  ///   iptal de sayılır). Üye ve tayfa şikâyetinde kullanılamaz.
  /// - `member_sanctioned`: şikâyet edilen kişi şu anda susturulmuş ya da
  ///   banlı.
  /// - `dismissed`: işlem yok.
  /// İşlem yapılmamışsa `report-action-missing`; çözülmüş şikâyette
  /// `report-already-resolved` döner. Şikâyet eden kişi hâlâ etkin üyeyse
  /// aktörsüz `report_resolved` bildirimi alır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/reports/{report_id}/resolution`
  Future<ModerationReport> resolveReport({
    required String tayfaId,
    required String reportId,
    required ReportResolveRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/reports/{report_id}/resolution',
      pathParams: {'tayfa_id': tayfaId, 'report_id': reportId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return ModerationReport.fromJson(jsonObject(response, 'resolveReport'));
  }
}
