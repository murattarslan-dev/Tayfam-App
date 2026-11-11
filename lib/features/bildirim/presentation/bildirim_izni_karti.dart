import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kabuğun içeriğinin altında, gerektiğinde bildirim izni açıklama kartını
/// gösterir (istemci ADR-0019 §3). Kart ilk gerçek ihtiyaçta
/// ([BildirimIzniNotifier.ihtiyacDogdu]) bir kez çıkar; "İzin ver" sistem
/// penceresini açar, "Şimdi değil" kartı kapatır. Modal değildir: açık
/// ekranı ve gezinmeyi engellemez.
class BildirimIzniAlani extends ConsumerWidget {
  const BildirimIzniAlani({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goster = ref.watch(
      bildirimIzniProvider.select((d) => d.aciklamaGoster),
    );
    return Column(
      children: [
        Expanded(child: child),
        if (goster) const BildirimIzniKarti(),
      ],
    );
  }
}

/// Bildirim izni açıklama kartı.
class BildirimIzniKarti extends ConsumerWidget {
  const BildirimIzniKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final izin = ref.read(bildirimIzniProvider.notifier);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.s16,
          TayfamSpacing.s8,
          TayfamSpacing.s16,
          TayfamSpacing.s8,
        ),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: TayfamKart(
            oneCikan: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: TayfamSizes.ikon,
                        color: r.marka,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Expanded(
                      child: Text(
                        m.bildirim_izni_baslik,
                        style: context.yazi.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Text(
                  m.bildirim_izni_aciklama,
                  style: context.yazi.bodyMedium?.copyWith(
                    color: r.metinIkincil,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    IkincilEylem(
                      etiket: m.bildirim_izni_simdi_degil,
                      onPressed: () => unawaited(izin.aciklamayiReddet()),
                    ),
                    BirincilEylem(
                      etiket: m.bildirim_izni_ver,
                      onPressed: () => unawaited(izin.aciklamayiKabulEt()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
