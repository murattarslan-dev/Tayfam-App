// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `event-series` olan uçlar.
final class EventSeriesApi {
  const EventSeriesApi(this._transport);

  final ApiTransport _transport;

  /// Tekrarlayan serinin kuralı
  ///
  /// Her etkin üyeye açıktır. Bilinmeyen seri `event-series-not-found`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/event-series/{series_id}`
  Future<EventSeries> getEventSeries({
    required String tayfaId,
    required String seriesId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/event-series/{series_id}',
      pathParams: {'tayfa_id': tayfaId, 'series_id': seriesId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventSeries.fromJson(jsonObject(response, 'getEventSeries'));
  }

  /// Seriyi bitirir (seriyi açan, moderatör, yönetici)
  ///
  /// Yeni etkinlik açılmaz; serinin başlamamış, planlı ve ayrıca
  /// düzenlenmemiş etkinlikleri iptal edilir. Bitmiş seri
  /// `event-series-ended` alır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/event-series/{series_id}/ending`
  Future<EventSeriesEnding> endEventSeries({
    required String tayfaId,
    required String seriesId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/event-series/{series_id}/ending',
      pathParams: {'tayfa_id': tayfaId, 'series_id': seriesId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return EventSeriesEnding.fromJson(jsonObject(response, 'endEventSeries'));
  }
}
