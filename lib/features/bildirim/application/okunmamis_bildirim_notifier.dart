import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/bildirim/data/bildirim_deposu.dart';

/// Bildirimler sekmesinin okunmamış sayısı (rozet; ADR-0018 §3).
///
/// - Oturum açıkken `GET /v1/notifications/unread-count` ile okunur; oturum
///   açık değilse 0'dır ve istek yapılmaz. Oturum değişince yeniden kurulur
///   (ADR-0001 kural 8).
/// - Uygulama ön plana dönünce ve Bildirimler sekmesi açılınca [yenile]
///   çağrılır. WebSocket `notification` olayı geldiğinde de aynı yol
///   kullanılır (ADR-0007; dalga 2).
/// - Okundu işaretleme sonrasında sayı yerelde düşürülür ([azalt],
///   [sifirla]); doğrusu bir sonraki [yenile]'de sunucudan gelir.
/// - Yalnızca bellektedir (ADR-0006).
class OkunmamisBildirimNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final oturum = ref.watch(oturumDurumuProvider);
    final depo = ref.watch(bildirimDeposuProvider);
    if (oturum != OturumDurumu.acik) return 0;
    return depo.okunmamisSayisi();
  }

  /// Sayıyı sunucudan yeniden okur. Okunamazsa eldeki sayı kalır; hata
  /// fırlatmaz (rozet bir hata göstermez).
  Future<void> yenile() async {
    if (ref.read(oturumDurumuProvider) != OturumDurumu.acik) return;
    try {
      final sayi = await ref.read(bildirimDeposuProvider).okunmamisSayisi();
      if (ref.mounted) state = AsyncData(sayi);
    } on Exception {
      // Rozet eldeki değerle kalır; sonraki yenilemede düzelir.
    }
  }

  /// Bir bildirim okundu işaretlenince sayıyı bir azaltır (0'ın altına
  /// inmez).
  void azalt() {
    final sayi = state.value;
    if (sayi != null && sayi > 0) state = AsyncData(sayi - 1);
  }

  /// Hepsi okundu sayılınca sayıyı sıfırlar.
  void sifirla() => state = const AsyncData(0);
}

/// Okunmamış bildirim sayısı. Kabuk boyunca yaşar (açıkça kalıcı;
/// ADR-0001 kural 4). Hata otomatik yeniden denenmez; sonraki yenileme
/// (ön plana dönüş, sekmeyi açma) yeniden okur.
final okunmamisBildirimProvider =
    AsyncNotifierProvider<OkunmamisBildirimNotifier, int>(
      OkunmamisBildirimNotifier.new,
      name: 'okunmamisBildirimProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
