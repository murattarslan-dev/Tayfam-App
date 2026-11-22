// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `library` olan uçlar.
final class LibraryApi {
  const LibraryApi(this._transport);

  final ApiTransport _transport;

  /// Kütüphanedeki kalemler
  ///
  /// Geri çekilmemiş kalemler, en yeni önce. `kind` yalnızca o türü,
  /// `mine=true` yalnızca çağıranın kalemlerini döndürür. Etkin ödünç
  /// (`active_loan`) yalnızca iki tarafına, sıra (`queue`) yalnızca
  /// `GET …/items/{library_item_id}` ile sahibine döner.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/library/items`
  Future<LibraryItemList> listLibraryItems({
    required String tayfaId,
    LibraryItemKind? kind,
    bool? mine,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/items',
      pathParams: {'tayfa_id': tayfaId},
      query: {
        if (kind != null) 'kind': kind.wire,
        if (mine != null) 'mine': '$mine',
      },
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItemList.fromJson(jsonObject(response, 'listLibraryItems'));
  }

  /// Kütüphaneye kendi kalemini ekler
  ///
  /// Kitabın adı tayfa sözlüğüne (ad alanı `book`) bağlanır: bilinen ad
  /// yeniden kullanılır, yeni ad sözlüğe eklenir; kitapta ad en fazla 60
  /// karakterdir. Fotoğraf isteğe bağlıdır: çağıranın bu tayfa için hazır
  /// `library_item` yüklemesi. Aynı `client_request_id` ile tekrar
  /// gönderim aynı kalemi döndürür. Üye başına en fazla 100 kalem
  /// (`library-item-limit`). Susturulmuş üye ekleyemez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/items`
  Future<LibraryItem> createLibraryItem({
    required String tayfaId,
    required LibraryItemCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/items',
      pathParams: {'tayfa_id': tayfaId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItem.fromJson(jsonObject(response, 'createLibraryItem'));
  }

  /// Kütüphane kalemi
  ///
  /// Sahibi sırayı (`queue`) da görür. Geri çekilmiş ya da bilinmeyen
  /// kalem `library-item-not-found`.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/library/items/{library_item_id}`
  ///
  /// [libraryItemId]: Ortak kütüphanedeki kalemin kimliği (`LibraryItem.id`).
  Future<LibraryItem> getLibraryItem({
    required String tayfaId,
    required String libraryItemId,
  }) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}',
      pathParams: {'tayfa_id': tayfaId, 'library_item_id': libraryItemId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItem.fromJson(jsonObject(response, 'getLibraryItem'));
  }

  /// Kendi kalemini düzenler (sahibi)
  ///
  /// Ad, not ve fotoğraf birlikte yazılır (kısmi güncelleme yok;
  /// `photo_upload_id` yoksa fotoğraf kalkar). Türü değişmez. Çağıranın
  /// olmayan kalem `library-item-not-found`.
  ///
  /// `PUT /v1/tayfas/{tayfa_id}/library/items/{library_item_id}`
  ///
  /// [libraryItemId]: Ortak kütüphanedeki kalemin kimliği (`LibraryItem.id`).
  Future<LibraryItem> updateLibraryItem({
    required String tayfaId,
    required String libraryItemId,
    required LibraryItemUpdateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}',
      pathParams: {'tayfa_id': tayfaId, 'library_item_id': libraryItemId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItem.fromJson(jsonObject(response, 'updateLibraryItem'));
  }

  /// Kalemi geri çeker (sahibi) ya da kaldırır (moderatör)
  ///
  /// Bekleyen istekler ve sıra biter; notu ve fotoğrafı silinir. Geri
  /// alınamaz. Sahibi teslim edilmiş kalemi geri çekemez, önce iade
  /// almalıdır (`library-item-on-loan`); moderatörün kaldırması teslim
  /// edilmiş ödüncü açık bırakır, sahibi iadeyi yine işaretler.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/library/items/{library_item_id}`
  ///
  /// [libraryItemId]: Ortak kütüphanedeki kalemin kimliği (`LibraryItem.id`).
  Future<void> withdrawLibraryItem({
    required String tayfaId,
    required String libraryItemId,
  }) async {
    await _transport.send(
      method: 'DELETE',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}',
      pathParams: {'tayfa_id': tayfaId, 'library_item_id': libraryItemId},
      expect: ResponseKind.none,
      authenticated: true,
    );
  }

  /// Kalemi ödünç ister
  ///
  /// Kalemin etkin ödüncü yoksa ödünç isteği açılır; varsa çağıran
  /// sıranın sonuna girer (`caller_queue_rank`). Tekrar istemek bir şey
  /// değiştirmez. Kendi kalemi `library-own-item`; sırada 20 kişi varsa
  /// `library-queue-full`. Susturulmuş üye isteyemez.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/items/{library_item_id}/request`
  ///
  /// [libraryItemId]: Ortak kütüphanedeki kalemin kimliği (`LibraryItem.id`).
  Future<LibraryItem> requestLibraryLoan({
    required String tayfaId,
    required String libraryItemId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}/request',
      pathParams: {'tayfa_id': tayfaId, 'library_item_id': libraryItemId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItem.fromJson(jsonObject(response, 'requestLibraryLoan'));
  }

  /// İsteğini ya da sıradaki yerini geri alır
  ///
  /// Teslim edilmemiş (istenen ya da onaylanan) ödünç iptal olur ya da
  /// sıradaki yer silinir; ikisi de yoksa bir şey değişmez. Teslim
  /// edilmiş ödünç `library-loan-state`. Sıradaki kişiye ödünç isteği
  /// açılır.
  ///
  /// `DELETE /v1/tayfas/{tayfa_id}/library/items/{library_item_id}/request`
  ///
  /// [libraryItemId]: Ortak kütüphanedeki kalemin kimliği (`LibraryItem.id`).
  Future<LibraryItem> cancelLibraryRequest({
    required String tayfaId,
    required String libraryItemId,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/items/{library_item_id}/request',
      pathParams: {'tayfa_id': tayfaId, 'library_item_id': libraryItemId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryItem.fromJson(jsonObject(response, 'cancelLibraryRequest'));
  }

  /// Ödünçlerim (aldıklarım ve verdiklerim)
  ///
  /// Çağıranın bu tayfadaki ödünçleri, borç alan ve sahip olarak: önce
  /// etkinler, sonra en yeniler; en fazla 200. Biten ödünç 1 yıl tutulur.
  ///
  /// `GET /v1/tayfas/{tayfa_id}/library/loans`
  Future<LibraryLoanList> listLibraryLoans({required String tayfaId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/tayfas/{tayfa_id}/library/loans',
      pathParams: {'tayfa_id': tayfaId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryLoanList.fromJson(jsonObject(response, 'listLibraryLoans'));
  }

  /// İsteği onaylar (sahibi)
  ///
  /// Yalnızca istenen (`requested`) ödünç onaylanır; başka durum `library-loan-state`. Çağıranın kalemine ait olmayan ödünç `library-loan-not-found`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/approve`
  ///
  /// [libraryLoanId]: Ödüncün kimliği (`LibraryLoan.id`).
  Future<LibraryLoan> approveLibraryLoan({
    required String tayfaId,
    required String libraryLoanId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/approve',
      pathParams: {'tayfa_id': tayfaId, 'library_loan_id': libraryLoanId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryLoan.fromJson(jsonObject(response, 'approveLibraryLoan'));
  }

  /// İsteği reddeder (sahibi)
  ///
  /// İstenen ya da onaylanan ödünç reddedilir; sıradaki kişiye ödünç isteği açılır. Çağıranın kalemine ait olmayan ödünç `library-loan-not-found`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/decline`
  ///
  /// [libraryLoanId]: Ödüncün kimliği (`LibraryLoan.id`).
  Future<LibraryLoan> declineLibraryLoan({
    required String tayfaId,
    required String libraryLoanId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/decline',
      pathParams: {'tayfa_id': tayfaId, 'library_loan_id': libraryLoanId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryLoan.fromJson(jsonObject(response, 'declineLibraryLoan'));
  }

  /// Teslim ettim (sahibi)
  ///
  /// Onaylanan ödünç teslim edilir; kalem `on_loan` olur. `due_at` isteğe bağlı iade tarihidir: şimdiden sonra, en fazla 90 gün; geçince borç alana tek uygulama içi hatırlatma gider. Çağıranın kalemine ait olmayan ödünç `library-loan-not-found`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/hand-over`
  ///
  /// [libraryLoanId]: Ödüncün kimliği (`LibraryLoan.id`).
  Future<LibraryLoan> handOverLibraryLoan({
    required String tayfaId,
    required String libraryLoanId,
    LibraryHandOverRequest? body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/hand-over',
      pathParams: {'tayfa_id': tayfaId, 'library_loan_id': libraryLoanId},
      body: body?.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryLoan.fromJson(jsonObject(response, 'handOverLibraryLoan'));
  }

  /// İade aldım (sahibi)
  ///
  /// Teslim edilen ödünç kapanır (karşı taraf tayfadan ayrılmış olsa da); kalem yeniden `available` olur ve sıradaki kişiye ödünç isteği açılır. Çağıranın kalemine ait olmayan ödünç `library-loan-not-found`.
  ///
  /// `POST /v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/return`
  ///
  /// [libraryLoanId]: Ödüncün kimliği (`LibraryLoan.id`).
  Future<LibraryLoan> returnLibraryLoan({
    required String tayfaId,
    required String libraryLoanId,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate:
          '/v1/tayfas/{tayfa_id}/library/loans/{library_loan_id}/return',
      pathParams: {'tayfa_id': tayfaId, 'library_loan_id': libraryLoanId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return LibraryLoan.fromJson(jsonObject(response, 'returnLibraryLoan'));
  }
}
