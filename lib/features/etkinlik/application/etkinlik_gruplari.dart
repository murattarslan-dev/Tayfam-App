import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Etkinlik listesindeki grubun türü (2026-11-13 tasarım: Etkinlikler).
enum EtkinlikGrubuTuru {
  /// Bu haftanın sonuna (pazar gece yarısına) kadar başlayanlar; daha önce
  /// başlamış ama bitmemiş etkinlikler de buradadır.
  buHafta,

  /// Gelecek haftanın pazartesisinden pazarına kadar başlayanlar.
  gelecekHafta,

  /// Daha sonrakiler, başladıkları aya göre.
  ay,
}

/// Etkinlik listesindeki bir grup: türü, ay grubundaysa ayın ilk günü
/// (cihazın saatinde) ve sıralı etkinlikleri.
@immutable
final class EtkinlikGrubu {
  const EtkinlikGrubu({required this.tur, required this.etkinlikler, this.ay});

  final EtkinlikGrubuTuru tur;

  /// [EtkinlikGrubuTuru.ay] grubunda ayın ilk günü (yerel); öbür
  /// gruplarda `null`.
  final DateTime? ay;

  final List<Event> etkinlikler;
}

/// Gruplama sırasında bir grubun türü, ayı ve etkinlikleri.
typedef _Grup = ({EtkinlikGrubuTuru tur, DateTime? ay, List<Event> liste});

/// [an]'ın haftasının ilk günü (pazartesi 00:00, cihazın saatinde; Türkiye
/// takvimi gibi hafta pazartesi başlar).
DateTime haftaBasi(DateTime an) {
  final yerel = an.toLocal();
  return DateTime(
    yerel.year,
    yerel.month,
    yerel.day - (yerel.weekday - DateTime.monday),
  );
}

/// Yaklaşan etkinlikleri "Bu hafta", "Gelecek hafta" ve sonraki aylara
/// göre gruplar (2026-11-13 tasarım: Etkinlikler). Hafta ve ay sınırları
/// cihazın saat dilimine göredir (ADR-0008); gün sınırları `DateTime`'ın
/// takvim alanlarıyla hesaplanır, yaz saati geçişinde kaymaz.
///
/// [etkinlikler] başlangıca göre sıralı gelir (sunucu sırası); sıra
/// korunur ve aynı gruptaki ardışık etkinlikler birleşir. Liste yalnızca
/// bitmemiş etkinlikleri içerdiği için bu haftadan önce başlamış (sürmekte
/// olan) etkinlik "Bu hafta"dadır.
List<EtkinlikGrubu> etkinlikGruplari(
  Iterable<Event> etkinlikler,
  DateTime simdi,
) {
  final buHafta = haftaBasi(simdi);
  final gelecekHafta = DateTime(
    buHafta.year,
    buHafta.month,
    buHafta.day + DateTime.daysPerWeek,
  );
  final sonrakiHafta = DateTime(
    buHafta.year,
    buHafta.month,
    buHafta.day + DateTime.daysPerWeek * 2,
  );
  final gruplar = <_Grup>[];
  for (final etkinlik in etkinlikler) {
    final an = etkinlik.startsAt.toLocal();
    final (EtkinlikGrubuTuru tur, DateTime? ay) = an.isBefore(gelecekHafta)
        ? (EtkinlikGrubuTuru.buHafta, null)
        : an.isBefore(sonrakiHafta)
        ? (EtkinlikGrubuTuru.gelecekHafta, null)
        : (EtkinlikGrubuTuru.ay, DateTime(an.year, an.month));
    final son = gruplar.lastOrNull;
    if (son != null && son.tur == tur && son.ay == ay) {
      son.liste.add(etkinlik);
    } else {
      gruplar.add((tur: tur, ay: ay, liste: [etkinlik]));
    }
  }
  return [
    for (final g in gruplar)
      EtkinlikGrubu(
        tur: g.tur,
        ay: g.ay,
        etkinlikler: List.unmodifiable(g.liste),
      ),
  ];
}
