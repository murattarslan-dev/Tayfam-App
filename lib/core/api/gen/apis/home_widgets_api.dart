// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `home-widgets` olan uçlar.
final class HomeWidgetsApi {
  const HomeWidgetsApi(this._transport);

  final ApiTransport _transport;

  /// Ana sayfa düzeninin tamamı (ayarlar ekranı)
  ///
  /// Sunucunun bildiği her bileşen, kapalılar dahil, sırasıyla. Her etkin
  /// üyeye açıktır (susturulmuş üye de okur). Ana sayfanın kendisi
  /// `GET /v1/tayfas/{tayfa_id}` yanıtındaki `home_widgets`'tır.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/home-widgets`
  Future<HomeWidgetLayout> getHomeWidgets({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/home-widgets',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return HomeWidgetLayout.fromJson(jsonObject(response, 'getHomeWidgets'));
  }

  /// Ana sayfa düzenini değiştirir (yönetici)
  ///
  /// Bütün liste tek istekte: `GET` yanıtındaki her bileşen tam bir kez,
  /// yeni sırasıyla, açık/kapalı ve ayarıyla (kısmi güncelleme yok).
  /// Eksik, fazla ya da bilinmeyen anahtar `invalid-request` (alan
  /// `widgets`). Ayar gerektiren bileşen (`goal`, `countdown`,
  /// `log_summary`) ayarsız açılamaz; ayarı olmayan bileşen ayar almaz
  /// (alan `config`). Modülü kapalı bileşen açılabilir; modül açılınca
  /// görünür. Yalnızca yönetici; değişiklik denetim kaydına yazılır.
  /// Cevap yeni düzendir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/home-widgets`
  Future<HomeWidgetLayout> setHomeWidgets({
    required String tayfaId,
    required HomeWidgetLayoutInput body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/home-widgets',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return HomeWidgetLayout.fromJson(jsonObject(response, 'setHomeWidgets'));
  }

  /// Bir gösterim bileşeninin verisi
  ///
  /// `stats`, `goal`, `countdown`, `champions` ve `log_summary` için,
  /// ana sayfanın gösterdiği haliyle. Her etkin üyeye açıktır. Ana
  /// sayfanın göstermediği bileşen (kapalı, modülü kapalı, tarihi geçmiş
  /// geri sayım) ya da verisi kendi uçlarından okunan bileşen (bölümler,
  /// modül bileşenleri) `home-widget-not-found`. İstatistikler donmuş
  /// etkinliklerdendir (#266); hassas değer hiçbir yerde yoktur.
  /// Şampiyonlar yalnızca ilan edilmiş, kazananı olan ve kutlama
  /// bileşeninin üyelere gösterdiği kutlamalardır; en fazla 10, en yeni
  /// ilan önce.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/home-widgets/{widget_key}/data`
  ///
  /// [widgetKey]: Ana sayfa bileşeninin anahtarı (`stats`).
  ///
  /// Kısıtlar: pattern: `^[a-z][a-z0-9_]{1,39}$`.
  Future<HomeWidgetData> getHomeWidgetData({
    required String tayfaId,
    required String widgetKey,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/home-widgets/{widget_key}/data',
      pathParams: {'tayfa_id': tayfaId, 'widget_key': widgetKey},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return HomeWidgetData.fromJson(jsonObject(response, 'getHomeWidgetData'));
  }
}
