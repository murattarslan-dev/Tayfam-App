// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `auth` olan uçlar.
final class AuthApi {
  const AuthApi(this._transport);

  final ApiTransport _transport;

  /// Google (ileride Apple) ID token'ı ile giriş
  ///
  /// Kullanıcı yoksa oluşturulur ve kayıt bekler (`registration_pending`).
  /// Bu durumdaki erişim token'ı yalnızca `/v1/registration` uçlarına
  /// geçer (ADR-0012). Token'lar gövdede döner; çerez yazılmaz.
  /// `platform: web` yalnızca prod dışında kabul edilir; prod'da
  /// `invalid-request` (400). Platform genelinde askıdaki veya banlı hesap
  /// `account-sanctioned` (403) alır; token yenileme de aynı cevabı verir.
  ///
  /// `POST /v1/auth/sign-in`
  ///
  /// Kimlik doğrulaması gerektirmez (`security: []`).
  Future<Session> signIn({required SignInRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/auth/sign-in',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: false,
    );
    return Session.fromJson(jsonObject(response, 'signIn'));
  }

  /// Refresh token ile yeni token çifti
  ///
  /// Refresh token her kullanımda yenilenir; eski token geçersiz olur.
  /// Kullanılmış bir token tekrar gelirse oturum tamamen kapanır.
  /// Refresh token yalnızca gövdede gelir; çerez okunmaz ve yazılmaz.
  ///
  /// `POST /v1/auth/refresh`
  ///
  /// Kimlik doğrulaması gerektirmez (`security: []`).
  Future<Session> refresh({required RefreshRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/auth/refresh',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: false,
    );
    return Session.fromJson(jsonObject(response, 'refresh'));
  }

  /// Bu cihazdaki oturumu kapatır
  ///
  /// `POST /v1/auth/sign-out`
  Future<void> signOut() async {
    await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/auth/sign-out',
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
