import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/giris_notifier.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/presentation/google_dugmesi.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Giriş ekranı (ADR-0012 §2): mor marka yüzeyinde yazı logo, slogan ve
/// "Google ile devam et".
///
/// Hesap kalıcı kapandıysa (`age-blocked`) ya da kısıtlandıysa
/// (`account-sanctioned`) düğme yerine sade bir bilgi gösterilir; yeniden
/// deneme yolu yoktur. Kullanıcı Google penceresini kapatırsa hata
/// gösterilmez.
class GirisEkrani extends ConsumerWidget {
  const GirisEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final engel = ref.watch(hesapEngeliProvider);
    final durum = ref.watch(girisProvider);
    final hata = durum.hata;

    final List<Widget> alt;
    if (engel != null) {
      alt = [
        Semantics(
          header: true,
          child: Text(
            switch (engel) {
              HesapEngeli.yasSiniri => metinler.hesap_engel_yas_baslik,
              HesapEngeli.kisitlandi => metinler.hesap_engel_kisit_baslik,
            },
            textAlign: TextAlign.center,
            style: yazi.headlineSmall?.copyWith(color: r.markaYuzeyUstu),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s12),
        Text(
          switch (engel) {
            HesapEngeli.yasSiniri => metinler.hesap_engel_yas_aciklama,
            HesapEngeli.kisitlandi => metinler.hesap_engel_kisit_aciklama,
          },
          textAlign: TextAlign.center,
          style: yazi.bodyLarge?.copyWith(color: r.markaYuzeyUstu),
        ),
      ];
    } else {
      alt = [
        if (durum.suruyor)
          SizedBox(
            height: TayfamSizes.dokunmaMin,
            child: Center(
              child: CircularProgressIndicator(
                color: r.markaYuzeyUstu,
                semanticsLabel: metinler.hesap_giris_suruyor,
              ),
            ),
          )
        else
          GoogleIleDevamDugmesi(
            etiket: metinler.hesap_google_ile_devam,
            onPressed: () =>
                unawaited(ref.read(girisProvider.notifier).girisYap()),
          ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s16),
          HataSatiri(
            metin: hesapHatasiMetni(metinler, hata),
            renk: r.markaYuzeyUstu,
          ),
        ],
      ];
    }

    return Scaffold(
      body: MarkaYuzeyi(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TayfamSizes.okumaGenisligi,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    YaziLogo(renk: r.markaYuzeyUstu),
                    const SizedBox(height: TayfamSpacing.s8),
                    Text(
                      metinler.hesap_slogan,
                      textAlign: TextAlign.center,
                      style: yazi.titleMedium?.copyWith(
                        color: r.markaYuzeyUstu,
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s40),
                    ...alt,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
