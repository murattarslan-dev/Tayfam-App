// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `users` olan uçlar.
final class UsersApi {
  const UsersApi(this._transport);

  final ApiTransport _transport;

  /// Bir kullanıcının profili (ad, avatar, ortak tayfalar)
  ///
  /// Ortak tayfalar yalnızca ikinizin de etkin üyesi olduğu tayfalardır.
  /// Engel varsa (iki yönden biri) `user-not-found`, var olmayan kullanıcıyla
  /// aynı cevap.
  ///
  /// `GET /v1/users/{user_id}/profile`
  Future<UserProfile> getUserProfile({required String userId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/profile',
      pathParams: {'user_id': userId},
      expect: ResponseKind.json,
    );
    return UserProfile.fromJson(jsonObject(response, 'getUserProfile'));
  }

  /// Kullanıcının katılım geçmişi, görünürlük ayarına göre
  ///
  /// Arkadaşlar tümünü görür; ortak tayfa üyeleri (`tayfa`, `public`) ve
  /// diğerleri (`public`) son 14 günü göremez; `private` yalnızca kişinin
  /// kendisine görünür. Görmeye yetkiniz yoksa liste boş döner. Tayfa,
  /// etkinlik ve süre yalnızca o tayfanın etkin üyelerine doludur.
  ///
  /// `GET /v1/users/{user_id}/activity`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<ActivityList> listUserActivity({
    required String userId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/users/{user_id}/activity',
      pathParams: {'user_id': userId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
    );
    return ActivityList.fromJson(jsonObject(response, 'listUserActivity'));
  }
}
