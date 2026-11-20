import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Yazboz bölümünün ve formlarının ortak metin ve ad yardımcıları.

/// Sayıyı cihazın dilinde yazar (1.250; 2,5).
String yazbozSayisi(AppLocalizations m, num sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);

/// Masanın kurallarının yazıyla özeti: tek maç, kazanan, hedef, BO, sonuç
/// modu. Tanınmayan kural atlanır.
List<String> yazbozKuralOzeti(AppLocalizations m, EventScoreRules kural) {
  final hedef = kural.target;
  final bo = kural.bestOf;
  final kazanan = switch (kural.winner) {
    EventScoreRulesWinner.high => m.bilesen_scoreboard_kural_high,
    EventScoreRulesWinner.low => m.bilesen_scoreboard_kural_low,
    EventScoreRulesWinner.first => m.bilesen_scoreboard_kural_first,
    _ => null,
  };
  return [
    if (kural.rounds == EventScoreRulesRounds.single)
      m.bilesen_scoreboard_kural_single,
    ?kazanan,
    if (hedef != null && hedef > 0)
      m.bilesen_scoreboard_kural_hedef(yazbozSayisi(m, hedef)),
    if (bo != null && bo > 1) m.bilesen_scoreboard_kural_bo(bo),
    if (kural.result == EventScoreRulesResult.wdl)
      m.bilesen_scoreboard_kural_wdl,
  ];
}

/// Bir el sonucunun adı; tanınmayan sonuçta `null`.
String? yazbozSonucAdi(AppLocalizations m, EventScoreEntryOutcome sonuc) =>
    switch (sonuc) {
      EventScoreEntryOutcome.win => m.bilesen_scoreboard_sonuc_win,
      EventScoreEntryOutcome.draw => m.bilesen_scoreboard_sonuc_draw,
      EventScoreEntryOutcome.loss => m.bilesen_scoreboard_sonuc_loss,
      EventScoreEntryOutcome.unknown => null,
    };

/// Bir elde bir yerin skoru yazıyla ("120", "Galibiyet"); skor yoksa "–".
String yazbozSkorMetni(AppLocalizations m, EventScoreEntry? skor) {
  if (skor == null) return m.bilesen_scoreboard_skor_yok;
  final puan = skor.points;
  if (puan != null) return yazbozSayisi(m, puan);
  final sonuc = skor.outcome;
  return (sonuc == null ? null : yazbozSonucAdi(m, sonuc)) ??
      m.bilesen_scoreboard_skor_yok;
}

/// Bir yerin adı: kişinin adı (hesabını silmişse "Silinmiş kullanıcı") ya
/// da takımın adı veya numarası (kaldırılmışsa "Kaldırılmış takım").
class YazbozYerAdi extends ConsumerWidget {
  const YazbozYerAdi({
    super.key,
    required this.yer,
    required this.takimlar,
    this.style,
  });

  final EventScorePlayer? yer;
  final TakimKimligi? takimlar;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final kisi = yer?.userId;
    if (kisi != null) {
      return KullaniciAdiMetni(kullaniciId: kisi, style: style);
    }
    final takim = yazbozTakimi(ref, takimlar, yer?.teamId);
    if (takim != null) {
      return Text(takimEtiketi(m, takim.position, takim.name), style: style);
    }
    return Text(
      yer?.teamId == null && takimlar == null
          ? m.kullanici_silinmis
          : m.bilesen_scoreboard_takim_yok,
      style: style,
    );
  }
}

/// [takimlar] bileşenindeki [takimId] takımı; okunamazsa ya da yoksa
/// `null`.
EventTeam? yazbozTakimi(
  WidgetRef ref,
  TakimKimligi? takimlar,
  String? takimId,
) {
  if (takimlar == null || takimId == null) return null;
  final liste =
      ref.watch(takimProvider(takimlar)).value?.teams ?? const <EventTeam>[];
  for (final t in liste) {
    if (t.id == takimId) return t;
  }
  return null;
}
