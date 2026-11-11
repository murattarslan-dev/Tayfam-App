import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/announcements_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Duyuru listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int duyuruSayfaBoyutu = 20;

/// Duyuru uçları (ADR-0015 §2). Yalnızca üretilmiş uç sınıfını kullanır;
/// bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class DuyuruDeposu {
  DuyuruDeposu(ApiTransport istemci) : _api = AnnouncementsApi(istemci);

  final AnnouncementsApi _api;

  /// `GET /v1/tayfas/{tayfa_id}/announcements`: sabitlenenler önce, sonra
  /// yeniden eskiye. [sayfaToken] opaktır.
  Future<Sayfa<Announcement>> sayfa(
    String tayfaId, {
    String? sayfaToken,
  }) async {
    final liste = await _api.listAnnouncements(
      tayfaId: tayfaId,
      pageSize: duyuruSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.announcements, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`.
  Future<Announcement> getir(String tayfaId, String duyuruId) =>
      _api.getAnnouncement(tayfaId: tayfaId, announcementId: duyuruId);

  /// `POST /v1/tayfas/{tayfa_id}/announcements`.
  Future<Announcement> olustur(
    String tayfaId,
    AnnouncementCreateRequest istek,
  ) => _api.createAnnouncement(tayfaId: tayfaId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`.
  Future<Announcement> duzenle(
    String tayfaId,
    String duyuruId,
    AnnouncementUpdateRequest istek,
  ) => _api.updateAnnouncement(
    tayfaId: tayfaId,
    announcementId: duyuruId,
    body: istek,
  );

  /// `DELETE /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`.
  Future<void> sil(String tayfaId, String duyuruId) =>
      _api.deleteAnnouncement(tayfaId: tayfaId, announcementId: duyuruId);

  /// Sabitler (`PUT …/pin`) ya da sabitlemeyi kaldırır (`DELETE …/pin`).
  Future<Announcement> sabitle(
    String tayfaId,
    String duyuruId, {
    required bool sabit,
  }) => sabit
      ? _api.pinAnnouncement(tayfaId: tayfaId, announcementId: duyuruId)
      : _api.unpinAnnouncement(tayfaId: tayfaId, announcementId: duyuruId);
}

/// Duyuru uçlarının deposu.
final duyuruDeposuProvider = Provider<DuyuruDeposu>(
  (ref) => DuyuruDeposu(ref.watch(apiClientProvider)),
  name: 'duyuruDeposuProvider',
);
