import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Güncelleme gerekli" (ADR-0012 §1.1): sürüm platformun en düşük
/// desteklenen sürümünün altında ya da bir istek `client-outdated` aldı.
/// Başka bir şey yapılamaz; Android'de Google Play sayfası açılır (iOS ve
/// mağaza bağlantısı iOS işiyle gelir).
class GuncellemeEkrani extends ConsumerWidget {
  const GuncellemeEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      body: SafeArea(
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
                  Semantics(
                    header: true,
                    child: Text(
                      metinler.hesap_guncelleme_baslik,
                      style: yazi.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  Text(
                    metinler.hesap_guncelleme_aciklama,
                    style: yazi.bodyLarge?.copyWith(
                      color: context.renkler.metinGovde,
                    ),
                  ),
                  if (android) ...[
                    const SizedBox(height: TayfamSpacing.s24),
                    BirincilEylem(
                      etiket: metinler.hesap_guncelleme_magaza,
                      ikon: Icons.system_update_outlined,
                      onPressed: () =>
                          disBaglantiyiAc(context, ref, playMagazaAdresi),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
