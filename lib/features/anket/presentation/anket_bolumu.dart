import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_karti.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasındaki "Açık anketler" bölümü (ADR-0018 Genel): en
/// yeni üç açık anket ve "Tüm anketler" bağlantısı. Açık anket yoksa kısa
/// bir boş durum ve "Anket aç" kısayolu (her üye anket açabilir; yetkiyi
/// sunucu verir).
class AnketBolumu extends ConsumerWidget {
  const AnketBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = anketListesiProvider((
      tayfaId: tayfaId,
      etkinlikId: null,
    ));
    final durum = ref.watch(saglayici);
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final liste = durum.value;
    final hata = durum.error;
    final acik = liste == null
        ? const <Poll>[]
        : anaSayfaAnketleri(liste.ogeler, simdi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.anket_ana_baslik,
          tumuEtiketi: m.anket_ana_tumu,
          onTumu: () => context.go(Adresler.anketler(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(etiket: m.anket_yukleniyor, gecikmeli: true,),
          )
        else if (acik.isEmpty) ...[
          Text(
            m.anket_ana_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IkincilEylem(
              etiket: m.anket_ac,
              ikon: Icons.add,
              onPressed: () =>
                  unawaited(anketFormunuAc(context, tayfaId: tayfaId)),
            ),
          ),
        ] else
          for (final (sira, anket) in acik.indexed) ...[
            if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
            AnketKarti(
              anket: anket,
              simdi: simdi,
              onTap: () => context.go(Adresler.anket(tayfaId, anket.id)),
            ),
          ],
      ],
    );
  }
}
