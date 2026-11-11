import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Bir balık etkinliğinin av günlüğü (ADR-0015 §6), eskiden yeniye,
/// sayfalı. Yalnızca bellektedir (ADR-0006).
///
/// Mera gizliliği sunucunundur: bir avın yeri yalnızca sunucu döndürdüyse
/// (avcıya ve `tayfa` görünürlüğünde noktayı görebilenlere) gösterilir.
class AvGunluguNotifier extends SayfaliListeNotifier<FishingCatch> {
  AvGunluguNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  Future<SayfaliListe<FishingCatch>> build() => ilkSayfayiOku();

  @override
  Future<Sayfa<FishingCatch>> sayfaGetir(String? sayfaToken) => ref
      .read(etkinlikDeposuProvider)
      .avlar(anahtar.tayfaId, anahtar.etkinlikId, sayfaToken: sayfaToken);

  @override
  String kimlik(FishingCatch oge) => oge.id;

  /// Eklenen avı listenin sonuna koyar (aynı kimlik varsa yerine).
  void eklendi(FishingCatch av) => ogeleriDegistir(
    (avlar) => [
      for (final a in avlar)
        if (a.id != av.id) a,
      av,
    ],
  );

  /// Çıkarılan avı listeden kaldırır.
  void cikarildi(String avId) => ogeleriDegistir(
    (avlar) => [
      for (final a in avlar)
        if (a.id != avId) a,
    ],
  );
}

/// Bir etkinliğin av günlüğü; detay ekranı kapanınca bırakılır.
final avGunluguProvider = AsyncNotifierProvider.autoDispose
    .family<AvGunluguNotifier, SayfaliListe<FishingCatch>, EtkinlikAnahtari>(
      AvGunluguNotifier.new,
      name: 'avGunluguProvider',
      retry: yenidenDenemeYok,
    );
