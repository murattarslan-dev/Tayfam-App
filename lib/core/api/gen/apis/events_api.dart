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
  /// de listededir. Türe özel ayrıntı (`fishing`) listede dolmaz; tek
  /// etkinlik ucunu kullanın.
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
  /// katılmayan üye `meeting_point` ve `meeting_point_name` almaz. Araçlar
  /// (ve plakalar) burada değildir; `vehicles` bileşenindedir
  /// (`GET …/components/{component_key}/vehicles`, #240). Kamp listesi
  /// `checklist` bileşenindedir (`GET …/components/{component_key}/items`,
  /// #241); kamp yeri, su, tuvalet ve notlar `fields`'tadır.
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
  /// - Türe özel ayrıntı (`fishing`) tamamen değişir. Konvoyun
  ///   rotası `route` bileşenindedir
  ///   (`PUT …/components/{component_key}/route`); kampın ve yürüyüşün
  ///   ayrıntıları `fields`'tadır, yürüyüşün beklenen dönüşü `roll_call`
  ///   bileşenindedir
  ///   (`PUT …/components/{component_key}/roll-call/expected-return`).
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

  /// Etkinlik albümü, eskiden yeniye
  ///
  /// Tayfanın her aktif üyesi okur (susturulmuşken ve iptal edilmiş
  /// etkinlikte de). Yanıt link taşımaz: fotoğrafların linkleri
  /// `POST /v1/media/urls` ile alınır (bir sayfa tek çağrıya sığar).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/photos`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<EventPhotoList> listEventPhotos({
    required String tayfaId,
    required String eventId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/photos',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventPhotoList.fromJson(jsonObject(response, 'listEventPhotos'));
  }

  /// Albüme fotoğraf ekler
  ///
  /// Önce `POST /v1/uploads` ile `event_photo` amaçlı, bu tayfa için
  /// bir yükleme açılıp tamamlanır; burada albüme bağlanır. Katılımınız
  /// doğrulanmış olmalıdır (`not-attended`). Albüm etkinliğin
  /// başlangıcından bitişten sonraki yedi günün sonuna kadar açıktır
  /// (`album-closed`); iptal edilmiş etkinlikte kapalıdır
  /// (`event-cancelled`). Kişi başı 30, albüm başına 500 fotoğraf
  /// (`event-limit`; silinenler sayılmaz). Aynı `client_request_id` ile
  /// tekrar gönderim ilk fotoğrafı döndürür. Fotoğraf bildirim üretmez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/photos`
  Future<EventPhoto> addEventPhoto({
    required String tayfaId,
    required String eventId,
    required EventPhotoCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/photos',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventPhoto.fromJson(jsonObject(response, 'addEventPhoto'));
  }

  /// Albümden fotoğraf kaldırır
  ///
  /// Kendi fotoğrafınızı (susturulmuşken de); organizatör kendi
  /// etkinliğinin, moderatör ve yönetici her etkinliğin her fotoğrafını.
  /// Dosya 30 gün sonra kalıcı olarak silinir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/photos/{photo_id}`
  Future<void> removeEventPhoto({
    required String tayfaId,
    required String eventId,
    required String photoId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/photos/{photo_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'photo_id': photoId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Etkinliğin bileşenleri ve organizatörün seçimleri
  ///
  /// Etkinliğin tür sürümündeki her bileşen, tanımdaki sırayla ve bu
  /// etkinlikteki haliyle: açık mı (`optional` bileşeni organizatör
  /// açıp kapatır) ve organizatöre bırakılan (`organizer_choice`) her
  /// parametrede geçerli seçenek (ADR-0037 §2). Bileşenin diğer
  /// parametreleri ve adı tür tanımındadır (`CatalogComponent`). Her
  /// etkin üyeye açıktır (susturulmuş üye de okur).
  ///
  /// **Bileşen uçlarının ortak kuralları** (her bileşenin
  /// `…/components/{component_key}/…` uçları için): etkinliğin tür
  /// sürümünde o anahtarla bir bileşen yoksa ya da bileşen ucun türünden
  /// değilse `component-not-found`; kapalı bileşenin bütün uçları
  /// (okuma dahil) `component-disabled`; iptal edilmiş etkinlikte yazma
  /// `event-cancelled`, salt okunur tayfada `tayfa-read-only`;
  /// etkinliğin bitiminden 7 gün sonra bileşen verisi donar
  /// (`component-frozen`, ADR-0025 §5). "Organizatör" yetkisi etkinliği
  /// açana ve her etkinlikte olduğu gibi moderatör ve yöneticilere
  /// aittir; hakemler `…/referees` ile atanır.
  ///
  /// **Canlı güncelleme:** bir bileşen, seçimler ya da hakemler
  /// değişince etkinliği izleyen bağlantılara `event.component_changed`
  /// çerçevesi gider (`GET /v1/realtime`, `event.watch`); istemci
  /// bileşeni REST'ten yeniden çeker.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components`
  Future<EventComponentList> listEventComponents({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventComponentList.fromJson(
      jsonObject(response, 'listEventComponents'),
    );
  }

  /// Organizatörün bir bileşen için seçimini değiştirir
  ///
  /// `optional` bileşeni açar ya da kapatır ve organizatöre bırakılan
  /// parametrelerde seçenek belirler (ADR-0037 §2). Gövdede en az biri
  /// bulunur; gönderilmeyen seçim olduğu gibi kalır. Organizatör,
  /// moderatör ve yönetici; yalnızca etkinlik **başlamadan önce**
  /// (`component-locked`). `optional` olmayan bileşeni kapatmak,
  /// organizatöre bırakılmamış bir parametre ya da listede olmayan bir
  /// seçenek `invalid-request`. Seriye ait etkinlikte yalnızca bu
  /// etkinlik değişir. Yeni etkinlikte seçimler `POST …/events`
  /// gövdesindeki `components` ile verilir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventComponentList> setEventComponent({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventComponentSelectionRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventComponentList.fromJson(
      jsonObject(response, 'setEventComponent'),
    );
  }

  /// Etkinliğin hakemleri
  ///
  /// Atama sırasıyla. Her etkin üyeye açıktır.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/referees`
  Future<EventRefereeList> listEventReferees({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/referees',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRefereeList.fromJson(jsonObject(response, 'listEventReferees'));
  }

  /// Hakem atar
  ///
  /// Tayfanın etkin bir üyesini etkinliğin tamamına, bir bileşenine
  /// (`component_key`) ya da bileşenin bir kapsamına (`scope_id`: masa,
  /// maç) hakem yapar. Hakem, organizatörle birlikte sonuç girer
  /// (ADR-0025 §5). Organizatör, moderatör ve yönetici. Aynı atama
  /// tekrar gönderilirse ilk atama döner. Etkinlik başına en fazla 50
  /// atama (`event-limit`). Etkin üye olmayan kişi `member-not-found`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/referees`
  Future<EventReferee> assignEventReferee({
    required String tayfaId,
    required String eventId,
    required EventRefereeAssignRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/referees',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventReferee.fromJson(jsonObject(response, 'assignEventReferee'));
  }

  /// Hakem atamasını kaldırır
  ///
  /// Organizatör, moderatör ve yönetici. Olmayan atamayı kaldırmak hata değildir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/referees/{referee_id}`
  Future<void> removeEventReferee({
    required String tayfaId,
    required String eventId,
    required String refereeId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/events/{event_id}/referees/{referee_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'referee_id': refereeId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Etkinliğin rotası
  ///
  /// Rota yoksa `points` boş dizidir ve `updated_at` yoktur. Her etkin
  /// üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve donmuş
  /// etkinlikte de okunur. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/route`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRoute> getEventRoute({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/route',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRoute.fromJson(jsonObject(response, 'getEventRoute'));
  }

  /// Rotayı yazar ya da kaldırır (organizatör, moderatör, yönetici)
  ///
  /// Rotanın tamamı değişir: 2–500 nokta. Boş `points` rotayı kaldırır;
  /// olmayan rotayı kaldırmak hata değildir. Etkinlik başladıktan ve
  /// bittikten sonra da değişir; bitişten 7 gün sonra donar
  /// (`component-frozen`). Seriye ait etkinlikte yalnızca bu etkinlik
  /// değişir. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/route`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRoute> setEventRoute({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventRouteRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/route',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRoute.fromJson(jsonObject(response, 'setEventRoute'));
  }

  /// Etkinliğin araçları
  ///
  /// Araçlar eklenme sırasıyladır. Her etkin üyeye açıktır (susturulmuş
  /// üye de okur); iptal edilmiş ve donmuş etkinlikte de okunur. Plaka
  /// yalnızca katılımcılara (`going`), organizatöre ve aracın sahibine
  /// döner. Bekleyen koltuk isteklerini aracın sahibi görür; başkası
  /// yalnızca kendi isteğini görür. Bileşen uçlarının ortak kuralları
  /// geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVehicles> listEventVehicles({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(jsonObject(response, 'listEventVehicles'));
  }

  /// Aracınızı yazar; önceki aracınızın yerini alır
  ///
  /// Yalnızca `going` cevabıyla (`event-not-going`) ve etkinlik bitene
  /// kadar (`event-ended`). Aracın kimliği değişmez. `plate` yalnızca
  /// bileşenin `plate` parametresi açıksa, sıfırdan büyük `seats`
  /// yalnızca `seats` parametresi açıksa kabul edilir (`plate_enabled`,
  /// `seats_enabled`). Koltuk sayısı onaylanmış yolcu sayısının altına
  /// inemez (`vehicle-seats-taken`). Araç yazan kişinin başka bir araca
  /// yazdığı koltuk isteği silinir. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/mine`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVehicles> setEventVehicle({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventVehicleRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/mine',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(jsonObject(response, 'setEventVehicle'));
  }

  /// Aracı, ona yazılmış koltuk istekleriyle birlikte çıkarır
  ///
  /// Kendi aracınızı (susturulmuş olsanız da); organizatör, moderatör ve
  /// yönetici her aracı. Bilinmeyen araç `event-item-not-found`. İptal
  /// edilmiş ve donmuş etkinlikte çıkarılamaz (`event-cancelled`,
  /// `component-frozen`); plaka etkinlik bitiminden 30 gün sonra
  /// kendiliğinden silinir. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vehicleId]: Bileşendeki aracın kimliği (`EventVehicle.id`).
  Future<EventVehicles> removeEventVehicle({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String vehicleId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'vehicle_id': vehicleId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(jsonObject(response, 'removeEventVehicle'));
  }

  /// Bu araçla gelmek için koltuk ister
  ///
  /// Yalnızca `going` cevabıyla (`event-not-going`), etkinlik bitene kadar
  /// (`event-ended`) ve bileşende kendi aracı olmayan için
  /// (`seat-request-driver`). Araçta boş koltuk yoksa ya da bileşenin
  /// `seats` parametresi kapalıysa `vehicle-full`. Kişinin bileşende tek
  /// isteği vardır; başka araca istek öncekinin (onaylanmış olsa da)
  /// yerini alır, aynı isteği yinelemek hiçbir şey değiştirmez. İstek
  /// araç sahibinin onayını bekler. Gövde yoktur.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/mine`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vehicleId]: Bileşendeki aracın kimliği (`EventVehicle.id`).
  Future<EventVehicles> requestEventVehicleSeat({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String vehicleId,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/mine',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'vehicle_id': vehicleId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(
      jsonObject(response, 'requestEventVehicleSeat'),
    );
  }

  /// Koltuk isteğini (bekleyen ya da onaylanmış) kaldırır
  ///
  /// İsteyen kişi kendi isteğini geri çeker (susturulmuş olsa da); araç
  /// sahibi isteği reddeder ya da yolcuyu çıkarır; organizatör, moderatör
  /// ve yönetici her isteği kaldırır. Araç ya da bu kişinin o araca isteği
  /// yoksa `event-item-not-found`. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/{user_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vehicleId]: Bileşendeki aracın kimliği (`EventVehicle.id`).
  Future<EventVehicles> releaseEventVehicleSeat({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String vehicleId,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/{user_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'vehicle_id': vehicleId,
        'user_id': userId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(
      jsonObject(response, 'releaseEventVehicleSeat'),
    );
  }

  /// Aracınıza yazılmış koltuk isteğini onaylar (yalnızca araç sahibi)
  ///
  /// Onaylanmış isteği yeniden onaylamak hiçbir şey değiştirmez. Boş
  /// koltuk kalmadıysa `vehicle-full`; etkinlik bittiyse `event-ended`.
  /// Araç ya da bu kişinin o araca isteği yoksa `event-item-not-found`.
  /// Gövde yoktur. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/{user_id}/approval`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [vehicleId]: Bileşendeki aracın kimliği (`EventVehicle.id`).
  Future<EventVehicles> approveEventVehicleSeat({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String vehicleId,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vehicles/{vehicle_id}/seat-requests/{user_id}/approval',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'vehicle_id': vehicleId,
        'user_id': userId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVehicles.fromJson(
      jsonObject(response, 'approveEventVehicleSeat'),
    );
  }

  /// Listenin maddeleri
  ///
  /// Maddeler eklenme sırasıyladır. Her etkin üyeye açıktır (susturulmuş
  /// üye de okur); iptal edilmiş ve donmuş etkinlikte de okunur. Bileşen
  /// uçlarının ortak kuralları geçerlidir (`component-not-found`,
  /// `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<Checklist> listChecklist({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Checklist.fromJson(jsonObject(response, 'listChecklist'));
  }

  /// Listeye madde ekler (organizatör, moderatör, yönetici)
  ///
  /// En fazla 200 madde (`event-limit`); etkinlik bitene kadar
  /// (`event-ended`). Birden büyük `quantity` yalnızca bileşenin
  /// `quantity` parametresi açıksa, `assigned_user_id` yalnızca
  /// `assignment` parametresi açıksa kabul edilir (`quantity_enabled`,
  /// `assignment_enabled`). Atanan kişi tayfanın etkin üyesi olmalı ve
  /// `going` cevabı vermiş olmalıdır (`event-not-going`). Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<Checklist> addChecklistItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required ChecklistItemRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Checklist.fromJson(jsonObject(response, 'addChecklistItem'));
  }

  /// Listeden madde çıkarır (organizatör, moderatör, yönetici)
  ///
  /// Bilinmeyen madde `event-item-not-found`; etkinlik bitene kadar
  /// (`event-ended`). Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items/{item_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [itemId]: Listedeki maddenin kimliği (`ChecklistItem.id`).
  Future<Checklist> removeChecklistItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String itemId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items/{item_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'item_id': itemId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Checklist.fromJson(jsonObject(response, 'removeChecklistItem'));
  }

  /// Maddeyi kimin üstleneceğini belirler ya da atamayı kaldırır
  ///
  /// Yalnızca bileşenin `assignment` parametresi açıksa (yoksa
  /// `invalid-request`). `assigned_user_id` bir kullanıcı kimliği atar;
  /// alan yoksa ya da `null` ise atama kaldırılır.
  ///
  /// - Organizatör, moderatör ve yönetici `going` cevabı vermiş herhangi
  ///   bir etkin üyeyi atayabilir ya da herhangi bir atamayı kaldırabilir.
  /// - `going` cevabı vermiş diğer üyeler (susturulmamış) yalnızca
  ///   boştaki maddeyi kendine atayabilir ve yalnızca kendi atamasını
  ///   kaldırabilir. Başkasına atamak `permission-denied`dır.
  ///
  /// `going` cevabı olmayan (ya da etkin üye olmayan) kişi:
  /// `event-not-going`. Maddeyi başkası üstlenmişse (aynı anda üstlenen
  /// iki kişiden ikincisi dahil): `event-item-taken`; istemci listeyi
  /// yeniden yükler. Değeri zaten olana ayarlamak değişiklik yapmadan
  /// başarılı olur. Etkinlik bitene kadar (`event-ended`). Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items/{item_id}/assignee`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [itemId]: Listedeki maddenin kimliği (`ChecklistItem.id`).
  Future<Checklist> assignChecklistItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String itemId,
    required ChecklistAssignRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/items/{item_id}/assignee',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'item_id': itemId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Checklist.fromJson(jsonObject(response, 'assignChecklistItem'));
  }

  /// Etkinliğin yoklaması
  ///
  /// Plan (beklenen dönüş), kendi kaydınız ve organizatör yetkisi
  /// olanlara herkesin kaydı. Her etkin üyeye açıktır (susturulmuş üye
  /// de okur); iptal edilmiş ve donmuş etkinlikte de okunur. Bileşen
  /// uçlarının ortak kuralları geçerlidir (`component-not-found`,
  /// `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRollCall> getEventRollCall({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRollCall.fromJson(jsonObject(response, 'getEventRollCall'));
  }

  /// Beklenen dönüşü yazar ya da kaldırır (organizatör, moderatör, yönetici)
  ///
  /// `expected_return_at` etkinliğin başlangıcından sonra olmalıdır
  /// (`invalid-request`); alan yoksa ya da `null` ise plan kaldırılır
  /// (alarm kurulmaz). Olmayan
  /// planı kaldırmak hata değildir. Etkinlik başladıktan ve bittikten
  /// sonra da değişir; bitişten 7 gün sonra donar (`component-frozen`).
  /// Seriye ait etkinlikte yalnızca bu etkinlik değişir; serinin yeni
  /// örnekleri şablonun beklenen dönüşünü kendi başlangıçlarına göre
  /// kaydırarak alır. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/expected-return`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRollCall> setEventRollCallExpectedReturn({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required RollCallPlanRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/expected-return',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRollCall.fromJson(
      jsonObject(response, 'setEventRollCallExpectedReturn'),
    );
  }

  /// Çıktığınızı kaydeder; katılım sayılır
  ///
  /// Katılım `hike_start` yöntemiyle doğrulanır. `going` cevabı gerekir
  /// (`event-not-going`); başlangıçtan 30 dakika önceden bitişe kadar
  /// (`check-in-closed`). Susturulmuş üye de çıkabilir (güvenlik
  /// sinyali). Tekrar gönderim ilk çıkışı döndürür. Bileşen uçlarının
  /// ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/start`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRollCall> startEventRollCall({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required RollCallStartRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/start',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRollCall.fromJson(jsonObject(response, 'startEventRollCall'));
  }

  /// Döndüğünüzü kaydeder
  ///
  /// Güvenlik sinyalidir: bitişten sonra, bileşen donduktan sonra,
  /// iptal edilmiş etkinlikte ve susturulmuşken de çalışır; yalnızca
  /// salt okunur tayfa reddeder (`tayfa-read-only`). Önce çıkış gerekir
  /// (`hike-not-started`). Tekrar gönderim ilk dönüşü döndürür.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/return`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRollCall> returnEventRollCall({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required RollCallReturnRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/roll-call/return',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRollCall.fromJson(jsonObject(response, 'returnEventRollCall'));
  }

  /// "Her şey yolunda mıydı?" cevabınız
  ///
  /// Cevap yoksa `answer` yoktur. Geri bildirim uçları, tayfaya Keşfet'ten
  /// gelip üyeliği son 30 günde biten kişiye de açıktır (yalnızca
  /// katıldığı etkinlik için).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/feedback`
  Future<EventFeedback> getEventFeedback({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/feedback',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventFeedback.fromJson(jsonObject(response, 'getEventFeedback'));
  }

  /// "Her şey yolunda mıydı?" cevabını verir ya da değiştirir
  ///
  /// Yalnızca katılımı doğrulanmış (`not-attended`) katılımcı, "halka açık
  /// yerde buluşur" işaretli yüz yüze etkinlikte, bitişten bitiş + 7 güne
  /// kadar (`feedback-closed`). Serbest metin yoktur; anlatmak için şikâyet
  /// akışını kullanın. Cevabı yalnızca siz görürsünüz; `serious` tayfayı
  /// inceleme bitene kadar Keşfet'ten çıkarır ve tayfaya nedeni söylenmez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/feedback`
  Future<EventFeedback> setEventFeedback({
    required String tayfaId,
    required String eventId,
    required EventFeedbackInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/feedback',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventFeedback.fromJson(jsonObject(response, 'setEventFeedback'));
  }

  /// Bu etkinlik için güvenlik kişiniz
  ///
  /// Seçilmemişse `contact` yoktur. Seçilmiş bir kaydınız varsa sunucu
  /// bayrağı (`SAFETY_CONTACT_ENABLED`) kapalıyken, tayfadan ayrıldıktan
  /// sonra ya da etkinlik modülü kapalıyken de döner, böylece "Döndüm"
  /// her zaman gösterilebilir; yalnızca kendi kaydınızı döndürür. Kaydınız
  /// yokken bayrak kapalıysa 404 `feature-disabled` (yeni kayıt
  /// oluşturulamaz).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact`
  Future<SafetyContact> getSafetyContact({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return SafetyContact.fromJson(jsonObject(response, 'getSafetyContact'));
  }

  /// Güvenlik kişisi seçer ya da değiştirir
  ///
  /// Etkinliğe `going` demiş olmalısınız (`event-not-going`); etkinlik yüz
  /// yüze, iptal edilmemiş ve bitmemiş olmalı, alarm gitmemiş olmalı
  /// (`safety-contact-closed`). Kişi kabul edilmiş arkadaşınız olmalı
  /// (`not-friends`). Bitiş + `grace_minutes` geçtiğinde "Döndüm"
  /// işaretlenmemişse yalnızca bu kişiye `safety_alert` bildirimi gider.
  /// Kişi yalnızca sizi, etkinliğin başlangıç ve bitiş saatini, toleransı
  /// ve "döndü / dönmedi / alarm gitti" durumunu görür
  /// (`GET /v1/me/safety-shares`); tayfa, etkinlik başlığı ve yer görmez.
  /// Seçildiğinde kişiye bildirim gitmez. Keşfet'ten bağımsızdır (sunucu
  /// bayrağı `SAFETY_CONTACT_ENABLED`, varsayılan açık); bütün yüz yüze
  /// etkinliklerde çalışır.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact`
  Future<SafetyContact> setSafetyContact({
    required String tayfaId,
    required String eventId,
    required SafetyContactInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return SafetyContact.fromJson(jsonObject(response, 'setSafetyContact'));
  }

  /// Güvenlik kişisini kaldırır
  ///
  /// Kaldırılacak bir şey yoksa da başarılıdır. Alarm gittikten sonra
  /// kaldırılamaz (`safety-contact-closed`). Keşfet kapalıyken, tayfadan
  /// ayrıldıktan sonra ya da etkinlik modülü kapalıyken de çalışır;
  /// yalnızca kendi kaydınıza dokunur.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact`
  Future<void> clearSafetyContact({
    required String tayfaId,
    required String eventId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// "Döndüm": güvenlik alarmını durdurur
  ///
  /// Güvenlik kişisi seçilmemişse `safety-contact-not-found`. Tekrar
  /// çağrı ilk zamanı korur. Keşfet kapalıyken, susturulmuşken, tayfadan
  /// ayrıldıktan sonra ya da etkinlik modülü kapalıyken de çalışır;
  /// yalnızca kendi kaydınıza dokunur.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact/return`
  Future<SafetyContact> markReturned({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact/return',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return SafetyContact.fromJson(jsonObject(response, 'markReturned'));
  }
}
