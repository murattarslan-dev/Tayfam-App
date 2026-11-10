import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
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
            // TODO(#6): TayfamSpacing
            padding: const EdgeInsets.all(16),
            child: Text(
              metinler.gezinme_yer_tutucu_aciklama,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
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
            // TODO(#6): TayfamSpacing
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metinler.gezinme_bulunamadi_aciklama,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                // TODO(#6): TayfamSpacing
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(Adresler.kok),
                  child: Text(metinler.gezinme_ana_sayfaya_don),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
