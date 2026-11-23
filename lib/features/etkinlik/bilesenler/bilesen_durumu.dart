import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Canlı izlenen şey: bir etkinliğin bir bileşeni ([anahtar]) ya da
/// ([anahtar] `null` ise) bileşen seçimleri ve hakemleri.
typedef BilesenKimligi = ({String tayfaId, String etkinlikId, String? anahtar});

/// Bir bileşenin canlı değişim sayacı (ADR-0024 §5).
///
/// Okunduğu sürece etkinlik WebSocket'te izlenir (`event.watch`); ekran
/// kapanıp okuyan kalmayınca izleme bırakılır. `event.component_changed`
/// çerçevesi bu bileşen için gelince ve bağlantı (yeniden) kurulunca sayaç
/// artar. Çerçeve yalnızca kimlik taşır: sayacı izleyen provider bileşeni
/// REST'ten yeniden çeker. Bağlantı yoksa sayaç değişmez; ekran çekip
/// yenilemeyle çalışır.
class BilesenDegisimiNotifier extends Notifier<int> {
  BilesenDegisimiNotifier(this.kimlik);

  final BilesenKimligi kimlik;

  @override
  int build() {
    final istemci = ref.watch(realtimeIstemcisiProvider);
    final EtkinlikRef etkinlik = (
      tayfaId: kimlik.tayfaId,
      etkinlikId: kimlik.etkinlikId,
    );
    istemci.etkinligiIzle(etkinlik);
    final abonelik = istemci.olaylar.listen((olay) {
      switch (olay) {
        case EtkinlikBileseniDegisti(
              etkinlik: final degisen,
              :final bilesenAnahtari,
            )
            when degisen == etkinlik && bilesenAnahtari == kimlik.anahtar:
          state++;
        // Bağlantı yokken kaçırılan değişiklikler REST'ten okunur.
        case Baglandi():
          state++;
        default:
          break;
      }
    });
    ref.onDispose(() {
      unawaited(abonelik.cancel());
      istemci.etkinlikIzlemeyiBirak(etkinlik);
    });
    return 0;
  }
}

/// Bir bileşenin (ya da seçimlerin) canlı değişim sayacı.
final bilesenDegisimiProvider = NotifierProvider.autoDispose
    .family<BilesenDegisimiNotifier, int, BilesenKimligi>(
      BilesenDegisimiNotifier.new,
      name: 'bilesenDegisimiProvider',
    );

/// Bileşen provider'ının `build`'inde çağrılır: [bilesenAnahtari] bileşeni
/// canlı değişince (ve bağlantı yeniden kurulunca) provider yeniden
/// kurulur, yani verisini REST'ten yeniden çeker (ADR-0024 §5).
/// [bilesenAnahtari] verilmezse bileşen seçimleri ve hakemler izlenir.
void bilesenDegisiminiIzle(
  Ref ref,
  EtkinlikAnahtari etkinlik, [
  String? bilesenAnahtari,
]) {
  ref.watch(
    bilesenDegisimiProvider((
      tayfaId: etkinlik.tayfaId,
      etkinlikId: etkinlik.etkinlikId,
      anahtar: bilesenAnahtari,
    )),
  );
}

/// Etkinliğin bileşenleri ve organizatörün seçimleri
/// (`GET …/events/{event_id}/components`; ADR-0031 §1). Ekran açıkken
/// canlıdır: seçimler değişince yeniden okunur. Yalnızca bellektedir.
class EtkinlikBilesenleriNotifier extends AsyncNotifier<EventComponentList> {
  EtkinlikBilesenleriNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  Future<EventComponentList> build() {
    bilesenDegisiminiIzle(ref, anahtar);
    return ref
        .read(etkinlikDeposuProvider)
        .bilesenler(anahtar.tayfaId, anahtar.etkinlikId);
  }

  /// Baştan okur (aşağı çekince ya da "Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu ekranda gösterilir.
    }
  }

  /// Bir seçim isteğinin yanıtını gösterir.
  void guncelle(EventComponentList bilesenler) {
    state = AsyncData(bilesenler);
  }
}

/// Bir etkinliğin bileşen durumu. Hata otomatik yeniden denenmez.
final etkinlikBilesenleriProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikBilesenleriNotifier, EventComponentList, EtkinlikAnahtari>(
      EtkinlikBilesenleriNotifier.new,
      name: 'etkinlikBilesenleriProvider',
      retry: yenidenDenemeYok,
    );

/// Etkinliğin hakem atamaları (`GET …/events/{event_id}/referees`). Ekran
/// açıkken canlıdır. Okunamazsa kimse hakem sayılmaz (yetki sunucudadır).
class EtkinlikHakemleriNotifier extends AsyncNotifier<List<EventReferee>> {
  EtkinlikHakemleriNotifier(this.anahtar);

  final EtkinlikAnahtari anahtar;

  @override
  Future<List<EventReferee>> build() {
    bilesenDegisiminiIzle(ref, anahtar);
    return ref
        .read(etkinlikDeposuProvider)
        .hakemler(anahtar.tayfaId, anahtar.etkinlikId);
  }
}

/// Bir etkinliğin hakemleri. Hata otomatik yeniden denenmez.
final etkinlikHakemleriProvider = AsyncNotifierProvider.autoDispose
    .family<EtkinlikHakemleriNotifier, List<EventReferee>, EtkinlikAnahtari>(
      EtkinlikHakemleriNotifier.new,
      name: 'etkinlikHakemleriProvider',
      retry: yenidenDenemeYok,
    );

/// [kullaniciId], [bilesenAnahtari] bileşeninin (kapsamı ne olursa olsun)
/// ya da etkinliğin tamamının hakemi mi.
bool hakemMi(
  List<EventReferee> hakemler,
  String? kullaniciId,
  String bilesenAnahtari,
) =>
    kullaniciId != null &&
    hakemler.any(
      (h) =>
          h.userId == kullaniciId &&
          (h.componentKey == null || h.componentKey == bilesenAnahtari),
    );

/// Çağıranın [bilesen]'deki rolü. [durum] ve [hakemler] okunamadıysa en
/// dar rol varsayılır.
BilesenRolu bilesenRolu({
  required Event etkinlik,
  required CatalogComponent bilesen,
  required EventComponentList? durum,
  required List<EventReferee> hakemler,
  required String? kullaniciId,
}) {
  if (durum?.callerCanManage ?? false) return BilesenRolu.organizator;
  if (hakemMi(hakemler, kullaniciId, bilesenAnahtari(bilesen))) {
    return BilesenRolu.hakem;
  }
  return etkinlik.callerRsvp == RsvpStatus.going
      ? BilesenRolu.katilimci
      : BilesenRolu.uye;
}
