import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

enum _Secim { profil, sessizeAl, sesiAc }

/// Birebir konuşma ekranının üst çubuğundaki ⋯ düğmesi (2026-11-13
/// tasarım: Birebir-Menu): alttan sayfada karşı tarafın avatarı ve adı,
/// "Profili gör" ve "Sessize al" (8 saat, 1 hafta, süresiz) ya da
/// sessizdeyse bitişiyle birlikte "Sesi aç". Sessize alma mesajları
/// gizlemez; yalnızca anlık bildirim (push) gitmez (Tayfam-Api ADR-0019
/// §3). Tercihler okunamadıysa sessize alma satırı görünmez; karşı tarafın
/// hesabı silinmişse "Profili gör" yoktur. İkisi de yoksa düğme görünmez.
class KonusmaMenusu extends ConsumerWidget {
  const KonusmaMenusu({
    super.key,
    required this.konusmaId,
    required this.karsiId,
  });

  final String konusmaId;

  /// Karşı tarafın kimliği; hesabı silinmişse `null`.
  final String? karsiId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final sessizlikler = ref.watch(konusmaSessizlikProvider).value;
    final karsiId = this.karsiId;
    if (sessizlikler == null && karsiId == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: m.birebir_sessiz_menu_ipucu,
      icon: const Icon(Icons.more_horiz),
      onPressed: () => unawaited(_ac(context, ref)),
    );
  }

  Future<void> _ac(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final karsiId = this.karsiId;
    final sessizlikler = ref.read(konusmaSessizlikProvider).value;
    final simdi = ref.read(birebirSaatiProvider)();
    final sessizlik = sessizlikler?[konusmaId];
    final etkin = sessizlik != null && sessizlik.etkin(simdi)
        ? sessizlik
        : null;
    final secim = await altSayfaAc<_Secim>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        ust: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TayfamSpacing.s8,
            0,
            TayfamSpacing.s8,
            TayfamSpacing.s12,
          ),
          child: Row(
            children: [
              KimlikAvatari(
                kullaniciId: karsiId,
                cap: TayfamSizes.konusmaAvatari,
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: KarsiTarafAdi(
                    kullaniciId: karsiId,
                    style: sayfa.yazi.headlineSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        children: [
          if (karsiId != null)
            MenuSatiri(
              ikon: Icons.person_outline,
              baslik: m.birebir_profili_gor,
              onTap: () => Navigator.of(sayfa).pop(_Secim.profil),
            ),
          if (sessizlikler != null)
            if (etkin case final s?)
              MenuSatiri(
                ikon: Icons.notifications_active_outlined,
                baslik: m.birebir_sessiz_ac,
                aciklama: _bitisMetni(m, s.bitis),
                onTap: () => Navigator.of(sayfa).pop(_Secim.sesiAc),
              )
            else
              MenuSatiri(
                ikon: Icons.notifications_off_outlined,
                baslik: m.birebir_sessiz_al,
                aciklama: m.birebir_sessiz_al_aciklama,
                onTap: () => Navigator.of(sayfa).pop(_Secim.sessizeAl),
              ),
        ],
      ),
    );
    if (secim == null || !context.mounted) return;
    await _sec(context, ref, secim);
  }

  Future<void> _sec(BuildContext context, WidgetRef ref, _Secim secim) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final notifier = ref.read(konusmaSessizlikProvider.notifier);
    switch (secim) {
      case _Secim.profil:
        final karsiId = this.karsiId;
        if (karsiId != null) unawaited(context.push(Adresler.kisi(karsiId)));
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
    return altSayfaAc<SessizSure>(
      context,
      builder: (sayfa) => AltSayfaIcerigi(
        baslik: m.birebir_sessiz_sure_baslik,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TayfamSpacing.s8,
              0,
              TayfamSpacing.s8,
              TayfamSpacing.s8,
            ),
            child: BirebirAciklama(m.birebir_sessiz_aciklama),
          ),
          for (final sure in SessizSure.values)
            MenuSatiri(
              ikon: sure == SessizSure.suresiz
                  ? Icons.notifications_off_outlined
                  : Icons.schedule_outlined,
              baslik: _sureMetni(m, sure),
              onTap: () => Navigator.of(sayfa).pop(sure),
            ),
        ],
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
