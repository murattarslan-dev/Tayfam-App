import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/duyuru/data/duyuru_deposu.dart';

/// Tayfa ana sayfasında sabitlenenlerin ardından gösterilen en son duyuru
/// sayısı (ADR-0015 §1).
const int anaSayfaDuyuruSayisi = 2;

/// Duyuruların sırası (ADR-0015 §2, sunucuyla aynı): sabitlenenler önce,
/// sonra yeniden eskiye.
List<Announcement> duyuruSirala(Iterable<Announcement> duyurular) {
  final sirali = [...duyurular];
  sirali.sort(_duyuruSirasi);
  return sirali;
}

int _duyuruSirasi(Announcement a, Announcement b) {
  if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
  final zaman = b.createdAt.compareTo(a.createdAt);
  return zaman != 0 ? zaman : a.id.compareTo(b.id);
}

/// Tayfa ana sayfasındaki duyurular: bütün sabitlenenler, sonra en son
/// [anaSayfaDuyuruSayisi] duyuru (ADR-0015 §1). [duyurular] sıralıdır.
List<Announcement> anaSayfaDuyurulari(List<Announcement> duyurular) {
  var digerleri = 0;
  return [
    for (final d in duyurular)
      if (d.pinned || digerleri++ < anaSayfaDuyuruSayisi) d,
  ];
}

/// Bir tayfanın duyuruları (`GET /v1/tayfas/{tayfa_id}/announcements`,
/// sayfalı; ADR-0015 §2). Tayfaya bağlıdır: `family(tayfaId)` +
/// `autoDispose`; ana sayfa, liste ve detay aynı durumu paylaşır. Oturum
/// değişince yeniden kurulur (ADR-0001 kural 8). Yalnızca bellektedir
/// (ADR-0006).
class DuyuruListesiNotifier extends SayfaliListeNotifier<Announcement> {
  DuyuruListesiNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<SayfaliListe<Announcement>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(duyuruDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Announcement>> sayfaGetir(String? sayfaToken) {
    final depo = ref.read(duyuruDeposuProvider);
    return depo.sayfa(tayfaId, sayfaToken: sayfaToken);
  }

  @override
  String kimlik(Announcement oge) => oge.id;

  /// Oluşturulan ya da değişen [duyuru]'yu listeye yansıtır ve sırayı
  /// korur.
  void yansit(Announcement duyuru) => ogeleriDegistir(
    (ogeler) => duyuruSirala([
      duyuru,
      for (final d in ogeler)
        if (d.id != duyuru.id) d,
    ]),
  );

  /// Silinen duyuruyu listeden çıkarır.
  void cikar(String duyuruId) => ogeleriDegistir(
    (ogeler) => [
      for (final d in ogeler)
        if (d.id != duyuruId) d,
    ],
  );
}

/// Bir tayfanın duyuru listesi. Hata otomatik yeniden denenmez; ekranlar
/// "Tekrar dene" sunar, aşağı çekince yenilenir.
final duyuruListesiProvider = AsyncNotifierProvider.autoDispose
    .family<DuyuruListesiNotifier, SayfaliListe<Announcement>, String>(
      DuyuruListesiNotifier.new,
      name: 'duyuruListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
