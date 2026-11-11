import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Etkinlik listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int etkinlikSayfaBoyutu = 20;

/// Etkinlik uçları (ADR-0015 §3, §5, §6): liste, tek etkinlik, oluşturma,
/// düzenleme, iptal, katılım, katılımcılar, `.ics`, varış bildirimi, türe
/// özel araçlar ve organizatör düzeltmesi. Yalnızca üretilmiş uç
/// sınıflarını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005).
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

  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}`.
  Future<Event> etkinlik(String tayfaId, String etkinlikId) =>
      _api.getEvent(tayfaId: tayfaId, eventId: etkinlikId);

  /// `POST /v1/tayfas/{tayfa_id}/events`.
  Future<Event> olustur(String tayfaId, EventCreateRequest istek) =>
      _api.createEvent(tayfaId: tayfaId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/events/{event_id}`.
  Future<Event> duzenle(
    String tayfaId,
    String etkinlikId,
    EventUpdateRequest istek,
  ) => _api.updateEvent(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/cancellation`.
  Future<Event> iptalEt(String tayfaId, String etkinlikId, String gerekce) =>
      _api.cancelEvent(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        body: EventCancelRequest(reason: gerekce),
      );

  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/rsvp`; kaydedilen cevap
  /// (dolu etkinlikte `going` yerine `waitlist`).
  Future<RsvpStatus> katilim(
    String tayfaId,
    String etkinlikId,
    RsvpRequestStatus durum,
  ) async {
    final yanit = await _api.setEventRsvp(
      tayfaId: tayfaId,
      eventId: etkinlikId,
      body: RsvpRequest(status: durum),
    );
    return yanit.status;
  }

  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/attendees`: bir cevaptaki
  /// katılımcıların bir sayfası.
  Future<AttendeeList> katilimcilar(
    String tayfaId,
    String etkinlikId,
    ListEventAttendeesStatus durum, {
    String? token,
  }) => _api.listEventAttendees(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    status: durum,
    pageSize: etkinlikSayfaBoyutu,
    pageToken: token,
  );

  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/calendar`: iCalendar
  /// metni. Çevrimiçi bağlantıyı içerebilir; önbelleğe alınmaz.
  Future<String> takvim(String tayfaId, String etkinlikId) =>
      _api.exportEventCalendar(tayfaId: tayfaId, eventId: etkinlikId);

  /// `POST .../check-in`: varış bildirimi (ADR-0015 §5). Yüz yüze
  /// etkinlikte [konum] cihazın o anki konumudur; yalnızca bu istek
  /// gövdesinde gider, saklanmaz ve log'a yazılmaz (kesin kural 3).
  /// Çevrimiçi etkinlikte [konum] `null`'dır ("Katıldım").
  Future<CheckIn> varisBildir(
    String tayfaId,
    String etkinlikId, {
    LatLng? konum,
  }) => _api.checkInToEvent(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    body: CheckInRequest(location: konum),
  );

  /// `POST .../hike-start`: "Çıktım". Zaman sunucunundur; tekrar gönderim
  /// ilk çıkışı döndürür.
  Future<HikeCheckin> yuruyuseCik(String tayfaId, String etkinlikId) =>
      _api.startHike(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        body: const HikeStartRequest(),
      );

  /// `POST .../hike-return`: "Döndüm". Tekrar gönderim ilk dönüşü
  /// döndürür.
  Future<HikeCheckin> yuruyustenDon(String tayfaId, String etkinlikId) =>
      _api.finishHike(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        body: const HikeReturnRequest(),
      );

  /// `POST .../camp-items`: ortak malzeme listesine ekler.
  Future<CampItem> kampMalzemesiEkle(
    String tayfaId,
    String etkinlikId,
    CampItemCreateRequest istek,
  ) => _api.addCampItem(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `DELETE .../camp-items/{item_id}`.
  Future<void> kampMalzemesiCikar(
    String tayfaId,
    String etkinlikId,
    String malzemeId,
  ) => _api.removeCampItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    itemId: malzemeId,
  );

  /// `POST .../convoy-vehicles`: kendi aracını ekler; önceki aracının
  /// yerini alır.
  Future<ConvoyVehicle> aracEkle(
    String tayfaId,
    String etkinlikId,
    ConvoyVehicleCreateRequest istek,
  ) =>
      _api.addConvoyVehicle(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `DELETE .../convoy-vehicles/{vehicle_id}`.
  Future<void> aracCikar(String tayfaId, String etkinlikId, String aracId) =>
      _api.removeConvoyVehicle(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        vehicleId: aracId,
      );

  /// `GET .../fishing-catches`: av günlüğünün bir sayfası, eskiden yeniye.
  Future<Sayfa<FishingCatch>> avlar(
    String tayfaId,
    String etkinlikId, {
    String? sayfaToken,
  }) async {
    final liste = await _api.listFishingCatches(
      tayfaId: tayfaId,
      eventId: etkinlikId,
      pageSize: etkinlikSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.catches, sonraki: liste.nextPageToken);
  }

  /// `POST .../fishing-catches`. Aynı `client_request_id` ile tekrar
  /// gönderim ilk avı döndürür. Av yeri kullanıcının bilerek paylaştığı
  /// içeriktir; log'a yazılmaz.
  Future<FishingCatch> avEkle(
    String tayfaId,
    String etkinlikId,
    FishingCatchCreateRequest istek,
  ) => _api.addFishingCatch(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `DELETE .../fishing-catches/{catch_id}`.
  Future<void> avCikar(String tayfaId, String etkinlikId, String avId) => _api
      .removeFishingCatch(tayfaId: tayfaId, eventId: etkinlikId, catchId: avId);

  /// Organizatör düzeltmesi: `PUT .../attendees/{user_id}/attendance`
  /// ([ekle]) ya da `DELETE` ile katılımı ekler veya kaldırır.
  Future<void> katilimDuzelt(
    String tayfaId,
    String etkinlikId,
    String kullaniciId, {
    required bool ekle,
  }) => ekle
      ? _api.confirmAttendance(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          userId: kullaniciId,
        )
      : _api.removeAttendance(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          userId: kullaniciId,
        );
}

/// Etkinlik uçlarının deposu.
final etkinlikDeposuProvider = Provider<EtkinlikDeposu>(
  (ref) => EtkinlikDeposu(ref.watch(apiClientProvider)),
  name: 'etkinlikDeposuProvider',
);
