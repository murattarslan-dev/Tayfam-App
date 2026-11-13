import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/notification_preferences_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Bildirim ayarları ekranının tercih uçları (Tayfam-Api ADR-0019 §3).
/// Yalnızca üretilmiş uç sınıfını kullanır; bütün istekler tek
/// `ApiClient`'tan geçer (ADR-0005). Sessize alma bildirimleri listeden
/// gizlemez; yalnızca anlık bildirim (push) gitmez.
final class BildirimTercihleriDeposu {
  BildirimTercihleriDeposu(ApiTransport istemci)
    : _api = NotificationPreferencesApi(istemci);

  final NotificationPreferencesApi _api;

  /// `GET /v1/notification-preferences`: tayfa ve konuşma tercihleri.
  /// Tercihi olmayan tayfa ya da konuşma `all`'dur.
  Future<List<NotificationPreference>> tercihler() async =>
      (await _api.listNotificationPreferences()).preferences;

  /// `DELETE /v1/notification-preferences/tayfas/{tayfa_id}`: tayfanın
  /// sesini açar (varsayılan `all`).
  Future<void> tayfaSesiniAc(String tayfaId) =>
      _api.resetTayfaNotificationPreference(tayfaId: tayfaId);
}

/// Bildirim tercihi uçlarının deposu.
final bildirimTercihleriDeposuProvider = Provider<BildirimTercihleriDeposu>(
  (ref) => BildirimTercihleriDeposu(ref.watch(apiClientProvider)),
  name: 'bildirimTercihleriDeposuProvider',
);
