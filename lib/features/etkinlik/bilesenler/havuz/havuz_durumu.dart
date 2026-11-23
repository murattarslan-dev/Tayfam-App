import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir etkinliğin bir soru havuzu bağlantısı bileşeni: bileşen
/// uçlarındaki `{component_key}` ([anahtar]).
typedef HavuzBaglantisiKimligi = ({
  String tayfaId,
  String etkinlikId,
  String anahtar,
});

/// Bağlantının yeniden okunmasını gerektiren hatalar: durumu etkinlikle,
/// tür tanımıyla ya da havuzla değişmiş.
const Set<ProblemType> _bayatHatalar = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
  ProblemType.questionNotFound,
  ProblemType.moduleDisabled,
};

/// Soru havuzu bağlantısı bileşeninin durumu (`GET …/components/
/// {component_key}/pool-links`; Tayfam-Api #271, ADR-0037 §3): etkinliğe
/// bağlı havuz soruları, organizatörün sırasıyla. Silinen soru listede
/// görünmez. Bölüm açıkken canlıdır (ADR-0024 §5). Yalnızca bellekte
/// tutulur (ADR-0006). Yazma yetkisi için istemci yalnızca
/// `caller_can_edit`'e bakar; kararı sunucu verir (kesin kural 5).
class HavuzBaglantilariNotifier extends AsyncNotifier<EventPoolLinks> {
  HavuzBaglantilariNotifier(this.kimlik);

  final HavuzBaglantisiKimligi kimlik;

  @override
  Future<EventPoolLinks> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .havuzBaglantilari(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Bağlı soruları [soruIdleri] yapar (verilen sırayla). Başarıda `null`,
  /// değilse hata döner; durum değişmez ve hata çağıranda gösterilir.
  /// Bağlantı bayatlamışsa yeniden okunur.
  Future<Object?> yaz(List<String> soruIdleri) async {
    try {
      final yeni = await ref
          .read(etkinlikDeposuProvider)
          .havuzBaglantilariniYaz(
            kimlik.tayfaId,
            kimlik.etkinlikId,
            kimlik.anahtar,
            soruIdleri,
          );
      if (ref.mounted) state = AsyncData(yeni);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatHatalar.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir soru havuzu bağlantısı bileşeninin durumu. Hata otomatik yeniden
/// denenmez.
final havuzBaglantilariProvider = AsyncNotifierProvider.autoDispose
    .family<HavuzBaglantilariNotifier, EventPoolLinks, HavuzBaglantisiKimligi>(
      HavuzBaglantilariNotifier.new,
      name: 'havuzBaglantilariProvider',
      retry: yenidenDenemeYok,
    );

/// Bağlanacak soruların seçimi için tayfanın soru havuzu (sayfalı, yeniden
/// eskiye). Seçim sayfası açıkken yaşar; yalnızca bellektedir.
class HavuzSecimListesiNotifier extends SayfaliListeNotifier<Question> {
  HavuzSecimListesiNotifier(this.tayfaId);

  final String tayfaId;

  @override
  Future<SayfaliListe<Question>> build() => ilkSayfayiOku();

  @override
  Future<Sayfa<Question>> sayfaGetir(String? sayfaToken) => ref
      .read(etkinlikDeposuProvider)
      .havuzSorulari(tayfaId, sayfaToken: sayfaToken);

  @override
  String kimlik(Question oge) => oge.id;
}

/// Seçim sayfasındaki havuz soruları. Hata otomatik yeniden denenmez.
final havuzSecimListesiProvider = AsyncNotifierProvider.autoDispose
    .family<HavuzSecimListesiNotifier, SayfaliListe<Question>, String>(
      HavuzSecimListesiNotifier.new,
      name: 'havuzSecimListesiProvider',
      retry: yenidenDenemeYok,
    );
