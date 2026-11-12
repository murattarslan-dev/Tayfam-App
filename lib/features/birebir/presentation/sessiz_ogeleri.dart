import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

enum _Secim { sessizeAl, sesiAc }

/// Konuşma ekranının üst çubuğundaki menü: "Sessize al" (8 saat, 1 hafta,
/// süresiz) ya da sessizdeyse bitişiyle birlikte "Sesi aç". Sessize alma
/// mesajları gizlemez; yalnızca anlık bildirim (push) gitmez (Tayfam-Api
/// ADR-0019 §3). Tercihler okunamadıysa menü görünmez.
class KonusmaSessizMenusu extends ConsumerWidget {
  const KonusmaSessizMenusu({super.key, required this.konusmaId});

  final String konusmaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final sessizlikler = ref.watch(konusmaSessizlikProvider).value;
    if (sessizlikler == null) return const SizedBox.shrink();
    final simdi = ref.read(birebirSaatiProvider)();
    final sessizlik = sessizlikler[konusmaId];
    final etkin = sessizlik != null && sessizlik.etkin(simdi)
        ? sessizlik
        : null;
    return PopupMenuButton<_Secim>(
      tooltip: m.birebir_sessiz_menu_ipucu,
      onSelected: (secim) => unawaited(_sec(context, ref, secim)),
      itemBuilder: (_) => [
        if (etkin case final s?)
          PopupMenuItem(
            value: _Secim.sesiAc,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(m.birebir_sessiz_ac),
              subtitle: Text(_bitisMetni(m, s.bitis)),
            ),
          )
        else
          PopupMenuItem(
            value: _Secim.sessizeAl,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(m.birebir_sessiz_al),
            ),
          ),
      ],
    );
  }

  Future<void> _sec(BuildContext context, WidgetRef ref, _Secim secim) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final notifier = ref.read(konusmaSessizlikProvider.notifier);
    switch (secim) {
      case _Secim.sessizeAl:
        final sure = await _sureSec(context);
        if (sure == null || !context.mounted) return;
        final hata = await notifier.sessizeAl(konusmaId, sure);
        birebirSonucunuBildir(bildirim, m, hata, m.birebir_sessiz_alindi);
      case _Secim.sesiAc:
        final hata = await notifier.sesiAc(konusmaId);
        birebirSonucunuBildir(bildirim, m, hata, m.birebir_sessiz_acildi);
    }
  }

  Future<SessizSure?> _sureSec(BuildContext context) {
    final m = AppLocalizations.of(context);
    return showModalBottomSheet<SessizSure>(
      context: context,
      showDragHandle: true,
      builder: (sayfa) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.kenarMobil,
                ),
                child: Text(
                  m.birebir_sessiz_sure_baslik,
                  style: context.yazi.titleMedium?.copyWith(
                    color: context.renkler.metin,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s8,
                  TayfamSpacing.kenarMobil,
                  TayfamSpacing.s8,
                ),
                child: BirebirAciklama(m.birebir_sessiz_aciklama),
              ),
              for (final sure in SessizSure.values)
                ListTile(
                  leading: Icon(
                    sure == SessizSure.suresiz
                        ? Icons.notifications_off_outlined
                        : Icons.schedule_outlined,
                  ),
                  title: Text(_sureMetni(m, sure)),
                  onTap: () => Navigator.of(sayfa).pop(sure),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sureMetni(AppLocalizations m, SessizSure sure) => switch (sure) {
  SessizSure.sekizSaat => m.birebir_sessiz_sure_8_saat,
  SessizSure.birHafta => m.birebir_sessiz_sure_1_hafta,
  SessizSure.suresiz => m.birebir_sessiz_sure_suresiz,
};

String _bitisMetni(AppLocalizations m, DateTime? bitis) {
  if (bitis == null) return m.birebir_sessiz_suresiz_durum;
  final yerel = bitis.toLocal();
  return m.birebir_sessiz_bitis(yerel, yerel);
}

/// Konuşma listesinde sessize alınmış konuşmanın simgesi; ekran okuyucu
/// "Sessizde" okur.
class SessizSimgesi extends StatelessWidget {
  const SessizSimgesi({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).birebir_sessiz_simge,
      excludeSemantics: true,
      child: Icon(
        Icons.notifications_off_outlined,
        size: TayfamSizes.ikonKucuk,
        color: context.renkler.metinIkincil,
      ),
    );
  }
}
