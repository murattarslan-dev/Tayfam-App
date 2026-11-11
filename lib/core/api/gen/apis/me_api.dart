// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `me` olan uçlar.
final class MeApi {
  const MeApi(this._transport);

  final ApiTransport _transport;

  /// Hesabınızı siler (KVKK)
  ///
  /// **Yeniden kimlik doğrulama:** Son 10 dakika içinde Google/Apple ile
  /// giriş yapılmış olmalıdır; hem erişim token'ı hem de oturumu o
  /// girişten gelmelidir. `/v1/auth/refresh` ile yenilenmiş bir token
  /// yetmez. Değilse `403 reauthentication-required`: istemci kullanıcıyı
  /// sağlayıcıyla yeniden giriş yaptırır (`/v1/auth/sign-in`) ve yeni
  /// token'la tekrar dener.
  ///
  /// Kişisel bilgiler (ad, profil fotoğrafı, doğum tarihi, referans kodu)
  /// hemen silinir; tüm cihazlardaki oturumlar kapanır, tayfalardan
  /// çıkılır. İçerikler kalır, yazarı "Silinmiş kullanıcı" görünür. Kayıt
  /// 30 gün sonra tamamen silinir; geri alma yoktur. Aynı Google/Apple
  /// hesabıyla sonraki giriş yeni bir hesap açar.
  ///
  /// Erişim token'ı iptal edilemez (ADR-0004): kalan ömrü boyunca (en
  /// fazla 15 dakika) hesap uçları onu reddeder, tayfa uçları üyelik
  /// kalmadığı için reddeder.
  ///
  /// `DELETE /v1/me`
  Future<void> deleteAccount() async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Açık oturumlarınız (cihaz başına bir oturum)
  ///
  /// En son kullanılan önce, en fazla 100. IP adresi ve token dönmez.
  /// `current` bu isteğin oturumudur. Kapatılmış bir oturumun token'ı
  /// oturum uçlarında `401` alır.
  ///
  /// `GET /v1/me/sessions`
  Future<DeviceSessionList> listSessions() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/sessions',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DeviceSessionList.fromJson(jsonObject(response, 'listSessions'));
  }

  /// Bir oturumu kapatır (uzaktan çıkış)
  ///
  /// O cihazın refresh token'ı hemen geçersiz olur; erişim token'ı en
  /// fazla 15 dakika daha geçerli kalabilir (ADR-0004). Kendi oturumunuzu
  /// kapatmak çıkış yapmaktır (istemci kendi oturumu için
  /// `/v1/auth/sign-out` kullanır). Başka kullanıcının, bilinmeyen ya da
  /// zaten kapalı oturum aynı cevabı alır (`session-not-found`).
  ///
  /// `DELETE /v1/me/sessions/{session_id}`
  Future<void> revokeSession({required String sessionId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/sessions/{session_id}',
      pathParams: {'session_id': sessionId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bu oturum dışındaki tüm oturumları kapatır
  ///
  /// `POST /v1/me/sessions/sign-out-others`
  Future<RevokedSessions> revokeOtherSessions() async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/sessions/sign-out-others',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return RevokedSessions.fromJson(
      jsonObject(response, 'revokeOtherSessions'),
    );
  }

  /// Güncel metin sürümleri ve onay durumunuz
  ///
  /// Aydınlatma metni veya kullanım koşulları yeni sürümle yayınlanınca
  /// `consent_required` true olur (giriş ve yenileme yanıtında da döner).
  /// İstemci yeni metinleri gösterir ve `POST /v1/me/consents` ile onaylar.
  ///
  /// `GET /v1/me/consents`
  Future<ConsentStatus> getConsents() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/consents',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ConsentStatus.fromJson(jsonObject(response, 'getConsents'));
  }

  /// Güncel metin sürümlerini onaylar
  ///
  /// Gösterilen sürümler gönderilir; güncel değillerse `409
  /// consent-outdated` (ekran açıkken yeni sürüm yayınlanmış olabilir).
  /// Onaylar yalnızca eklenir; aynı sürüm tekrar onaylanınca bir şey
  /// değişmez.
  ///
  /// `POST /v1/me/consents`
  Future<void> acceptConsents({required ConsentRequest body}) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/consents',
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bu oturumun push (FCM) token'ını kaydeder ya da yeniler
  ///
  /// Uygulama her açılışta ve FCM token'ı yenilediğinde çağırır; 60 gün
  /// yenilenmeyen token silinir. Oturum başına bir token: yeni değer
  /// eskisinin yerine geçer. Aynı token başka bir oturumda kayıtlıysa
  /// (cihazda başka hesapla giriş) oraya bağlı kayıt silinir. Hesap
  /// başına en fazla 10 token (en eski yenilenen gider). Kapatılmış
  /// oturumun hâlâ geçerli token'ı kaydedemez (401). Hız sınırı:
  /// kullanıcı başına dakikada 10. Push sunucuda kapalıysa da kayıt
  /// kabul edilir.
  ///
  /// `PUT /v1/me/push-token`
  Future<void> putPushToken({required PushTokenRegistration body}) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/me/push-token',
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bu oturumun push token'ını siler
  ///
  /// Çıkışta ya da kullanıcı cihazda bildirimleri kapatınca. Token yoksa
  /// bir şey değişmez. Çıkışta oturum kapanınca token zaten silinir; bu
  /// çağrı onu beklemeden yapar.
  ///
  /// `DELETE /v1/me/push-token`
  Future<void> deletePushToken() async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/push-token',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bu oturumun E2E cihazı ve hesabın E2E durumu
  ///
  /// Tek kullanımlık ön anahtar sayıları (`prekey_counts.low`: bir türden
  /// 10'dan az kaldı), geçmiş anahtarı sürümü, anahtar yenileme gerekip
  /// gerekmediği ve eşleştirilmiş başka cihaz olup olmadığı (varsa QR
  /// eşleştirme önerin). Cihaz yoksa `e2e-device-not-registered` (409).
  ///
  /// `GET /v1/me/e2e/device`
  Future<E2EDeviceState> getMyE2EDevice() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/e2e/device',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EDeviceState.fromJson(jsonObject(response, 'getMyE2EDevice'));
  }

  /// Bu oturumu E2E cihazı olarak kaydeder
  ///
  /// Kimlik anahtarı, kayıt kimliği, imzalı ön anahtar ve son çare Kyber
  /// ön anahtarı zorunlu (PQXDH); tek kullanımlık EC ve Kyber ön
  /// anahtarları türüne göre en fazla 100. Hesap sıradaki cihaz
  /// numarasını alır (1–127, Signal adresi) ve karşı taraflar için
  /// `device_added` anahtar olayı yazılır. Hesap başına en fazla 5 cihaz
  /// (`e2e-device-limit`, 409: eski bir oturumu kapatın). Aynı oturum aynı
  /// anahtarlarla tekrar kaydolursa aynı cihaz döner; başka anahtarlarla
  /// `e2e-device-already-registered` (409; önce `DELETE`). Kapatılmış
  /// oturumun hâlâ geçerli token'ı kaydedemez (401). Gövde en fazla
  /// 512 KiB. Hız sınırı: anahtar işlemleri kullanıcı başına dakikada 30.
  ///
  /// `POST /v1/me/e2e/device`
  Future<E2EDeviceRegistered> registerE2EDevice({
    required E2EDeviceRegistration body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/device',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EDeviceRegistered.fromJson(
      jsonObject(response, 'registerE2EDevice'),
    );
  }

  /// Bu oturumun E2E cihazını kaldırır
  ///
  /// Ön anahtarlar, bekleyen zarflar, anahtar paylaşımları ve eşleştirme
  /// isteği de silinir; `device_removed` anahtar olayı yazılır.
  /// Eşleştirilmiş cihazsa ve eşleştirilmiş başka cihaz kalırsa geçmiş
  /// anahtarının yenilenmesi istenir. Cihaz yoksa bir şey değişmez.
  ///
  /// `DELETE /v1/me/e2e/device`
  Future<void> unregisterE2EDevice() async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/e2e/device',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Ön anahtar yükler
  ///
  /// Verilirse imzalı ön anahtarı ve son çare Kyber ön anahtarını
  /// değiştirir; tek kullanımlık ön anahtarları ekler (çağrı başına
  /// türüne göre en fazla 100, cihazda türüne göre en fazla 200; var olan
  /// kimlik değişmez). Gövde en fazla 512 KiB.
  ///
  /// `POST /v1/me/e2e/device/prekeys`
  Future<E2EPreKeyCounts> uploadE2EPreKeys({
    required E2EPreKeyUpload body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/device/prekeys',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EPreKeyCounts.fromJson(jsonObject(response, 'uploadE2EPreKeys'));
  }

  /// Bu cihazı bekleyen zarflar (en eski önce)
  ///
  /// Teslim en az bir kezdir: zarf `id` ile tekilleştirilir, saklandıktan
  /// sonra onaylanır. Onaylanmayan zarf 30 gün sonra silinir. Onaydan
  /// sonra liste baştan çekilir.
  ///
  /// `GET /v1/me/e2e/envelopes`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<E2EEnvelopeList> listE2EEnvelopes({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/e2e/envelopes',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EEnvelopeList.fromJson(jsonObject(response, 'listE2EEnvelopes'));
  }

  /// Teslim alınan zarfları onaylar (siler)
  ///
  /// Yalnızca bu cihazın zarfları silinir; başka cihazın ya da bilinmeyen
  /// kimlikler yok sayılır. WebSocket `dm.envelope_ack` ile aynı.
  ///
  /// `POST /v1/me/e2e/envelopes/ack`
  Future<void> ackE2EEnvelopes({required E2EEnvelopeAck body}) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/envelopes/ack',
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Geçmiş arşivine kayıt yazar
  ///
  /// Her kayıt hesabın geçmiş anahtarıyla şifrelidir (sunucu çözemez).
  /// Yalnızca eşleştirilmiş cihaz yazar (`e2e-not-paired`, 409);
  /// `history_key_version` güncel olmalı (`e2e-history-key-stale`, 409).
  /// Taraf olmadığınız ya da silinmiş mesajlar atlanır, var olan kayıt
  /// değişmez; `accepted_message_ids` artık kaydınız olan mesajlardır.
  /// Çağrı başına 1–50 kayıt, kayıt 1 B – 32 KiB; gövde en fazla 2,5 MiB.
  /// Hız sınırı: kullanıcı başına dakikada 120.
  ///
  /// `POST /v1/me/e2e/archive`
  Future<E2EArchiveWritten> putE2EArchiveEntries({
    required E2EArchiveWrite body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/archive',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EArchiveWritten.fromJson(
      jsonObject(response, 'putE2EArchiveEntries'),
    );
  }

  /// Tüm geçmiş arşivinizi siler
  ///
  /// Karşı tarafların arşivi etkilenmez.
  ///
  /// `DELETE /v1/me/e2e/archive`
  Future<void> deleteE2EArchive() async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/e2e/archive',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Yeni geçmiş anahtarını bildirir (ilk cihaz)
  ///
  /// Hesabın eşleştirilmiş cihazı yoksa bu cihaz yeni bir geçmiş anahtarı
  /// üretir ve bunu çağırır: sürüm bir artar, cihaz eşleştirilmiş olur.
  /// Eski arşiv bu cihaz için okunamaz; kullanıcıya söyleyin.
  /// Eşleştirilmiş başka cihaz varsa `e2e-paired-device-exists` (409; QR
  /// ile eşleşin). Zaten eşleştirilmiş cihaz güncel sürümü alır.
  ///
  /// `POST /v1/me/e2e/history-key`
  Future<E2EHistoryKeyVersion> claimE2EHistoryKey() async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/history-key',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EHistoryKeyVersion.fromJson(
      jsonObject(response, 'claimE2EHistoryKey'),
    );
  }

  /// Geçmiş anahtarını yeniler
  ///
  /// Eşleştirilmiş bir cihaz, yenileme gerektiğinde (eşleştirilmiş bir
  /// cihaz kaldırıldı; `rotation_needed`) yeni anahtarı üretir ve
  /// **diğer tüm** eşleştirilmiş cihazlara birer paylaşım gönderir
  /// (paylaşım 1 B – 16 KiB). `history_key_version` güncel sürümün bir
  /// fazlası olmalı (`e2e-history-key-stale`, 409); paylaşımlar kümesi
  /// tutmazsa `e2e-devices-changed` (409). Alan cihazlara WebSocket
  /// `e2e.history_key_shared` gider.
  ///
  /// `POST /v1/me/e2e/history-key/rotate`
  Future<void> rotateE2EHistoryKey({
    required E2EHistoryKeyRotation body,
  }) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/history-key/rotate',
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bu cihazı bekleyen geçmiş anahtarı paylaşımları
  ///
  /// En eski önce, en fazla 100. Onaylanmayan 30 gün sonra silinir.
  ///
  /// `GET /v1/me/e2e/history-key-shares`
  Future<E2EHistoryKeyShareList> listE2EHistoryKeyShares() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/e2e/history-key-shares',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EHistoryKeyShareList.fromJson(
      jsonObject(response, 'listE2EHistoryKeyShares'),
    );
  }

  /// Alınan paylaşımları onaylar (siler)
  ///
  /// `POST /v1/me/e2e/history-key-shares/ack`
  Future<void> ackE2EHistoryKeyShares({required E2EShareAck body}) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/history-key-shares/ack',
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// QR eşleştirme isteği açar (yeni cihaz)
  ///
  /// Eşleştirilmemiş cihaz açar (eşleştirilmişse `e2e-already-paired`,
  /// 409). 10 dakika yaşar; cihazın önceki isteğinin yerine geçer. QR'ı
  /// istemci üretir: istek kimliği, bu iş için üretilen açık anahtar ve
  /// tek kullanımlık doğrulama kodu. Sunucu QR'ın hiçbir parçasını
  /// saklamaz.
  ///
  /// `POST /v1/me/e2e/link-requests`
  Future<E2ELinkRequestCreated> createE2ELinkRequest() async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/link-requests',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2ELinkRequestCreated.fromJson(
      jsonObject(response, 'createE2ELinkRequest'),
    );
  }

  /// Bu cihazın eşleştirme isteği ve cevabı
  ///
  /// Yalnızca isteği açan cihaz okur; başkasınınki ve süresi dolmuş
  /// cevapsız istek `e2e-link-request-not-found` (404).
  ///
  /// `GET /v1/me/e2e/link-requests/{link_request_id}`
  Future<E2ELinkRequest> getE2ELinkRequest({
    required String linkRequestId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/e2e/link-requests/{link_request_id}',
      pathParams: {'link_request_id': linkRequestId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2ELinkRequest.fromJson(jsonObject(response, 'getE2ELinkRequest'));
  }

  /// Eşleştirme isteğini cevaplar (eşleştirilmiş cihaz)
  ///
  /// QR'ı okutan, aynı hesabın eşleştirilmiş cihazı geçmiş anahtarlarını
  /// yeni cihazın açık anahtarıyla şifreleyip gönderir (1 B – 16 KiB);
  /// `history_key_version` güncel olmalı. Başka hesabın, süresi dolmuş,
  /// cevaplanmış ya da bilinmeyen istek `e2e-link-request-not-found`
  /// (404). Yeni cihaza WebSocket `e2e.link_answered` gider.
  ///
  /// `POST /v1/me/e2e/link-requests/{link_request_id}/answer`
  Future<void> answerE2ELinkRequest({
    required String linkRequestId,
    required E2ELinkAnswer body,
  }) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/link-requests/{link_request_id}/answer',
      pathParams: {'link_request_id': linkRequestId},
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Eşleştirmeyi tamamlar (yeni cihaz)
  ///
  /// Yeni cihaz cevabı çözdükten sonra çağırır: cihaz eşleştirilmiş olur,
  /// istek silinir. Arada anahtar yenilendiyse `e2e-history-key-stale`
  /// (409); yeni istek açın.
  ///
  /// `POST /v1/me/e2e/link-requests/{link_request_id}/complete`
  Future<E2EDevice> completeE2ELinkRequest({
    required String linkRequestId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/e2e/link-requests/{link_request_id}/complete',
      pathParams: {'link_request_id': linkRequestId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EDevice.fromJson(jsonObject(response, 'completeE2ELinkRequest'));
  }

  /// Kendi referans kodunuz ve katılım geçmişi görünürlüğünüz
  ///
  /// `GET /v1/me/account`
  Future<Account> getAccount() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/account',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Account.fromJson(jsonObject(response, 'getAccount'));
  }

  /// Katılım geçmişinin kime görüneceğini değiştirir
  ///
  /// `private`: yalnızca siz. `tayfa` (varsayılan): arkadaşlar tümünü,
  /// ortak tayfa üyeleri son 14 gün hariç. `public`: arkadaşlar tümünü,
  /// diğer herkes son 14 gün hariç.
  ///
  /// `PATCH /v1/me/account`
  Future<Account> updateAccount({required AccountUpdate body}) async {
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/me/account',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Account.fromJson(jsonObject(response, 'updateAccount'));
  }

  /// Yeni referans kodu üretir; eski kod ve linki hemen geçersiz olur
  ///
  /// `POST /v1/me/referral-code`
  Future<ReferralCode> rotateReferralCode() async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/referral-code',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ReferralCode.fromJson(jsonObject(response, 'rotateReferralCode'));
  }

  /// Arkadaşlarınız (yalnızca size görünür)
  ///
  /// `GET /v1/me/friends`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<FriendList> listFriends({int? pageSize, String? pageToken}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/friends',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return FriendList.fromJson(jsonObject(response, 'listFriends'));
  }

  /// Arkadaşlığı bitirir, isteğinizi geri çeker ya da gelen isteği reddeder
  ///
  /// Karşı tarafa bildirilmez. Silinecek bir şey yoksa da başarılıdır.
  ///
  /// `DELETE /v1/me/friends/{user_id}`
  Future<void> removeFriendship({required String userId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/friends/{user_id}',
      pathParams: {'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Size gelen (`incoming`, varsayılan) ya da gönderdiğiniz (`outgoing`) istekler
  ///
  /// `GET /v1/me/friend-requests`
  ///
  /// [direction]: Kısıtlar: varsayılan (sunucu): `incoming`.
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<FriendList> listFriendRequests({
    ListFriendRequestsDirection? direction,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/friend-requests',
      query: {
        if (direction != null) 'direction': direction.wire,
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return FriendList.fromJson(jsonObject(response, 'listFriendRequests'));
  }

  /// Arkadaşlık isteği gönderir
  ///
  /// Karşı tarafın size isteği zaten bekliyorsa kabul edilir (`state:
  /// friends`). Günde 20 istek; reddedilenler de sayılır
  /// (`friend-request-limit`). Engel varsa (iki yönden biri) kullanıcı
  /// bilinmeyen gibi görünür (`user-not-found`).
  ///
  /// `POST /v1/me/friend-requests`
  Future<Friend> sendFriendRequest({required UserRef body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/friend-requests',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Friend.fromJson(jsonObject(response, 'sendFriendRequest'));
  }

  /// Bu kullanıcının size gönderdiği isteği kabul eder
  ///
  /// `POST /v1/me/friend-requests/{user_id}/acceptance`
  Future<Friend> acceptFriendRequest({required String userId}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/friend-requests/{user_id}/acceptance',
      pathParams: {'user_id': userId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Friend.fromJson(jsonObject(response, 'acceptFriendRequest'));
  }

  /// Engellediğiniz kullanıcılar (sizi engelleyenler hiç listelenmez)
  ///
  /// `GET /v1/me/blocks`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<BlockedUserList> listBlockedUsers({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/blocks',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return BlockedUserList.fromJson(jsonObject(response, 'listBlockedUsers'));
  }

  /// Kullanıcıyı engeller; arkadaşlık ve bekleyen istek silinir
  ///
  /// `PUT /v1/me/blocks/{user_id}`
  Future<void> blockUser({required String userId}) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/me/blocks/{user_id}',
      pathParams: {'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Engeli kaldırır; arkadaşlık geri gelmez
  ///
  /// `DELETE /v1/me/blocks/{user_id}`
  Future<void> unblockUser({required String userId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/blocks/{user_id}',
      pathParams: {'user_id': userId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Size gelen cevaplanmamış davetler, yeniden eskiye
  ///
  /// `GET /v1/me/invitations`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<InvitationList> listMyInvitations({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/invitations',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return InvitationList.fromJson(jsonObject(response, 'listMyInvitations'));
  }

  /// Daveti reddeder; davet edene bildirilmez
  ///
  /// `DELETE /v1/me/invitations/{tayfa_id}`
  Future<void> declineInvitation({required String tayfaId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/invitations/{tayfa_id}',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Daveti kabul eder
  ///
  /// Tayfa açık katılımlıysa ya da davet eden şu an moderatör veya
  /// yöneticiyse üyelik etkin olur; değilse onay bekler.
  ///
  /// `POST /v1/me/invitations/{tayfa_id}/acceptance`
  Future<Membership> acceptInvitation({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/invitations/{tayfa_id}/acceptance',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Membership.fromJson(jsonObject(response, 'acceptInvitation'));
  }

  /// Hazır avatar yüklemenizi avatarınız yapar
  ///
  /// `purpose: avatar` ile açılıp `ready` olmuş kendi yüklemeniz. identity
  /// yüklemeyi core'a sizin token'ınızla doğrulatır: başkasının, hazır
  /// olmayan ya da başka amaçlı yükleme `upload-not-found` /
  /// `upload-not-ready` / `upload-in-use` döner. Eski avatar silinir.
  /// Diğer kullanıcılar yeni avatarı kısa süre sonra görür (profil
  /// kopyaları olayla güncellenir).
  ///
  /// `PUT /v1/me/avatar`
  Future<AvatarView> putAvatar({required AvatarRequest body}) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/me/avatar',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return AvatarView.fromJson(jsonObject(response, 'putAvatar'));
  }

  /// Avatarı kaldırır (dosya silinir)
  ///
  /// `DELETE /v1/me/avatar`
  Future<void> deleteAvatar() async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/me/avatar',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// KVKK veri dışa aktarma talebi açar (30 günde bir)
  ///
  /// Verilerinizin bir kopyasını hazırlar (KVKK md. 11; ADR-0021).
  /// Toplama hemen, **sizin erişim token'ınızla** başlar: talepten hemen
  /// önce token'ı yenileyin; süresi bir dakikadan az kalmışsa `401` döner,
  /// yenileyip tekrar deneyin. Yanıt `202` ve `pending` ya da
  /// `processing` durumudur; hazır olunca `data_export_ready` bildirimi
  /// gelir. Durumu `GET /v1/me/data-exports/{data_export_id}` ile de
  /// yoklayabilirsiniz.
  ///
  /// 30 günde bir talep açılabilir (`429 data-export-limit`); başarısız
  /// talepler sayılmaz. Aynı anda tek talep (`409 data-export-in-progress`).
  /// Bir sonraki talep zamanı ve süren talep `GET /v1/me/data-exports`
  /// yanıtındadır. Aynı `client_request_id` ile tekrar aynı talebi döner.
  ///
  /// İçerik: profil (doğum tarihi dahil), giriş kimlikleri, cihazlar,
  /// onaylar, üyelikler, katılımlar, yazdığınız içerikler (duyuru,
  /// etkinlik, soru, cevap, kanal mesajları, av kayıtları), kendi anket
  /// oylarınız (gizli anket dahil), arkadaşlıklar, engellemeler,
  /// şikâyetleriniz ve yüklediğiniz dosyaların listesi. Birebir mesajlar
  /// girmez (uçtan uca şifreli; uygulama cihazda dışa aktarır). Dosyaların
  /// kendisi girmez; kendi dosyalarınızı `POST /v1/media/urls` ile
  /// indirebilirsiniz. Alanlar: `docs/data-export-format.md`.
  ///
  /// Depolama veya anahtar yapılandırılmamışsa `503 unavailable`.
  ///
  /// `POST /v1/me/data-exports`
  Future<DataExport> createDataExport({required DataExportRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/data-exports',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DataExport.fromJson(jsonObject(response, 'createDataExport'));
  }

  /// Son 30 günün dışa aktarma talepleri, yeniden eskiye
  ///
  /// `GET /v1/me/data-exports`
  Future<DataExportList> listDataExports() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/data-exports',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DataExportList.fromJson(jsonObject(response, 'listDataExports'));
  }

  /// Bir dışa aktarma talebiniz
  ///
  /// Başkasının talebi `404 data-export-not-found` döner.
  ///
  /// `GET /v1/me/data-exports/{data_export_id}`
  Future<DataExport> getDataExport({required String dataExportId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/data-exports/{data_export_id}',
      pathParams: {'data_export_id': dataExportId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DataExport.fromJson(jsonObject(response, 'getDataExport'));
  }

  /// Hazır dışa aktarmanın indirme linki ve anahtarı
  ///
  /// Son 10 dakika içinde sağlayıcıyla (Google/Apple) giriş yapılmış
  /// olmalıdır (hesap silmedeki kural); yenilenmiş token yetmez, değilse
  /// `403 reauthentication-required`. Link 5 dakika geçerlidir; dosya
  /// şifrelidir ve `key` ile cihazda çözülür (`format: aes-256-gcm-v1`):
  /// bayt 0 = `0x01`, bayt 1–12 nonce, kalanı AES-256-GCM şifreli metin
  /// ve sondaki 16 baytlık etiket; ek veri (AAD) `tayfam/data-export/v1/`
  /// ve talep kimliğinin 16 baytı. Çözülen içerik bir zip'tir. Link ve
  /// anahtar saklanmaz, log'a yazılmaz; yanıt önbelleğe alınmaz.
  /// Hazır değilse `409 data-export-not-ready`, 7 gün dolduysa
  /// `410 data-export-expired`.
  ///
  /// `POST /v1/me/data-exports/{data_export_id}/download`
  Future<DataExportDownload> downloadDataExport({
    required String dataExportId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/data-exports/{data_export_id}/download',
      pathParams: {'data_export_id': dataExportId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DataExportDownload.fromJson(
      jsonObject(response, 'downloadDataExport'),
    );
  }

  /// Yaptığınız şikâyetler, yeniden eskiye
  ///
  /// `GET /v1/me/reports`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<MyReportList> listMyReports({int? pageSize, String? pageToken}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/reports',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MyReportList.fromJson(jsonObject(response, 'listMyReports'));
  }

  /// Bir birebir mesajı şikâyet eder (yalnızca platforma gider)
  ///
  /// Tayfaya ait olmayan şikâyetler için; şimdilik yalnızca
  /// `target_type: dm_message`. `target_id` mesajın kimliğidir. Mesajın
  /// konuşmasının tarafı olmalısınız (reddettiğiniz istek dahil; silinmiş
  /// mesaj da olur); kendi mesajınız, bilinmeyen mesaj ve göndereni
  /// hesabını silmiş mesaj `report-target-not-found`.
  ///
  /// `evidence_text` zorunludur (1–2000 karakter): mesajın metnini kendi
  /// cihazınızdan bilinçli olarak paylaşırsınız; sunucu mesaj içeriğini
  /// şikâyete kendisi eklemez (uçtan uca şifreleme aşamasında göremeyecek).
  /// Bu metin yalnızca platform tarafından okunur, size de geri dönmez.
  ///
  /// Şikâyet hiçbir tayfanın moderasyon kuyruğuna düşmez; oluşturulduğu
  /// anda platforma gider. Öncelik kuralı aynıdır (sizden ya da
  /// göndericiden biri 18 yaş altıysa öne geçer; yaş gösterilmez).
  /// `staff_conduct` geçerli değildir. Aynı mesajı ikinci kez şikâyet
  /// etmek ilk şikâyetinizi `200` ile döndürür; 24 saatte en fazla 20
  /// şikâyet (`report-limit`, tüm şikâyetlerle birlikte).
  ///
  /// `POST /v1/me/reports`
  Future<MyReport> createDirectMessageReport({
    required ReportCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/me/reports',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MyReport.fromJson(jsonObject(response, 'createDirectMessageReport'));
  }

  /// Yaptığınız bir şikâyet
  ///
  /// `report_resolved` bildiriminin hedefidir. Tayfadan ayrılmış olsanız da
  /// döner. Başkasının şikâyeti `report-not-found` döner.
  ///
  /// `GET /v1/me/reports/{report_id}`
  Future<MyReport> getMyReport({required String reportId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/reports/{report_id}',
      pathParams: {'report_id': reportId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MyReport.fromJson(jsonObject(response, 'getMyReport'));
  }
}
