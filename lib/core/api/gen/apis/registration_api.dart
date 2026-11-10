// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `registration` olan uçlar.
final class RegistrationApi {
  const RegistrationApi(this._transport);

  final ApiTransport _transport;

  /// Onaylanacak belge sürümleri ve yaş sınırı
  ///
  /// `GET /v1/registration/requirements`
  Future<RegistrationRequirements> getRegistrationRequirements() async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/registration/requirements',
      expect: ResponseKind.json,
    );
    return RegistrationRequirements.fromJson(
      jsonObject(response, 'getRegistrationRequirements'),
    );
  }

  /// Kaydı tamamlar (doğum tarihi, onaylar, ad)
  ///
  /// Başarılı olunca istemci `/v1/auth/refresh` çağırır ve tam erişim
  /// token'ı alır. Yaş sınırının altındaki bir doğum tarihi hesabı kalıcı
  /// olarak kapatır (`age-blocked`) ve oturumları sonlandırır.
  ///
  /// `POST /v1/registration`
  Future<void> completeRegistration({required RegistrationRequest body}) async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/registration',
      body: body.toJson(),
      expect: ResponseKind.none,
    );
  }
}
