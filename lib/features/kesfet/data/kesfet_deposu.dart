import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/discover_api.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Güvenlik kişisi seçerken okunan arkadaş sayısı (sözleşme: sayfa en çok
/// 100). Yalnızca ilk sayfa okunur (30-kesfet-ve-guvenlik, açık soru 3).
const int guvenlikArkadasSayfasi = 100;

/// Keşfet ve güvenlik ağı uçları (Tayfam-Api ADR-0033; istemci ADR-0027):
/// akış, Keşfet'ten katılım, tayfanın Keşfet ayarı, "Her şey yolunda
/// mıydı?", güvenlik kişisi, "Döndüm" ve güvenlik kişisi olunan
/// paylaşımlar. Yalnızca üretilmiş uç sınıflarını kullanır; bütün istekler
/// tek `ApiClient`'tan geçer (ADR-0005).
///
/// Cevaplar ve kimlikler log'a yazılmaz (kesin kural 3).
final class KesfetDeposu {
  KesfetDeposu(ApiTransport istemci)
    : _kesfet = DiscoverApi(istemci),
      _etkinlik = EventsApi(istemci),
      _ben = MeApi(istemci);

  final DiscoverApi _kesfet;
  final EventsApi _etkinlik;
  final MeApi _ben;

  /// `GET /v1/discover/events`: en çok 50 öğe, sayfalanmaz. Keşfet
  /// kapalıysa `feature-disabled`.
  Future<List<DiscoverItem>> akis() async =>
      (await _kesfet.listDiscoverFeed()).items;

  /// `POST /v1/discover/tayfas/{tayfa_id}/join`: her zaman bekleyen istek.
  Future<Membership> katil(String tayfaId) =>
      _kesfet.joinFromDiscover(tayfaId: tayfaId);

  /// `GET /v1/tayfas/{tayfa_id}/discover` (yönetici).
  Future<TayfaDiscover> tayfaAyari(String tayfaId) =>
      _kesfet.getTayfaDiscover(tayfaId: tayfaId);

  /// `PUT /v1/tayfas/{tayfa_id}/discover` (yönetici).
  Future<TayfaDiscover> tayfaAyariniDegistir(
    String tayfaId, {
    required bool acik,
  }) => _kesfet.setTayfaDiscover(
    tayfaId: tayfaId,
    body: TayfaDiscoverInput(enabled: acik),
  );

  /// `PUT /v1/tayfas/{tayfa_id}/discover/stats-showcase` (yönetici;
  /// #250, Tayfam-Api ADR-0026 §3).
  Future<TayfaDiscover> vitrinAyariniDegistir(
    String tayfaId, {
    required bool goster,
  }) => _kesfet.setTayfaStatsShowcase(
    tayfaId: tayfaId,
    body: TayfaStatsShowcaseInput(statsShowcase: goster),
  );

  /// `GET …/events/{event_id}/feedback`: cevap yoksa `answer` yok.
  Future<EventFeedback> geriBildirim(String tayfaId, String etkinlikId) =>
      _etkinlik.getEventFeedback(tayfaId: tayfaId, eventId: etkinlikId);

  /// `PUT …/events/{event_id}/feedback`.
  Future<EventFeedback> geriBildirimVer(
    String tayfaId,
    String etkinlikId,
    EventFeedbackInputAnswer cevap,
  ) => _etkinlik.setEventFeedback(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    body: EventFeedbackInput(answer: cevap),
  );

  /// `GET …/events/{event_id}/safety-contact`: seçilmemişse `contact` yok.
  Future<SafetyContact> guvenlikKisisi(String tayfaId, String etkinlikId) =>
      _etkinlik.getSafetyContact(tayfaId: tayfaId, eventId: etkinlikId);

  /// `PUT …/events/{event_id}/safety-contact`.
  Future<SafetyContact> guvenlikKisisiSec(
    String tayfaId,
    String etkinlikId, {
    required String kisiId,
    required int toleransDakika,
  }) => _etkinlik.setSafetyContact(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    body: SafetyContactInput(
      contactUserId: kisiId,
      graceMinutes: toleransDakika,
    ),
  );

  /// `DELETE …/events/{event_id}/safety-contact` (bayraksız).
  Future<void> guvenlikKisisiniKaldir(String tayfaId, String etkinlikId) =>
      _etkinlik.clearSafetyContact(tayfaId: tayfaId, eventId: etkinlikId);

  /// `POST …/events/{event_id}/safety-contact/return`: "Döndüm"
  /// (bayraksız).
  Future<SafetyContact> dondum(String tayfaId, String etkinlikId) =>
      _etkinlik.markReturned(tayfaId: tayfaId, eventId: etkinlikId);

  /// `GET /v1/me/safety-shares`: en çok 50, sayfalanmaz.
  Future<List<SafetyShare>> paylasimlar() async =>
      (await _ben.listSafetyShares()).shares;

  /// `GET /v1/me/friends`: güvenlik kişisi adayları (ilk sayfa).
  Future<List<Friend>> arkadaslar() async =>
      (await _ben.listFriends(pageSize: guvenlikArkadasSayfasi)).friends;
}

/// Keşfet deposu; testlerde sahtesi verilir.
final kesfetDeposuProvider = Provider<KesfetDeposu>(
  (ref) => KesfetDeposu(ref.watch(apiClientProvider)),
  name: 'kesfetDeposuProvider',
);
