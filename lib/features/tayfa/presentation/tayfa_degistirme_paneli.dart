import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa değiştirme panelini alttan açar (ADR-0003).
///
/// Panel kök navigator'da açılır; gezinme çubuğunun da üstünü örter.
/// Seçenekler paneli kapatıp akışı [context]'in yönlendiricisiyle açar.
Future<void> tayfaDegistirmePaneliniAc(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (panelContext) {
      void ac(String adres) {
        Navigator.of(panelContext).pop();
        unawaited(context.push<void>(adres));
      }

      return TayfaDegistirmePaneli(
        onKodlaKatil: () => ac(Adresler.tayfaKatil),
        onTayfaOlustur: () => ac(Adresler.tayfaOlustur),
      );
    },
  );
}

/// Tayfa değiştirme panelinin içeriği: Tayfalarım, kodla katıl, tayfa
/// oluştur.
///
/// GEÇİCİ: "Tayfalarım" listesi ApiClient (#7) sonrasında sunucudan
/// gelir; o zamana kadar boş durum gösterilir (sahte veri yok).
class TayfaDegistirmePaneli extends StatelessWidget {
  const TayfaDegistirmePaneli({
    super.key,
    required this.onKodlaKatil,
    required this.onTayfaOlustur,
  });

  /// "Kodla katıl" seçildiğinde.
  final VoidCallback onKodlaKatil;

  /// "Tayfa oluştur" seçildiğinde.
  final VoidCallback onTayfaOlustur;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: TayfamSpacing.s16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
          ),
          child: Semantics(
            header: true,
            child: Text(metinler.tayfa_tayfalarim, style: yazi.titleMedium),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s8,
            TayfamSpacing.kenarMobil,
            TayfamSpacing.s16,
          ),
          child: Text(
            metinler.tayfa_tayfalarim_bos,
            style: yazi.bodyMedium?.copyWith(color: context.renkler.metinGovde),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const ExcludeSemantics(child: Icon(Icons.vpn_key_outlined)),
          title: Text(metinler.tayfa_kodla_katil),
          onTap: onKodlaKatil,
        ),
        ListTile(
          leading: const ExcludeSemantics(
            child: Icon(Icons.add_circle_outline),
          ),
          title: Text(metinler.tayfa_olustur),
          onTap: onTayfaOlustur,
        ),
      ],
    );
  }
}
