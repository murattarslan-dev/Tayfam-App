import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';

/// Tayfa ana sayfasında gösterilen en çok açık anket sayısı.
const int anaSayfaAnketSayisi = 1;

/// Anket listesinin anahtarı: tayfa ve isteğe bağlı etkinlik süzgeci
/// (`event_id`; `null` ise tayfanın bütün anketleri).
typedef AnketListesiAnahtari = ({String tayfaId, String? etkinlikId});

/// Tayfa ana sayfasındaki "Açık anketler": eldeki listede kapanmamış
/// olanlardan en yeni [anaSayfaAnketSayisi] tanesi.
List<Poll> anaSayfaAnketleri(List<Poll> anketler, DateTime simdi) => [
  for (final a in anketler)
    if (!anketKapali(a, simdi)) a,
].take(anaSayfaAnketSayisi).toList();

/// Bir tayfanın anketleri (`GET /v1/tayfas/{tayfa_id}/polls`, sayfalı,
/// yeniden eskiye; ADR-0018 §5). Açık ve kapanmış anketler birlikte gelir.
///
/// Tayfaya bağlıdır: `family` + `autoDispose`; ana sayfa ve liste aynı
/// durumu paylaşır. Oturum değişince yeniden kurulur. Yalnızca
/// bellektedir (ADR-0006).
class AnketListesiNotifier extends SayfaliListeNotifier<Poll> {
  AnketListesiNotifier(this.anahtar);

  final AnketListesiAnahtari anahtar;

  @override
  Future<SayfaliListe<Poll>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(anketDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Poll>> sayfaGetir(String? sayfaToken) => ref
      .read(anketDeposuProvider)
      .sayfa(
        anahtar.tayfaId,
        etkinlikId: anahtar.etkinlikId,
        sayfaToken: sayfaToken,
      );

  @override
  String kimlik(Poll oge) => oge.id;

  /// Değişen [anket]'i (oy, kapanma) yerinde günceller; listede yoksa bir
  /// şey yapmaz.
  void guncelle(Poll anket) => ogeleriDegistir(
    (ogeler) => [for (final a in ogeler) a.id == anket.id ? anket : a],
  );

  /// Yeni açılan [anket]'i listenin başına ekler (liste yeniden eskiye).
  void ekle(Poll anket) => ogeleriDegistir(
    (ogeler) => [
      anket,
      for (final a in ogeler)
        if (a.id != anket.id) a,
    ],
  );
}

/// Bir tayfanın (ya da etkinliğin) anket listesi. Hata otomatik yeniden
/// denenmez; ekranlar "Tekrar dene" sunar, aşağı çekince yenilenir.
final anketListesiProvider = AsyncNotifierProvider.autoDispose
    .family<AnketListesiNotifier, SayfaliListe<Poll>, AnketListesiAnahtari>(
      AnketListesiNotifier.new,
      name: 'anketListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;

/// Değişen ya da yeni açılan [anket]'i [tayfaId] tayfasının açık olan
/// listelerine yansıtır: tayfanın bütün anketleri ve (bağlıysa)
/// etkinliğin anketleri.
void anketiListelereYansit(
  Ref ref,
  String tayfaId,
  Poll anket, {
  bool yeni = false,
}) {
  final anahtarlar = <AnketListesiAnahtari>[
    (tayfaId: tayfaId, etkinlikId: null),
    if (anket.eventId case final etkinlikId?)
      (tayfaId: tayfaId, etkinlikId: etkinlikId),
  ];
  for (final anahtar in anahtarlar) {
    final liste = anketListesiProvider(anahtar);
    if (!ref.read(liste.exists)) continue;
    final notifier = ref.read(liste.notifier);
    if (yeni) {
      notifier.ekle(anket);
    } else {
      notifier.guncelle(anket);
    }
  }
}
