import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Takma adın en çok uzunluğu (`EventGuestPlayerRequest.nickname`).
const int misafirAdiEnCok = 24;

/// Misafir oyuncuların okunduğu ve eklendiği bileşen: misafir alan
/// (`guests: true`) bir yazboz bileşeni, `{component_key}` ile. Misafir
/// etkinliğindir; misafir alan her yazboz bileşeni aynı listeyi döner.
typedef MisafirKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// [bilesen] misafir oyuncu alan bir yazboz bileşeni mi (ADR-0031 §4;
/// Tayfam-Api ADR-0037 §6).
bool misafirAlir(CatalogComponent bilesen) =>
    bilesen.kind == 'scoreboard' &&
    BilesenParametreleri(bilesen.params).mantik('guests');

/// [tur] tür tanımında misafir alan ilk yazboz bileşeninin anahtarı; yoksa
/// `null`.
String? misafirBileseni(CatalogEventType? tur) {
  for (final b in turBilesenleri(tur)) {
    if (misafirAlir(b)) return bilesenAnahtari(b);
  }
  return null;
}

/// Takma adın baştaki ve sondaki boşluk atılmış hali; boşsa ya da 24
/// karakteri aşıyorsa `null`. Denetim ve biçim karakterlerini sunucu
/// reddeder (`validation`).
String? misafirAdiTemiz(String metin) {
  final ad = metin.trim();
  if (ad.isEmpty || ad.runes.length > misafirAdiEnCok) return null;
  return ad;
}

/// [liste]'deki [id] misafiri; yoksa `null`.
EventGuestPlayer? misafirBul(EventGuestPlayers? liste, String id) {
  for (final g in liste?.guests ?? const <EventGuestPlayer>[]) {
    if (g.id == id) return g;
  }
  return null;
}

/// Misafir listesinin yeniden okunmasını gerektiren hatalar.
const Set<ProblemType> _bayatMisafirHatalari = {
  ProblemType.guestPlayersDisabled,
  ProblemType.guestPlayerNotFound,
  ProblemType.guestPlayerInUse,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Bir misafir işlemi: depoda çalışır, listenin güncel halini döner.
typedef MisafirYazimi =
    Future<EventGuestPlayers> Function(EtkinlikDeposu depo, MisafirKimligi k);

/// Etkinliğin misafir oyuncuları (`GET …/components/{component_key}/
/// guests`; Tayfam-Api #252). Misafir hesabı olmayan, yalnızca takma adla
/// oynayan kişidir; profili yoktur. Takma ad etkinliğin bitiminden 30 gün
/// sonra sunucuda silinir (alan gelmez). Liste yalnızca bellektedir
/// (ADR-0006) ve takma ad log'a yazılmaz; bileşen canlı değişince yeniden
/// okunur (ADR-0024 §5). Yetki sunucudadır (kesin kural 5).
class MisafirNotifier extends AsyncNotifier<EventGuestPlayers> {
  MisafirNotifier(this.kimlik);

  final MisafirKimligi kimlik;

  @override
  Future<EventGuestPlayers> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    return ref
        .read(etkinlikDeposuProvider)
        .misafirler(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu çağıranda gösterilir.
    }
  }

  /// Misafir ekler; masanın hakemi [masaId] ile ekler.
  Future<Object?> ekle(String takmaAd, {String? masaId}) => _yaz(
    (d, k) => d.misafirEkle(
      k.tayfaId,
      k.etkinlikId,
      k.anahtar,
      EventGuestPlayerRequest(nickname: takmaAd, tableId: masaId),
    ),
  );

  /// Misafiri siler (masada ya da kurada yeri yoksa).
  Future<Object?> sil(String misafirId) => _yaz(
    (d, k) => d.misafiriSil(k.tayfaId, k.etkinlikId, k.anahtar, misafirId),
  );

  /// Başarıda `null`, değilse hata döner; hata çağıranda gösterilir.
  Future<Object?> _yaz(MisafirYazimi islem) async {
    try {
      final liste = await islem(ref.read(etkinlikDeposuProvider), kimlik);
      if (ref.mounted) state = AsyncData(liste);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatMisafirHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir etkinliğin misafir oyuncuları. Hata otomatik yeniden denenmez.
final misafirProvider = AsyncNotifierProvider.autoDispose
    .family<MisafirNotifier, EventGuestPlayers, MisafirKimligi>(
      MisafirNotifier.new,
      name: 'misafirProvider',
      retry: yenidenDenemeYok,
    );

/// Etkinlik detayı açıkken etkinliğin türü ve sürümü; okunmadıysa `null`.
typedef EtkinlikTuru = ({String tur, int? surum});

/// [etkinlik]'in türü ve sürümü (detay ekranının okuduğu etkinlikten).
EtkinlikTuru? etkinlikTuru(WidgetRef ref, EtkinlikAnahtari etkinlik) =>
    ref.watch(
      etkinlikDetayProvider(etkinlik).select((d) {
        final e = d.value;
        return e == null ? null : (tur: e.type, surum: e.typeVersion);
      }),
    );
