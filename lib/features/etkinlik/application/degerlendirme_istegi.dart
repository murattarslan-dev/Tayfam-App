import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/degerlendirme/magaza_degerlendirmesi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';

/// Sayfa açıldıktan sonra mağaza penceresi istenmeden önce beklenen süre
/// (ADR-0016 §3): kullanıcı sayfayı görür, bir işe başlamışsa istenmez.
const Duration degerlendirmeGecikmesi = Duration(seconds: 2);

/// Kullanıcının "ilk etkinliği tamamlaması" (ADR-0016 §1): cevabı
/// "Geliyorum" olan, iptal edilmemiş ve bitmiş bir etkinlik. Katılımın
/// doğrulanması (varış bildirimi) aranmaz; organizatör de aynı kurala
/// tabidir.
bool etkinlikTamamlandi(Event etkinlik, DateTime simdi) =>
    etkinlik.callerRsvp == RsvpStatus.going &&
    !iptalEdildi(etkinlik) &&
    !simdi.isBefore(etkinlik.endsAt);

/// Uygulama değerlendirme penceresinin cihazda bir kez istenmesi
/// (ADR-0016).
///
/// Durum, bu çalışmada artık istenmeyecek olmasıdır (istendi, bayrak
/// bulundu ya da mağaza kullanılamıyor). Kalıcı bayrak
/// [CihazBayragi.degerlendirmeIstendi]'dir ve cihaza aittir: bu notifier
/// oturuma bağlı değildir, oturum kapanınca ne durum ne bayrak sıfırlanır.
/// Sunucuya hiçbir şey gönderilmez; hiçbir şey loglanmaz.
class DegerlendirmeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  CihazAyarlariDeposu get _depo => ref.read(cihazAyarlariDeposuProvider);

  /// [etkinlikler] arasında tamamlanmış biri varsa ve pencere bu cihazda
  /// daha önce istenmediyse, mağaza da kullanılabiliyorsa `true`. Hata
  /// sessizce `false` olur.
  Future<bool> adayMi(Iterable<Event> etkinlikler) async {
    if (state) return false;
    final simdi = ref.read(etkinlikSaatiProvider)();
    if (!etkinlikler.any((e) => etkinlikTamamlandi(e, simdi))) return false;
    try {
      if (await _depo.bayrakOku(CihazBayragi.degerlendirmeIstendi)) {
        if (ref.mounted) state = true;
        return false;
      }
      if (!await ref.read(magazaDegerlendirmesiProvider).kullanilabilirMi()) {
        // Mağaza yoksa (ör. Play hizmetleri yok) sessizce hiçbir şey
        // yapılmaz; bayrak yazılmaz, bu çalışmada yeniden sorulmaz.
        if (ref.mounted) state = true;
        return false;
      }
    } on Exception {
      return false;
    }
    return ref.mounted && !state;
  }

  /// Bayrağı yazar ve mağaza penceresini ister; sonucu beklenmez ve
  /// yorumlanmaz. Bayrak yazılamazsa istenmez (bir kez kuralı). Bu
  /// çalışmada en çok bir kez denenir.
  Future<void> iste() async {
    if (state) return;
    state = true;
    try {
      await _depo.bayrakKoy(CihazBayragi.degerlendirmeIstendi);
      await ref.read(magazaDegerlendirmesiProvider).iste();
    } on Exception {
      // Mağaza sonucu bildirmez; hata da yok sayılır.
    }
  }
}

/// Değerlendirme penceresi isteği; uygulama boyunca yaşar.
final degerlendirmeProvider = NotifierProvider<DegerlendirmeNotifier, bool>(
  DegerlendirmeNotifier.new,
  name: 'degerlendirmeProvider',
);
