import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Rota: boş ya da en az 2, en çok 500 nokta (`EventRouteRequest.points`).
const int rotaEnAzNokta = 2;
const int rotaEnCokNokta = 500;

/// Rotanın nokta sayısı geçersiz mi (boş ya da 2–500 olmalı).
bool rotaHatali(List<LatLng> rota) =>
    rota.isNotEmpty &&
    (rota.length < rotaEnAzNokta || rota.length > rotaEnCokNokta);

/// Bir etkinliğin bir rota bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef RotaKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Rota bileşeninin güzergâhı (`GET …/components/{component_key}/route`;
/// Tayfam-Api #239). Bölüm açıkken canlıdır (ADR-0024 §5): bileşen
/// değişince REST'ten yeniden okunur. Noktalar organizatörün bilerek
/// paylaştığı içeriktir (Tayfam-Api ADR-0008); yalnızca bellekte tutulur,
/// loglanmaz.
class RotaNotifier extends AsyncNotifier<EventRoute> {
  RotaNotifier(this.kimlik);

  final RotaKimligi kimlik;

  @override
  Future<EventRoute> build() {
    bilesenDegisiminiIzle(ref, (
      tayfaId: kimlik.tayfaId,
      etkinlikId: kimlik.etkinlikId,
    ), kimlik.anahtar);
    return ref
        .read(etkinlikDeposuProvider)
        .rota(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Rotanın tamamını [noktalar] yapar (boşsa kaldırır). Başarıda `null`,
  /// değilse hata döner; durum değişmez ve hata çağıranda gösterilir.
  Future<Object?> kaydet(List<LatLng> noktalar) async {
    try {
      final rota = await ref
          .read(etkinlikDeposuProvider)
          .rotaYaz(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar, noktalar);
      if (ref.mounted) state = AsyncData(rota);
      return null;
    } on Exception catch (hata) {
      return hata;
    }
  }
}

/// Bir rota bileşeninin durumu. Hata otomatik yeniden denenmez.
final rotaProvider = AsyncNotifierProvider.autoDispose
    .family<RotaNotifier, EventRoute, RotaKimligi>(
      RotaNotifier.new,
      name: 'rotaProvider',
      retry: yenidenDenemeYok,
    );
