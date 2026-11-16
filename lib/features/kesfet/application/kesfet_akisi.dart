import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/kesfet/application/kesfet_ortak.dart';
import 'package:tayfam/features/kesfet/data/kesfet_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

/// Keşfet akışı (`GET /v1/discover/events`; Tayfam-Api ADR-0033 §4;
/// istemci ADR-0027 §2). En çok 50 öğe, sunucunun sırasıyla; sayfalanmaz.
///
/// Oturum boyunca bellekte yaşar (ADR-0006): Keşfet girişleri bu
/// sağlayıcının okunup okunmadığına bakar ([kesfetAcikProvider]); bayrak
/// kapalıysa hata `feature-disabled`'dır. Oturum değişince sıfırlanır.
/// Ekran aşağı çekilince yenilenir.
class KesfetAkisiNotifier extends AsyncNotifier<List<DiscoverItem>> {
  @override
  Future<List<DiscoverItem>> build() {
    oturumuDenetle(ref);
    return ref.watch(kesfetDeposuProvider).akis();
  }

  /// Akışı yeniden okur; önceki liste hata olursa da görünür kalır.
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumda tutulur; ekran gösterir.
    }
  }
}

/// Keşfet akışı.
final kesfetAkisiProvider =
    AsyncNotifierProvider<KesfetAkisiNotifier, List<DiscoverItem>>(
      KesfetAkisiNotifier.new,
      name: 'kesfetAkisiProvider',
      retry: yenidenDenemeYok,
    );

/// Keşfet girişleri görünür mü: akış bir kez okunduysa ve son cevap
/// `feature-disabled` değilse. Akış okunamadıysa (başka bir hata) da
/// giriş görünmez; kapalı ya da çalışmayan bir özellik vaat edilmez
/// (30-kesfet-ve-guvenlik, karar 1).
final kesfetAcikProvider = Provider<bool>((ref) {
  final akis = ref.watch(kesfetAkisiProvider);
  if (ozellikKapali(akis.error)) return false;
  return akis.hasValue;
}, name: 'kesfetAcikProvider');

/// Keşfet'ten katılım isteğinin bir karttaki aşaması.
enum KatilimAsamasi {
  /// İstek gidiyor; düğme pasif.
  gonderiliyor,

  /// İstek bekliyor (yöneticiler onaylayınca katılınır).
  gonderildi,
}

/// Keşfet'ten katılımın sonucu.
sealed class KesfetKatilimSonucu {
  const KesfetKatilimSonucu();
}

/// İstek gönderildi ya da zaten bekliyordu.
final class KatilimGonderildi extends KesfetKatilimSonucu {
  const KatilimGonderildi();
}

/// Kişi bu tayfanın zaten üyesi.
final class ZatenUye extends KesfetKatilimSonucu {
  const ZatenUye();
}

/// Tayfa artık akışta değil (`tayfa-not-found`); akış yenilenir.
final class ArtikAkistaDegil extends KesfetKatilimSonucu {
  const ArtikAkistaDegil();
}

/// Başka bir hata; metni ortak eşlemeden.
final class KatilimHatasi extends KesfetKatilimSonucu {
  const KatilimHatasi(this.hata);

  final Object hata;
}

/// Keşfet kartlarındaki katılım istekleri: tayfa kimliği → aşama.
/// Ekran kapanınca bırakılır (yalnızca bellek).
class KesfetKatilimNotifier extends Notifier<Map<String, KatilimAsamasi>> {
  @override
  Map<String, KatilimAsamasi> build() => const {};

  /// [tayfaId]'ye katılım isteği gönderir; istek her zaman onay bekler
  /// (sözleşme). Başarıda tayfa listesi yenilenir, bekleyen istek panelde
  /// görünür (ADR-0014 §2). Süren istek varken `null`.
  Future<KesfetKatilimSonucu?> katil(String tayfaId) async {
    if (state.containsKey(tayfaId)) return null;
    _ayarla(tayfaId, KatilimAsamasi.gonderiliyor);
    Object? hata;
    try {
      await ref.read(kesfetDeposuProvider).katil(tayfaId);
    } on Exception catch (e) {
      hata = e;
    }
    if (!ref.mounted) return null;
    final sonuc = switch (hata) {
      null => const KatilimGonderildi(),
      _ when problemMi(hata, ProblemType.alreadyPending) =>
        const KatilimGonderildi(),
      _ when problemMi(hata, ProblemType.alreadyMember) => const ZatenUye(),
      _ when problemMi(hata, ProblemType.tayfaNotFound) =>
        const ArtikAkistaDegil(),
      final Object e => KatilimHatasi(e),
    };
    if (sonuc is KatilimGonderildi) {
      _ayarla(tayfaId, KatilimAsamasi.gonderildi);
      // Liste alınamazsa bekleyen istek bir sonraki yenilemede görünür.
      await ref.read(tayfalarimProvider.notifier).yenile();
    } else {
      state = {
        for (final girdi in state.entries)
          if (girdi.key != tayfaId) girdi.key: girdi.value,
      };
      if (sonuc is ArtikAkistaDegil) {
        await ref.read(kesfetAkisiProvider.notifier).yenile();
      }
    }
    return sonuc;
  }

  void _ayarla(String tayfaId, KatilimAsamasi asama) {
    state = {...state, tayfaId: asama};
  }
}

/// Keşfet kartlarındaki katılım istekleri.
final kesfetKatilimProvider =
    NotifierProvider.autoDispose<
      KesfetKatilimNotifier,
      Map<String, KatilimAsamasi>
    >(KesfetKatilimNotifier.new, name: 'kesfetKatilimProvider');
