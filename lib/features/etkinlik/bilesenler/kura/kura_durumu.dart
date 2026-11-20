import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Kurada bir eşleşme: ardışık iki yer (1–2, 3–4 …). [ikinci] yoksa tek
/// sayıda girişte son yerdir; [ilk] bay geçer.
typedef KuraEslesmesi = ({int no, EventDrawEntry ilk, EventDrawEntry? ikinci});

/// Kuranın yerlerini eşleşmelere böler: yerler sırasıyla, ardışık iki yer
/// bir eşleşme (sözleşme: `EventDraw.entries`). Eşleşmenin numarası
/// yerlerden çıkar (`(sıra + 1) ~/ 2`); sıra kaymaz, boş yer de yerinde
/// kalır.
List<KuraEslesmesi> kuraEslesmeleri(EventDraw kura) {
  final sirali = [...kura.entries]
    ..sort((a, b) => a.position.compareTo(b.position));
  final gruplar = <int, List<EventDrawEntry>>{};
  for (final yer in sirali) {
    if (yer.position < 1) continue;
    gruplar.putIfAbsent((yer.position + 1) ~/ 2, () => []).add(yer);
  }
  return [
    for (final MapEntry(key: no, value: yerler) in gruplar.entries)
      (no: no, ilk: yerler.first, ikinci: yerler.length > 1 ? yerler[1] : null),
  ];
}

/// Yer boş mu: kişi ya da takım geri çekilmiş (bay).
bool kuraYeriBos(EventDrawEntry yer) =>
    yer.userId == null && yer.teamId == null;

/// Bir etkinliğin bir kura bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef KuraKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Kuranın yeniden okunmasını gerektiren hatalar: kura başkası tarafından
/// çekilmiş, etkinliğin durumu ya da yetki değişmiş.
const Set<ProblemType> _bayatKuraHatalari = {
  ProblemType.drawAlreadyMade,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Kura bileşeninin durumu (`GET …/components/{component_key}/draw`;
/// Tayfam-Api #249), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): kura ya da etkinliğin durumu değişince REST'ten yeniden
/// okunur.
///
/// Kura bir kez çekilir ve değişmez; çekme ucu kuranın son halini döner.
/// Yetki sunucudadır; istemci yalnızca düğmeyi sadeleştirir (kesin
/// kural 5).
class KuraNotifier extends AsyncNotifier<EventDraw> {
  KuraNotifier(this.kimlik);

  final KuraKimligi kimlik;

  @override
  Future<EventDraw> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .kura(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Kurayı çeker (organizatör, moderatör, yönetici). Başarıda `null`,
  /// değilse hata döner; durum değişmez ve hata çağıranda gösterilir. Kura
  /// bayatlamışsa (ör. başkası çekmiş) yeniden okunur.
  Future<Object?> cek() async {
    try {
      final kura = await ref
          .read(etkinlikDeposuProvider)
          .kurayiCek(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
      if (ref.mounted) state = AsyncData(kura);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatKuraHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir kura bileşeninin durumu. Hata otomatik yeniden denenmez.
final kuraProvider = AsyncNotifierProvider.autoDispose
    .family<KuraNotifier, EventDraw, KuraKimligi>(
      KuraNotifier.new,
      name: 'kuraProvider',
      retry: yenidenDenemeYok,
    );
