// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `referral-lookups` olan uçlar.
final class ReferralLookupsApi {
  const ReferralLookupsApi(this._transport);

  final ApiTransport _transport;

  /// Referans koduyla kullanıcı bulur (yalnızca kimlik, ad, avatar)
  ///
  /// Kod gövdededir; yol ve sorguda taşınmaz (erişim log'larına düşmez).
  /// Kullanıcı başına saatte 10 arama; bulunan, bulunamayan ve bozuk her
  /// deneme sayılır (`rate-limited`). Bulunamayan kod
  /// `referral-code-not-found`.
  ///
  /// `POST /v1/referral-lookups`
  Future<ReferredUser> lookupReferralCode({
    required ReferralLookupRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/referral-lookups',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ReferredUser.fromJson(jsonObject(response, 'lookupReferralCode'));
  }
}
