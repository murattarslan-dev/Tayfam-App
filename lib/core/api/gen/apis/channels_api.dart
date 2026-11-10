// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `channels` olan uçlar.
final class ChannelsApi {
  const ChannelsApi(this._transport);

  final ApiTransport _transport;

  /// Tayfanın kanalları ve okunmamış sayılarınız
  ///
  /// Etkin üyesi olduğunuz tayfanın görebildiğiniz kanalları
  /// (`tayfa-not-found`). `staff` kanallarını yalnızca yönetici ve
  /// moderatörler görür. İzinleri core'un tek izin tablosu verir.
  /// Askıdaki, arşivlenmiş ya da silinmeyi bekleyen tayfada kanallar salt
  /// okunurdur: değişiklikler `tayfa-read-only` (409) alır; okuma ve
  /// okundu işareti sürer. Arşivlenmiş kanallar sondadır. `unread_count`
  /// başkalarının silinmemiş mesajlarından okunmamış olanlardır; en
  /// fazla 100 döner, istemci "99+" gösterir.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/channels`
  Future<ChannelList> listChannels({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
    );
    return ChannelList.fromJson(jsonObject(response, 'listChannels'));
  }

  /// Kanal açar (yönetici ve moderatör)
  ///
  /// İsim 1–40 karakterdir; arşivlenmemiş kanallar arasında Türkçe büyük/
  /// küçük harf duyarsız tekildir (`channel-name-taken`). Susturulmuş
  /// yönetim kanal açamaz (`muted`).
  ///
  /// `POST /v1/tayfas/{tayfa_id}/channels`
  Future<Channel> createChannel({
    required String tayfaId,
    required ChannelCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return Channel.fromJson(jsonObject(response, 'createChannel'));
  }

  /// Bir kanal
  ///
  /// Başka tayfanın kanalı ve üyeye `staff` kanalı, olmayan kanalla aynı
  /// cevabı alır (`channel-not-found`).
  ///
  /// `GET /v1/tayfas/{tayfa_id}/channels/{channel_id}`
  Future<Channel> getChannel({
    required String tayfaId,
    required String channelId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      expect: ResponseKind.json,
    );
    return Channel.fromJson(jsonObject(response, 'getChannel'));
  }

  /// Kanalın adını, görünürlüğünü ya da yavaş modunu değiştirir
  ///
  /// Yalnızca gönderilen alanlar değişir; en az biri gerekir. Yönetici ve moderatör.
  ///
  /// `PATCH /v1/tayfas/{tayfa_id}/channels/{channel_id}`
  Future<Channel> updateChannel({
    required String tayfaId,
    required String channelId,
    required ChannelUpdateRequest body,
  }) async {
    final json = body.toJson();
    if (json.length < 1) {
      throw ArgumentError('ChannelUpdateRequest: en az 1 alan verilmeli');
    }
    final response = await _transport.send(
      method: 'PATCH',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      body: json,
      expect: ResponseKind.json,
    );
    return Channel.fromJson(jsonObject(response, 'updateChannel'));
  }

  /// Kanalı arşivler (salt okunur)
  ///
  /// Arşivli kanala mesaj yazılamaz; okuma ve moderasyon sürer. Yönetici ve moderatör.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/channels/{channel_id}/archive`
  Future<Channel> archiveChannel({
    required String tayfaId,
    required String channelId,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/archive',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      expect: ResponseKind.json,
    );
    return Channel.fromJson(jsonObject(response, 'archiveChannel'));
  }

  /// Kanalı arşivden çıkarır
  ///
  /// Arada aynı isimde kanal açıldıysa `channel-name-taken`.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/channels/{channel_id}/archive`
  Future<Channel> unarchiveChannel({
    required String tayfaId,
    required String channelId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/archive',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      expect: ResponseKind.json,
    );
    return Channel.fromJson(jsonObject(response, 'unarchiveChannel'));
  }

  /// Kanal mesajları
  ///
  /// `after_message_id` yoksa en yeni önce, `next_page_token` eskiye
  /// doğru gider. `after_message_id` (elinizdeki son mesaj) verilirse
  /// ondan yeni mesajlar en eski önce gelir ve `next_page_token` yeniye
  /// doğru gider: yeniden bağlanınca eksikler böyle tamamlanır (ADR-0005).
  /// Silinen mesaj yerinde `deleted: true` ve metinsiz durur ("Bu mesaj
  /// silindi").
  ///
  /// `GET /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<ChannelMessageList> listChannelMessages({
    required String tayfaId,
    required String channelId,
    int? pageSize,
    String? pageToken,
    String? afterMessageId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
        if (afterMessageId != null) 'after_message_id': afterMessageId,
      },
      expect: ResponseKind.json,
    );
    return ChannelMessageList.fromJson(
      jsonObject(response, 'listChannelMessages'),
    );
  }

  /// Kanala mesaj yazar
  ///
  /// Metin 1–4000 karakter, yalnız boşluk olamaz; sekme ve satır sonu
  /// dışında kontrol karakteri içeremez. Aynı `client_request_id` ile
  /// tekrar gönderim ilk mesajı döndürür, yeni mesaj yazmaz (yavaş moda da
  /// takılmaz); başka kanalda kullanılmış değer `invalid-request`.
  /// Susturulmuşsanız `muted`, kanal arşivliyse `channel-archived`. Yavaş
  /// modda erken gönderim `slow-mode` (429) ve `Retry-After` başlığını
  /// (saniye) alır; yönetici ve moderatörler muaftır. Mesaj düzenlenemez.
  /// Aynı kurallar WebSocket gönderiminde de geçerlidir.
  ///
  /// Mesaj gönderimi kullanıcı başına hız sınırlıdır: kanal ve birebir
  /// mesajlar, REST ve WebSocket tek sayaçtan sayılır (dakikada 30, kısa
  /// patlama 10; tekrar gönderim de sayılır). Aşılınca `rate-limited`
  /// (429). Yavaş mod ve mesaj isteği sınırı ayrıca geçerlidir.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages`
  Future<ChannelMessage> sendChannelMessage({
    required String tayfaId,
    required String channelId,
    required ChannelMessageCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return ChannelMessage.fromJson(jsonObject(response, 'sendChannelMessage'));
  }

  /// Mesajı siler
  ///
  /// Kendi mesajınızı silerseniz metin hemen ve geri alınamaz biçimde
  /// silinir. Yönetici ve moderatörler başkasının mesajını gizler; yazarın
  /// güncel rolü sizinkine eşit ya da yüksekse `role-hierarchy` (403;
  /// tayfadan ayrılmış yazar sınırlamaz). Yönetici 30 gün içinde geri
  /// alabilir, sonra kalıcı silinir. Silinmiş mesajı silmek bir şey
  /// değiştirmez.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages/{message_id}`
  Future<void> deleteChannelMessage({
    required String tayfaId,
    required String channelId,
    required String messageId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages/{message_id}',
      pathParams: {
        'tayfa_id': tayfaId,
        'channel_id': channelId,
        'message_id': messageId,
      },
      expect: ResponseKind.none,
    );
  }

  /// Moderasyonla gizlenen mesajı geri alır (yönetici)
  ///
  /// 30 gün içinde, yazarın güncel rolünün üstündeyseniz (`role-hierarchy`).
  /// Yazarın kendi silmesi ve daha eskisi `message-not-found` alır. Görünür mesajı geri almak bir şey
  /// değiştirmez. Her geri alma kayıt altına alınır.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages/{message_id}/restoration`
  Future<ChannelMessage> restoreChannelMessage({
    required String tayfaId,
    required String channelId,
    required String messageId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages/{message_id}/restoration',
      pathParams: {
        'tayfa_id': tayfaId,
        'channel_id': channelId,
        'message_id': messageId,
      },
      expect: ResponseKind.json,
    );
    return ChannelMessage.fromJson(
      jsonObject(response, 'restoreChannelMessage'),
    );
  }

  /// Kanalı bu mesaja kadar okundu işaretler
  ///
  /// Okundu işareti yalnızca ileri gider; daha eski bir mesaj bir şey
  /// değiştirmez. Mesaj bu kanalda olmalıdır (`message-not-found`).
  /// Susturulmuş üyeler de işaretleyebilir.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/channels/{channel_id}/read`
  Future<void> markChannelRead({
    required String tayfaId,
    required String channelId,
    required ChannelReadRequest body,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/channels/{channel_id}/read',
      pathParams: {'tayfa_id': tayfaId, 'channel_id': channelId},
      body: body.toJson(),
      expect: ResponseKind.none,
    );
  }
}
