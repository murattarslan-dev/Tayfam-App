import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/etkinlik_turu_cipi.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katalogsuz ekranlardaki örnek türler: giriş ekranı, hoş geldin
/// tanıtımı ve karşılama. Bu ekranlar katalog gelmeden (çoğu oturum
/// açılmadan) çizilir; tür adları bu yüzden çeviri dosyasındadır ve
/// yalnızca tanıtım içindir. Uygulamanın gerçek türleri katalogdan gelir
/// (ADR-0024).
///
/// Renk ve ikon ADR-0004 Notlar 2026-11-10 tablosundandır.
enum TanitimTuru {
  konvoy(Icons.directions_car, TurRengi.konvoy),
  kamp(Icons.cabin, TurRengi.kamp),
  yuruyus(Icons.hiking, TurRengi.yuruyus),
  balik(Icons.phishing, TurRengi.balik),
  oyun(Icons.sports_esports, TurRengi.oyun),
  spor(Icons.sports_soccer, TurRengi.spor);

  const TanitimTuru(this.ikon, this.renk);

  /// Türün ikonu; yanında her zaman ad gösterilir.
  final IconData ikon;

  /// Türün renk anahtarı.
  final TurRengi renk;

  /// Türün çeviri dosyasındaki adı.
  String ad(AppLocalizations m) => switch (this) {
    TanitimTuru.konvoy => m.etkinlik_turu_convoy,
    TanitimTuru.kamp => m.etkinlik_turu_camp,
    TanitimTuru.yuruyus => m.etkinlik_turu_hike,
    TanitimTuru.balik => m.etkinlik_turu_fishing,
    TanitimTuru.oyun => m.etkinlik_turu_gaming,
    TanitimTuru.spor => m.etkinlik_turu_sports,
  };
}

/// Örnek türün çipi ([TurCipi]); katalog gerektirmez.
class TanitimTurCipi extends StatelessWidget {
  const TanitimTurCipi({super.key, required this.tur, this.buyuk = false});

  final TanitimTuru tur;

  /// Büyük çip mi.
  final bool buyuk;

  @override
  Widget build(BuildContext context) => TurCipi(
    etiket: tur.ad(AppLocalizations.of(context)),
    ikon: tur.ikon,
    renk: tur.renk,
    buyuk: buyuk,
  );
}
