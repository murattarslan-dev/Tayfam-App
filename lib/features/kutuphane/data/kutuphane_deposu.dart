import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/library_api.dart';
import 'package:tayfam/core/api/gen/apis/vocabulary_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/bilesenler/sozluk_girisi.dart';

/// Kitap adlarının tayfa sözlüğündeki ad alanı (Tayfam-Api ADR-0040 §1).
const String kitapSozlugu = 'book';

/// Ortak kütüphane uçları (Tayfam-Api ADR-0040 §1, #270). Yalnızca
/// üretilmiş uç sınıflarını kullanır; bütün istekler tek `ApiClient`'tan
/// geçer (ADR-0005). Ad ve not içeriktir; log'a yazılmaz.
final class KutuphaneDeposu {
  KutuphaneDeposu(ApiTransport istemci)
    : _api = LibraryApi(istemci),
      _sozluk = VocabularyApi(istemci);

  final LibraryApi _api;
  final VocabularyApi _sozluk;

  /// `GET …/library/items`: geri çekilmemiş kalemler, en yeni önce.
  /// [tur] yalnızca o türü, [benim] yalnızca çağıranın kalemlerini getirir.
  Future<LibraryItemList> kalemler(
    String tayfaId, {
    LibraryItemKind? tur,
    bool benim = false,
  }) => _api.listLibraryItems(
    tayfaId: tayfaId,
    kind: tur,
    mine: benim ? true : null,
  );

  /// `GET …/library/items/{id}`: sahibine sıra da döner.
  Future<LibraryItem> kalem(String tayfaId, String kalemId) =>
      _api.getLibraryItem(tayfaId: tayfaId, libraryItemId: kalemId);

  /// `POST …/library/items`: kendi kalemini ekler.
  Future<LibraryItem> ekle(String tayfaId, LibraryItemCreateRequest istek) =>
      _api.createLibraryItem(tayfaId: tayfaId, body: istek);

  /// `PUT …/library/items/{id}`: ad, not ve fotoğraf birlikte yazılır.
  Future<LibraryItem> duzenle(
    String tayfaId,
    String kalemId,
    LibraryItemUpdateRequest istek,
  ) => _api.updateLibraryItem(
    tayfaId: tayfaId,
    libraryItemId: kalemId,
    body: istek,
  );

  /// `DELETE …/library/items/{id}`: geri çeker (sahibi) ya da kaldırır
  /// (moderatör). Geri alınamaz.
  Future<void> geriCek(String tayfaId, String kalemId) =>
      _api.withdrawLibraryItem(tayfaId: tayfaId, libraryItemId: kalemId);

  /// `POST …/items/{id}/request`: ödünç ister ya da sıraya girer.
  Future<LibraryItem> iste(String tayfaId, String kalemId) =>
      _api.requestLibraryLoan(tayfaId: tayfaId, libraryItemId: kalemId);

  /// `DELETE …/items/{id}/request`: isteği ya da sıradaki yeri geri alır.
  Future<LibraryItem> istegiGeriAl(String tayfaId, String kalemId) =>
      _api.cancelLibraryRequest(tayfaId: tayfaId, libraryItemId: kalemId);

  /// `GET …/library/loans`: çağıranın ödünçleri (aldıkları ve verdikleri).
  Future<LibraryLoanList> oduncler(String tayfaId) =>
      _api.listLibraryLoans(tayfaId: tayfaId);

  /// `POST …/loans/{id}/approve` (sahibi).
  Future<LibraryLoan> onayla(String tayfaId, String oduncId) =>
      _api.approveLibraryLoan(tayfaId: tayfaId, libraryLoanId: oduncId);

  /// `POST …/loans/{id}/decline` (sahibi).
  Future<LibraryLoan> reddet(String tayfaId, String oduncId) =>
      _api.declineLibraryLoan(tayfaId: tayfaId, libraryLoanId: oduncId);

  /// `POST …/loans/{id}/hand-over` (sahibi); [iadeTarihi] isteğe bağlı.
  Future<LibraryLoan> teslimEt(
    String tayfaId,
    String oduncId, {
    DateTime? iadeTarihi,
  }) => _api.handOverLibraryLoan(
    tayfaId: tayfaId,
    libraryLoanId: oduncId,
    body: iadeTarihi == null
        ? null
        : LibraryHandOverRequest(dueAt: iadeTarihi.toUtc()),
  );

  /// `POST …/loans/{id}/return` (sahibi).
  Future<LibraryLoan> iadeAl(String tayfaId, String oduncId) =>
      _api.returnLibraryLoan(tayfaId: tayfaId, libraryLoanId: oduncId);

  /// Kitap adı önerileri (`GET …/vocabulary/book?q=`; App ADR-0031 §5).
  Future<List<SozlukOnerisi>> kitapOnerileri(
    String tayfaId,
    String arama,
  ) async {
    final liste = await _sozluk.listTayfaVocabulary(
      tayfaId: tayfaId,
      namespace: kitapSozlugu,
      q: arama.trim().isEmpty ? null : arama.trim(),
    );
    return [for (final d in liste.values) (kimlik: d.id, metin: d.value)];
  }
}

/// Kütüphane deposu; testlerde sahtesi verilir.
final kutuphaneDeposuProvider = Provider<KutuphaneDeposu>(
  (ref) => KutuphaneDeposu(ref.watch(apiClientProvider)),
  name: 'kutuphaneDeposuProvider',
);
