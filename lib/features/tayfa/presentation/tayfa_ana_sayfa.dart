import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
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
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              children: [
                Text(
                  metinler.tayfa_ana_sayfa_bos,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tayfa ana sayfasının mor üst bölümü (ADR-0004 §2a): `brand` zemin üzerinde
/// beyaz tayfa adı; dokununca alttan tayfa değiştirme paneli açılır. İki
/// temada da aynıdır; odak çerçevesi mor yüzeyde mangodur.
class TayfaUstBolumu extends StatelessWidget {
  const TayfaUstBolumu({super.key, required this.ad});

  /// Gösterilecek tayfa adı.
  final String ad;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    return MarkaYuzeyi(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s4,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s20,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _TayfaAdiDugmesi(
              ad: ad,
              ipucu: metinler.tayfa_degistir_ipucu,
              // Panel bu (MarkaYuzeyi dışındaki) bağlamla açılır; böylece
              // panel mor yüzeyin temasını (mango odak) devralmaz.
              onPressed: () => unawaited(tayfaDegistirmePaneliniAc(context)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TayfaAdiDugmesi extends StatelessWidget {
  const _TayfaAdiDugmesi({
    required this.ad,
    required this.ipucu,
    required this.onPressed,
  });

  final String ad;
  final String ipucu;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: r.markaYuzeyUstu,
          textStyle: context.yazi.headlineSmall,
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s12,
            vertical: TayfamSpacing.s8,
          ),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
        ),
        child: Semantics(
          hint: ipucu,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(ad)),
              const SizedBox(width: TayfamSpacing.s4),
              const ExcludeSemantics(child: Icon(Icons.expand_more)),
            ],
          ),
        ),
      ),
    );
  }
}
