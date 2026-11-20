import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/apis/instant_events_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Etkinlik listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int etkinlikSayfaBoyutu = 20;

/// Albümün sayfa boyutu (sözleşme: en çok 100; 3 sütunlu ızgaraya tam
/// bölünür). Bir sayfanın linkleri tek `POST /v1/media/urls`'e sığar.
const int albumSayfaBoyutu = 60;

/// Etkinlik uçları (ADR-0015 §3, §5, §6): liste, tek etkinlik, oluşturma,
/// düzenleme, iptal, katılım, katılımcılar, `.ics`, varış bildirimi, türe
/// özel araçlar, organizatör düzeltmesi ve anlık etkinlik (ADR-0026).
/// Yalnızca üretilmiş uç
/// sınıflarını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005).
final class EtkinlikDeposu {
  EtkinlikDeposu(ApiTransport istemci)
    : _api = EventsApi(istemci),
      _anlik = InstantEventsApi(istemci);

  final EventsApi _api;
  final InstantEventsApi _anlik;

  /// `POST /v1/instant-events`: gizli, tek etkinlikli tayfa ve etkinliği
  /// açar (Tayfam-Api ADR-0032). Aynı `event.client_request_id` ile tekrar
  /// gönderim ilk açılanı döndürür.
  Future<InstantEvent> anlikOlustur(InstantEventCreateRequest istek) =>
      _anlik.createInstantEvent(body: istek);

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

  /// `GET .../events/{event_id}/components`: etkinliğin bileşenleri ve
  /// organizatörün seçimleri (ADR-0031 §1).
  Future<EventComponentList> bilesenler(String tayfaId, String etkinlikId) =>
      _api.listEventComponents(tayfaId: tayfaId, eventId: etkinlikId);

  /// `PUT .../events/{event_id}/components/{component_key}`: `optional`
  /// bileşeni açar ya da kapatır, organizatöre bırakılan parametrelerde
  /// seçenek belirler. Etkinlik başladıktan sonra `component-locked`.
  Future<EventComponentList> bilesenSec(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventComponentSelectionRequest istek,
  ) => _api.setEventComponent(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `GET .../components/{component_key}/route`: rota bileşeninin
  /// güzergâhı (#227); rota yoksa `points` boştur.
  Future<EventRoute> rota(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventRoute(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../components/{component_key}/route`: rotanın tamamını yazar;
  /// boş [noktalar] rotayı kaldırır.
  Future<EventRoute> rotaYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    List<LatLng> noktalar,
  ) => _api.setEventRoute(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: EventRouteRequest(points: noktalar),
  );

  /// `GET .../events/{event_id}/referees`: hakem atamaları.
  Future<List<EventReferee>> hakemler(String tayfaId, String etkinlikId) async {
    final liste = await _api.listEventReferees(
      tayfaId: tayfaId,
      eventId: etkinlikId,
    );
    return liste.referees;
  }

  /// `POST .../events/{event_id}/referees`: etkinliğin tamamına, bir
  /// bileşenine ya da bileşenin bir kapsamına hakem atar. Aynı atama tekrar
  /// gönderilirse ilk atama döner.
  Future<EventReferee> hakemAta(
    String tayfaId,
    String etkinlikId,
    EventRefereeAssignRequest istek,
  ) => _api.assignEventReferee(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    body: istek,
  );

  /// `DELETE .../events/{event_id}/referees/{referee_id}`.
  Future<void> hakemKaldir(String tayfaId, String etkinlikId, String hakemId) =>
      _api.removeEventReferee(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        refereeId: hakemId,
      );

  /// `POST /v1/tayfas/{tayfa_id}/events`.
  Future<Event> olustur(String tayfaId, EventCreateRequest istek) =>
      _api.createEvent(tayfaId: tayfaId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/events/{event_id}`.
  Future<Event> duzenle(
    String tayfaId,
    String etkinlikId,
    EventUpdateRequest istek,
  ) => _api.updateEvent(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/finish`: açık uçlu
  /// (Şimdi başlat) etkinliği bitirir; gövdesizdir (Tayfam-Api ADR-0038).
  Future<Event> bitir(String tayfaId, String etkinlikId) =>
      _api.finishEvent(tayfaId: tayfaId, eventId: etkinlikId);

  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/cancellation`.
  Future<Event> iptalEt(String tayfaId, String etkinlikId, String? gerekce) =>
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

  /// `GET .../components/{component_key}/roll-call`: yoklama bileşeni
  /// (#230), çağıranın gördüğü haliyle.
  Future<EventRollCall> yoklama(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventRollCall(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../roll-call/expected-return`: beklenen dönüşü [donus] yapar;
  /// `null` ise planı kaldırır (gövdede alan yok).
  Future<EventRollCall> beklenenDonusYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    DateTime? donus,
  ) => _api.setEventRollCallExpectedReturn(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: RollCallPlanRequest(expectedReturnAt: donus?.toUtc()),
  );

  /// `POST .../roll-call/start`: "Çıktım"; katılım sayılır. Zaman
  /// sunucunundur; tekrar gönderim ilk çıkışı döndürür. Konum gönderilmez.
  Future<EventRollCall> yoklamadaCik(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.startEventRollCall(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: const RollCallStartRequest(),
  );

  /// `POST .../roll-call/return`: "Döndüm". Güvenlik sinyalidir: bitişten
  /// sonra ve iptal edilmiş etkinlikte de çalışır. Tekrar gönderim ilk
  /// dönüşü döndürür.
  Future<EventRollCall> yoklamadanDon(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.returnEventRollCall(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: const RollCallReturnRequest(),
  );

  /// `GET .../components/{component_key}/items`: liste bileşeninin
  /// maddeleri (#229), çağıranın gördüğü haliyle.
  Future<Checklist> liste(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.listChecklist(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../items`: listeye madde ekler.
  Future<Checklist> maddeEkle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    ChecklistItemRequest istek,
  ) => _api.addChecklistItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `DELETE .../items/{item_id}`.
  Future<Checklist> maddeCikar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String maddeId,
  ) => _api.removeChecklistItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    itemId: maddeId,
  );

  /// `PUT .../items/{item_id}/assignee`: maddeyi [kullaniciId]'ye atar;
  /// `null` ise atamayı kaldırır (gövdede alan yok).
  Future<Checklist> maddeAta(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String maddeId,
    String? kullaniciId,
  ) => _api.assignChecklistItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    itemId: maddeId,
    body: ChecklistAssignRequest(assignedUserId: kullaniciId),
  );

  /// `GET .../components/{component_key}/vehicles`: araçlar bileşeninin
  /// araçları (#228), çağıranın gördüğü haliyle.
  Future<EventVehicles> araclar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.listEventVehicles(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../vehicles/mine`: kendi aracını yazar; önceki aracının yerini
  /// alır.
  Future<EventVehicles> aracYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventVehicleRequest istek,
  ) => _api.setEventVehicle(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `DELETE .../vehicles/{vehicle_id}`: aracı koltuk istekleriyle
  /// birlikte çıkarır.
  Future<EventVehicles> aracCikar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String aracId,
  ) => _api.removeEventVehicle(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    vehicleId: aracId,
  );

  /// `PUT .../vehicles/{vehicle_id}/seat-requests/mine`: bu araçta koltuk
  /// ister; araç sahibinin onayını bekler.
  Future<EventVehicles> koltukIste(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String aracId,
  ) => _api.requestEventVehicleSeat(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    vehicleId: aracId,
  );

  /// `PUT .../seat-requests/{user_id}/approval`: araç sahibi isteği
  /// onaylar.
  Future<EventVehicles> koltukOnayla(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String aracId,
    String kullaniciId,
  ) => _api.approveEventVehicleSeat(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    vehicleId: aracId,
    userId: kullaniciId,
  );

  /// `DELETE .../seat-requests/{user_id}`: bekleyen ya da onaylanmış
  /// koltuk isteğini kaldırır (geri çekme, reddetme, yolcuyu çıkarma).
  Future<EventVehicles> koltukBirak(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String aracId,
    String kullaniciId,
  ) => _api.releaseEventVehicleSeat(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    vehicleId: aracId,
    userId: kullaniciId,
  );

  /// `GET .../components/{component_key}/entries`: günlüğün bir sayfası,
  /// eskiden yeniye (Tayfam-Api #243). Her sayfa günlüğün parametrelerini
  /// ve çağıranın yetkisini de taşır.
  Future<EventLogEntryList> gunlukKayitlari(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari, {
    String? sayfaToken,
  }) => _api.listEventLogEntries(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    pageSize: etkinlikSayfaBoyutu,
    pageToken: sayfaToken,
  );

  /// `POST .../entries`: günlüğe kayıt ekler. Aynı `client_request_id` ile
  /// tekrar gönderim ilk kaydı döndürür. Konum kişinin bilerek paylaştığı
  /// içeriktir; log'a yazılmaz.
  Future<EventLogEntry> gunlugeEkle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventLogEntryCreateRequest istek,
  ) => _api.addEventLogEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `DELETE .../entries/{entry_id}`: günlükten kayıt çıkarır.
  Future<void> gunluktenCikar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String kayitId,
  ) => _api.removeEventLogEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    entryId: kayitId,
  );

  /// `GET .../components/{component_key}/measure`: ölçüm bileşeni (#233),
  /// çağıranın gördüğü haliyle (hassas ölçümde yalnızca kendi değeri).
  Future<EventMeasure> olcum(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventMeasure(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../measure/total`: toplam ölçümü yazar (önerilen değeri onaylamak
  /// da düzeltmek de budur).
  Future<EventMeasure> olcumToplamiYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    double deger,
  ) => _api.setEventMeasureTotal(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: EventMeasureValueRequest(value: deger),
  );

  /// `DELETE .../measure/total`.
  Future<EventMeasure> olcumToplaminiKaldir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.removeEventMeasureTotal(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../measure/entries/{user_id}`: [kullaniciId]'nin kişisel
  /// ölçümünü yazar.
  Future<EventMeasure> olcumDegeriYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String kullaniciId,
    double deger,
  ) => _api.setEventMeasureEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    userId: kullaniciId,
    body: EventMeasureValueRequest(value: deger),
  );

  /// `DELETE .../measure/entries/{user_id}`.
  Future<EventMeasure> olcumDegeriniKaldir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String kullaniciId,
  ) => _api.removeEventMeasureEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    userId: kullaniciId,
  );

  /// `GET .../components/{component_key}/ranking`: derece bileşeni (#241),
  /// çağıranın gördüğü haliyle (hassas ölçümden hesaplananda gizli
  /// olabilir).
  Future<EventRanking> derece(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventRanking(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../ranking/entries/{user_id}`: [kullaniciId]'nin elle girilen
  /// derecesini yazar (süre saniye ya da sıra).
  Future<EventRanking> dereceYaz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String kullaniciId,
    double deger,
  ) => _api.setEventRankingEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    userId: kullaniciId,
    body: EventRankingValueRequest(value: deger),
  );

  /// `DELETE .../ranking/entries/{user_id}`.
  Future<EventRanking> dereceyiKaldir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String kullaniciId,
  ) => _api.removeEventRankingEntry(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    userId: kullaniciId,
  );

  /// `GET .../components/{component_key}/celebration`: kutlama bileşeni
  /// (#243), çağıranın gördüğü haliyle (gizliyse kazanan yok).
  Future<EventCelebration> kutlama(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventCelebration(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../celebration`: kazananı ilan eder. Kaynaklı kutlamada
  /// [kazananlar] `null`dır (gövde boş nesne); elle seçilende 1–10 kişi.
  Future<EventCelebration> kutlamayiIlanEt(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    List<String>? kazananlar,
  ) => _api.announceEventCelebration(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: EventCelebrationRequest(winnerIds: kazananlar),
  );

  /// `GET .../components/{component_key}/questions`: soru toplama
  /// bileşeninin soruları (#244), çağıranın gördüğü haliyle. Anonim
  /// sorunun yazarı hiçbir yanıtta yoktur.
  Future<EventQuestionList> sorular(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.listEventQuestions(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../questions`: soru sorar. Aynı [istek] kimliğiyle tekrar
  /// gönderim ilk soruyu döndürür.
  Future<EventQuestion> soruSor(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventQuestionCreateRequest istek,
  ) => _api.askEventQuestion(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `DELETE .../questions/{question_id}`: soruyu kaldırır.
  Future<void> soruyuKaldir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String soruId,
  ) => _api.removeEventQuestion(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    questionId: soruId,
  );

  /// `PUT` / `DELETE .../questions/{question_id}/vote`: [ver] ise oy
  /// verir, değilse oyu geri alır.
  Future<void> soruyaOy(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String soruId, {
    required bool ver,
  }) => ver
      ? _api.voteEventQuestion(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          componentKey: bilesenAnahtari,
          questionId: soruId,
        )
      : _api.unvoteEventQuestion(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          componentKey: bilesenAnahtari,
          questionId: soruId,
        );

  /// `PUT` / `DELETE .../questions/{question_id}/answered`: [isaretle] ise
  /// soruyu cevaplandı işaretler, değilse işareti kaldırır.
  Future<void> soruCevaplandi(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String soruId, {
    required bool isaretle,
  }) => isaretle
      ? _api.markEventQuestionAnswered(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          componentKey: bilesenAnahtari,
          questionId: soruId,
        )
      : _api.unmarkEventQuestionAnswered(
          tayfaId: tayfaId,
          eventId: etkinlikId,
          componentKey: bilesenAnahtari,
          questionId: soruId,
        );

  /// `GET .../components/{component_key}/goal`: hedef bileşeni (#234),
  /// çağıranın gördüğü haliyle (hassas ölçümde ilerleme gizli olabilir).
  Future<EventGoal> hedef(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventGoal(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../goal/target`: etkinliğin hedefini koyar.
  Future<EventGoal> hedefiKoy(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    double deger,
  ) => _api.setEventGoalTarget(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: EventGoalTargetRequest(target: deger),
  );

  /// `DELETE .../goal/target`: tanımdaki varsayılan hedef geri gelir.
  Future<EventGoal> hedefiKaldir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.removeEventGoalTarget(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `GET .../components/{component_key}/schedule`: program akışı
  /// bileşeni (#235); maddeler başlangıç saatine göre sıralı.
  Future<EventSchedule> program(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventSchedule(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../schedule/items`: programa madde ekler.
  Future<EventSchedule> programMaddesiEkle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventScheduleItemRequest istek,
  ) => _api.addEventScheduleItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `PUT .../schedule/items/{item_id}`: maddenin bütün değerlerini
  /// değiştirir (gönderilmeyen bitiş ve not kalkar).
  Future<EventSchedule> programMaddesiniGuncelle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String maddeId,
    EventScheduleItemRequest istek,
  ) => _api.updateEventScheduleItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    itemId: maddeId,
    body: istek,
  );

  /// `DELETE .../schedule/items/{item_id}`: maddeyi programdan çıkarır.
  Future<EventSchedule> programMaddesiniCikar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String maddeId,
  ) => _api.removeEventScheduleItem(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    itemId: maddeId,
  );

  /// `GET .../components/{component_key}/teams`: takım kurma bileşeni
  /// (#236); takımlar sırasıyla.
  Future<EventTeams> takimlar(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventTeams(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `PUT .../teams`: takımları elle kurar; mevcut takımların yerini alır
  /// (boş liste takımları kaldırır).
  Future<EventTeams> takimlariElleKur(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventTeamsRequest istek,
  ) => _api.replaceEventTeams(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `POST .../teams/generate`: takımları katılımcılardan sunucu kurar
  /// (rastgele ya da gönderilen seviyelere göre dengeli). Seviyeler
  /// saklanmaz.
  Future<EventTeams> takimlariOlustur(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventTeamsGenerateRequest istek,
  ) => _api.generateEventTeams(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `GET .../components/{component_key}/draw`: kura bileşeni (#237);
  /// çekilmemişse `drawn` false, yerler boş.
  Future<EventDraw> kura(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventDraw(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../draw`: kurayı çeker. Kura bir kez çekilir; sonra
  /// değiştirilemez ve yeniden çekilemez.
  Future<EventDraw> kurayiCek(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.makeEventDraw(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `GET .../components/{component_key}/scoreboard`: yazboz bileşeni
  /// (#238); masalar kuruluş sırasıyla, ön ayarlar katalog sırasıyla.
  Future<EventScoreboard> yazboz(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventScoreboard(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../scoreboard/tables`: masa kurar.
  Future<EventScoreboard> yazbozMasasiKur(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventScoreTableRequest istek,
  ) => _api.createEventScoreTable(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `PATCH .../tables/{table_id}`: masanın adını ya da durumunu değiştirir.
  Future<EventScoreboard> yazbozMasasiniGuncelle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
    EventScoreTableUpdate istek,
  ) => _api.updateEventScoreTable(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
    body: istek,
  );

  /// `DELETE .../tables/{table_id}`: masayı yerleri, elleri ve hakem
  /// atamalarıyla siler.
  Future<EventScoreboard> yazbozMasasiniSil(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
  ) => _api.deleteEventScoreTable(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
  );

  /// `PUT .../tables/{table_id}/players`: masanın yerlerini sırasıyla
  /// belirler (ilk elden önce).
  Future<EventScoreboard> yazbozYerleriniBelirle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
    EventScorePlayersRequest istek,
  ) => _api.setEventScorePlayers(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
    body: istek,
  );

  /// `POST .../tables/{table_id}/rounds`: sıradaki eli girer. Çevrimdışı
  /// kuyruğa girmez: skor ancak sunucu kabul edince yazılmış sayılır.
  Future<EventScoreboard> yazbozEliGir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
    EventScoreRoundRequest istek,
  ) => _api.addEventScoreRound(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
    body: istek,
  );

  /// `PUT .../tables/{table_id}/rounds/{round}`: girilmiş eli düzeltir.
  Future<EventScoreboard> yazbozEliniDuzelt(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
    int el,
    EventScoreRoundRequest istek,
  ) => _api.correctEventScoreRound(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
    round: el,
    body: istek,
  );

  /// `DELETE .../tables/{table_id}/rounds/{round}`: masanın son elini siler.
  Future<EventScoreboard> yazbozEliniSil(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
    int el,
  ) => _api.deleteEventScoreRound(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
    round: el,
  );

  /// `POST .../tables/{table_id}/finish`: masayı bitirir.
  Future<EventScoreboard> yazbozMasasiniBitir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String masaId,
  ) => _api.finishEventScoreTable(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    tableId: masaId,
  );

  /// `GET .../components/{component_key}/bracket`: eşleşme ağacı bileşeni
  /// (#239); başlamamışsa `started` false, maç yok.
  Future<EventBracket> agac(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.getEventBracket(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../bracket`: eşleşme ağacını kuradan başlatır; kurallar
  /// sabitlenir.
  Future<EventBracket> agaciBaslat(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.startEventBracket(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `DELETE .../bracket`: maçları ve oyunları siler; kura kalır.
  Future<EventBracket> agaciSifirla(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.resetEventBracket(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../bracket/rounds`: sonraki turu eşler.
  Future<EventBracket> agactaSonrakiTur(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.pairEventBracketRound(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../matches/{match_id}/games`: maça sonraki oyunu girer.
  /// Çevrimdışı kuyruğa girmez: skor ancak sunucu kabul edince yazılmış
  /// sayılır.
  Future<EventBracket> agacOyunuGir(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String macId,
    EventBracketGameRequest istek,
  ) => _api.addEventBracketGame(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    matchId: macId,
    body: istek,
  );

  /// `PUT .../matches/{match_id}/games/{game}`: girilmiş oyunu düzeltir.
  Future<EventBracket> agacOyununuDuzelt(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String macId,
    int oyun,
    EventBracketGameRequest istek,
  ) => _api.correctEventBracketGame(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    matchId: macId,
    game: oyun,
    body: istek,
  );

  /// `DELETE .../matches/{match_id}/games/{game}`: maçın son oyununu siler.
  Future<EventBracket> agacOyununuSil(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String macId,
    int oyun,
  ) => _api.deleteEventBracketGame(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    matchId: macId,
    game: oyun,
  );

  /// `GET .../components/{component_key}/guests`: etkinliğin misafir
  /// oyuncuları (Tayfam-Api #252). Takma ad log'a yazılmaz.
  Future<EventGuestPlayers> misafirler(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
  ) => _api.listEventGuestPlayers(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
  );

  /// `POST .../guests`: misafir oyuncu ekler.
  Future<EventGuestPlayers> misafirEkle(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    EventGuestPlayerRequest istek,
  ) => _api.addEventGuestPlayer(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    body: istek,
  );

  /// `DELETE .../guests/{guest_id}`: misafir oyuncuyu siler.
  Future<EventGuestPlayers> misafiriSil(
    String tayfaId,
    String etkinlikId,
    String bilesenAnahtari,
    String misafirId,
  ) => _api.removeEventGuestPlayer(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    componentKey: bilesenAnahtari,
    guestId: misafirId,
  );

  /// `GET .../photos`: albümün bir sayfası, eskiden yeniye (Tayfam-Api
  /// ADR-0028 §3). Yanıt link taşımaz; linkler `POST /v1/media/urls`.
  Future<Sayfa<EventPhoto>> albumFotograflari(
    String tayfaId,
    String etkinlikId, {
    String? sayfaToken,
  }) async {
    final liste = await _api.listEventPhotos(
      tayfaId: tayfaId,
      eventId: etkinlikId,
      pageSize: albumSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.photos, sonraki: liste.nextPageToken);
  }

  /// `POST .../photos`: hazır `event_photo` yüklemesini albüme bağlar.
  /// Aynı `client_request_id` ile tekrar gönderim ilk fotoğrafı döndürür.
  /// Açıklama log'a yazılmaz.
  Future<EventPhoto> albumeEkle(
    String tayfaId,
    String etkinlikId,
    EventPhotoCreateRequest istek,
  ) => _api.addEventPhoto(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `DELETE .../photos/{photo_id}`.
  Future<void> albumdenSil(String tayfaId, String etkinlikId, String fotoId) =>
      _api.removeEventPhoto(
        tayfaId: tayfaId,
        eventId: etkinlikId,
        photoId: fotoId,
      );

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
