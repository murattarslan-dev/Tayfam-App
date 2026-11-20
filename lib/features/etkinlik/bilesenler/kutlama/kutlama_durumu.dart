import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir etkinliğin bir kutlama bileşeni: bileşen uçlarındaki
/// `{component_key}` ([anahtar]) ve tanımdaki kaynak bileşenin anahtarı
/// ([kaynak], `source` parametresi). Kaynaklı kutlamada kazananlar
/// kaynağın kaydedilmiş sonucundan hesaplanır; kaynak değişince canlı olay
/// kaynağın anahtarıyla gelir, kutlama onunla da yeniden okunur.
typedef KutlamaKimligi = ({
  String tayfaId,
  String etkinlikId,
  String anahtar,
  String? kaynak,
});

/// Sözleşmedeki elle seçilen kazanan sınırları (`winner_ids`, 1–10).
const int kutlamaKazananEnAz = 1;
const int kutlamaKazananEnCok = 10;

/// Kazananlar kaynaktan mı hesaplanıyor (yoksa organizatör elle seçer).
bool kutlamaKaynakli(EventCelebration kutlama) => kutlama.source != null;

/// Kaynağın türü uygulamanın bu sürümünce tanınıyor mu (elle seçilen
/// kutlamada kaynak yoktur, her zaman tanınır).
bool kutlamaKaynagiTanindi(EventCelebration kutlama) =>
    kutlama.sourceKind != EventCelebrationSourceKind.unknown;

/// Kazanan elle seçilen kişilerin kimlikleri (formun ilk seçimi).
List<String> kutlamaKisileri(EventCelebration kutlama) => [
  for (final k in kutlama.winners) ?k.userId,
];

/// Kutlamanın yeniden okunmasını gerektiren hatalar: durumu etkinlikle,
/// tür tanımıyla ya da kaynağın sonucuyla değişmiş.
const Set<ProblemType> _bayatKutlamaHatalari = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.celebrationNotStarted,
  ProblemType.celebrationNoWinner,
};

/// Kutlama bileşeni (`GET …/components/{component_key}/celebration`;
/// Tayfam-Api #255), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): bileşen ya da kaynak bileşen değişince REST'ten yeniden
/// okunur.
///
/// Kazananlar yalnızca bellekte tutulur ve loglanmaz (ADR-0006). Gizli
/// kutlamada (`hidden`) liste boştur. İlan eden uç kutlamanın güncel
/// halini döner; durum onunla değişir. Yetki sunucudadır; istemci yalnızca
/// düğmeleri sadeleştirir (kesin kural 5).
class KutlamaNotifier extends AsyncNotifier<EventCelebration> {
  KutlamaNotifier(this.kimlik);

  final KutlamaKimligi kimlik;

  @override
  Future<EventCelebration> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    final kaynak = kimlik.kaynak;
    if (kaynak != null && kaynak != kimlik.anahtar) {
      bilesenDegisiminiIzle(ref, etkinlik, kaynak);
    }
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .kutlama(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// Kazananı ilan eder. Kaynaklı kutlamada [kazananlar] verilmez (gövde
  /// boş nesnedir); elle seçilende 1–10 kişi. Başarıda `null`, değilse
  /// hata döner; durum değişmez ve hata çağıranda gösterilir. Kutlama
  /// bayatlamışsa yeniden okunur.
  Future<Object?> ilanEt([List<String>? kazananlar]) async {
    try {
      final kutlama = await ref
          .read(etkinlikDeposuProvider)
          .kutlamayiIlanEt(
            kimlik.tayfaId,
            kimlik.etkinlikId,
            kimlik.anahtar,
            kazananlar,
          );
      if (ref.mounted) state = AsyncData(kutlama);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatKutlamaHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir kutlama bileşeninin durumu. Hata otomatik yeniden denenmez.
final kutlamaProvider = AsyncNotifierProvider.autoDispose
    .family<KutlamaNotifier, EventCelebration, KutlamaKimligi>(
      KutlamaNotifier.new,
      name: 'kutlamaProvider',
      retry: yenidenDenemeYok,
    );
