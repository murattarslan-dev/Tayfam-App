import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Eşleşme ağacı bölümünün ve formunun ortak metin ve ad yardımcıları.
// Adlar metin olarak üretilir: maç ekran okuyucuda tek cümle okunur
// ("Tur 1, Maç 2: …").

/// Sayıyı cihazın dilinde yazar (2; 0,5).
String agacSayisi(AppLocalizations m, num sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);

/// Biçimin adı; tanınmayan biçimde `null`.
String? agacBicimAdi(AppLocalizations m, EventBracketFormat bicim) =>
    switch (bicim) {
      EventBracketFormat.elimination => m.bilesen_bracket_format_elimination,
      EventBracketFormat.league => m.bilesen_bracket_format_league,
      EventBracketFormat.swiss => m.bilesen_bracket_format_swiss,
      EventBracketFormat.unknown => null,
    };

/// Maç başına oyunun adı ("Tek oyun", "BO3").
String agacBoAdi(AppLocalizations m, int bo) =>
    bo > 1 ? m.bilesen_bracket_bo(bo) : m.bilesen_bracket_bo_tek;

/// Kuralların yazıyla özeti: biçim, maç başına oyun, skor kuralı, tur
/// sayısı. Tanınmayan kural atlanır.
List<String> agacKuralOzeti(AppLocalizations m, EventBracket agac) {
  final skor = switch ((agac.result, agac.winner)) {
    (EventBracketResult.wdl, _) => m.bilesen_bracket_kural_wdl,
    (EventBracketResult.points, EventBracketWinner.high) =>
      m.bilesen_bracket_kural_high,
    (EventBracketResult.points, EventBracketWinner.low) =>
      m.bilesen_bracket_kural_low,
    _ => null,
  };
  return [
    ?agacBicimAdi(m, agac.format),
    agacBoAdi(m, agac.bestOf),
    ?skor,
    if (agac.rounds > 0) m.bilesen_bracket_tur_sayisi(agac.rounds),
  ];
}

/// Takım kurasında takımların okunduğu bileşen; katılımcı kurasında
/// `null`.
TakimKimligi? agacTakimlari(AgacKimligi kimlik, EventBracket agac) {
  final anahtar = agac.teamsKey;
  if (agac.subject != EventBracketSubject.teams || anahtar == null) {
    return null;
  }
  return (
    tayfaId: kimlik.tayfaId,
    etkinlikId: kimlik.etkinlikId,
    anahtar: anahtar,
  );
}

EventTeam? _takim(WidgetRef ref, TakimKimligi? takimlar, String? takimId) {
  if (takimlar == null || takimId == null) return null;
  final liste =
      ref.watch(takimProvider(takimlar)).value?.teams ?? const <EventTeam>[];
  for (final t in liste) {
    if (t.id == takimId) return t;
  }
  return null;
}

/// Etkinliğin misafirlerinin okunduğu bileşen (katılımcı kurasına misafir
/// de girer); yoksa `null`.
MisafirKimligi? agacMisafirleri(WidgetRef ref, AgacKimligi kimlik) =>
    etkinlikMisafirleri(ref, kimlik.tayfaId, kimlik.etkinlikId);

/// Kuradaki [sira] yerin adı: kişinin adı (hesabını silmişse "Silinmiş
/// kullanıcı"), takımın adı ya da numarası, misafirin takma adı
/// ("Deniz (misafir)"); boş yerde "Boş yer", taraf yoksa "Bay".
String agacYerAdi(
  WidgetRef ref,
  AppLocalizations m,
  EventBracket agac,
  TakimKimligi? takimlar,
  int? sira, {
  MisafirKimligi? misafirler,
}) {
  if (sira == null) return m.bilesen_bracket_bay;
  final yer = agacYeri(agac, sira);
  if (agacYeriBos(yer)) return m.bilesen_bracket_bos_yer;
  final misafir = yer?.guestId;
  if (misafir != null) return misafirAdiMetni(ref, m, misafirler, misafir);
  final kisi = yer?.userId;
  if (kisi != null) {
    ref.read(kullaniciAdlariProvider.notifier).iste(kisi);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kisi]),
    );
    return switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
  }
  final takim = _takim(ref, takimlar, yer?.teamId);
  return takim == null
      ? m.bilesen_bracket_takim
      : takimEtiketi(m, takim.position, takim.name);
}

/// [sira] yer çağıranın mı (kişi kurasında kendisi, takım kurasında
/// takımı).
bool agacBenimYerim(
  WidgetRef ref,
  EventBracket agac,
  TakimKimligi? takimlar,
  int? sira,
) {
  final yer = agacYeri(agac, sira);
  final kisi = yer?.userId;
  if (kisi != null) return ref.watch(kendisiMiProvider(kisi));
  final takim = _takim(ref, takimlar, yer?.teamId);
  if (takim == null) return false;
  var benim = false;
  for (final uye in takim.memberIds) {
    if (ref.watch(kendisiMiProvider(uye))) benim = true;
  }
  return benim;
}

/// Bir tarafın maçtaki skoru yazıyla: birden çok oyunlu maçta kazanılan
/// oyun, tek oyunda puan (ya da 1 / 0,5 / 0); oyun yoksa "–".
String agacSkorMetni(
  AppLocalizations m,
  EventBracket agac,
  EventBracketMatch mac, {
  required bool a,
}) {
  if (mac.games.isEmpty) return m.bilesen_bracket_skor_yok;
  if (agac.bestOf > 1 || mac.games.length > 1) {
    return agacSayisi(m, a ? mac.aGamesWon : mac.bGamesWon);
  }
  return agacSayisi(m, a ? mac.aTotal : mac.bTotal);
}

/// Bir oyunun skoru A–B ("21–18", "½–½"); tanınmayan sonuçta `null`.
String? agacOyunMetni(AppLocalizations m, EventBracketGame oyun) {
  final ap = oyun.aPoints;
  final bp = oyun.bPoints;
  if (ap != null && bp != null) {
    return m.bilesen_bracket_oyun_skoru(agacSayisi(m, ap), agacSayisi(m, bp));
  }
  return switch (oyun.aOutcome) {
    EventBracketGameAOutcome.win => m.bilesen_bracket_oyun_skoru('1', '0'),
    EventBracketGameAOutcome.draw => m.bilesen_bracket_oyun_skoru('½', '½'),
    EventBracketGameAOutcome.loss => m.bilesen_bracket_oyun_skoru('0', '1'),
    _ => null,
  };
}

/// Maçın oyunları tek satırda ("Oyunlar: 21–18 · 15–21"); oyun yoksa
/// `null`.
String? agacOyunlarMetni(AppLocalizations m, EventBracketMatch mac) {
  final oyunlar = [
    for (final oyun in agacOyunlari(mac)) ?agacOyunMetni(m, oyun),
  ];
  if (oyunlar.isEmpty) return null;
  return m.bilesen_bracket_oyunlar(oyunlar.join(' · '));
}
