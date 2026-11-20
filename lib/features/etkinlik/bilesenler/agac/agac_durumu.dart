import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';

/// Sözleşmedeki sınırlar (`EventBracketGameRequest`, `EventBracketGame`).
const int agacPuanSiniri = 1000000;
const int agacOyunEnCok = 9;

/// Bir etkinliğin bir eşleşme ağacı bileşeni: bileşen uçlarındaki
/// `{component_key}` ile. [kura] türün ilk kura bileşeninin anahtarıdır
/// (yoksa `null`): kura çekilince ağaç da yeniden okunur.
typedef AgacKimligi = ({
  String tayfaId,
  String etkinlikId,
  String anahtar,
  String? kura,
});

/// Bir tur: numarası ve maçları sırasıyla.
typedef AgacTuru = ({int no, List<EventBracketMatch> maclar});

/// Maçları tura göre gruplar; turlar ve maçlar sırasıyla (sözleşme:
/// `EventBracket.matches` tura ve sıraya göre).
List<AgacTuru> agacTurlari(EventBracket agac) {
  final gruplar = <int, List<EventBracketMatch>>{};
  for (final mac in agac.matches) {
    gruplar.putIfAbsent(mac.round, () => []).add(mac);
  }
  final turlar = gruplar.keys.toList()..sort();
  return [
    for (final no in turlar)
      (
        no: no,
        maclar: [...gruplar[no]!]..sort((a, b) => a.slot.compareTo(b.slot)),
      ),
  ];
}

/// Turdaki sonuçlanmış maç sayısı.
int agacBitenMaclar(AgacTuru tur) => tur.maclar.where((m) => m.decided).length;

/// [sira] kuradaki yer; ağaçta yoksa `null`.
EventBracketEntrant? agacYeri(EventBracket agac, int? sira) {
  if (sira == null) return null;
  for (final yer in agac.entrants) {
    if (yer.position == sira) return yer;
  }
  return null;
}

/// Yer boş mu: kişi ya da takım geri çekilmiş.
bool agacYeriBos(EventBracketEntrant? yer) =>
    yer == null || (yer.userId == null && yer.teamId == null);

/// Maçın oyunları numarasıyla.
List<EventBracketGame> agacOyunlari(EventBracketMatch mac) =>
    [...mac.games]..sort((a, b) => a.number.compareTo(b.number));

/// Maçın son oyunu; oyun yoksa `null`. Yalnızca son oyun silinir.
EventBracketGame? agacSonOyun(EventBracketMatch mac) {
  final oyunlar = agacOyunlari(mac);
  return oyunlar.isEmpty ? null : oyunlar.last;
}

/// Ağaç sonuçlandıysa [sira] kazananlardan mı.
bool agacSampiyonuMu(EventBracket agac, int sira) =>
    agac.finished && agac.winnerPositions.contains(sira);

/// Organizatör sonraki turu eşleyebilir mi: eleme ya da İsviçre, ağaç
/// sürüyor, mevcut turun bütün maçları sonuçlandı ve planlanan tur
/// bitmedi. Yetkiyi ve kalan durumları sunucu denetler.
bool agacSonrakiTurEslenebilir(EventBracket agac) {
  if (!agac.callerCanManage || !agac.started || agac.finished) return false;
  if (agac.format == EventBracketFormat.league) return false;
  if (agac.currentRound < 1 || agac.currentRound >= agac.rounds) return false;
  final mevcut = agac.matches.where((m) => m.round == agac.currentRound);
  return mevcut.isNotEmpty && mevcut.every((m) => m.decided);
}

/// Oyun formunun sonucu: istek ya da hatalı taraflar (`a`, `b`). İki
/// alan da boşsa istek de hatalı taraf da yoktur (çağıran "iki skoru da
/// yaz" der).
typedef AgacOyunSonucu = ({EventBracketGameRequest? istek, Set<String> hatali});

/// Puan kuralında oyun isteği: iki tarafın puanı birlikte; tam sayı
/// olmayan, ±1 000 000 dışındaki ya da boş değer hatalıdır.
AgacOyunSonucu agacPuanIstegi(String a, String b) {
  int? oku(String metin) {
    final temiz = metin.trim().replaceAll('−', '-');
    final puan = int.tryParse(temiz);
    if (puan == null || puan.abs() > agacPuanSiniri) return null;
    return puan;
  }

  final aBos = a.trim().isEmpty;
  final bBos = b.trim().isEmpty;
  if (aBos && bBos) return (istek: null, hatali: const {});
  final ap = oku(a);
  final bp = oku(b);
  final hatali = {if (ap == null) 'a', if (bp == null) 'b'};
  if (ap == null || bp == null) return (istek: null, hatali: hatali);
  return (
    istek: EventBracketGameRequest(aPoints: ap, bPoints: bp),
    hatali: const {},
  );
}

/// Ağacın yeniden okunmasını gerektiren hatalar: maç, tur, etkinliğin
/// durumu ya da yetki değişmiş (ör. başkası oyun girmiş ya da ağacı
/// sıfırlamış).
const Set<ProblemType> _bayatAgacHatalari = {
  ProblemType.bracketDrawRequired,
  ProblemType.bracketStarted,
  ProblemType.bracketNotStarted,
  ProblemType.bracketMatchNotFound,
  ProblemType.bracketGameNotFound,
  ProblemType.bracketMatchDecided,
  ProblemType.bracketRoundOpen,
  ProblemType.bracketRoundClosed,
  ProblemType.bracketFinished,
  ProblemType.scoreNotStarted,
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.permissionDenied,
  ProblemType.tayfaReadOnly,
};

/// Bir ağaç işlemi: depoda çalışır, ağacın güncel halini döner.
typedef AgacYazimi = Future<EventBracket> Function(
  EtkinlikDeposu depo,
  AgacKimligi k,
);

/// Eşleşme ağacı bileşeninin durumu (`GET …/components/{component_key}/
/// bracket`; Tayfam-Api #251), çağıranın gördüğü haliyle. Bölüm açıkken
/// canlıdır (ADR-0024 §5): bir oyun girilince, tur eşlenince, kura
/// çekilince ya da etkinliğin durumu değişince REST'ten yeniden okunur;
/// ağaç anında yenilenir.
///
/// Yazan her uç ağacın güncel halini döner; durum onunla değişir. Oyun
/// girişi çevrimdışı kuyruğa girmez. Yetki sunucudadır; istemci yalnızca
/// düğmeleri sadeleştirir (kesin kural 5).
class AgacNotifier extends AsyncNotifier<EventBracket> {
  AgacNotifier(this.kimlik);

  final AgacKimligi kimlik;

  @override
  Future<EventBracket> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    if (kimlik.kura case final kura?) {
      bilesenDegisiminiIzle(ref, etkinlik, kura);
    }
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .agac(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene"; kura çekilince).
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// Ağacı kuradan başlatır (organizatör, moderatör, yönetici).
  Future<Object?> baslat() =>
      _yaz((d, k) => d.agaciBaslat(k.tayfaId, k.etkinlikId, k.anahtar));

  /// Ağacı sıfırlar; kura kalır.
  Future<Object?> sifirla() =>
      _yaz((d, k) => d.agaciSifirla(k.tayfaId, k.etkinlikId, k.anahtar));

  /// Sonraki turu eşler.
  Future<Object?> sonrakiTur() =>
      _yaz((d, k) => d.agactaSonrakiTur(k.tayfaId, k.etkinlikId, k.anahtar));

  /// Maça sonraki oyunu girer (organizatör ya da hakem).
  Future<Object?> oyunGir(String macId, EventBracketGameRequest istek) => _yaz(
    (d, k) => d.agacOyunuGir(k.tayfaId, k.etkinlikId, k.anahtar, macId, istek),
  );

  /// Girilmiş oyunu düzeltir.
  Future<Object?> oyunuDuzelt(
    String macId,
    int oyun,
    EventBracketGameRequest istek,
  ) => _yaz(
    (d, k) => d.agacOyununuDuzelt(
      k.tayfaId,
      k.etkinlikId,
      k.anahtar,
      macId,
      oyun,
      istek,
    ),
  );

  /// Maçın son oyununu siler.
  Future<Object?> sonOyunuSil(String macId, int oyun) => _yaz(
    (d, k) => d.agacOyununuSil(k.tayfaId, k.etkinlikId, k.anahtar, macId, oyun),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Ağaç bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(AgacYazimi islem) async {
    try {
      final agac = await islem(ref.read(etkinlikDeposuProvider), kimlik);
      if (ref.mounted) state = AsyncData(agac);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatAgacHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir eşleşme ağacı bileşeninin durumu. Hata otomatik yeniden denenmez.
final agacProvider = AsyncNotifierProvider.autoDispose
    .family<AgacNotifier, EventBracket, AgacKimligi>(
      AgacNotifier.new,
      name: 'agacProvider',
      retry: yenidenDenemeYok,
    );
