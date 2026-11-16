import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/sohbet_balonu.dart';
import 'package:tayfam/core/sohbet/giden_icerik.dart';
import 'package:tayfam/core/sohbet/sohbet_ekleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kuyruktaki (henüz gönderilmemiş) kendi mesajın balonu: metin, yerel
/// fotoğraf önizlemesi ya da yer kartı (tasarım 28 `Kanal-Fotograf`).
/// Kanal ve birebirde aynıdır; içerik yalnızca bellektedir.
class GidenBalon extends StatelessWidget {
  const GidenBalon({super.key, required this.icerik, required this.tur});

  final GidenIcerik icerik;
  final BalonTuru tur;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return switch (icerik) {
      GidenMetin(:final metin) => SohbetBalonu(
        metin: metin,
        giden: true,
        tur: tur,
      ),
      GidenFotograf(:final goruntu) => SohbetBalonu(
        metin: m.sohbet_fotograf_etiketi,
        giden: true,
        tur: tur,
        medya: YerelFotograf(
          baytlar: goruntu.onizleme,
          oran: goruntu.tamOlcu.genislik / goruntu.tamOlcu.yukseklik,
          etiket: m.sohbet_fotograf_etiketi,
        ),
      ),
      GidenYer(:final yer) => SohbetBalonu(
        metin: m.sohbet_yer_etiketi(yer.ad ?? m.sohbet_yer_adsiz),
        giden: true,
        tur: tur,
        medya: SohbetYerKarti(yer: yer, giden: tur != BalonTuru.gonderilemedi),
      ),
    };
  }
}
