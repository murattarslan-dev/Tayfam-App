import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/events_api.dart';
import 'package:tayfam/core/api/gen/apis/tayfas_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Etkinlik listesi ve katılımcılar okunurken bir sayfada istenen kayıt
/// (sözleşme: en fazla 100).
const int etkinlikSayfaBoyutu = 20;

/// Etkinlik çekirdeğinin uçları (ADR-0015 §3): liste, tek etkinlik,
/// oluşturma, düzenleme, iptal, katılım, katılımcılar ve `.ics`. Yalnızca
/// üretilmiş uç sınıflarını kullanır; bütün istekler tek `ApiClient`'tan
/// geçer (ADR-0005).
final class EtkinlikIslemleri {
  EtkinlikIslemleri(ApiTransport istemci)
    : _uclar = EventsApi(istemci),
      _kullanicilar = UsersApi(istemci),
      _tayfalar = TayfasApi(istemci);

  final EventsApi _uclar;
  final UsersApi _kullanicilar;
  final TayfasApi _tayfalar;

  /// `GET /v1/tayfas/{tayfa_id}`: kullanıcının rolü ve tayfanın "üyeler
  /// etkinlik açabilir" ayarı ("Etkinlik aç" düğmesini göstermek için).
  Future<TayfaView> tayfaGorunumu(String tayfaId) =>
      _tayfalar.getTayfa(tayfaId: tayfaId);

  /// `GET /v1/tayfas/{tayfa_id}/events`: bitmemiş etkinliklerin bir
  /// sayfası. Sayfa token'ı opaktır; ayrıştırılmaz, üretilmez.
  Future<EventList> sayfa(String tayfaId, {String? token}) =>
      _uclar.listUpcomingEvents(
        tayfaId: tayfaId,
        pageSize: etkinlikSayfaBoyutu,
        pageToken: token,
      );

  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}`.
  Future<Event> etkinlik(String tayfaId, String etkinlikId) =>
      _uclar.getEvent(tayfaId: tayfaId, eventId: etkinlikId);

  /// `POST /v1/tayfas/{tayfa_id}/events`.
  Future<Event> olustur(String tayfaId, EventCreateRequest istek) =>
      _uclar.createEvent(tayfaId: tayfaId, body: istek);

  /// `PATCH /v1/tayfas/{tayfa_id}/events/{event_id}`.
  Future<Event> duzenle(
    String tayfaId,
    String etkinlikId,
    EventUpdateRequest istek,
  ) => _uclar.updateEvent(tayfaId: tayfaId, eventId: etkinlikId, body: istek);

  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/cancellation`.
  Future<Event> iptalEt(String tayfaId, String etkinlikId, String gerekce) =>
      _uclar.cancelEvent(
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
    final yanit = await _uclar.setEventRsvp(
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
  }) => _uclar.listEventAttendees(
    tayfaId: tayfaId,
    eventId: etkinlikId,
    status: durum,
    pageSize: etkinlikSayfaBoyutu,
    pageToken: token,
  );

  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/calendar`: iCalendar
  /// metni. Çevrimiçi bağlantıyı içerebilir; önbelleğe alınmaz.
  Future<String> takvim(String tayfaId, String etkinlikId) =>
      _uclar.exportEventCalendar(tayfaId: tayfaId, eventId: etkinlikId);

  /// `GET /v1/users/{user_id}/profile`: organizatörün ve katılımcıların
  /// görünen adı (katılımcı listesi yalnızca kimlik döndürür).
  Future<String> kullaniciAdi(String kullaniciId) async {
    final profil = await _kullanicilar.getUserProfile(userId: kullaniciId);
    return profil.displayName;
  }
}

/// Etkinlik uçlarının deposu.
final etkinlikIslemleriProvider = Provider<EtkinlikIslemleri>(
  (ref) => EtkinlikIslemleri(ref.watch(apiClientProvider)),
  name: 'etkinlikIslemleriProvider',
);
