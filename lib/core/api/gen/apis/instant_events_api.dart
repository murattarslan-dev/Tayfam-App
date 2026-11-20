// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `instant-events` olan uçlar.
final class InstantEventsApi {
  const InstantEventsApi(this._transport);

  final ApiTransport _transport;

  /// Anlık (bireysel) etkinlik açar; arka planda gizli bir tayfa açılır
  ///
  /// Tek istekte gizli, tek etkinlikli bir tayfa (`kind: instant`) ve
  /// etkinliği açılır; açan kişi tayfanın tek yöneticisi ve etkinliğin
  /// organizatörüdür (ADR-0032). Yalnızca etkinlik modülü açıktır.
  /// `invitee_user_ids`'deki kişiler doğrudan davet edilir; hepsi
  /// arkadaşınız olmalıdır (`not-friends`), biri davet edilemezse hiçbir
  /// şey açılmaz. Aynı anda en fazla 3 açık anlık etkinlik (bitmemiş,
  /// iptal edilmemiş) ve 24 saatte en fazla 5 anlık etkinlik (iptal
  /// edilenler de sayılır); ikisi de `instant-event-limit`. Tayfa açma sınırlarına
  /// sayılmaz. `event` alanının kuralları `POST
  /// /v1/tayfas/{tayfa_id}/events` ile aynıdır; `recurrence` ve
  /// `cover_upload_id` kabul edilmez (kapak sonra etkinlik
  /// düzenlemesiyle eklenir), `discoverable` `true` olamaz (sonradan da). Aynı `event.client_request_id` ile tekrar
  /// gönderim ilk açılanı döndürür. `event.starts_now` ile anlık
  /// etkinlik şimdi başlar (ADR-0038 §1); açık şimdi etkinliği hem bu
  /// sınıra hem kişi başı 1 açık şimdi etkinliği sınırına
  /// (`now-limit-reached`) sayılır.
  ///
  /// Etkinlik bitince (iptalde iptal anından) 7 gün sonra tayfa
  /// arşivlenir. Davet linkiyle gelen her zaman katılım isteği bırakır,
  /// organizatör onaylar; katılım koduyla katılım yoktur. Etkinlik
  /// kanalını istemci `POST /v1/tayfas/{tayfa_id}/channels`
  /// (`visibility: event`) ile açar.
  ///
  /// `POST /v1/instant-events`
  Future<InstantEvent> createInstantEvent({
    required InstantEventCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/instant-events',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return InstantEvent.fromJson(jsonObject(response, 'createInstantEvent'));
  }
}
