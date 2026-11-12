// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `users` olan uçlar.
final class UsersApi {
  const UsersApi(this._transport);

  final ApiTransport _transport;

  /// Bir kullanıcının E2E cihazları (açık kimlik anahtarlarıyla)
  ///
  /// Güvenlik kodu ve zarf adresleme için. Kullanıcının kendisi, onunla
  /// görünür bir konuşması olan ya da ona yazabilecek kişi görür; diğerleri
  /// `direct-message-not-allowed` (403).
  ///
  /// `GET /v1/users/{user_id}/e2e/devices`
  Future<E2EPublicDeviceList> listE2EDevices({required String userId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/e2e/devices',
      pathParams: {'user_id': userId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EPublicDeviceList.fromJson(jsonObject(response, 'listE2EDevices'));
  }

  /// Bir kullanıcının anahtar olayları ("güvenlik kodu değişti")
  ///
  /// En yeni önce; 90 gün tutulur. İzin cihaz listesiyle aynı.
  ///
  /// `GET /v1/users/{user_id}/e2e/key-events`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<E2EKeyEventList> listE2EKeyEvents({
    required String userId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/e2e/key-events',
      pathParams: {'user_id': userId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EKeyEventList.fromJson(jsonObject(response, 'listE2EKeyEvents'));
  }

  /// Ön anahtar paketlerini çeker (tek kullanımlık anahtarları tüketir)
  ///
  /// Kullanıcının her cihazı (ya da yalnızca `device_ids`) için bir paket;
  /// her cihazdan bir tek kullanımlık EC ve bir tek kullanımlık Kyber ön
  /// anahtarı alınır ve silinir: aynı anahtar eşzamanlı çekmelerde de iki
  /// kişiye verilmez. Tek kullanımlık Kyber kalmadıysa son çare Kyber
  /// (`kyber_last_resort: true`), EC kalmadıysa paket EC'siz döner.
  /// Bu oturumun kendi cihazı hiçbir zaman dönmez.
  ///
  /// Yalnızca kendi diğer cihazlarınız için ya da o an bu kişiye mesaj
  /// **gönderebiliyorsanız**: gönderimle aynı kurallar
  /// (`direct-message-not-allowed` 403, `message-request-pending` 409,
  /// `message-request-limit` 429). Hız sınırı: kullanıcı başına dakikada
  /// 20 (`rate-limited`).
  ///
  /// `POST /v1/users/{user_id}/e2e/prekey-bundles`
  Future<E2EPreKeyBundleList> claimE2EPreKeyBundles({
    required String userId,
    required E2EBundleRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/users/{user_id}/e2e/prekey-bundles',
      pathParams: {'user_id': userId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EPreKeyBundleList.fromJson(
      jsonObject(response, 'claimE2EPreKeyBundles'),
    );
  }

  /// Bir kullanıcının profili (ad, avatar, ortak tayfalar)
  ///
  /// Ad ve avatar, ortak tayfanız ya da arkadaşlığınız olmasa da her
  /// kullanıcı için döner; bildirimlerdeki `actor_id` ve `target_id`
  /// (ör. `friend_request`, `tayfa_invitation`) kişinin adı bu uçtan
  /// alınır. Bildirimler isim taşımaz.
  /// Ortak tayfalar yalnızca ikinizin de etkin üyesi olduğu tayfalardır.
  /// Engel varsa (iki yönden biri) ya da hesap silinmişse `user-not-found`,
  /// var olmayan kullanıcıyla aynı cevap.
  ///
  /// `GET /v1/users/{user_id}/profile`
  Future<UserProfile> getUserProfile({required String userId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/profile',
      pathParams: {'user_id': userId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return UserProfile.fromJson(jsonObject(response, 'getUserProfile'));
  }

  /// Kullanıcının katılım geçmişi, görünürlük ayarına göre
  ///
  /// Arkadaşlar tümünü görür; ortak tayfa üyeleri (`tayfa`, `public`) ve
  /// diğerleri (`public`) son 14 günü göremez; `private` yalnızca kişinin
  /// kendisine görünür. Görmeye yetkiniz yoksa liste boş döner. Tayfa,
  /// etkinlik ve süre yalnızca o tayfanın etkin üyelerine doludur.
  ///
  /// `GET /v1/users/{user_id}/activity`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<ActivityList> listUserActivity({
    required String userId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/activity',
      pathParams: {'user_id': userId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ActivityList.fromJson(jsonObject(response, 'listUserActivity'));
  }
}
