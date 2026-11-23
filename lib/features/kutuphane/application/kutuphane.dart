import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/kutuphane/data/kutuphane_deposu.dart';

/// Kalem listesinin sorgusu: tayfa, isteğe bağlı tür ve "yalnızca benim".
typedef KalemSorgusu = ({String tayfaId, LibraryItemKind? tur, bool benim});

/// Bir kalemin anahtarı.
typedef KalemAnahtari = ({String tayfaId, String kalemId});

/// Formdan gelen kalem: ad, not ve fotoğraf (`null`: yok).
typedef KalemGirdisi = ({String ad, String? not, String? fotograf});

/// Kütüphanedeki kalemler (`GET …/library/items`). Ödünç ilişkisini
/// yalnızca iki taraf görür; diğer üyelere sunucu yalnızca durumu ve sıra
/// uzunluğunu döndürür, istemci de fazlasını göstermez. Yalnızca
/// bellektedir (ADR-0006).
class KalemlerNotifier extends AsyncNotifier<LibraryItemList> {
  KalemlerNotifier(this.sorgu);

  final KalemSorgusu sorgu;

  @override
  Future<LibraryItemList> build() => ref
      .read(kutuphaneDeposuProvider)
      .kalemler(sorgu.tayfaId, tur: sorgu.tur, benim: sorgu.benim);
}

/// Kalem listesi; ekrandan kalkınca bırakılır.
final kalemlerProvider = AsyncNotifierProvider.autoDispose
    .family<KalemlerNotifier, LibraryItemList, KalemSorgusu>(
      KalemlerNotifier.new,
      name: 'kalemlerProvider',
      retry: _yenidenDenemeYok,
    );

/// Bir kalem (`GET …/library/items/{id}`); sahibine sıra da gelir.
class KalemNotifier extends AsyncNotifier<LibraryItem> {
  KalemNotifier(this.anahtar);

  final KalemAnahtari anahtar;

  @override
  Future<LibraryItem> build() =>
      ref.read(kutuphaneDeposuProvider).kalem(anahtar.tayfaId, anahtar.kalemId);
}

/// Kalem detayı; ekrandan kalkınca bırakılır.
final kalemProvider = AsyncNotifierProvider.autoDispose
    .family<KalemNotifier, LibraryItem, KalemAnahtari>(
      KalemNotifier.new,
      name: 'kalemProvider',
      retry: _yenidenDenemeYok,
    );

/// Çağıranın ödünçleri (`GET …/library/loans`): aldıkları ve verdikleri.
class OdunclerNotifier extends AsyncNotifier<LibraryLoanList> {
  OdunclerNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<LibraryLoanList> build() =>
      ref.read(kutuphaneDeposuProvider).oduncler(tayfaId);
}

/// "Ödünçlerim"; ekrandan kalkınca bırakılır.
final odunclerProvider = AsyncNotifierProvider.autoDispose
    .family<OdunclerNotifier, LibraryLoanList, String>(
      OdunclerNotifier.new,
      name: 'odunclerProvider',
      retry: _yenidenDenemeYok,
    );

/// Ödünç sürüyor mu (istendi, onaylandı ya da teslim edildi).
bool oduncSuruyor(LibraryLoanState durum) => switch (durum) {
  LibraryLoanState.requested ||
  LibraryLoanState.approved ||
  LibraryLoanState.handedOver => true,
  LibraryLoanState.returned ||
  LibraryLoanState.declined ||
  LibraryLoanState.cancelled ||
  LibraryLoanState.closed ||
  LibraryLoanState.unknown => false,
};

/// Kütüphanedeki yazma işlemleri. Hata çağırana fırlatılır (ekran
/// gösterir); başarıda listeler, kalem ve ödünçler sunucudan yeniden
/// okunur: istemci durum geçişini kendisi kurmaz, yalnızca sunucunun
/// döndürdüğünü çizer (App ADR-0033 §4). Yetkiyi sunucu verir (kesin
/// kural 5).
final class KutuphaneIslemleri {
  KutuphaneIslemleri(this._ref);

  final Ref _ref;

  KutuphaneDeposu get _depo => _ref.read(kutuphaneDeposuProvider);

  /// Kendi kalemini ekler. [istekKimligi] aynı iş tekrar gönderilirken
  /// aynı kalır (`client_request_id`).
  Future<LibraryItem> ekle(
    String tayfaId,
    LibraryItemKind tur,
    KalemGirdisi girdi,
    String istekKimligi,
  ) => _tazeleyerek(
    tayfaId,
    _depo.ekle(
      tayfaId,
      LibraryItemCreateRequest(
        kind: tur,
        name: girdi.ad,
        note: girdi.not,
        photoUploadId: girdi.fotograf,
        clientRequestId: istekKimligi,
      ),
    ),
  );

  /// Ad, not ve fotoğrafı birlikte yazar (fotoğraf verilmezse kalkar).
  Future<LibraryItem> duzenle(
    String tayfaId,
    String kalemId,
    KalemGirdisi girdi,
  ) => _tazeleyerek(
    tayfaId,
    _depo.duzenle(
      tayfaId,
      kalemId,
      LibraryItemUpdateRequest(
        name: girdi.ad,
        note: girdi.not,
        photoUploadId: girdi.fotograf,
      ),
    ),
  );

  /// Geri çeker (sahibi) ya da kaldırır (moderatör); geri alınamaz.
  /// Detay ekranı kapanacağı için kalem yeniden okunmaz.
  Future<void> geriCek(String tayfaId, String kalemId) =>
      _tazeleyerek(tayfaId, _depo.geriCek(tayfaId, kalemId), kalem: false);

  /// Ödünç ister ya da sıraya girer.
  Future<LibraryItem> iste(String tayfaId, String kalemId) =>
      _tazeleyerek(tayfaId, _depo.iste(tayfaId, kalemId));

  /// İsteği ya da sıradaki yeri geri alır.
  Future<LibraryItem> istegiGeriAl(String tayfaId, String kalemId) =>
      _tazeleyerek(tayfaId, _depo.istegiGeriAl(tayfaId, kalemId));

  /// İsteği onaylar (sahibi).
  Future<LibraryLoan> onayla(String tayfaId, String oduncId) =>
      _tazeleyerek(tayfaId, _depo.onayla(tayfaId, oduncId));

  /// İsteği reddeder (sahibi).
  Future<LibraryLoan> reddet(String tayfaId, String oduncId) =>
      _tazeleyerek(tayfaId, _depo.reddet(tayfaId, oduncId));

  /// Teslim edildi (sahibi); [iadeTarihi] isteğe bağlı.
  Future<LibraryLoan> teslimEt(
    String tayfaId,
    String oduncId, {
    DateTime? iadeTarihi,
  }) => _tazeleyerek(
    tayfaId,
    _depo.teslimEt(tayfaId, oduncId, iadeTarihi: iadeTarihi),
  );

  /// İade alındı (sahibi).
  Future<LibraryLoan> iadeAl(String tayfaId, String oduncId) =>
      _tazeleyerek(tayfaId, _depo.iadeAl(tayfaId, oduncId));

  Future<T> _tazeleyerek<T>(
    String tayfaId,
    Future<T> is_, {
    bool kalem = true,
  }) async {
    final sonuc = await is_;
    _ref
      ..invalidate(kalemlerProvider)
      ..invalidate(odunclerProvider(tayfaId));
    if (kalem) _ref.invalidate(kalemProvider);
    return sonuc;
  }
}

/// Kütüphane işlemleri; durum tutmaz.
final kutuphaneIslemleriProvider = Provider<KutuphaneIslemleri>(
  KutuphaneIslemleri.new,
  name: 'kutuphaneIslemleriProvider',
);

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
