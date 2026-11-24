import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`EventScoreTableRequest`, `EventScoreEntry`).
const int masaAdiEnCok = 30;
const int yazbozYerEnCok = 50;
const int yazbozHedefEnCok = 100000;
const int yazbozPuanSiniri = 1000000;

/// Bir etkinliğin bir yazboz bileşeni: bileşen uçlarındaki
/// `{component_key}` ile.
typedef YazbozKimligi = ({String tayfaId, String etkinlikId, String anahtar});

/// Yer seçimindeki kişiler: etkinliğe "Geliyorum" diyenler.
KatilimcilarAnahtari yazbozKatilimcilari(YazbozKimligi kimlik) => (
  tayfaId: kimlik.tayfaId,
  etkinlikId: kimlik.etkinlikId,
  durum: ListEventAttendeesStatus.going,
);

/// [anahtar] ön ayarı; yoksa `null`.
EventScorePreset? yazbozOnAyari(EventScoreboard yazboz, String? anahtar) {
  if (anahtar == null) return null;
  for (final on in yazboz.presets) {
    if (on.key == anahtar) return on;
  }
  return null;
}

/// Yeni masada seçilebilen ön ayarlar (emekliler eski masalarda görünür).
List<EventScorePreset> yazbozSecilebilirOnAyarlar(EventScoreboard yazboz) => [
  for (final on in yazboz.presets)
    if (!on.retired) on,
];

/// Yeni masanın kuralı: ön ayarın verdiği, yoksa bileşeninki.
EventScoreRules yazbozMasaKurali(EventScoreboard yazboz, EventScorePreset? on) {
  final b = yazboz.rules;
  final o = on?.rules;
  return EventScoreRules(
    side: o?.side ?? b.side,
    rounds: o?.rounds ?? b.rounds,
    winner: o?.winner ?? b.winner,
    result: o?.result ?? b.result,
    target: o?.target ?? b.target,
    bestOf: o?.bestOf ?? b.bestOf,
  );
}

/// Masada yeni masa açılabilir mi (sınır dolmadı).
bool yazbozMasaAcilabilir(EventScoreboard yazboz) =>
    yazboz.callerCanManage && yazboz.tables.length < yazboz.maxTables;

/// Masanın yerleri sırasıyla.
List<EventScorePlayer> yazbozYerleri(EventScoreTable masa) =>
    [...masa.players]..sort((a, b) => a.position.compareTo(b.position));

/// Masanın elleri numarasıyla.
List<EventScoreRound> yazbozElleri(EventScoreTable masa) =>
    [...masa.rounds]..sort((a, b) => a.number.compareTo(b.number));

/// Masanın son eli; el yoksa `null`. Yalnızca son el düzeltilir ve silinir.
EventScoreRound? yazbozSonEl(EventScoreTable masa) {
  final eller = yazbozElleri(masa);
  return eller.isEmpty ? null : eller.last;
}

/// Sıralamanın bir satırı: yer (masada yoksa `null`) ve kazanan mı.
typedef YazbozSirasi = ({
  EventScoreStanding sira,
  EventScorePlayer? yer,
  bool kazanan,
});

/// Masanın sıralaması sunucunun verdiği sırayla (sıra, sonra yer); biten
/// masada `winner_ids`'teki yerler kazanandır (beraberlikte birden çok).
List<YazbozSirasi> yazbozSiralamasi(EventScoreTable masa) {
  final yerler = {for (final y in masa.players) y.id: y};
  final kazananlar = masa.status == EventScoreTableStatus.finished
      ? masa.winnerIds.toSet()
      : const <String>{};
  final sirali = [...masa.standings]
    ..sort((a, b) {
      final fark = a.rank.compareTo(b.rank);
      if (fark != 0) return fark;
      final ay = yerler[a.playerId]?.position ?? 0;
      final by = yerler[b.playerId]?.position ?? 0;
      return ay.compareTo(by);
    });
  return [
    for (final s in sirali)
      (
        sira: s,
        yer: yerler[s.playerId],
        kazanan: kazananlar.contains(s.playerId),
      ),
  ];
}

/// Eşli masadaki yer sayısı (Tayfam-Api ADR-0044 §2).
const int yazbozEsliYer = 4;

/// Kural eşli oyun mu (`side: pair`): 4 kişi, karşılıklı oturanlar eş.
bool yazbozEsli(EventScoreRules kural) =>
    kural.side == EventScoreRulesSide.pair;

/// Eşli masada [koltuk]un (1'den, seçim sırası) eşi: koltuk 1 ve 3 eş 1,
/// koltuk 2 ve 4 eş 2 (karşılıklı oturanlar).
int yazbozEsNo(int koltuk) => (koltuk - 1) % 2 + 1;

/// Eşli masada [es] numaralı eşin koltukları: eş 1 → (1, 3), eş 2 → (2, 4).
(int, int) yazbozEsKoltuklari(int es) => (es, es + 2);

/// Eşli masada seçilen yer sayısı uygun mu: tam 4 ya da hiç (yerler sonra
/// verilir).
bool yazbozEsliSayiUygun(int adet) => adet == 0 || adet == yazbozEsliYer;

/// Eşli masada bir eş: numarası ve yerleri koltuk sırasıyla. Skor eşin
/// herhangi bir yeriyle gönderilir; istemci ilk yeri ([temsilci]) kullanır.
typedef YazbozEsi = ({int es, List<EventScorePlayer> yerler});

/// Eşin skor girişinde kullanılan yeri: koltuk sırasıyla ilki.
String yazbozTemsilci(YazbozEsi es) => es.yerler.first.id;

/// Eşli masanın eşleri numara sırasıyla. Yerin eşi sunucunun `pair`
/// alanıdır; alan yoksa koltuk numarasından türetilir. Yeri olmayan eş
/// listede yoktur.
List<YazbozEsi> yazbozEsleri(EventScoreTable masa) {
  final gruplar = <int, List<EventScorePlayer>>{};
  for (final yer in yazbozYerleri(masa)) {
    final es = yer.pair ?? yazbozEsNo(yer.position);
    (gruplar[es] ??= []).add(yer);
  }
  final numaralar = gruplar.keys.toList()..sort();
  return [for (final n in numaralar) (es: n, yerler: gruplar[n]!)];
}

/// Bir elde eşin skoru: eşin yerlerinden birindeki skor (sunucu ikisine de
/// aynı değeri yazar); yoksa `null`.
EventScoreEntry? yazbozEsSkoru(EventScoreRound el, YazbozEsi es) {
  final yerler = {for (final y in es.yerler) y.id};
  for (final s in el.scores) {
    if (yerler.contains(s.playerId)) return s;
  }
  return null;
}

/// Eşli masanın sıralamasının bir satırı: eş, eşin sırası ve toplamı
/// (iki yerde aynı; bir kez sayılır) ve kazanan mı.
typedef YazbozEsSirasi = ({
  YazbozEsi es,
  EventScoreStanding sira,
  bool kazanan,
});

/// Eşli masanın sıralaması eş başına: sunucu sıralamayı yer başına verir
/// ve eşin iki yeri aynı sırayı ve toplamı taşır; satırlar eşte birleşir,
/// toplam toplanmaz. Biten masada eşin yerlerinden biri `winner_ids`'te ise
/// eş kazanandır.
List<YazbozEsSirasi> yazbozEsSiralamasi(EventScoreTable masa) {
  final esler = {
    for (final es in yazbozEsleri(masa))
      for (final y in es.yerler) y.id: es,
  };
  final satirlar = <int, YazbozEsSirasi>{};
  for (final satir in yazbozSiralamasi(masa)) {
    final es = esler[satir.sira.playerId];
    if (es == null) continue;
    final onceki = satirlar[es.es];
    if (onceki == null) {
      satirlar[es.es] = (es: es, sira: satir.sira, kazanan: satir.kazanan);
    } else if (satir.kazanan && !onceki.kazanan) {
      satirlar[es.es] = (es: es, sira: onceki.sira, kazanan: true);
    }
  }
  return satirlar.values.toList();
}

/// El formunun sonucu: istek ya da hatalı alanların yerleri.
typedef YazbozElSonucu = ({EventScoreRoundRequest? istek, Set<String> hatali});

/// Puan modunda el isteği: [puanlar] yer → yazılan metin. Boş alan o yerin
/// bu elde skoru olmadığı anlamına gelir; tam sayı olmayan ya da
/// ±1 000 000 dışındaki değer hatalıdır. Hiç skor yoksa istek de hatalı
/// yer de yoktur (çağıran "en az bir skor" der). Yerler [sira] sırasıyla
/// gider.
YazbozElSonucu yazbozPuanIstegi(
  List<String> sira,
  Map<String, String> puanlar,
) {
  final skorlar = <EventScoreEntry>[];
  final hatali = <String>{};
  for (final yer in sira) {
    final metin = (puanlar[yer] ?? '').trim().replaceAll('−', '-');
    if (metin.isEmpty) continue;
    final puan = int.tryParse(metin);
    if (puan == null || puan.abs() > yazbozPuanSiniri) {
      hatali.add(yer);
      continue;
    }
    skorlar.add(EventScoreEntry(playerId: yer, points: puan));
  }
  if (hatali.isNotEmpty) return (istek: null, hatali: hatali);
  if (skorlar.isEmpty) return (istek: null, hatali: const {});
  return (istek: EventScoreRoundRequest(scores: skorlar), hatali: const {});
}

/// Galibiyet/beraberlik/mağlubiyet modunda el isteği: [sonuclar] yer →
/// sonuç; seçilmeyen yer gitmez. Kuralın geri kalanını (bir galibiyet ya da
/// herkes berabere) sunucu denetler.
YazbozElSonucu yazbozSonucIstegi(
  List<String> sira,
  Map<String, EventScoreEntryOutcome> sonuclar,
) {
  final skorlar = [
    for (final yer in sira)
      if (sonuclar[yer] case final sonuc?
          when sonuc != EventScoreEntryOutcome.unknown)
        EventScoreEntry(playerId: yer, outcome: sonuc),
  ];
  if (skorlar.isEmpty) return (istek: null, hatali: const {});
  return (istek: EventScoreRoundRequest(scores: skorlar), hatali: const {});
}

/// Yazbozun yeniden okunmasını gerektiren hatalar: masa, etkinliğin durumu
/// ya da yetki değişmiş.
const Set<ProblemType> _bayatYazbozHatalari = {
  ProblemType.scoreTableNotFound,
  ProblemType.scoreTableFinished,
  ProblemType.scoreTableStarted,
  ProblemType.scorePresetUnavailable,
  ProblemType.scoreNotStarted,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Bir yazboz işlemi: depoda çalışır, yazbozun güncel halini döner.
typedef YazbozYazimi = Future<EventScoreboard> Function(
  EtkinlikDeposu depo,
  YazbozKimligi k,
);

/// Yazboz bileşeninin durumu (`GET …/components/{component_key}/
/// scoreboard`; Tayfam-Api #250), çağıranın gördüğü haliyle. Bölüm açıkken
/// canlıdır (ADR-0024 §5): bir el girilince, masa açılınca ya da etkinliğin
/// durumu değişince REST'ten yeniden okunur; skor tablosu anında yenilenir.
///
/// Yazan her uç yazbozun güncel halini döner; durum onunla değişir. Skor
/// girişi çevrimdışı kuyruğa girmez. Yetki sunucudadır; istemci yalnızca
/// düğmeleri sadeleştirir (kesin kural 5).
class YazbozNotifier extends AsyncNotifier<EventScoreboard> {
  YazbozNotifier(this.kimlik);

  final YazbozKimligi kimlik;

  @override
  Future<EventScoreboard> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .yazboz(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
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

  /// Masa kurar (organizatör, moderatör, yönetici).
  Future<Object?> masaKur(EventScoreTableRequest istek) => _yaz(
    (d, k) => d.yazbozMasasiKur(k.tayfaId, k.etkinlikId, k.anahtar, istek),
  );

  /// Masanın adını ya da durumunu (yeniden aç) değiştirir.
  Future<Object?> masayiGuncelle(String masaId, EventScoreTableUpdate istek) =>
      _yaz(
        (d, k) => d.yazbozMasasiniGuncelle(
          k.tayfaId,
          k.etkinlikId,
          k.anahtar,
          masaId,
          istek,
        ),
      );

  /// Masayı siler.
  Future<Object?> masayiSil(String masaId) => _yaz(
    (d, k) => d.yazbozMasasiniSil(k.tayfaId, k.etkinlikId, k.anahtar, masaId),
  );

  /// Masanın yerlerini sırasıyla belirler.
  Future<Object?> yerleriBelirle(
    String masaId,
    List<EventScorePlayerInput> yerler,
  ) => _yaz(
    (d, k) => d.yazbozYerleriniBelirle(
      k.tayfaId,
      k.etkinlikId,
      k.anahtar,
      masaId,
      EventScorePlayersRequest(players: yerler),
    ),
  );

  /// Sıradaki eli girer (organizatör ya da masanın hakemi).
  Future<Object?> elGir(String masaId, EventScoreRoundRequest istek) => _yaz(
    (d, k) => d.yazbozEliGir(k.tayfaId, k.etkinlikId, k.anahtar, masaId, istek),
  );

  /// Girilmiş eli düzeltir.
  Future<Object?> eliDuzelt(
    String masaId,
    int el,
    EventScoreRoundRequest istek,
  ) => _yaz(
    (d, k) => d.yazbozEliniDuzelt(
      k.tayfaId,
      k.etkinlikId,
      k.anahtar,
      masaId,
      el,
      istek,
    ),
  );

  /// Masanın son elini siler.
  Future<Object?> sonEliSil(String masaId, int el) => _yaz(
    (d, k) => d.yazbozEliniSil(k.tayfaId, k.etkinlikId, k.anahtar, masaId, el),
  );

  /// Masayı bitirir (organizatör ya da masanın hakemi).
  Future<Object?> masayiBitir(String masaId) => _yaz(
    (d, k) => d.yazbozMasasiniBitir(k.tayfaId, k.etkinlikId, k.anahtar, masaId),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Yazboz bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(YazbozYazimi islem) async {
    try {
      final yazboz = await islem(ref.read(etkinlikDeposuProvider), kimlik);
      if (ref.mounted) state = AsyncData(yazboz);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatYazbozHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir yazboz bileşeninin durumu. Hata otomatik yeniden denenmez.
final yazbozProvider = AsyncNotifierProvider.autoDispose
    .family<YazbozNotifier, EventScoreboard, YazbozKimligi>(
      YazbozNotifier.new,
      name: 'yazbozProvider',
      retry: yenidenDenemeYok,
    );
