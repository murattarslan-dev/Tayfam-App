// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `events` olan uçlar.
final class EventsApi {
  const EventsApi(this._transport);

  final ApiTransport _transport;

  /// Bitmemiş etkinlikler, başlangıç zamanına göre
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur). İptal edilenler
  /// de listededir. Türe özel ayrıntılar (`convoy`, `camp`, …) listede
  /// dolmaz; tek etkinlik ucunu kullanın.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<EventList> listUpcomingEvents({
    required String tayfaId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventList.fromJson(jsonObject(response, 'listUpcomingEvents'));
  }

  /// Etkinlik açar; açan kişi organizatördür
  ///
  /// Moderatör ve yönetici; tayfada `members_can_create_events` açıksa
  /// her etkin üye. Aynı `client_request_id` ile tekrar gönderim ilk
  /// açılan etkinliği döndürür ve yeni etkinlik açmaz. `recurrence`
  /// verilirse etkinlik tekrarlayan bir serinin ilkidir; sunucu sonraki
  /// etkinlikleri sekiz hafta ileriye kadar kendisi açar.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events`
  Future<Event> createEvent({
    required String tayfaId,
    required EventCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Event.fromJson(jsonObject(response, 'createEvent'));
  }

  /// Tek etkinlik, türe özel ayrıntılarıyla
  ///
  /// Katılımcılara özel balık noktasında (`spot_visibility=participants`)
  /// katılmayan üye `meeting_point` ve `meeting_point_name` almaz. Konvoy
  /// plakaları yalnızca katılımcılara (`going`) ve organizatöre döner.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}`
  Future<Event> getEvent({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Event.fromJson(jsonObject(response, 'getEvent'));
  }

  /// Etkinliği düzenler (organizatör, moderatör, yönetici)
  ///
  /// Gövdede bulunan alanlar değişir; en az bir alan gerekir. Alanlar
  /// gruplar halinde değişir:
  /// - `starts_at` ve `ends_at` birlikte gönderilir.
  /// - Yer: `mode`, `meeting_point_name`, `meeting_point`, `city`,
  ///   `district`, `online_url` birlikte değişir; bunlardan biri
  ///   gönderilirse `mode` zorunludur ve gönderilmeyenler boşalır.
  /// - Türe özel ayrıntı (`convoy`, `camp`, …) tamamen değişir; araçlar
  ///   ve kamp listesi korunur.
  ///
  /// Kapasiteyi artırmak bekleme listesindekileri sırayla `going` yapar.
  /// Seriye ait bir etkinlikte `apply_to_series` `false` (varsayılan) ise
  /// yalnızca bu etkinlik değişir ve seriden ayrılır (`series_override`);
  /// `true` ise serinin başlamamış, düzenlenmemiş bütün etkinliklerini ve
  /// ileride açılacakları değiştirir; seride zaman değişmez. Bitmiş seri
  /// `event-series-ended` alır.
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/events/{event_id}`
  Future<Event> updateEvent({
    required String tayfaId,
    required String eventId,
    required EventUpdateRequest body,
  }) async {
    final json = body.toJson();
    if (json.length < 1) {
      throw ArgumentError('EventUpdateRequest: en az 1 alan verilmeli');
    }
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: json,
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Event.fromJson(jsonObject(response, 'updateEvent'));
  }

  /// Etkinliği iptal eder (organizatör, moderatör, yönetici)
  ///
  /// Etkinlik silinmez; üyeler onu iptal zamanı ve sebebiyle görmeye devam
  /// eder. Sonrasında katılım cevapları değişmez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/cancellation`
  Future<Event> cancelEvent({
    required String tayfaId,
    required String eventId,
    required EventCancelRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/cancellation',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Event.fromJson(jsonObject(response, 'cancelEvent'));
  }

  /// Etkinliği takvime eklemek için iCalendar (.ics) dosyası
  ///
  /// RFC 5545. `UID` etkinlik kimliğidir; dosya tekrar içe aktarılırsa
  /// takvim kaydı güncellenir, iptal edilmiş etkinlik `STATUS:CANCELLED`
  /// taşır. Zamanlar UTC'dir. Koordinat, katılımcı, organizatör ya da
  /// plaka içermez; çevrimiçi etkinliğin linkini içerebilir, bu yüzden
  /// yanıt önbelleğe alınmaz (`Cache-Control: private, no-store`). Hata
  /// yanıtları `application/problem+json`'dur.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/calendar`
  Future<String> exportEventCalendar({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/calendar',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.text,
      authenticated: true,
    );
    return textBody(response, 'exportEventCalendar');
  }

  /// Etkinliğe katılım cevabınızı verir
  ///
  /// Dolu etkinlikte `going` bekleme listesine (`waitlist`) düşer;
  /// yanıttaki `status` kaydedilen cevaptır. Bir `going` cevabı
  /// değişince bekleme listesinin en eskisi `going` olur. Aynı cevabı
  /// tekrar vermek bir şey değiştirmez; bekleme listesindeyken `going`
  /// sıranızı korur.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/rsvp`
  Future<Rsvp> setEventRsvp({
    required String tayfaId,
    required String eventId,
    required RsvpRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/rsvp',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Rsvp.fromJson(jsonObject(response, 'setEventRsvp'));
  }

  /// Bir cevaptaki katılımcılar, eskiden yeniye
  ///
  /// `status=waitlist` için sıra bekleme sırasıdır. `attendance`
  /// doğrulanmış katılımı gösterir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/attendees`
  ///
  /// [status]: Kısıtlar: varsayılan (sunucu): `going`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<AttendeeList> listEventAttendees({
    required String tayfaId,
    required String eventId,
    ListEventAttendeesStatus? status,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      query: {
        if (status != null) 'status': status.wire,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return AttendeeList.fromJson(jsonObject(response, 'listEventAttendees'));
  }

  /// Organizatör düzeltmesi — katılımı ekler
  ///
  /// Organizatör kendi etkinliği için, moderatör ve yönetici her etkinlik
  /// için; iptal edilmemiş bir etkinliğin bitişinden sonraki yedi gün
  /// içinde (`correction-closed`). Kimse kendi katılımını düzeltemez
  /// (`permission-denied`). Kişi etkin üye olmalıdır (`member-not-found`).
  /// Her düzeltme denetim kaydına yazılır.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance`
  Future<void> confirmAttendance({
    required String tayfaId,
    required String eventId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId, 'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Organizatör düzeltmesi — sahte katılımı kaldırır
  ///
  /// Ekleme ile aynı kurallar; kişinin katılım geçmişi kaydı silinir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance`
  Future<void> removeAttendance({
    required String tayfaId,
    required String eventId,
    required String userId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId, 'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Katılımınızı doğrular (konumla check-in ya da "Katıldım")
  ///
  /// Pencere başlangıçtan 30 dakika önce açılır, bitişte kapanır
  /// (`check-in-closed`); `going` cevabı gerekir (`event-not-going`).
  ///
  /// Yüz yüze etkinlikte `location` zorunludur ve buluşma noktasına en
  /// fazla 300 m olmalıdır (`check-in-too-far`; uzaklık hiçbir yanıtta
  /// söylenmez). Etkinlik başına başarısızlar dahil en fazla beş deneme
  /// sayılır (`check-in-attempts-exhausted`, core). Ayrıca IP başına
  /// sınır vardır (`rate-limited`, gateway). Konum yalnızca uzaklık
  /// kontrolünde kullanılır: saklanmaz, log'a yazılmaz, geri dönmez.
  ///
  /// Çevrimiçi etkinlikte `location` gönderilmez; `going` cevabı
  /// başlangıçtan önce verilmiş olmalıdır.
  ///
  /// Başarılı check-in'den sonra tekrar denemek bir şey değiştirmez ve
  /// deneme saymaz. Susturulmuş üye de check-in yapabilir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/check-in`
  Future<CheckIn> checkInToEvent({
    required String tayfaId,
    required String eventId,
    required CheckInRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/check-in',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return CheckIn.fromJson(jsonObject(response, 'checkInToEvent'));
  }

  /// Yürüyüşe çıktığınızı kaydeder; katılım sayılır
  ///
  /// Yalnızca yürüyüş etkinliğinde (`event-type-mismatch`). Check-in ile
  /// aynı pencere ve `going` kuralı. Tekrar gönderim ilk çıkışı döndürür.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/hike-start`
  Future<HikeCheckin> startHike({
    required String tayfaId,
    required String eventId,
    required HikeStartRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/hike-start',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return HikeCheckin.fromJson(jsonObject(response, 'startHike'));
  }

  /// Yürüyüşten döndüğünüzü kaydeder
  ///
  /// Bitişten sonra ve iptal edilmiş etkinlikte de çalışır. Önce çıkış
  /// gerekir (`hike-not-started`). Tekrar gönderim ilk dönüşü döndürür.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/hike-return`
  Future<HikeCheckin> finishHike({
    required String tayfaId,
    required String eventId,
    required HikeReturnRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/hike-return',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return HikeCheckin.fromJson(jsonObject(response, 'finishHike'));
  }

  /// Kamp listesine malzeme ekler (organizatör, moderatör, yönetici)
  ///
  /// Yalnızca kamp etkinliğinde (`event-type-mismatch`); en fazla 200
  /// malzeme (`event-limit`). Liste tek etkinlik yanıtındaki
  /// `camp.items`'tadır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/camp-items`
  Future<CampItem> addCampItem({
    required String tayfaId,
    required String eventId,
    required CampItemCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/camp-items',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return CampItem.fromJson(jsonObject(response, 'addCampItem'));
  }

  /// Kamp listesinden malzeme çıkarır (organizatör, moderatör, yönetici)
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/camp-items/{item_id}`
  Future<void> removeCampItem({
    required String tayfaId,
    required String eventId,
    required String itemId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/events/{event_id}/camp-items/{item_id}',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId, 'item_id': itemId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Konvoya aracınızı ekler; önceki aracınızın yerini alır
  ///
  /// Yalnızca konvoy etkinliğinde (`event-type-mismatch`) ve `going`
  /// cevabıyla (`event-not-going`). Araçlar tek etkinlik yanıtındaki
  /// `convoy.vehicles`'tadır. Plaka kişisel veridir; isteğe bağlıdır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles`
  Future<ConvoyVehicle> addConvoyVehicle({
    required String tayfaId,
    required String eventId,
    required ConvoyVehicleCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ConvoyVehicle.fromJson(jsonObject(response, 'addConvoyVehicle'));
  }

  /// Konvoydan araç çıkarır
  ///
  /// Kendi aracınızı; organizatör, moderatör ve yönetici her aracı.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles/{vehicle_id}`
  Future<void> removeConvoyVehicle({
    required String tayfaId,
    required String eventId,
    required String vehicleId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles/{vehicle_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'vehicle_id': vehicleId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Av günlüğü, eskiden yeniye
  ///
  /// Yalnızca balık etkinliğinde. Bir avın konumu avcıya, `tayfa`
  /// görünürlüğünde noktayı görebilen herkese döner; diğerlerinde yoktur.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<FishingCatchList> listFishingCatches({
    required String tayfaId,
    required String eventId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return FishingCatchList.fromJson(
      jsonObject(response, 'listFishingCatches'),
    );
  }

  /// Av günlüğüne av ekler
  ///
  /// Katılımınız doğrulanmış olmalıdır (`not-attended`); bitişten sonraki
  /// yedi güne kadar (`event-ended`). Avcı ve etkinlik başına en fazla 100
  /// (`event-limit`). Aynı `client_request_id` ile tekrar gönderim ilk
  /// avı döndürür. Konum isteğe bağlıdır; log'a yazılmaz.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches`
  Future<FishingCatch> addFishingCatch({
    required String tayfaId,
    required String eventId,
    required FishingCatchCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return FishingCatch.fromJson(jsonObject(response, 'addFishingCatch'));
  }

  /// Av günlüğünden av çıkarır
  ///
  /// Kendi avınızı; moderatör ve yönetici herkesinkini.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches/{catch_id}`
  Future<void> removeFishingCatch({
    required String tayfaId,
    required String eventId,
    required String catchId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches/{catch_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'catch_id': catchId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
