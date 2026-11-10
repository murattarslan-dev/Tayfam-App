import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açılışta oturum kaydı güvenli depodan okunurken kısa süre görünen ekran
/// (ADR-0012 §1). Yazı logo ve ilerleme göstergesi; süs animasyonu yok.
class AcilisEkrani extends StatelessWidget {
  const AcilisEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const YaziLogo(),
                const SizedBox(height: TayfamSpacing.s24),
                CircularProgressIndicator(
                  semanticsLabel: metinler.hesap_acilis_yukleniyor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
