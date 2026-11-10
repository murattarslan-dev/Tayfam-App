import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir etkinlik türünün görünümü (ADR-0002 etkinlik türü kaydı, ADR-0004
/// Notlar 2026-11-10): API değeri, çeviri anahtarı, renk anahtarı ve ikon.
///
/// İlgi alanı çipleri, karşılamadaki tür hapları ve etkinlik kartları türü
/// bu girdiden gösterir. Türe özel form ve araç bölümleri etkinlik
/// özelliğindeki `EtkinlikTuru` arayüzündedir.
@immutable
final class EtkinlikTuruGirdisi {
  const EtkinlikTuruGirdisi({
    required this.tur,
    required this.adAnahtari,
    required this.renk,
    required this.ikon,
  });

  /// Sözleşmedeki `EventType` değeri.
  final EventType tur;

  /// Türün adının `app_tr.arb`'deki anahtarı.
  final String adAnahtari;

  /// Türün renk anahtarı (`TayfamTurRenkleri`).
  final TurRengi renk;

  /// Türün ikonu; yanında her zaman ad gösterilir.
  final IconData ikon;

  /// Türün çeviri dosyasındaki adı ([adAnahtari]).
  String ad(AppLocalizations m) => switch (tur) {
    EventType.convoy => m.etkinlik_turu_convoy,
    EventType.camp => m.etkinlik_turu_camp,
    EventType.hike => m.etkinlik_turu_hike,
    EventType.fishing => m.etkinlik_turu_fishing,
    EventType.gaming => m.etkinlik_turu_gaming,
    EventType.sports => m.etkinlik_turu_sports,
    EventType.general || EventType.unknown => m.etkinlik_turu_general,
  };
}

/// [tur]'ün kayıt girdisi. `default` dalı yoktur: sözleşmeye yeni bir tür
/// eklenip üretici çalışınca derleyici eksik girdiyi gösterir. Henüz
/// tanımadığımız sunucu türü ([EventType.unknown]) "genel" görünür.
///
/// Yeni tür: sözleşme → üretici → buraya girdi + `TurRengi` ve iki temada
/// renk çifti + ARB adı + kontrast testi (ADR-0004 Notlar).
EtkinlikTuruGirdisi etkinlikTuruGirdisi(EventType tur) => switch (tur) {
  EventType.convoy => const EtkinlikTuruGirdisi(
    tur: EventType.convoy,
    adAnahtari: 'etkinlik_turu_convoy',
    renk: TurRengi.konvoy,
    ikon: Icons.directions_car,
  ),
  EventType.camp => const EtkinlikTuruGirdisi(
    tur: EventType.camp,
    adAnahtari: 'etkinlik_turu_camp',
    renk: TurRengi.kamp,
    ikon: Icons.cabin,
  ),
  EventType.hike => const EtkinlikTuruGirdisi(
    tur: EventType.hike,
    adAnahtari: 'etkinlik_turu_hike',
    renk: TurRengi.yuruyus,
    ikon: Icons.hiking,
  ),
  EventType.fishing => const EtkinlikTuruGirdisi(
    tur: EventType.fishing,
    adAnahtari: 'etkinlik_turu_fishing',
    renk: TurRengi.balik,
    ikon: Icons.phishing,
  ),
  EventType.gaming => const EtkinlikTuruGirdisi(
    tur: EventType.gaming,
    adAnahtari: 'etkinlik_turu_gaming',
    renk: TurRengi.oyun,
    ikon: Icons.sports_esports,
  ),
  EventType.sports => const EtkinlikTuruGirdisi(
    tur: EventType.sports,
    adAnahtari: 'etkinlik_turu_sports',
    renk: TurRengi.spor,
    ikon: Icons.sports_soccer,
  ),
  EventType.general || EventType.unknown => _genel,
};

const EtkinlikTuruGirdisi _genel = EtkinlikTuruGirdisi(
  tur: EventType.general,
  adAnahtari: 'etkinlik_turu_general',
  renk: TurRengi.genel,
  ikon: Icons.event,
);

/// Bilinen bütün türler, sözleşmenin sırasıyla ([EventType.unknown] hariç).
final List<EtkinlikTuruGirdisi> bilinenEtkinlikTurleri = List.unmodifiable([
  for (final tur in EventType.values)
    if (tur != EventType.unknown) etkinlikTuruGirdisi(tur),
]);
