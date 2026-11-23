// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `stats` olan uçlar.
final class StatsApi {
  const StatsApi(this._transport);

  final ApiTransport _transport;

  /// Tayfanın istatistikleri ve sizin katkınız
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur). `year` yoksa tüm
  /// zamanlar. Tayfa toplamları herkese açıktır; kişisel katkıdan
  /// yalnızca çağıranın kendi katkısı döner (`own_contributions`, ölçüm
  /// ve günlük metrikleri). Başka üyelerin katkısı yönetici ve moderatör
  /// dahil kimseye listelenmez (#322).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/stats`
  ///
  /// [year]: Europe/Istanbul takvim yılı (2000–2999); yoksa tüm zamanlar.
  ///
  /// Kısıtlar: minimum: 2000; maximum: 2999.
  Future<TayfaStats> getTayfaStats({required String tayfaId, int? year}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/stats',
      pathParams: {'tayfa_id': tayfaId},
      query: {if (year != null) 'year': '$year'},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return TayfaStats.fromJson(jsonObject(response, 'getTayfaStats'));
  }
}
