// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `client-config` olan uçlar.
final class ClientConfigApi {
  const ClientConfigApi(this._transport);

  final ApiTransport _transport;

  /// Desteklenen istemci sürümleri
  ///
  /// Platform başına en düşük desteklenen ve en son sürüm (issue #114,
  /// ADR-0016). İstemci açılışta, girişten önce çağırır; kendi sürümü
  /// `min_supported_version`'ın altındaysa kullanıcıyı mağazaya
  /// yönlendirir. Token istemez, kişisel veri döndürmez; herkese aynı
  /// cevap. Bir platformda değer yapılandırılmamışsa alan yoktur
  /// (`min_supported_version` yoksa o platformda zorlama yoktur). IP
  /// başına hız sınırı vardır (`rate-limited`). Sürüm başlığına
  /// bakılmaz; eski sürüm de bu ucu her zaman çağırabilir.
  ///
  /// `GET /v1/client-config`
  ///
  /// Kimlik doğrulaması gerektirmez (`security: []`).
  Future<ClientConfig> getClientConfig() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/client-config',
      expect: ResponseKind.json,
      authenticated: false,
    );
    return ClientConfig.fromJson(jsonObject(response, 'getClientConfig'));
  }
}
