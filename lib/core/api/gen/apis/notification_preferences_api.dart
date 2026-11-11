// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `notification-preferences` olan uçlar.
final class NotificationPreferencesApi {
  const NotificationPreferencesApi(this._transport);

  final ApiTransport _transport;

  /// Bildirim tercihleriniz (sessize alınanlar)
  ///
  /// Tercihi olmayan tayfa ya da konuşma için seviye `all`'dur.
  ///
  /// `GET /v1/notification-preferences`
  Future<NotificationPreferenceList> listNotificationPreferences() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/notification-preferences',
      expect: ResponseKind.json,
      authenticated: true,
    );
    return NotificationPreferenceList.fromJson(
      jsonObject(response, 'listNotificationPreferences'),
    );
  }

  /// Bir tayfayı sessize alır ya da seviyesini değiştirir
  ///
  /// Etkin üyesi olduğunuz tayfa için (`tayfa-not-found`). `mentions` ya da
  /// `none` isteğe bağlı olarak `mute_until`'e kadar sürer (en fazla bir
  /// yıl), sonra tayfa `all`'a döner. `all` ile `mute_until` verilemez;
  /// `all` tercihi kaldırır. Sessize alma bildirimleri listeden gizlemez;
  /// anlık bildirim (push) gönderiminde kullanılır.
  ///
  /// `PUT /v1/notification-preferences/tayfas/{tayfa_id}`
  Future<NotificationPreference> setTayfaNotificationPreference({
    required String tayfaId,
    required NotificationPreferenceRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/notification-preferences/tayfas/{tayfa_id}',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return NotificationPreference.fromJson(
      jsonObject(response, 'setTayfaNotificationPreference'),
    );
  }

  /// Tayfanın bildirim tercihini varsayılana (`all`) döndürür
  ///
  /// `DELETE /v1/notification-preferences/tayfas/{tayfa_id}`
  Future<void> resetTayfaNotificationPreference({
    required String tayfaId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/notification-preferences/tayfas/{tayfa_id}',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bir birebir konuşmayı sessize alır ya da seviyesini değiştirir
  ///
  /// Yalnızca tarafı olduğunuz ve gördüğünüz konuşma için (konuşmayı
  /// getiren uçla aynı kural); başka bir kullanıcının konuşması, olmayan
  /// bir konuşmayla aynı cevabı alır (`conversation-not-found`). Seviye
  /// yalnızca `all` ya da `none` olabilir: birebir mesaj bildirimleri
  /// kişisel olduğundan `mentions` anlamsızdır ve `invalid-request` döner.
  /// `none` isteğe bağlı olarak `mute_until`'e kadar sürer (en fazla bir
  /// yıl), sonra konuşma `all`'a döner; `all` ile `mute_until` verilemez;
  /// `all` tercihi kaldırır. Sessize alma bildirimleri listeden gizlemez; yalnızca anlık bildirim
  /// (push) gitmez. Konuşma ya da hesabınız silinince tercih de silinir.
  ///
  /// `PUT /v1/notification-preferences/conversations/{conversation_id}`
  Future<NotificationPreference> setConversationNotificationPreference({
    required String conversationId,
    required ConversationNotificationPreferenceRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate:
          '/v1/notification-preferences/conversations/{conversation_id}',
      pathParams: {'conversation_id': conversationId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return NotificationPreference.fromJson(
      jsonObject(response, 'setConversationNotificationPreference'),
    );
  }

  /// Konuşmanın bildirim tercihini varsayılana (`all`) döndürür
  ///
  /// `DELETE /v1/notification-preferences/conversations/{conversation_id}`
  Future<void> resetConversationNotificationPreference({
    required String conversationId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/notification-preferences/conversations/{conversation_id}',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
