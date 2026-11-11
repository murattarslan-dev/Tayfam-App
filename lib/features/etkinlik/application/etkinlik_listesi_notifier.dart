import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Tayfa ana sayfasında gösterilen en yakın etkinlik sayısı (ADR-0015 §1).
const int anaSayfaEtkinlikSayisi = 3;

/// Etkinliklerin sırası (sunucuyla aynı): başlangıç zamanına göre.
List<Event> etkinlikSirala(Iterable<Event> etkinlikler) {
  final sirali = [...etkinlikler];
  sirali.sort(_etkinlikSirasi);
  return sirali;
}

int _etkinlikSirasi(Event a, Event b) {
  final zaman = a.startsAt.compareTo(b.startsAt);
  return zaman != 0 ? zaman : a.id.compareTo(b.id);
}

/// Bir tayfanın yaklaşan (bitmemiş) etkinlikleri
/// (`GET /v1/tayfas/{tayfa_id}/events`, sayfalı; ADR-0015 §1, §3).
///
/// Tayfaya bağlıdır: `family(tayfaId)` + `autoDispose`; ana sayfa ve
/// etkinlik listesi aynı durumu paylaşır. Oturum değişince yeniden kurulur
/// (ADR-0001 kural 8). Yalnızca bellektedir (ADR-0006).
class EtkinlikListesiNotifier extends SayfaliListeNotifier<Event> {
  EtkinlikListesiNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<SayfaliListe<Event>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(etkinlikDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Event>> sayfaGetir(String? sayfaToken) {
    final depo = ref.read(etkinlikDeposuProvider);
    return depo.sayfa(tayfaId, sayfaToken: sayfaToken);
  }

  @override
  String kimlik(Event oge) => oge.id;

  /// Oluşturulan ya da değişen [etkinlik]'i listeye yansıtır ve sırayı
  /// korur.
  void yansit(Event etkinlik) => ogeleriDegistir(
    (ogeler) => etkinlikSirala([
      etkinlik,
      for (final e in ogeler)
        if (e.id != etkinlik.id) e,
    ]),
  );
}

/// Bir tayfanın yaklaşan etkinlikleri. Hata otomatik yeniden denenmez;
/// ekranlar "Tekrar dene" sunar, aşağı çekince yenilenir.
final etkinlikListesiProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikListesiNotifier, SayfaliListe<Event>, String>(
      EtkinlikListesiNotifier.new,
      name: 'etkinlikListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
