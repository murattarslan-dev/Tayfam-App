import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/notification_preferences_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Birebir konuşmaların bildirim tercihi uçları (sessize alma; Tayfam-Api
/// ADR-0019 §3). Yalnızca üretilmiş uç sınıfını kullanır; bütün istekler
/// tek `ApiClient`'tan geçer (ADR-0005). Sessize alma bildirimleri
/// listeden gizlemez; yalnızca anlık bildirim (push) gitmez.
final class SessizDeposu {
  SessizDeposu(ApiTransport istemci)
    : _api = NotificationPreferencesApi(istemci);

  final NotificationPreferencesApi _api;

  /// `GET /v1/notification-preferences`: kullanıcının bütün tercihleri
  /// (tayfa ve konuşma). Tercihi olmayan konuşma `all`'dur.
  Future<List<NotificationPreference>> tercihler() async =>
      (await _api.listNotificationPreferences()).preferences;

  /// `PUT /v1/notification-preferences/conversations/{conversation_id}`:
  /// konuşmayı `none` seviyesine alır; [bitis] verilirse o ana kadar
  /// (sözleşme: en çok bir yıl), verilmezse süresiz. Birebir konuşmada
  /// `mentions` yoktur.
  Future<NotificationPreference> sessizeAl(
    String konusmaId, {
    DateTime? bitis,
  }) => _api.setConversationNotificationPreference(
    conversationId: konusmaId,
    body: ConversationNotificationPreferenceRequest(
      level: ConversationNotificationPreferenceRequestLevel.none,
      muteUntil: bitis,
    ),
  );

  /// `DELETE /v1/notification-preferences/conversations/{conversation_id}`:
  /// konuşmayı varsayılana (`all`) döndürür.
  Future<void> sesiAc(String konusmaId) =>
      _api.resetConversationNotificationPreference(conversationId: konusmaId);
}

/// Konuşma bildirim tercihi uçlarının deposu.
final sessizDeposuProvider = Provider<SessizDeposu>(
  (ref) => SessizDeposu(ref.watch(apiClientProvider)),
  name: 'sessizDeposuProvider',
);
