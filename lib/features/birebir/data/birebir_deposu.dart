import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/direct_messages_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';

/// Konuşma listesinde bir sayfada istenen kayıt sayısı (sözleşme: en çok
/// 100).
const int konusmaSayfaBoyutu = 30;

/// Mesaj akışında bir sayfada istenen mesaj sayısı.
const int mesajSayfaBoyutu = 30;

/// Birebir mesaj uçları (ADR-0018 §9, düz sürüm). Yalnızca üretilmiş uç
/// sınıfını kullanır; bütün istekler tek `ApiClient`'tan geçer
/// (ADR-0005). Mesaj metni hiçbir yere yazılmaz ve loglanmaz.
final class BirebirDeposu {
  BirebirDeposu(ApiTransport istemci) : _api = DirectMessagesApi(istemci);

  final DirectMessagesApi _api;

  /// `GET /v1/direct-messages/conversations`: son mesaja göre, yeniden
  /// eskiye; reddedilen istekler yoktur. [sayfaToken] opaktır.
  Future<Sayfa<Conversation>> konusmalar({
    String? sayfaToken,
    int sayfaBoyutu = konusmaSayfaBoyutu,
  }) async {
    final liste = await _api.listConversations(
      pageSize: sayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.conversations, sonraki: liste.nextPageToken);
  }

  /// `GET /v1/direct-messages/conversations/{conversation_id}`.
  Future<Conversation> konusma(String konusmaId) =>
      _api.getConversation(conversationId: konusmaId);

  /// `GET …/messages`: [sonrakiMesajId] yoksa en yeni önce; verilirse
  /// ondan yeniler en eski önce (eksikleri tamamlama).
  Future<Sayfa<DirectMessage>> mesajlar(
    String konusmaId, {
    String? sayfaToken,
    String? sonrakiMesajId,
  }) async {
    final liste = await _api.listDirectMessages(
      conversationId: konusmaId,
      pageSize: mesajSayfaBoyutu,
      pageToken: sayfaToken,
      afterMessageId: sonrakiMesajId,
    );
    return (ogeler: liste.messages, sonraki: liste.nextPageToken);
  }

  /// `POST /v1/direct-messages`: [aliciId]'ye düz metin yazar. Aynı
  /// [istekKimligi] ile tekrar gönderim ilk mesajı döndürür.
  Future<DirectMessageSent> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) => _api.sendDirectMessage(
    body: DirectMessageCreateRequest(
      recipientUserId: aliciId,
      body: metin,
      clientRequestId: istekKimligi,
    ),
  );

  /// `DELETE …/messages/{message_id}`: kendi mesajını siler.
  Future<void> sil(String konusmaId, String mesajId) =>
      _api.deleteDirectMessage(conversationId: konusmaId, messageId: mesajId);

  /// `PUT …/read`: konuşmayı [mesajId]'ye kadar okundu işaretler.
  Future<void> okundu(String konusmaId, String mesajId) =>
      _api.markConversationRead(
        conversationId: konusmaId,
        body: ChannelReadRequest(messageId: mesajId),
      );

  /// `POST …/accept`: gelen mesaj isteğini kabul eder.
  Future<Conversation> kabulEt(String konusmaId) =>
      _api.acceptMessageRequest(conversationId: konusmaId);

  /// `POST …/decline`: gelen mesaj isteğini reddeder; gönderen öğrenmez.
  Future<void> reddet(String konusmaId) =>
      _api.declineMessageRequest(conversationId: konusmaId);

  /// `GET /v1/direct-messages/declined-requests`: en son reddedilen önce.
  Future<Sayfa<DeclinedRequest>> reddedilenler({String? sayfaToken}) async {
    final liste = await _api.listDeclinedRequests(
      pageSize: konusmaSayfaBoyutu,
      pageToken: sayfaToken,
    );
    return (ogeler: liste.declinedRequests, sonraki: liste.nextPageToken);
  }

  /// `DELETE /v1/direct-messages/declined-requests/{conversation_id}`:
  /// istek yeniden gelen bekleyen istek olur.
  Future<void> reddedilenlerdenCikar(String konusmaId) =>
      _api.removeDeclinedRequest(conversationId: konusmaId);
}

/// Birebir mesaj uçlarının deposu.
final birebirDeposuProvider = Provider<BirebirDeposu>(
  (ref) => BirebirDeposu(ref.watch(apiClientProvider)),
  name: 'birebirDeposuProvider',
);
