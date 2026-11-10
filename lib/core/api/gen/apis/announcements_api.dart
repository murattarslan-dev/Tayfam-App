// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `announcements` olan uçlar.
final class AnnouncementsApi {
  const AnnouncementsApi(this._transport);

  final ApiTransport _transport;

  /// Duyuruları listeler
  ///
  /// Her etkin üyeye açıktır (susturulmuş üye de okur). Sıra: sabitlenenler
  /// önce, sonra yeniden eskiye. Tayfanın duyuru modülü kapalıysa
  /// `module-disabled`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/announcements`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<AnnouncementList> listAnnouncements({
    required String tayfaId,
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
    );
    return AnnouncementList.fromJson(jsonObject(response, 'listAnnouncements'));
  }

  /// Duyuru yayınlar (moderatör, yönetici)
  ///
  /// Aynı `client_request_id` ile tekrar gönderilen istek yeni duyuru
  /// açmaz, ilk duyuruyu döndürür.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/announcements`
  Future<Announcement> createAnnouncement({
    required String tayfaId,
    required AnnouncementCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'createAnnouncement'));
  }

  /// Tek bir duyuru
  ///
  /// `GET /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`
  Future<Announcement> getAnnouncement({
    required String tayfaId,
    required String announcementId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'getAnnouncement'));
  }

  /// Duyuruyu düzenler (moderatör, yönetici)
  ///
  /// Kendi duyurunuzu, ya da yazarın şu anki rolü sizinkinden düşükse
  /// başkasınınkini (`role-hierarchy`). Gövdede bulunan alanlar değişir.
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`
  Future<Announcement> updateAnnouncement({
    required String tayfaId,
    required String announcementId,
    required AnnouncementUpdateRequest body,
  }) async {
    final json = body.toJson();
    if (json.length < 1) {
      throw ArgumentError('AnnouncementUpdateRequest: en az 1 alan verilmeli');
    }
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      body: json,
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'updateAnnouncement'));
  }

  /// Duyuruyu siler (moderatör, yönetici)
  ///
  /// Kendi duyurunuzu silerseniz başlık ve gövde hemen boşaltılır, geri
  /// alınamaz. Başkasınınkini (hiyerarşi düzenlemedeki gibi) silmek onu
  /// gizler; yönetici 30 gün içinde geri alabilir.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/announcements/{announcement_id}`
  Future<void> deleteAnnouncement({
    required String tayfaId,
    required String announcementId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      expect: ResponseKind.none,
    );
  }

  /// Duyuruyu sabitler (moderatör, yönetici)
  ///
  /// Herhangi bir yazarın duyurusu sabitlenebilir. Zaten sabitse değişmez.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/announcements/{announcement_id}/pin`
  Future<Announcement> pinAnnouncement({
    required String tayfaId,
    required String announcementId,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}/pin',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'pinAnnouncement'));
  }

  /// Duyurunun sabitlemesini kaldırır (moderatör, yönetici)
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/announcements/{announcement_id}/pin`
  Future<Announcement> unpinAnnouncement({
    required String tayfaId,
    required String announcementId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}/pin',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'unpinAnnouncement'));
  }

  /// Gizlenen duyuruyu geri alır (yönetici)
  ///
  /// Moderatör ya da yöneticinin sildiği duyuru 30 gün içinde geri
  /// alınabilir; yazarın şu anki rolü sizinkinden düşük olmalıdır. Yazarın
  /// kendi sildiği ya da süresi geçen duyuru `announcement-not-found`
  /// alır. Görünen bir duyuru için de başarılıdır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/announcements/{announcement_id}/restoration`
  Future<Announcement> restoreAnnouncement({
    required String tayfaId,
    required String announcementId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}/restoration',
      pathParams: {'tayfa_id': tayfaId, 'announcement_id': announcementId},
      expect: ResponseKind.json,
    );
    return Announcement.fromJson(jsonObject(response, 'restoreAnnouncement'));
  }
}
