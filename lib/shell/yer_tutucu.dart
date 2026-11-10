import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Henüz yapılmamış bir ekranın yerini tutan sade sayfa.
///
/// Sekme kökleri (Sohbet, Bildirimler, Profil), oturum korumalarının
/// gönderdiği ekranlar ve tayfa akışları kendi paketlerinde gelene kadar
/// bunu gösterir. Üst çubuk sadedir (`surface`, ADR-0004 §2a).
class YerTutucuSayfa extends StatelessWidget {
  const YerTutucuSayfa({super.key, required this.baslik});

  /// Sayfa başlığını çeviri dosyasından seçer.
  final String Function(AppLocalizations metinler) baslik;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(baslik(metinler))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Text(
              metinler.gezinme_yer_tutucu_aciklama,
              textAlign: TextAlign.center,
              style: context.yazi.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uygulamada karşılığı olmayan bir adres açıldığında gösterilen sayfa.
///
/// Adres ekrana veya log'a yazılmaz (CLAUDE.md, kesin kural 3: tam URL
/// loglanmaz).
class BulunamadiSayfasi extends StatelessWidget {
  const BulunamadiSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(metinler.gezinme_bulunamadi_baslik)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metinler.gezinme_bulunamadi_aciklama,
                  textAlign: TextAlign.center,
                  style: context.yazi.bodyLarge,
                ),
                const SizedBox(height: TayfamSpacing.s24),
                BirincilEylem(
                  etiket: metinler.gezinme_ana_sayfaya_don,
                  onPressed: () => context.go(Adresler.kok),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
