import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

/// Katalog anahtarı → renk anahtarı (ADR-0004 Notlar 2026-11-10 tablosu).
///
/// Katalog renk taşımaz; renk tek başına bilgi de taşımaz (tür her zaman
/// ikon ve adla gösterilir). Faz 1'in yedi türü tablodaki rengini korur;
/// ilgi alanları kendilerine en yakın türün rengini alır. Burada olmayan
/// tür ana ilgi alanının rengini, o da yoksa genel rengi alır.
const Map<String, TurRengi> _renkler = {
  // Türler (ADR-0004 tablosu).
  'convoy': TurRengi.konvoy,
  'camp': TurRengi.kamp,
  'hike': TurRengi.yuruyus,
  'fishing': TurRengi.balik,
  'gaming': TurRengi.oyun,
  'sports': TurRengi.spor,
  'general': TurRengi.genel,
  // İlgi alanları.
  'automotive': TurRengi.konvoy,
  'nature': TurRengi.kamp,
  'water': TurRengi.balik,
  'games': TurRengi.oyun,
};

/// [anahtar]'ın (tür ya da ilgi alanı) renk anahtarı. Bilinmeyen anahtar
/// sırayla [ilgiAlanlari]'ndaki ilk bilinen anahtarın, o da yoksa genel
/// rengi alır.
TurRengi katalogRengi(
  String anahtar, {
  Iterable<String> ilgiAlanlari = const [],
}) {
  final dogrudan = _renkler[anahtar];
  if (dogrudan != null) return dogrudan;
  for (final ilgi in ilgiAlanlari) {
    final renk = _renkler[ilgi];
    if (renk != null) return renk;
  }
  return TurRengi.genel;
}
