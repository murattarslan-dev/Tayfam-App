import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasındaki "Son sorular" bölümü (ADR-0018 Genel): en son
/// [anaSayfaSoruSayisi] soru ve "Tümü" bağlantısı. Boşken kısa bir boş
/// durum ve "Soru sor" kısayolu gösterilir (her üye soru sorabilir).
class SoruBolumu extends ConsumerWidget {
  const SoruBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = soruListesiProvider(anaSoruListesi(tayfaId));
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: metinler.soru_bolum_baslik,
          tumuEtiketi: metinler.soru_tum_sorular,
          onTumu: () => context.go(Adresler.sorular(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(metinler.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(etiket: metinler.soru_yukleniyor, gecikmeli: true,),
          )
        else if (liste.ogeler.isEmpty) ...[
          Text(
            metinler.soru_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BirincilEylem(
              etiket: metinler.soru_sor,
              ikon: Icons.help_outline,
              onPressed: () =>
                  unawaited(soruFormunuAc(context, tayfaId: tayfaId)),
            ),
          ),
        ] else
          for (final (sira, soru)
              in liste.ogeler.take(anaSayfaSoruSayisi).indexed) ...[
            if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
            SoruKarti(
              soru: soru,
              onTap: () => context.go(Adresler.soru(tayfaId, soru.id)),
            ),
          ],
      ],
    );
  }
}
