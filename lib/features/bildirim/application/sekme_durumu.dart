import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';

/// Bildirimler sekmesinin üstündeki mor izin kartı açılabilir mi (karar
/// 5; istemci ADR-0019 §3).
///
/// Push'un olduğu derlemede, açıklama kartı daha önce kabul ya da ret ile
/// kapatılmadıysa (`CihazBayragi.bildirimIzniSoruldu` yoksa) `true`'dur.
/// "Şimdi değil" mevcut erteleme kuralıdır: bayrak konur ve kart bir daha
/// kendiliğinden çıkmaz; izin Profil → Bildirim ayarları'ndan açılır.
/// Cihazdaki iznin verilmiş olması ayrıca ekranda denetlenir.
class IzinKartiNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    if (!ref.watch(pushPlatformuProvider).etkin) return false;
    final ayarlar = ref.watch(cihazAyarlariDeposuProvider);
    try {
      return !await ayarlar.bayrakOku(CihazBayragi.bildirimIzniSoruldu);
    } on Exception {
      // Okunamazsa sorulmuş sayılır: kart yanlışlıkla tekrar çıkmasın.
      return false;
    }
  }

  /// Kart "İzin ver" ya da "Şimdi değil" ile kapandı.
  void kapat() => state = const AsyncData(false);
}

/// Bildirimler sekmesindeki izin kartı; ekran kapanınca bırakılır.
final izinKartiProvider =
    AsyncNotifierProvider.autoDispose<IzinKartiNotifier, bool>(
      IzinKartiNotifier.new,
      name: 'izinKartiProvider',
      retry: _yenidenDenemeYok,
    );

/// Güvenlik uyarısı kartındaki etkinliğin adı (karar 3; `GET
/// /v1/tayfas/{tayfa_id}/events/{event_id}`). Yalnızca ad tutulur,
/// yalnızca bellektedir (ADR-0006). Okunamazsa kart adsız gösterilir.
class UyariEtkinligiNotifier extends AsyncNotifier<String> {
  UyariEtkinligiNotifier(this.etkinlik);

  /// Uyarının tayfası ve etkinliği (doğrulanmış kimlikler).
  final ({String tayfaId, String etkinlikId}) etkinlik;

  @override
  Future<String> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(etkinlikDeposuProvider);
    final olay = await depo.etkinlik(etkinlik.tayfaId, etkinlik.etkinlikId);
    return olay.title;
  }
}

/// Güvenlik uyarısındaki etkinliğin adı; kart kapanınca bırakılır.
final uyariEtkinligiProvider = AsyncNotifierProvider.autoDispose
    .family<
      UyariEtkinligiNotifier,
      String,
      ({String tayfaId, String etkinlikId})
    >(
      UyariEtkinligiNotifier.new,
      name: 'uyariEtkinligiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
