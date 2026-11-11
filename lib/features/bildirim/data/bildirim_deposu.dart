import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/notifications_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Bildirim listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int bildirimSayfaBoyutu = 30;

/// Uygulama içi bildirim uçları (ADR-0018 §3). Yalnızca üretilmiş uç
/// sınıfını kullanır; bütün istekler tek `ApiClient`'tan geçer (ADR-0005).
final class BildirimDeposu {
  BildirimDeposu(ApiTransport istemci) : _api = NotificationsApi(istemci);

  final NotificationsApi _api;

  /// `GET /v1/notifications`: en yeni önce. [sayfaToken] opaktır.
  Future<Sayfa<Notification>> sayfa({String? sayfaToken}) async {
    final liste = await _api.listNotifications(
      pageSize: bildirimSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.notifications, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/notifications/unread-count` (en fazla 1000).
  Future<int> okunmamisSayisi() async =>
      (await _api.getUnreadNotificationCount()).unreadCount;

  /// `PUT /v1/notifications/{notification_id}/read`.
  Future<void> okunduIsaretle(String bildirimId) =>
      _api.markNotificationRead(notificationId: bildirimId);

  /// `POST /v1/notifications/read-all`.
  Future<void> hepsiniOkunduSay() => _api.markAllNotificationsRead();
}

/// Bildirim uçlarının deposu.
final bildirimDeposuProvider = Provider<BildirimDeposu>(
  (ref) => BildirimDeposu(ref.watch(apiClientProvider)),
  name: 'bildirimDeposuProvider',
);
