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
    );
  }

  /// Kendi referans kodunuz ve katılım geçmişi görünürlüğünüz
  ///
  /// `GET /v1/me/account`
  Future<Account> getAccount() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/me/account',
      expect: ResponseKind.json,
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
    );
    return Membership.fromJson(jsonObject(response, 'acceptInvitation'));
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
    );
    return MyReport.fromJson(jsonObject(response, 'getMyReport'));
  }
}
