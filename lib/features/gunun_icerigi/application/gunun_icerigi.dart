import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/gunun_icerigi/data/gunun_icerigi_deposu.dart';

/// Bugünün içeriği (`GET …/daily/today`). Seçimi sunucu yapar (Tayfam-Api
/// ADR-0027 §5); istemci yalnızca gösterir. Yalnızca bellektedir
/// (ADR-0006); kart ekrandan kalkınca bırakılır.
class BugunkuIcerikNotifier extends AsyncNotifier<DailyToday> {
  BugunkuIcerikNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<DailyToday> build() =>
      ref.read(gununIcerigiDeposuProvider).bugun(tayfaId);
}

/// Bugünün içeriği; hata otomatik yeniden denenmez (kartta "Tekrar dene").
final bugunkuIcerikProvider = AsyncNotifierProvider.autoDispose
    .family<BugunkuIcerikNotifier, DailyToday, String>(
      BugunkuIcerikNotifier.new,
      name: 'bugunkuIcerikProvider',
      retry: _yenidenDenemeYok,
    );

/// Bir içeriğin formdan gelen hali: metin, söyleyen ve sabitleme.
typedef IcerikGirdisi = ({String metin, String? soyleyen, DailyPin? sabit});

/// Havuz (`GET …/daily/items`) ve yönetim işlemleri. Yazma işlemleri
/// hatayı çağırana fırlatır (ekran gösterir); başarıda liste ve bugünün
/// içeriği tazelenir. Yetkiyi sunucu verir (`caller_can_manage`, kesin
/// kural 5).
class HavuzNotifier extends AsyncNotifier<DailyItemList> {
  HavuzNotifier(this.tayfaId);

  final String tayfaId;

  GununIcerigiDeposu get _depo => ref.read(gununIcerigiDeposuProvider);

  @override
  Future<DailyItemList> build() => _depo.liste(tayfaId);

  /// Havuzun sonuna ekler. [istekKimligi] aynı iş tekrar gönderilirken
  /// aynı kalır (`client_request_id`).
  Future<DailyItemSaved> ekle(IcerikGirdisi girdi, String istekKimligi) async {
    final kayit = await _depo.ekle(
      tayfaId,
      DailyItemCreateRequest(
        body: girdi.metin,
        attribution: girdi.soyleyen,
        pin: girdi.sabit,
        clientRequestId: istekKimligi,
      ),
    );
    if (ref.mounted) _yerlestir(kayit.item);
    return kayit;
  }

  /// İçeriği tam olarak değiştirir (sabitleme verilmezse kalkar).
  Future<DailyItemSaved> duzenle(String icerikId, IcerikGirdisi girdi) async {
    final kayit = await _depo.duzenle(
      tayfaId,
      icerikId,
      DailyItemInput(
        body: girdi.metin,
        attribution: girdi.soyleyen,
        pin: girdi.sabit,
      ),
    );
    if (ref.mounted) _yerlestir(kayit.item);
    return kayit;
  }

  /// Siler (30 gün geri alınabilir).
  Future<void> sil(String icerikId) async {
    await _depo.sil(tayfaId, icerikId);
    if (!ref.mounted) return;
    final mevcut = state.value;
    if (mevcut != null) {
      state = AsyncData(
        DailyItemList(
          items: [
            for (final i in mevcut.items)
              if (i.id != icerikId) i,
          ],
          callerCanManage: mevcut.callerCanManage,
        ),
      );
    }
    _tazele();
  }

  /// Silinen içeriği geri alır; havuzun sonuna döner.
  Future<DailyItemSaved> geriAl(String icerikId) async {
    final kayit = await _depo.geriAl(tayfaId, icerikId);
    if (ref.mounted) _yerlestir(kayit.item);
    return kayit;
  }

  /// [eski] sıradaki içeriği [yeni] sıraya taşır ve bütün sırayı gönderir.
  /// Ekran hemen yeni sırayı gösterir; sunucu reddederse eski sıraya döner
  /// ve hata fırlatılır.
  Future<void> tasi(int eski, int yeni) async {
    final mevcut = state.value;
    if (mevcut == null || eski < 0 || eski >= mevcut.items.length) return;
    final hedef = yeni.clamp(0, mevcut.items.length - 1);
    if (hedef == eski) return;
    final liste = [...mevcut.items];
    final oge = liste.removeAt(eski);
    liste.insert(hedef, oge);
    state = AsyncData(
      DailyItemList(items: liste, callerCanManage: mevcut.callerCanManage),
    );
    try {
      final sira = await _depo.sirala(tayfaId, [for (final i in liste) i.id]);
      if (!ref.mounted) return;
      state = AsyncData(
        DailyItemList(
          items: sira.items,
          callerCanManage: mevcut.callerCanManage,
        ),
      );
      _tazele();
    } on Exception {
      if (ref.mounted) state = AsyncData(mevcut);
      rethrow;
    }
  }

  /// Kaydedilen içeriği listeye koyar: varsa yerinde değiştirir, yoksa
  /// sona ekler (sunucu yeni ve geri alınan içeriği sona koyar).
  void _yerlestir(DailyItem oge) {
    final mevcut = state.value;
    if (mevcut != null) {
      final vardi = mevcut.items.any((i) => i.id == oge.id);
      state = AsyncData(
        DailyItemList(
          items: vardi
              ? [for (final i in mevcut.items) i.id == oge.id ? oge : i]
              : [...mevcut.items, oge],
          callerCanManage: mevcut.callerCanManage,
        ),
      );
    }
    _tazele();
  }

  /// Bugünün içeriği ve silinenler listesi yeniden okunur.
  void _tazele() {
    ref
      ..invalidate(bugunkuIcerikProvider(tayfaId))
      ..invalidate(silinenlerProvider(tayfaId));
  }
}

/// Tayfanın havuzu; ekrandan kalkınca bırakılır.
final havuzProvider = AsyncNotifierProvider.autoDispose
    .family<HavuzNotifier, DailyItemList, String>(
      HavuzNotifier.new,
      name: 'havuzProvider',
      retry: _yenidenDenemeYok,
    );

/// Son 30 günde silinenler (`?deleted=true`; yalnızca yönetenler).
class SilinenlerNotifier extends AsyncNotifier<DailyItemList> {
  SilinenlerNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<DailyItemList> build() =>
      ref.read(gununIcerigiDeposuProvider).liste(tayfaId, silinenler: true);
}

/// Silinenler listesi; geri alma havuz üzerinden yapılır.
final silinenlerProvider = AsyncNotifierProvider.autoDispose
    .family<SilinenlerNotifier, DailyItemList, String>(
      SilinenlerNotifier.new,
      name: 'silinenlerProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
