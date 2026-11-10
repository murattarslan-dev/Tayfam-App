import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa sekmesinin kökü: bir tayfanın ana sayfası (`/t/<tayfaId>`).
///
/// [tayfaId] adresten gelir ve yalnızca biçimi doğrulanmıştır; tayfanın
/// içeriği varsayılmaz, sunucudan gelir (ADR-0003). Yaklaşan etkinlikler,
/// son duyurular ve modül kartları kendi paketlerinde eklenir.
class TayfaAnaSayfa extends ConsumerWidget {
  const TayfaAnaSayfa({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final ad =
        ref.watch(tayfaAdiProvider(tayfaId)) ?? metinler.tayfa_adi_bilinmiyor;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TayfaUstBolumu(ad: ad),
          Expanded(
            child: ListView(
              // TODO(#6): TayfamSpacing
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  metinler.tayfa_ana_sayfa_bos,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tayfa ana sayfasının mor üst bölümü (ADR-0004 §2a): tayfa adı ve
/// dokununca alttan açılan tayfa değiştirme paneli.
///
/// Renkler şimdilik `colorScheme.primary` zemin + `onPrimary` metindir;
/// tema (#6) marka renklerini (`brand` + beyaz) buraya getirir.
// TODO(#6): TayfamColors.brand zemin, beyaz metin; iki temada aynı.
class TayfaUstBolumu extends StatelessWidget {
  const TayfaUstBolumu({super.key, required this.ad});

  /// Gösterilecek tayfa adı.
  final String ad;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final renkler = Theme.of(context).colorScheme;
    final durumCubugu =
        ThemeData.estimateBrightnessForColor(renkler.primary) ==
            Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: durumCubugu,
      child: ColoredBox(
        color: renkler.primary,
        child: SafeArea(
          bottom: false,
          child: Padding(
            // TODO(#6): TayfamSpacing
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => unawaited(tayfaDegistirmePaneliniAc(context)),
                style: TextButton.styleFrom(
                  foregroundColor: renkler.onPrimary,
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                ),
                child: Semantics(
                  hint: metinler.tayfa_degistir_ipucu,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(ad)),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
