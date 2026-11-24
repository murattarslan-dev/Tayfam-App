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
  /// de listededir. Türün alan değerleri (`fields`) listede dolmaz; tek
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
  /// her etkin üye. `starts_now` ile (Şimdi başlat) tayfanın
  /// `now_create_min_role` ayarı ve üstü (varsayılan her etkin üye).
  /// Aynı `client_request_id` ile tekrar gönderim ilk
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
  /// Balık etkinliğinin av günlüğü ve mera gizliliği `log` bileşenindedir
  /// (`GET …/components/{component_key}/entries`, #243). Araçlar
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
  /// - Türe özel ayrıntı yoktur (#243). Konvoyun
  ///   rotası `route` bileşenindedir
  ///   (`PUT …/components/{component_key}/route`); kampın ve yürüyüşün
  ///   ayrıntıları `fields`'tadır, yürüyüşün beklenen dönüşü `roll_call`
  ///   bileşenindedir
  ///   (`PUT …/components/{component_key}/roll-call/expected-return`);
  ///   balık etkinliğinin av günlüğü `log` bileşenindedir.
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

  /// Açık uçlu etkinliği bitirir (organizatör)
  ///
  /// Şimdi başlat ile açılmış (`open_ended`) etkinlikte "Bitir"
  /// (ADR-0038 §1): `ends_at` sunucu saatiyle şimdi olur, `open_ended`
  /// `false` olur. Check-in, bileşenlerin yazma penceresi ve 7 günlük
  /// düzeltme penceresi yeni bitişten sayılır. Katılımcılara bildirim
  /// gitmez. Yalnızca organizatör; bitirilmeyen etkinlik başlangıçtan 12
  /// saat sonra kendiliğinden biter. Planlı etkinlik
  /// `event-not-open-ended`, bitmiş ya da bitirilmiş etkinlik
  /// `event-ended`, iptal edilmiş etkinlik `event-cancelled` alır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/finish`
  Future<Event> finishEvent({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/finish',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Event.fromJson(jsonObject(response, 'finishEvent'));
  }

  /// Etkinliğin QR'ı için kısa ömürlü katılım token'ı
  ///
  /// QR ile katılım (ADR-0038 §3). Organizatör kendi etkinliği için,
  /// tayfanın yöneticileri her etkinlik için alır. Yalnızca yüz yüze ve
  /// bitmemiş etkinlik; çevrimiçi etkinlik `invalid-request`, bitmiş
  /// etkinlik `event-ended`, iptal edilmiş etkinlik `event-cancelled`
  /// alır. Token 128 bit rastgele değerdir ve yalnızca bu yanıtta
  /// döner; sunucu yalnızca özetini saklar. Ömrü 2 dakikadır
  /// (`expires_at`): istemci süre dolmadan yenisini ister; eski token
  /// süresi dolana kadar geçerli kalır. QR yalnızca token'ı taşır
  /// (`https://tayfam.app/q#<token>`, token fragment'ta). Etkinlik 30
  /// QR katılımına ulaştıysa `join-qr-limit-reached`. IP başına sınır
  /// vardır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/join-qr`
  Future<JoinQrToken> createEventJoinQr({
    required String tayfaId,
    required String eventId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/join-qr',
      pathParams: {'tayfa_id': tayfaId, 'event_id': eventId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return JoinQrToken.fromJson(jsonObject(response, 'createEventJoinQr'));
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
  /// doğrulanmış katılımı gösterir. Türü `sensitive_attendance`
  /// bayraklı etkinlikte (ADR-0037 §1, kan bağışı) listeyi yalnızca
  /// organizatör, moderatör ve yönetici alır; diğerleri
  /// `attendees-hidden` alır ve etkinlikteki sayıları görür.
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
  /// Türü `album_notice` bayraklı etkinlikte (ADR-0037 §1, ziyaret)
  /// `consent_ack: true` zorunludur; yoksa `album-consent-required`.
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
  /// inemez (`vehicle-seats-taken`). `garage_vehicle_id` ile çağıranın
  /// garajındaki araç seçilir (#272): marka, model, yıl ve renk
  /// kopyalanır; plaka yalnızca bu kayda yazılır. Araç yazan kişinin başka bir araca
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

  /// Günlüğün kayıtları, eskiden yeniye
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Kayıtları herkes görür; bir kaydın
  /// konumu kaydı girene, diğerlerine `location_visibility`'nin izin
  /// verdiği kadar döner. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<EventLogEntryList> listEventLogEntries({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventLogEntryList.fromJson(
      jsonObject(response, 'listEventLogEntries'),
    );
  }

  /// Günlüğe kayıt ekler
  ///
  /// Katılımınız doğrulanmış olmalıdır (`not-attended`). Kişi başına en
  /// fazla bileşenin `max_entries` kadar (yoksa 100) kayıt
  /// (`event-limit`). Değerler tanıma göre doğrulanır
  /// (`invalid-request`, alan `values.<anahtar>`); zorunlu alanlar
  /// verilir, tanımda olmayan alan gönderilmez. Tayfa sözlüğüne bağlı
  /// alan (`CatalogVocabulary`) için ya `values`'ta metin ya
  /// `vocabulary_ids`'te tayfanın o ad alanındaki bir değerin kimliği
  /// gönderilir, ikisi birden değil (`vocabulary_ids.<anahtar>`); yeni
  /// metin sözlüğe eklenir. Konum yalnızca `location`
  /// parametresi açık günlükte verilir. Aynı `client_request_id` ile
  /// tekrar gönderim ilk kaydı döndürür. Bitişten 7 gün sonra donar
  /// (`component-frozen`); iptal edilmiş etkinliğe yazılmaz. Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventLogEntry> addEventLogEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventLogEntryCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventLogEntry.fromJson(jsonObject(response, 'addEventLogEntry'));
  }

  /// Günlükten kayıt çıkarır
  ///
  /// Kendi kaydınızı yazma penceresi içinde (`component-frozen`);
  /// moderatör ve yönetici herkesinkini her zaman (iptal edilmiş ve
  /// donmuş etkinlikte de). Kayıt 30 gün sonra fotoğrafıyla kalıcı
  /// silinir. Bilinmeyen kayıt `event-item-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries/{entry_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> removeEventLogEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String entryId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/entries/{entry_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'entry_id': entryId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Etkinliğin ölçümü
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Hassas ölçümde (`sensitive`) herkes
  /// yalnızca kendi değerini görür; başkası adına değer girebilenler
  /// hepsini görür. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventMeasure> getEventMeasure({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventMeasure.fromJson(jsonObject(response, 'getEventMeasure'));
  }

  /// Toplam ölçümü yazar (organizatör, moderatör, yönetici)
  ///
  /// Önerilen değeri (`suggested`) onaylamak da düzeltmek de bu uçtur;
  /// onaylanmamış öneri istatistiğe girmez. Aynı değeri yeniden yazmak
  /// bir şey değiştirmez. Kişisel ölçümde `measurement-scope`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/total`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventMeasure> setEventMeasureTotal({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventMeasureValueRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/total',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventMeasure.fromJson(jsonObject(response, 'setEventMeasureTotal'));
  }

  /// Toplam ölçümü kaldırır (organizatör, moderatör, yönetici)
  ///
  /// Olmayan değeri kaldırmak hata değildir. Kişisel ölçümde
  /// `measurement-scope`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/total`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventMeasure> removeEventMeasureTotal({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/total',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventMeasure.fromJson(
      jsonObject(response, 'removeEventMeasureTotal'),
    );
  }

  /// Bir katılımcının kişisel ölçümünü yazar
  ///
  /// `entered_by: self` ölçümde yalnızca kendi kimliğinizle ve katılımınız
  /// doğrulanmışsa (`not-attended`); başkasının değeri `permission-denied`.
  /// `entered_by: organizer` ölçümde organizatör, moderatör, yönetici ve
  /// atanmış hakem; `going` cevabı vermemiş ve katılımı doğrulanmamış
  /// kişi `measurement-not-participant`. Aynı değeri yeniden yazmak bir
  /// şey değiştirmez. Toplam ölçümde `measurement-scope`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/entries/{user_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventMeasure> setEventMeasureEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String userId,
    required EventMeasureValueRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/entries/{user_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'user_id': userId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventMeasure.fromJson(jsonObject(response, 'setEventMeasureEntry'));
  }

  /// Bir katılımcının kişisel ölçümünü kaldırır
  ///
  /// Değeri yazabilen kaldırır (katılım denetimi olmadan). Olmayan değeri
  /// kaldırmak hata değildir. Toplam ölçümde `measurement-scope`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/entries/{user_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventMeasure> removeEventMeasureEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/measure/entries/{user_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'user_id': userId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventMeasure.fromJson(
      jsonObject(response, 'removeEventMeasureEntry'),
    );
  }

  /// Etkinliğin hedefi ve ilerlemesi
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Bağlı ölçüm hassassa (`sensitive`,
  /// kişisel) ilerlemeyi yalnızca bütün değerleri görebilenler görür
  /// (organizatörün girdiği ölçümde organizatör, moderatör, yönetici);
  /// diğerlerine `progress_hidden` döner. Bileşen uçlarının ortak
  /// kuralları geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventGoal> getEventGoal({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGoal.fromJson(jsonObject(response, 'getEventGoal'));
  }

  /// Etkinliğin hedefini koyar (organizatör, moderatör, yönetici)
  ///
  /// Hedef ölçümün ondalık basamağına yuvarlanır; sıfırdan büyük olmalı,
  /// toplam ölçümde ölçümün üst sınırını aşamaz (`invalid-request`). Aynı
  /// hedefi yeniden yazmak bir şey değiştirmez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal/target`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventGoal> setEventGoalTarget({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventGoalTargetRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal/target',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGoal.fromJson(jsonObject(response, 'setEventGoalTarget'));
  }

  /// Etkinliğin hedefini kaldırır (organizatör, moderatör, yönetici)
  ///
  /// Tanımdaki varsayılan hedef yeniden geçerli olur. Olmayan hedefi
  /// kaldırmak hata değildir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal/target`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventGoal> removeEventGoalTarget({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/goal/target',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGoal.fromJson(jsonObject(response, 'removeEventGoalTarget'));
  }

  /// Etkinliğin programı
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Bileşen uçlarının ortak kuralları
  /// geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventSchedule> getEventSchedule({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventSchedule.fromJson(jsonObject(response, 'getEventSchedule'));
  }

  /// Programa madde ekler (organizatör, moderatör, yönetici)
  ///
  /// En fazla `max_items` madde (`event-limit`). Saatler etkinliğin
  /// başlangıcından en çok bir gün önce, bitişinden en çok bir gün sonra
  /// olabilir; bitiş saati başlangıçtan sonra olmalıdır (aksi
  /// `invalid-request`). Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventSchedule> addEventScheduleItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventScheduleItemRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventSchedule.fromJson(jsonObject(response, 'addEventScheduleItem'));
  }

  /// Program maddesini düzenler (organizatör, moderatör, yönetici)
  ///
  /// Maddenin bütün değerlerini değiştirir (gönderilmeyen `ends_at` ve
  /// `note` kaldırılır); kurallar eklemedekiyle aynıdır. Bilinmeyen
  /// madde `event-item-not-found`. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items/{item_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [itemId]: Programdaki maddenin kimliği (`EventScheduleItem.id`).
  Future<EventSchedule> updateEventScheduleItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String itemId,
    required EventScheduleItemRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items/{item_id}',
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
    return EventSchedule.fromJson(
      jsonObject(response, 'updateEventScheduleItem'),
    );
  }

  /// Programdan madde çıkarır (organizatör, moderatör, yönetici)
  ///
  /// Bilinmeyen madde `event-item-not-found`. Bileşen uçlarının ortak
  /// kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items/{item_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [itemId]: Programdaki maddenin kimliği (`EventScheduleItem.id`).
  Future<EventSchedule> removeEventScheduleItem({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String itemId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/schedule/items/{item_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'item_id': itemId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventSchedule.fromJson(
      jsonObject(response, 'removeEventScheduleItem'),
    );
  }

  /// Etkinliğin takımları
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Bileşen uçlarının ortak kuralları
  /// geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventTeams> getEventTeams({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventTeams.fromJson(jsonObject(response, 'getEventTeams'));
  }

  /// Takımları elle kurar (organizatör, moderatör, yönetici)
  ///
  /// Her modda kullanılır; mevcut takımların yerini alır (boş liste
  /// takımları kaldırır). En fazla `team_count` (yoksa 50) takım;
  /// `team_count` ile `team_size` birlikte verilmişse takımda en fazla
  /// `team_size` kişi; bir kişi en fazla bir takımda; toplam en fazla 500
  /// kişi (aksi `invalid-request`). Katılımcı olmayan kişi
  /// `teams-not-participant`. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventTeams> replaceEventTeams({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventTeamsRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventTeams.fromJson(jsonObject(response, 'replaceEventTeams'));
  }

  /// Takımları katılımcılardan kurar (organizatör, moderatör, yönetici)
  ///
  /// Mevcut takımların yerini alır (takım adları sırasıyla korunur).
  /// Rastgelelik sunucuda kriptografik üreteçle sağlanır. `random` modda
  /// katılımcılar karıştırılıp sırayla dağıtılır; `balanced` modda
  /// gönderilen seviyelere göre (güçlüden zayıfa, yılan sırasıyla)
  /// dağıtılır, seviyesi gönderilmeyen katılımcı 3 sayılır, eşitler
  /// rastgele sıralanır. Seviyeler saklanmaz, loglanmaz, yanıtta dönmez.
  /// Takım sayısı `team_count`; yoksa katılımcı sayısı / `team_size`
  /// (artanlar takımlara katılır); ikisi de yoksa 2. `team_count` ile
  /// `team_size` birlikte verilmişse takımlar en fazla `team_size` kişi
  /// alır, kalanlar (rastgele) dışarıda kalır. `manual` modda
  /// `teams-manual`; iki katılımcıdan ya da takım sayısından az
  /// katılımcıda `teams-too-few`; 500'den çok katılımcıda `event-limit`.
  /// Gövde zorunludur (seviyesiz istekte boş nesne). Bileşen uçlarının
  /// ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams/generate`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventTeams> generateEventTeams({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventTeamsGenerateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/teams/generate',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventTeams.fromJson(jsonObject(response, 'generateEventTeams'));
  }

  /// Etkinliğin kurası
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Kura çekilmemişse `drawn` false,
  /// `entries` boştur; `subject` çekilecek kuranın neyi sıralayacağını
  /// gösterir. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/draw`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventDraw> getEventDraw({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/draw',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventDraw.fromJson(jsonObject(response, 'getEventDraw'));
  }

  /// Kurayı çeker (organizatör, moderatör, yönetici)
  ///
  /// Gövde almaz. Sıra sunucuda kriptografik üreteçle belirlenir ve
  /// sabitlenir. Kura daha önce çekildiyse `draw-already-made`; ikiden
  /// az katılımcıda (takım kurasında üyesi olan ikiden az takımda)
  /// `draw-too-few`; 500'den çok katılımcıda `event-limit`. Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/draw`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventDraw> makeEventDraw({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/draw',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventDraw.fromJson(jsonObject(response, 'makeEventDraw'));
  }

  /// Etkinliğin yazbozu
  ///
  /// Masalar, yerleri, elleri, sıralama ve (biten masada) kazananlar ile
  /// bileşenin sunduğu ve masaların kullandığı ön ayarlar. Her etkin
  /// üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve donmuş
  /// etkinlikte de okunur. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventScoreboard> getEventScoreboard({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(jsonObject(response, 'getEventScoreboard'));
  }

  /// Masa kurar (organizatör, moderatör, yönetici)
  ///
  /// Yerler şimdi ya da ilk elden önce (`…/players`) verilir. Bileşen ön
  /// ayar sunuyorsa `preset_key` onlardan biri olmalı, sunmuyorsa
  /// verilmez (aksi ya da emekli ön ayar `score-preset-unavailable`).
  /// `first_to` ya da `first` kuralında hedef puan yoksa, etiket 1–30
  /// karakter değilse, yer tam olarak bir kişi ya da takım değilse, bir
  /// kişi ya da takım iki kez geçerse, ön ayarın oyuncu sayısı dışındaysa,
  /// oyuncu ya da eşli masaya takım ya da takım masasına kişi verilirse,
  /// eşli masada yer sayısı 4 değilse, takım
  /// masasında `teams_key` etkinliğin türündeki bir `teams` bileşeni
  /// değilse `invalid-request`. Katılımcı olmayan kişi ya da takım
  /// bileşeninde olmayan takım `score-player-not-participant`; masalar
  /// doluysa `event-limit`. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventScoreboard> createEventScoreTable({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventScoreTableRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'createEventScoreTable'),
    );
  }

  /// Masanın adını ya da durumunu değiştirir (organizatör, moderatör, yönetici)
  ///
  /// `status` ile masa yeniden açılır (`open`) ya da bitirilir
  /// (`finished`). En az bir alan verilir. Masa yoksa
  /// `score-table-not-found`. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  Future<EventScoreboard> updateEventScoreTable({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
    required EventScoreTableUpdate body,
  }) async {
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'updateEventScoreTable'),
    );
  }

  /// Masayı siler (organizatör, moderatör, yönetici)
  ///
  /// Masa yerleri, elleri ve hakem atamalarıyla silinir. Masa yoksa
  /// `score-table-not-found`. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  Future<EventScoreboard> deleteEventScoreTable({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'deleteEventScoreTable'),
    );
  }

  /// Masanın yerlerini belirler (organizatör, moderatör, yönetici)
  ///
  /// Sırasıyla yerlerin yerini alır (boş liste yerleri boşaltır). İlk el
  /// girildikten sonra `score-table-started`. Yer kuralları ve hataları
  /// masa kurmadaki gibidir. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/players`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  Future<EventScoreboard> setEventScorePlayers({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
    required EventScorePlayersRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/players',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'setEventScorePlayers'),
    );
  }

  /// Masanın sıradaki elini girer (organizatör, moderatör, yönetici, hakem)
  ///
  /// Hakem masaya, bileşene ya da etkinliğe atanmış olmalıdır. Oyunu
  /// bitiren el masayı bitirir. Skor masanın yerleri için verilir, her yer
  /// en fazla bir kez; `points` modunda `points` (−1000000…1000000),
  /// `wdl` modunda `outcome` verilir ve el en az iki yerde ya birinin
  /// galibiyeti ile diğerlerinin mağlubiyeti ya da herkesin
  /// beraberliğidir (aksi `invalid-request`). Eşli masada skor eş
  /// başınadır: eşin herhangi bir yeriyle verilir, iki yeri birlikte
  /// verilirse değerleri aynı olmalıdır; kurallar eş düzeyinde geçerlidir
  /// (`wdl` modunda iki eş) ve skor eşin iki yerine de yazılır. Biten masada
  /// `score-table-finished`; 200 elden sonra `event-limit`; etkinlik
  /// başlamadıysa `score-not-started`. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  Future<EventScoreboard> addEventScoreRound({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
    required EventScoreRoundRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(jsonObject(response, 'addEventScoreRound'));
  }

  /// Girilmiş bir eli düzeltir (organizatör, moderatör, yönetici)
  ///
  /// Açık ya da biten masada elin skorlarının yerini alır. Oyunu bitiren
  /// düzeltme açık masayı bitirir; biten masa bitmiş kalır (yeniden açmak
  /// için `PATCH`). Girilmemiş el `invalid-request`; skor kuralları el
  /// girmedeki gibidir. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds/{round}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  ///
  /// [round]: Elin numarası (1–200).
  ///
  /// Kısıtlar: minimum: 1; maximum: 200.
  Future<EventScoreboard> correctEventScoreRound({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
    required int round,
    required EventScoreRoundRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds/{round}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
        'round': '$round',
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'correctEventScoreRound'),
    );
  }

  /// Masanın son elini siler (organizatör, moderatör, yönetici)
  ///
  /// Yalnızca son el silinir (aksi `invalid-request`); masanın durumu
  /// değişmez. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds/{round}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  ///
  /// [round]: Elin numarası (1–200).
  ///
  /// Kısıtlar: minimum: 1; maximum: 200.
  Future<EventScoreboard> deleteEventScoreRound({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
    required int round,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/rounds/{round}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
        'round': '$round',
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'deleteEventScoreRound'),
    );
  }

  /// Masayı bitirir (organizatör, moderatör, yönetici, hakem)
  ///
  /// Gövde almaz. Biten masayı bitirmek bir şey değiştirmez. Etkinlik
  /// başlamadıysa `score-not-started`. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/finish`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [tableId]: Yazboz masasının kimliği (`EventScoreTable.id`).
  Future<EventScoreboard> finishEventScoreTable({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String tableId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/scoreboard/tables/{table_id}/finish',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'table_id': tableId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventScoreboard.fromJson(
      jsonObject(response, 'finishEventScoreTable'),
    );
  }

  /// Etkinliğin misafir oyuncuları
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventGuestPlayers> listEventGuestPlayers({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGuestPlayers.fromJson(
      jsonObject(response, 'listEventGuestPlayers'),
    );
  }

  /// Misafir oyuncu ekler (organizatör, moderatör, yönetici, hakem)
  ///
  /// Etkinliğin, bileşenin ya da `table_id` masasının hakemi de ekler;
  /// diğerleri `permission-denied`. Bileşende olmayan masa
  /// `score-table-not-found`; 30 misafirde `event-limit`. Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventGuestPlayers> addEventGuestPlayer({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventGuestPlayerRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGuestPlayers.fromJson(
      jsonObject(response, 'addEventGuestPlayer'),
    );
  }

  /// Misafir oyuncuyu siler (organizatör, moderatör, yönetici)
  ///
  /// Masada yeri ya da kurada yeri olan misafir silinmez
  /// (`guest-player-in-use`); etkinliğin misafiri değilse
  /// `guest-player-not-found`. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests/{guest_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [guestId]: Misafir oyuncunun kimliği (`EventGuestPlayer.id`).
  Future<EventGuestPlayers> removeEventGuestPlayer({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String guestId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/guests/{guest_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'guest_id': guestId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventGuestPlayers.fromJson(
      jsonObject(response, 'removeEventGuestPlayer'),
    );
  }

  /// Etkinliğin eşleşme ağacı
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Başlamamışsa `started` false; kurallar
  /// ve kuranın alanları başlatılırsa alınacak olanlardır. Bileşen
  /// uçlarının ortak kuralları geçerlidir (`component-not-found`,
  /// `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventBracket> getEventBracket({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(jsonObject(response, 'getEventBracket'));
  }

  /// Eşleşme ağacını başlatır (organizatör, moderatör, yönetici)
  ///
  /// Gövde almaz. Kuradan ilk turu (ligde tüm turları) eşler. Başlamışsa
  /// `bracket-started`; kura çekilmemişse ya da türde kura yoksa
  /// `bracket-draw-required`; kurada ikiden az dolu yer varsa
  /// `bracket-too-few`; elemede 128 yerden, ligde 20 ve İsviçre'de 64
  /// katılımcıdan fazlası `event-limit`. Bileşen uçlarının ortak
  /// kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventBracket> startEventBracket({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(jsonObject(response, 'startEventBracket'));
  }

  /// Eşleşme ağacını sıfırlar (organizatör, moderatör, yönetici)
  ///
  /// Maçları, oyunları ve maçlara atanmış hakemleri siler; kura kalır.
  /// Başlamamışsa `bracket-not-started`. Bileşen uçlarının ortak
  /// kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventBracket> resetEventBracket({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(jsonObject(response, 'resetEventBracket'));
  }

  /// Sonraki turu eşler (organizatör, moderatör, yönetici)
  ///
  /// Gövde almaz. Elemede ve İsviçre'de, mevcut turun tüm maçları
  /// sonuçlanınca sonraki turu eşler. Sonuçlanmamış maç varsa
  /// `bracket-round-open`; sonraki tur yoksa (ligde turların hepsi
  /// başlangıçta eşlenir) `bracket-finished`; başlamamışsa
  /// `bracket-not-started`. Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/rounds`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventBracket> pairEventBracketRound({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/rounds',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(jsonObject(response, 'pairEventBracketRound'));
  }

  /// Maça sonraki oyunu girer (organizatör, moderatör, yönetici, hakem)
  ///
  /// `points` kuralında iki tarafın puanı (`a_points`, `b_points`),
  /// `wdl` kuralında A tarafının sonucu (`a_outcome`); kurala uymayan
  /// gövde `invalid-request`. Maçı sonuçlandıran oyunla maç biter.
  /// Etkinlik başlamadıysa `score-not-started`; maç yoksa
  /// `bracket-match-not-found`; sonuçlanmış maçta ya da bayda
  /// `bracket-match-decided`; sonraki tur eşlenmişse
  /// `bracket-round-closed`; 9 oyundan sonra `event-limit`. Bileşen
  /// uçlarının ortak kuralları geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [matchId]: Eşleşme ağacındaki maçın kimliği (`EventBracketMatch.id`).
  Future<EventBracket> addEventBracketGame({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String matchId,
    required EventBracketGameRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'match_id': matchId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(jsonObject(response, 'addEventBracketGame'));
  }

  /// Girilmiş bir oyunu düzeltir (organizatör, moderatör, yönetici)
  ///
  /// Sonuçlanmış maçta da oyunun yerini alır. Girilmemiş oyun
  /// `bracket-game-not-found`; sonraki tur bu maçın turundan eşlenmişse
  /// `bracket-round-closed` (gerekirse eşleşme ağacı sıfırlanır). Gövde
  /// kuralları oyun girmedeki gibidir. Bileşen uçlarının ortak kuralları
  /// geçerlidir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games/{game}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [matchId]: Eşleşme ağacındaki maçın kimliği (`EventBracketMatch.id`).
  ///
  /// [game]: Maçtaki oyunun numarası (1–9).
  ///
  /// Kısıtlar: minimum: 1; maximum: 9.
  Future<EventBracket> correctEventBracketGame({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String matchId,
    required int game,
    required EventBracketGameRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games/{game}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'match_id': matchId,
        'game': '$game',
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(
      jsonObject(response, 'correctEventBracketGame'),
    );
  }

  /// Maçın son oyununu siler (organizatör, moderatör, yönetici)
  ///
  /// Yalnızca son oyun silinir (aksi `bracket-game-not-found`); sonraki
  /// tur eşlenmişse `bracket-round-closed`. Bileşen uçlarının ortak
  /// kuralları geçerlidir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games/{game}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  ///
  /// [matchId]: Eşleşme ağacındaki maçın kimliği (`EventBracketMatch.id`).
  ///
  /// [game]: Maçtaki oyunun numarası (1–9).
  ///
  /// Kısıtlar: minimum: 1; maximum: 9.
  Future<EventBracket> deleteEventBracketGame({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String matchId,
    required int game,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/bracket/matches/{match_id}/games/{game}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'match_id': matchId,
        'game': '$game',
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventBracket.fromJson(
      jsonObject(response, 'deleteEventBracketGame'),
    );
  }

  /// Etkinliğin derecesi
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Hassas ölçümden (`sensitive`) hesaplanan
  /// derece, ölçümün bütün değerlerini görebilenler (ölçümü organizatör
  /// giriyorsa organizatör, moderatör, yönetici) dışında gizlidir
  /// (`hidden`). Kaynak ölçüm kapalıysa (`measure_enabled: false`) derece
  /// boştur. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRanking> getEventRanking({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRanking.fromJson(jsonObject(response, 'getEventRanking'));
  }

  /// Bir katılımcının derecesini elle yazar (organizatör, moderatör, yönetici, hakem)
  ///
  /// Süre sıfırdan büyük, en çok 1000000 saniye ve iki basamağa
  /// yuvarlanır; sıra 1–10000 arası tam sayıdır (dışı `invalid-request`).
  /// `going` cevabı vermemiş ve katılımı doğrulanmamış kişi
  /// `ranking-not-participant`. Aynı değeri yeniden yazmak bir şey
  /// değiştirmez. Ölçümden hesaplanan derecede `ranking-from-measure`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking/entries/{user_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRanking> setEventRankingEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String userId,
    required EventRankingValueRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking/entries/{user_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'user_id': userId,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRanking.fromJson(jsonObject(response, 'setEventRankingEntry'));
  }

  /// Bir katılımcının elle girilmiş derecesini kaldırır
  ///
  /// Değeri yazabilen kaldırır (başlangıç ve katılım denetimi olmadan).
  /// Olmayan değeri kaldırmak hata değildir. Ölçümden hesaplanan derecede
  /// `ranking-from-measure`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking/entries/{user_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventRanking> removeEventRankingEntry({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String userId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/ranking/entries/{user_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'user_id': userId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventRanking.fromJson(
      jsonObject(response, 'removeEventRankingEntry'),
    );
  }

  /// Etkinliğin oylaması
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Bileşen uçlarının ortak kuralları
  /// geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> getEventVote({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'getEventVote'));
  }

  /// Oy verir ya da oyunuzu değiştirir
  ///
  /// Etkinliğe `going` cevabı vermiş ya da katılımı doğrulanmış olmalısınız
  /// (`event-not-going`); susturulmuş üye oy veremez. Kişi başına bir oy;
  /// yeni oy öncekinin yerine geçer, aynı oyu yeniden vermek bir şey
  /// değiştirmez. Kendinize, kendi aracınıza ya da kendi fotoğrafınıza oy
  /// veremezsiniz (`vote-own-option`). Oylamanın şu anki seçeneği
  /// olmayan `option_id` `event-item-not-found`. Kapatılmış oylamada
  /// `vote-closed`; bitişten 7 gün sonra donar (`component-frozen`); iptal
  /// edilmiş etkinlikte oy verilmez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> castEventVote({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventVoteCastRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'castEventVote'));
  }

  /// Oyunuzu geri alır
  ///
  /// Oyu olmayan için hata değildir. Oylama açıkken ve yazma penceresi
  /// içinde (`vote-closed`, `component-frozen`); susturulmuş üye geri
  /// alamaz.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> withdrawEventVote({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'withdrawEventVote'));
  }

  /// Serbest seçenek ekler (organizatör, moderatör, yönetici)
  ///
  /// Yalnızca `free` kaynaklı oylamada (`vote-options-fixed`) ve oylama
  /// açıkken (`vote-closed`). Etiket kırpılır, iç boşlukları teke
  /// indirilir; 1–100 karakter, denetim ve biçim karakteri olmadan
  /// (`invalid-request`, alan `label`). Aynı etiket (Türkçe küçük harfle)
  /// `vote-option-exists`; en fazla 20 seçenek (`event-limit`).
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/options`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> addEventVoteOption({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventVoteOptionRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/options',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'addEventVoteOption'));
  }

  /// Serbest seçeneği ve ona verilen oyları kaldırır (organizatör, moderatör, yönetici)
  ///
  /// Yalnızca `free` kaynaklı oylamada (`vote-options-fixed`) ve oylama
  /// açıkken (`vote-closed`). Bilinmeyen seçenek `event-item-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/options/{option_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> removeEventVoteOption({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String optionId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/options/{option_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'option_id': optionId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'removeEventVoteOption'));
  }

  /// Oylamayı kapatır (organizatör, moderatör, yönetici)
  ///
  /// Kapanış geri alınmaz: oy ve seçenek değişikliği biter, seçenek başına
  /// oy sayıları ve kazananlar herkese görünür. Yazma penceresi içinde
  /// (`component-frozen`). Kapalı oylamayı yeniden kapatmak bir şey
  /// değiştirmez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/close`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventVote> closeEventVote({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/vote/close',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventVote.fromJson(jsonObject(response, 'closeEventVote'));
  }

  /// Etkinliğin kutlaması
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Kaynak henüz sonuçlanmadıysa ya da
  /// kapalıysa `winners` boştur. Bileşen uçlarının ortak kuralları
  /// geçerlidir (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/celebration`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventCelebration> getEventCelebration({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/celebration',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventCelebration.fromJson(
      jsonObject(response, 'getEventCelebration'),
    );
  }

  /// Kazananı ilan eder (organizatör, moderatör, yönetici)
  ///
  /// Etkinlik başladıktan (`celebration-not-started`) bitişten 7 gün
  /// sonrasına kadar (`component-frozen`). Kaynaklı kutlamada gövde boş
  /// nesnedir (`winner_ids` verilirse `invalid-request`) ve kaynağın
  /// kazananı yoksa `celebration-no-winner`. Kaynaksız kutlamada
  /// `winner_ids` 1–10 farklı kişidir; `going` cevabı vermemiş ve katılımı
  /// doğrulanmamış kişi `celebration-not-participant`. İlk ilan bildirim
  /// gönderir; yeniden ilan yalnızca elle seçilen kazananları değiştirir,
  /// bildirim göndermez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/celebration`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventCelebration> announceEventCelebration({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventCelebrationRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/celebration',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventCelebration.fromJson(
      jsonObject(response, 'announceEventCelebration'),
    );
  }

  /// Bileşenin soruları
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur); iptal edilmiş ve
  /// donmuş etkinlikte de okunur. Cevaplanmamışlar önce, sonra çok oy
  /// alan, sonra eski. Bileşen uçlarının ortak kuralları geçerlidir
  /// (`component-not-found`, `component-disabled`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventQuestionList> listEventQuestions({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventQuestionList.fromJson(
      jsonObject(response, 'listEventQuestions'),
    );
  }

  /// Soru sorar
  ///
  /// Etkinliğe `going` cevabı vermiş ya da katılımı doğrulanmış olmalısınız
  /// (`event-not-going`); susturulmuş üye soramaz. Metin kırpılır, iç
  /// boşlukları teke indirilir; 1–500 karakter, denetim ve biçim
  /// karakteri olmadan (`invalid-request`, alan `body`). `anonymous`
  /// yalnızca bileşen izin veriyorsa (`anonymous_allowed`; alan
  /// `anonymous`). Kişi başına en fazla 20, bileşende en fazla 500 soru
  /// (`event-limit`). Aynı `client_request_id` ile tekrar gönderim ilk
  /// soruyu döndürür. Bitişten 7 gün sonra donar (`component-frozen`);
  /// iptal edilmiş etkinliğe yazılmaz.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventQuestion> askEventQuestion({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventQuestionCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventQuestion.fromJson(jsonObject(response, 'askEventQuestion'));
  }

  /// Soruyu kaldırır
  ///
  /// Kendi sorunuzu yazma penceresi içinde (`component-frozen`);
  /// moderatör ve yönetici herkesinkini, anonim soruyu da yazarını
  /// görmeden, her zaman (iptal edilmiş ve donmuş etkinlikte de). Soru 30
  /// gün sonra oylarıyla kalıcı silinir. Bilinmeyen soru
  /// `event-item-not-found`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> removeEventQuestion({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'question_id': questionId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Soruya oy verir
  ///
  /// Soru sorabilenler oy verir (`event-not-going`); kişi başına soru
  /// başına bir oy, zaten verilmiş oy hata değildir. Yazma penceresi
  /// içinde. Bilinmeyen soru `event-item-not-found`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/vote`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> voteEventQuestion({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/vote',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'question_id': questionId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Sorudaki oyunuzu geri alır
  ///
  /// Verilmemiş oyu geri almak hata değildir. Yazma penceresi içinde;
  /// susturulmuş üye geri alamaz.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/vote`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> unvoteEventQuestion({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/vote',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'question_id': questionId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Soruyu cevaplandı işaretler
  ///
  /// Organizatör, moderatör ve yönetici; yazma penceresi içinde. Zaten
  /// işaretli soru hata değildir (ilk işaret zamanı kalır).
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/answered`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> markEventQuestionAnswered({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/answered',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'question_id': questionId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Cevaplandı işaretini kaldırır
  ///
  /// Organizatör, moderatör ve yönetici; yazma penceresi içinde.
  /// İşaretsiz soru hata değildir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/answered`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<void> unmarkEventQuestionAnswered({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required String questionId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/questions/{question_id}/answered',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
        'question_id': questionId,
      },
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Etkinliğe bağlı havuz soruları
  ///
  /// Bağlı ve görünen sorular, organizatörün sırasıyla. Silinen soru
  /// listede görünmez (geri alınırsa yeniden görünür). Sorunun tamamı ve
  /// cevapları `GET /v1/tayfas/{tayfa_id}/questions/{question_id}`
  /// uçlarından okunur. Her etkin üyeye açıktır (susturulmuş üye de
  /// okur). Bileşen uçlarının ortak kuralları geçerlidir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/pool-links`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventPoolLinks> getEventPoolLinks({
    required String tayfaId,
    required String eventId,
    required String componentKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/pool-links',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventPoolLinks.fromJson(jsonObject(response, 'getEventPoolLinks'));
  }

  /// Bağlı soruları yazar (organizatör, moderatör, yönetici)
  ///
  /// Listenin tamamı değişir, verilen sırayla; boş `question_ids` bütün
  /// bağları kaldırır. En fazla bileşenin `max_links` değeri (1–50)
  /// kadar, tekrarsız (`invalid-request`, alan `question_ids`). Her soru
  /// bu tayfanın soru havuzunda görünen bir soru olmalıdır
  /// (`question-not-found`). Aynı liste hiçbir şeyi değiştirmez. Yazma
  /// penceresi içinde (bitişten 7 gün sonra `component-frozen`).
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/pool-links`
  ///
  /// [componentKey]: Bileşenin, etkinliğin tür sürümündeki anahtarı (`CatalogComponent.key`; yoksa `kind`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<EventPoolLinks> setEventPoolLinks({
    required String tayfaId,
    required String eventId,
    required String componentKey,
    required EventPoolLinksRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/pool-links',
      pathParams: {
        'tayfa_id': tayfaId,
        'event_id': eventId,
        'component_key': componentKey,
      },
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventPoolLinks.fromJson(jsonObject(response, 'setEventPoolLinks'));
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
