// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `notifications` olan uçlar.
final class NotificationsApi {
  const NotificationsApi(this._transport);

  final ApiTransport _transport;

  /// Bildirimlerinizi listeler (uygulama içi, en yeni önce)
  ///
  /// Yalnızca kendi bildirimleriniz. Bildirim içerik metni taşımaz:
  /// tür, tayfa, işlemi yapan ve hedefin kimliği vardır; istemci içeriği
  /// ilgili uçtan (duyuru, etkinlik, cevap…) çeker. Yalnızca etkin
  /// üyesi olduğunuz tayfaların bildirimleri üretilir; kendi yaptığınız
  /// işlem için bildirim gelmez. Sessize aldığınız tayfanın bildirimleri
  /// de listede görünür. Bildirimler 90 gün saklanır.
  ///
  /// `GET /v1/notifications`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<NotificationList> listNotifications({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/notifications',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return NotificationList.fromJson(jsonObject(response, 'listNotifications'));
  }

  /// Okunmamış bildirim sayısı (en fazla 1000)
  ///
  /// `GET /v1/notifications/unread-count`
  Future<UnreadNotificationCount> getUnreadNotificationCount() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/notifications/unread-count',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return UnreadNotificationCount.fromJson(
      jsonObject(response, 'getUnreadNotificationCount'),
    );
  }

  /// Tüm bildirimlerinizi okundu işaretler
  ///
  /// `POST /v1/notifications/read-all`
  Future<void> markAllNotificationsRead() async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/notifications/read-all',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bir bildirimi okundu işaretler
  ///
  /// Tekrar çağrılırsa ilk okunma zamanı korunur. Başka bir kullanıcının
  /// bildirimi, olmayan bir bildirimle aynı cevabı alır
  /// (`notification-not-found`).
  ///
  /// `PUT /v1/notifications/{notification_id}/read`
  Future<void> markNotificationRead({required String notificationId}) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/notifications/{notification_id}/read',
      pathParams: {'notification_id': notificationId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
