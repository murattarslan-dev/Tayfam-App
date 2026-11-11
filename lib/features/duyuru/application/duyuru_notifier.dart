import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/data/duyuru_deposu.dart';

/// Tek bir duyurunun anahtarı: tayfa ve duyuru kimliği.
typedef DuyuruAnahtari = ({String tayfaId, String duyuruId});

/// Tek bir duyuru (ADR-0015 §2): detay ekranı ve sabitleme, kaldırma,
/// silme işlemleri.
///
/// Duyuru tayfanın listesinde zaten varsa oradan gösterilir; yoksa (derin
/// link, ilk sayfada olmayan duyuru) sunucudan okunur. İşlemlerin
/// sonucu listeye de yansır. Yetkiyi sunucu verir: düğmeler role göre
/// sadeleşir, ama hata (`permission-denied`, `role-hierarchy`,
/// `tayfa-read-only` …) her zaman ele alınır (kesin kural 5).
class DuyuruNotifier extends AsyncNotifier<Announcement> {
  DuyuruNotifier(this.anahtar);

  /// Tayfa ve duyuru kimliği.
  final DuyuruAnahtari anahtar;

  @override
  Future<Announcement> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(duyuruDeposuProvider);
    final liste = duyuruListesiProvider(anahtar.tayfaId);
    if (ref.exists(liste)) {
      for (final d in ref.read(liste).value?.ogeler ?? const []) {
        if (d.id == anahtar.duyuruId) return d;
      }
    }
    return depo.getir(anahtar.tayfaId, anahtar.duyuruId);
  }

  /// Gösterilen duyuruyu [duyuru] yapar (düzenleme sonrası).
  void yansit(Announcement duyuru) => state = AsyncData(duyuru);

  /// Duyuruyu sabitler ([sabit] `true`) ya da sabitlemeyi kaldırır.
  /// Başarıda `null`, aksi halde gösterilecek hata.
  Future<Object?> sabitle({required bool sabit}) => _islem(() async {
    final depo = ref.read(duyuruDeposuProvider);
    final (:tayfaId, :duyuruId) = anahtar;
    final duyuru = await depo.sabitle(tayfaId, duyuruId, sabit: sabit);
    if (ref.mounted) duyuruyuYansit(ref, tayfaId, duyuru);
  });

  /// Duyuruyu siler ve listeden çıkarır. Onay ekranda sorulur. Başarıda
  /// `null`, aksi halde gösterilecek hata.
  Future<Object?> sil() => _islem(() async {
    final depo = ref.read(duyuruDeposuProvider);
    final (:tayfaId, :duyuruId) = anahtar;
    await depo.sil(tayfaId, duyuruId);
    if (!ref.mounted) return;
    final liste = duyuruListesiProvider(tayfaId);
    if (ref.exists(liste)) ref.read(liste.notifier).cikar(duyuruId);
  });

  Future<Object?> _islem(Future<void> Function() islem) async {
    try {
      await islem();
      return null;
    } on OturumYok catch (hata) {
      if (ref.mounted) {
        ref.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      }
      return hata;
    } on Exception catch (hata) {
      return hata;
    }
  }
}

/// Tek bir duyuru. Hata otomatik yeniden denenmez.
final duyuruProvider = AsyncNotifierProvider.autoDispose
    .family<DuyuruNotifier, Announcement, DuyuruAnahtari>(
      DuyuruNotifier.new,
      name: 'duyuruProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Oluşturulan ya da değişen [duyuru]'yu açık olan liste ve detay
/// durumlarına yansıtır.
void duyuruyuYansit(Ref ref, String tayfaId, Announcement duyuru) {
  final liste = duyuruListesiProvider(tayfaId);
  if (ref.exists(liste)) ref.read(liste.notifier).yansit(duyuru);
  final tek = duyuruProvider((tayfaId: tayfaId, duyuruId: duyuru.id));
  if (ref.exists(tek)) ref.read(tek.notifier).yansit(duyuru);
}
