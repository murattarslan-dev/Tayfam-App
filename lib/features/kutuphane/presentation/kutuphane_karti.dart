import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_formu.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfada en çok bu kadar son eklenen kalem gösterilir.
const int kartKalemSayisi = 3;

/// Ana sayfadaki "Ortak eşya" kartı (`library`; App ADR-0033 §2): son
/// eklenenler ve ödünçteki kalem sayısı. Veri modülün kendi ucundan
/// (`GET …/library/items`) gelir. "Tümü" kütüphaneyi açar; kütüphane boşsa
/// ekleyebilen üyeye "Eşya ekle". Modül kapalıysa (`module-disabled`) kart
/// yer kaplamaz.
class KutuphaneKarti extends ConsumerWidget {
  const KutuphaneKarti({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = kalemlerProvider((
      tayfaId: tayfaId,
      tur: null,
      benim: false,
    ));
    final durum = ref.watch(saglayici);
    final veri = durum.value;
    final hata = durum.error;
    if (veri == null &&
        hata is ApiProblem &&
        hata.type == ProblemType.moduleDisabled) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: m.kutuphane_ad,
          tumuEtiketi: m.kutuphane_tumu,
          onTumu: () => context.go(kutuphaneAdresi(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (veri != null)
          _Icerik(tayfaId: tayfaId, liste: veri)
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
              etiket: m.kutuphane_yukleniyor,
              gecikmeli: true,
            ),
          ),
      ],
    );
  }
}

class _Icerik extends StatelessWidget {
  const _Icerik({required this.tayfaId, required this.liste});

  final String tayfaId;
  final LibraryItemList liste;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kalemler = liste.items;
    if (kalemler.isEmpty) {
      return TayfamKart(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              m.kutuphane_bos,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
            if (liste.callerCanAdd) ...[
              const SizedBox(height: TayfamSpacing.s8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => unawaited(kalemFormunuAc(context, tayfaId)),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(m.kutuphane_ekle),
                ),
              ),
            ],
          ],
        ),
      );
    }
    final oduncte = kalemler
        .where((k) => k.status == LibraryItemStatus.onLoan)
        .length;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            oduncte > 0
                ? m.kutuphane_kart_ozet_oduncte(kalemler.length, oduncte)
                : m.kutuphane_kart_ozet(kalemler.length),
            style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          for (final kalem in kalemler.take(kartKalemSayisi))
            InkWell(
              key: ValueKey(kalem.id),
              onTap: () => unawaited(
                context.push(kalemAdresi(tayfaId, kalem.id)),
              ),
              borderRadius: TayfamRadii.dugmeKoseleri,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TayfamSizes.dokunmaMin,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TayfamSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(turIkonu(kalem.kind), color: r.marka),
                      ),
                      const SizedBox(width: TayfamSpacing.s12),
                      Expanded(
                        child: Text(
                          kalem.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: yazi.bodyLarge?.copyWith(color: r.metin),
                        ),
                      ),
                      const SizedBox(width: TayfamSpacing.s8),
                      DurumEtiketi(durum: kalem.status),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
