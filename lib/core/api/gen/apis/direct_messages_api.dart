// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `direct-messages` olan uçlar.
final class DirectMessagesApi {
  const DirectMessagesApi(this._transport);

  final ApiTransport _transport;

  /// Birebir mesaj gönderir
  ///
  /// `recipient_user_id` kişisine yazar; ilk mesaj konuşmayı açar. Kim
  /// kime yazabilir her mesajda core'a sorulur (Notion v7): iki yönden
  /// biri engellediyse, ortak aktif tayfanız yoksa ve arkadaş
  /// değilseniz `direct-message-not-allowed` (403; hangisi olduğu
  /// söylenmez, bilinmeyen kullanıcı da aynı cevabı alır). Arkadaşlar ve
  /// ortak etkinlik geçmişi olanlar serbestçe yazışır; diğerleri **mesaj
  /// isteği** açar: alıcı cevap yazana ya da kabul edene kadar yalnızca
  /// bir mesaj (`message-request-pending`, 409; alıcı reddettiyse de aynı
  /// cevap, ret size söylenmez; alıcı sizi reddedilenler listesinden
  /// çıkarana kadar arkadaş olsanız bile yazamazsınız). Günde en fazla 20
  /// istek; ortak tayfaya 7 günden kısa süredir üyeyseniz 5
  /// (`message-request-limit`, 429; reddedilen istekler de sayılır).
  ///
  /// Mesaj gönderimi kullanıcı başına hız sınırlıdır: kanal ve birebir
  /// mesajlar, REST ve WebSocket tek sayaçtan sayılır (dakikada 30, kısa
  /// patlama 10; tekrar gönderim de sayılır). Aşılınca `rate-limited`
  /// (429). Yavaş mod ve mesaj isteği sınırı ayrıca geçerlidir.
  ///
  /// Metin 1–4000 karakter, yalnız boşluk olamaz; sekme ve satır sonu
  /// dışında kontrol karakteri içeremez. Aynı `client_request_id` ile
  /// tekrar gönderim ilk mesajı döndürür; başka konuşmada kullanılmış
  /// değer `invalid-request`. Mesaj düzenlenemez. Düz sürümde mesajlar
  /// sunucuda şifreli saklanır. Aynı kurallar WebSocket `dm.send`
  /// çerçevesinde de geçerlidir.
  ///
  /// **Uçtan uca şifreleme (Signal; #127, ADR-0018):** `body` yerine
  /// `envelopes` gönderilir: alıcının **tüm** cihazlarına ve sizin
  /// **diğer tüm** cihazlarınıza birer zarf (en fazla 16). Gönderen
  /// cihaz, token'ın oturumuna kayıtlı cihazdır
  /// (`POST /v1/me/e2e/device`; yoksa `e2e-device-not-registered`, 409).
  /// Küme birebir aynı olmalıdır: eksik, fazla, aynı cihaza iki zarf ya
  /// da kayıt kimliği değişmiş cihaz `e2e-devices-changed` (409,
  /// `missing_device_ids` ve `stale_device_ids` ile;
  /// `E2EDevicesChangedProblem`) döner; cihaz listelerini tazeleyip
  /// tekrar deneyin. Alıcının cihazı yoksa `e2e-recipient-unavailable`
  /// (409). Sunucu zarfları açmaz; mesaj içeriksiz saklanır
  /// (`encryption: e2e`, `body` yok). Zarflar hedef cihaza
  /// `GET /v1/me/e2e/envelopes` ve WebSocket `dm.envelope` ile gider.
  /// Zarflı gönderim yalnızca REST'tedir (WebSocket çerçevesi 64 KB).
  /// Gövde en fazla 1,5 MiB.
  ///
  /// **Geri düşüş yok:** sizin ya da alıcının E2E cihazı varsa `body`
  /// ile gönderim `e2e-required` (409) alır.
  ///
  /// `POST /v1/direct-messages`
  Future<DirectMessageSent> sendDirectMessage({
    required DirectMessageCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/direct-messages',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DirectMessageSent.fromJson(
      jsonObject(response, 'sendDirectMessage'),
    );
  }

  /// Birebir konuşmalarınız (son mesaja göre)
  ///
  /// Okunmamış sayısıyla (en fazla 100; istemci "99+" gösterir).
  /// Reddettiğiniz istekler listelenmez. `peer_last_read_message_id`
  /// karşı tarafın okundu işaretidir; yalnızca aktif konuşmada vardır.
  ///
  /// `GET /v1/direct-messages/conversations`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<ConversationList> listConversations({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/direct-messages/conversations',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return ConversationList.fromJson(jsonObject(response, 'listConversations'));
  }

  /// Bir konuşma
  ///
  /// Yalnızca tarafı olduğunuz konuşma; başkasınınki ve reddettiğiniz
  /// istek `conversation-not-found`.
  ///
  /// `GET /v1/direct-messages/conversations/{conversation_id}`
  Future<Conversation> getConversation({required String conversationId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/direct-messages/conversations/{conversation_id}',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Conversation.fromJson(jsonObject(response, 'getConversation'));
  }

  /// Konuşmanın mesajları
  ///
  /// Kanal mesajlarıyla aynı sayfalama: `after_message_id` yoksa en yeni
  /// önce; verilirse ondan yeniler en eski önce (yeniden bağlanınca
  /// eksikleri tamamlama, ADR-0005). Silinen mesaj yerinde
  /// `deleted: true` ve metinsiz durur ("Bu mesaj silindi").
  /// `encryption: e2e` mesajın metni burada hiçbir zaman yoktur; içerik
  /// zarfta ve arşivdedir (`…/archive`).
  ///
  /// `GET /v1/direct-messages/conversations/{conversation_id}/messages`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<DirectMessageList> listDirectMessages({
    required String conversationId,
    int? pageSize,
    String? pageToken,
    String? afterMessageId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate:
          '/v1/direct-messages/conversations/{conversation_id}/messages',
      pathParams: {'conversation_id': conversationId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
        if (afterMessageId != null) 'after_message_id': afterMessageId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DirectMessageList.fromJson(
      jsonObject(response, 'listDirectMessages'),
    );
  }

  /// Kendi mesajınızı siler
  ///
  /// Metin hemen ve geri alınamaz biçimde silinir. Başkasının mesajı
  /// `message-not-found`. Silinmiş mesajı silmek bir şey değiştirmez.
  /// Uçtan uca şifreli mesajın bekleyen zarfları ve iki tarafın arşiv
  /// kayıtları da silinir.
  /// Engellemeden sonra da kendi mesajınızı silebilirsiniz.
  ///
  /// `DELETE /v1/direct-messages/conversations/{conversation_id}/messages/{message_id}`
  Future<void> deleteDirectMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/direct-messages/conversations/{conversation_id}/messages/{message_id}',
      pathParams: {'conversation_id': conversationId, 'message_id': messageId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Konuşmayı bu mesaja kadar okundu işaretler
  ///
  /// Okundu işareti yalnızca ileri gider. Mesaj bu konuşmada olmalıdır
  /// (`message-not-found`). Karşı taraf işaretinizi yalnızca aktif
  /// konuşmada görür (isteği okuduğunuzu gönderen öğrenmez). Konuşmanın
  /// bildirimleri de okunmuş olur.
  ///
  /// `PUT /v1/direct-messages/conversations/{conversation_id}/read`
  Future<void> markConversationRead({
    required String conversationId,
    required ChannelReadRequest body,
  }) async {
    await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/direct-messages/conversations/{conversation_id}/read',
      pathParams: {'conversation_id': conversationId},
      body: body.toJson(),
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Size gelen mesaj isteğini kabul eder
  ///
  /// Konuşma aktif olur; cevap yazmak da kabul sayılır. Aktif konuşmayı
  /// kabul etmek bir şey değiştirmez. Bekleyen isteğiniz yoksa (kendi
  /// isteğiniz dahil) `message-request-not-found`.
  ///
  /// `POST /v1/direct-messages/conversations/{conversation_id}/accept`
  Future<Conversation> acceptMessageRequest({
    required String conversationId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/direct-messages/conversations/{conversation_id}/accept',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return Conversation.fromJson(jsonObject(response, 'acceptMessageRequest'));
  }

  /// Size gelen mesaj isteğini reddeder
  ///
  /// Gönderen bunu öğrenmez ve siz onu reddedilenler listesinden
  /// çıkarana kadar (`DELETE /v1/direct-messages/declined-requests/{conversation_id}`)
  /// arkadaş olsanız bile yeniden yazamaz. Konuşma listenizden çıkar,
  /// reddedilenler listesinde görünür. Sonra siz yazarsanız konuşma
  /// aktif açılır. Bekleyen isteğiniz yoksa `message-request-not-found`.
  ///
  /// `POST /v1/direct-messages/conversations/{conversation_id}/decline`
  Future<void> declineMessageRequest({required String conversationId}) async {
    await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/direct-messages/conversations/{conversation_id}/decline',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Reddettiğiniz mesaj istekleri (reddedilenler listesi)
  ///
  /// En son reddedilen önce. Listeyi yalnızca siz görürsünüz; gönderen
  /// ne reddi ne bu listeyi öğrenir. Hesabı silinmiş gönderenin isteği
  /// listelenmez.
  ///
  /// `GET /v1/direct-messages/declined-requests`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<DeclinedRequestList> listDeclinedRequests({
    int? pageSize,
    String? pageToken,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/direct-messages/declined-requests',
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return DeclinedRequestList.fromJson(
      jsonObject(response, 'listDeclinedRequests'),
    );
  }

  /// Bir isteği reddedilenler listesinden çıkarır
  ///
  /// Konuşma yeniden size gelen bekleyen istek olur
  /// (`request_received`): cevap yazabilir, kabul edebilir ya da yeniden
  /// reddedebilirsiniz. Gönderen yine yalnızca tek mesajını görür; kabul
  /// edene kadar (ya da serbest yazışabilir hale gelene kadar, ör.
  /// arkadaşlık) ikinci mesajı yazamaz. Gönderene bildirim gitmez.
  /// Tarafı olmadığınız konuşma `conversation-not-found`; sizin
  /// reddetmediğiniz konuşma (kendi isteğiniz dahil)
  /// `message-request-not-found`.
  ///
  /// `DELETE /v1/direct-messages/declined-requests/{conversation_id}`
  Future<void> removeDeclinedRequest({required String conversationId}) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/direct-messages/declined-requests/{conversation_id}',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Bir konuşmanın geçmiş arşivi (sizin kayıtlarınız)
  ///
  /// Mesaj listesiyle aynı sayfalama (`after_message_id`). Yalnızca
  /// eşleştirilmiş cihaz okur (`e2e-not-paired`, 409). Her kayıt kendi
  /// `key_version`'ıyla çözülür.
  ///
  /// `GET /v1/direct-messages/conversations/{conversation_id}/archive`
  ///
  /// [pageSize]: Kısıtlar: minimum: 0; maximum: 100; varsayılan (sunucu): 0.
  ///
  /// [pageToken]: Önceki yanıtın `next_page_token` değeri; opak.
  ///
  /// Kısıtlar: maxLength: 1024.
  Future<E2EArchiveEntryList> listE2EArchiveEntries({
    required String conversationId,
    int? pageSize,
    String? pageToken,
    String? afterMessageId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate:
          '/v1/direct-messages/conversations/{conversation_id}/archive',
      pathParams: {'conversation_id': conversationId},
      query: {
        if (pageSize != null) 'page_size': '$pageSize',
        if (pageToken != null) 'page_token': pageToken,
        if (afterMessageId != null) 'after_message_id': afterMessageId,
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return E2EArchiveEntryList.fromJson(
      jsonObject(response, 'listE2EArchiveEntries'),
    );
  }

  /// Bir konuşmanın arşiv kayıtlarınızı siler
  ///
  /// `DELETE /v1/direct-messages/conversations/{conversation_id}/archive`
  Future<void> deleteE2EConversationArchive({
    required String conversationId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/direct-messages/conversations/{conversation_id}/archive',
      pathParams: {'conversation_id': conversationId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }
}
