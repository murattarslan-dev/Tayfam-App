import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfadaki "Materyaller" kartı (`materials`; App ADR-0033 §2): son
/// eklenenler. Veri modülün kendi ucundan (`GET …/materials`) gelir ve
/// liste ekranının süzgeçsiz listesiyle paylaşılır. "Tümü" kütüphaneyi
/// açar; boşsa ekleyebilen üyeye "Materyal ekle". Satıra dokununca detay
/// açılır (bağlantı karttan doğrudan açılmaz). Modül kapalıysa
/// (`module-disabled`) kart yer kaplamaz.
class MateryalKarti extends ConsumerWidget {
  const MateryalKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = materyalListesiProvider(anaMateryalListesi(tayfaId));
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    if (liste == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.moduleDisabled) {
      return const SizedBox.shrink();
    }
    final ekleyebilir =
        durum.hasValue && ref.read(saglayici.notifier).ekleyebilir;
    final materyaller = liste?.ogeler.take(kartMateryalSayisi).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.materyal_ad,
          tumuEtiketi: m.materyal_tumu,
          onTumu: () => context.go(Adresler.materyal(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (materyaller != null && materyaller.isEmpty)
          TayfamKart(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  m.materyal_bos,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
                if (ekleyebilir) ...[
                  const SizedBox(height: TayfamSpacing.s8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => unawaited(
                        materyalFormunuAc(context, tayfaId: tayfaId),
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(m.materyal_ekle),
                    ),
                  ),
                ],
              ],
            ),
          )
        else if (materyaller != null)
          ListeKarti(
            children: [
              for (final materyal in materyaller)
                MateryalSatiri(
                  key: ValueKey(materyal.id),
                  materyal: materyal,
                  etiketler: false,
                  onTap: () => unawaited(
                    context.push(
                      Adresler.materyalDetayi(tayfaId, materyal.id),
                    ),
                  ),
                ),
            ],
          )
        else if (hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(m.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else
          Center(
            child: TayfamYukleniyor(
              etiket: m.materyal_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}
