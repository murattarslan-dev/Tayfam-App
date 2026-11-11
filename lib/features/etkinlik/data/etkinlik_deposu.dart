import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Etkinlik listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int etkinlikSayfaBoyutu = 20;

/// Etkinlik uçları (ADR-0015 §3). Yalnızca üretilmiş uç sınıfını kullanır;
/// bütün istekler tek `ApiClient`'tan geçer (ADR-0005). Etkinlik
/// çekirdeği paketi (issue #38) detay, katılım ve oluşturma uçlarını buraya
/// ekler.
final class EtkinlikDeposu {
  EtkinlikDeposu(ApiTransport istemci) : _api = EventsApi(istemci);

  final EventsApi _api;

  /// `GET /v1/tayfas/{tayfa_id}/events`: bitmemiş etkinlikler, başlangıç
  /// zamanına göre; iptal edilenler de listededir. [sayfaToken] opaktır.
  Future<Sayfa<Event>> sayfa(String tayfaId, {String? sayfaToken}) async {
    final liste = await _api.listUpcomingEvents(
      tayfaId: tayfaId,
      pageSize: etkinlikSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.events, sonraki: liste.nextPageToken);
  }
}

/// Etkinlik uçlarının deposu.
final etkinlikDeposuProvider = Provider<EtkinlikDeposu>(
  (ref) => EtkinlikDeposu(ref.watch(apiClientProvider)),
  name: 'etkinlikDeposuProvider',
);
