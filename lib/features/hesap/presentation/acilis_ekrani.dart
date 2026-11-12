import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açılış ekranı (ADR-0012 §1; Design: Splash açık / koyu, issue #100).
///
/// Oturum kaydı güvenli depodan, tanıtım bayrağı ve tayfa listesi okunurken
/// görünür. Native açılış ekranının devamıdır: aynı zemin (açık temada
/// brand, koyu temada ink; `acilisZemini`), ortada logo, altta "tayfam"
/// yazısı. Logo Flutter'ın ilk karesinde bloklarla kurulur
/// ([AcilisLogosu]); "hareketi azalt" açıksa animasyonsuzdur.
///
/// Splash kuralı gereği ekranda metin ya da ilerleme göstergesi yoktur;
/// ekran okuyucu "Tayfam" başlığını ve "Açılıyor" durumunu okur.
class AcilisEkrani extends StatelessWidget {
  const AcilisEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // acilisZemini iki temada da koyu (brand / ink); üstünde açık ikonlar.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: r.acilisZemini,
        body: SafeArea(
          child: Semantics(
            container: true,
            liveRegion: true,
            label: metinler.hesap_acilis_yukleniyor,
            child: AcilisLogosu(zemin: r.acilisZemini),
          ),
        ),
      ),
    );
  }
}
