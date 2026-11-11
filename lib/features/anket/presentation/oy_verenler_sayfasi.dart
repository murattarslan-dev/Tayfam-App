import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/oy_verenler_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açık (gizli olmayan) ankette [secenek]'e oy verenleri alttan açılan
/// sayfada gösterir (ADR-0018 §5). Gizli ankette hiçbir şey yapmaz: sayfa
/// açılmaz, istek gitmez (kesin kural 7).
Future<void> oyVerenleriGoster(
  BuildContext context, {
  required String tayfaId,
  required Poll anket,
  required PollOption secenek,
}) async {
  if (!oyVerenlerGorunur(anket)) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => OyVerenlerSayfasi(
      anahtar: (tayfaId: tayfaId, anket: anket, secenekId: secenek.id),
      secenekMetni: secenek.text,
    ),
  );
}

/// Bir seçeneğe oy verenlerin listesi: görünen adlar, en eski oy önce,
/// sayfalı.
class OyVerenlerSayfasi extends ConsumerWidget {
  const OyVerenlerSayfasi({
    super.key,
    required this.anahtar,
    required this.secenekMetni,
  });

  final OyVerenlerAnahtari anahtar;
  final String secenekMetni;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = oyVerenlerProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.only(
        start: TayfamSpacing.kenarMobil,
        end: TayfamSpacing.kenarMobil,
        bottom: TayfamSpacing.kenarMobil,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(m.anket_oy_verenler, style: context.yazi.titleMedium),
        ),
        const SizedBox(height: TayfamSpacing.s4),
        Text(
          secenekMetni,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s16),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
        ] else if (liste == null)
          Center(
            child: CircularProgressIndicator(
              semanticsLabel: m.anket_yukleniyor,
            ),
          )
        else if (liste.ogeler.isEmpty)
          Text(m.anket_oy_verenler_bos, style: context.yazi.bodyLarge)
        else ...[
          for (final oy in liste.ogeler)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.dokunmaMin,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: KullaniciAdiMetni(
                  kullaniciId: oy.userId,
                  style: context.yazi.bodyLarge,
                ),
              ),
            ),
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            HataSatiri.hatadan(dahaHatasi),
            AnketTekrarDene(
              onPressed: () =>
                  unawaited(ref.read(saglayici.notifier).dahaFazla()),
            ),
          ] else if (liste.dahaYukleniyor)
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: m.anket_yukleniyor,
              ),
            )
          else if (liste.dahaVar)
            Center(
              child: TextButton(
                onPressed: () =>
                    unawaited(ref.read(saglayici.notifier).dahaFazla()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.tayfa_ana_daha_fazla),
              ),
            ),
        ],
      ],
    );
  }
}
