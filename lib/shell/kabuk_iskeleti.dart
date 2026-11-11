import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';
import 'package:tayfam/shell/okunmamis.dart';

/// Dört sabit sekmeli uygulama kabuğu (ADR-0003): Tayfa, Sohbet,
/// Bildirimler, Profil.
///
/// Dar ekranda alt gezinme çubuğu, en az [TayfamSizes.genisEkranEsigi]
/// genişlikte solda dikey gezinme çubuğu gösterilir (ADR-0004 §5).
/// Sekmelerin sırası `yonlendirici.dart`'taki dalların sırasıyla aynıdır.
/// Uygulama ön plana dönünce tayfa listesi ([TayfaYenileyici]) ve
/// bildirimler ([BildirimYenileyici]) yenilenir; Bildirimler sekmesi
/// açılınca da bildirimler yenilenir (ADR-0018 §3).
class KabukIskeleti extends ConsumerWidget {
  const KabukIskeleti({super.key, required this.navigationShell});

  /// go_router'ın sekme dallarını tutan kabuğu.
  final StatefulNavigationShell navigationShell;

  /// Bildirimler sekmesinin sırası (`yonlendirici.dart`'taki dallar).
  static const int _bildirimlerSekmesi = 2;

  void _sekmeyeGit(WidgetRef ref, int index) {
    if (index == _bildirimlerSekmesi) bildirimleriYenile(ref);
    // Seçili sekmeye yeniden dokunmak o sekmenin köküne döndürür.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final sohbet = ref.watch(okunmamisSohbetSayisiProvider);
    final bildirim = ref.watch(okunmamisBildirimSayisiProvider);

    final sekmeler = [
      _Sekme(
        ikon: Icons.groups_outlined,
        seciliIkon: Icons.groups,
        etiket: metinler.gezinme_sekme_tayfa,
      ),
      _Sekme(
        ikon: Icons.chat_bubble_outline,
        seciliIkon: Icons.chat_bubble,
        etiket: metinler.gezinme_sekme_sohbet,
        okunmamis: sohbet,
        okunmamisEtiketi: metinler.gezinme_sohbet_okunmamis(sohbet),
      ),
      _Sekme(
        ikon: Icons.notifications_outlined,
        seciliIkon: Icons.notifications,
        etiket: metinler.gezinme_sekme_bildirimler,
        okunmamis: bildirim,
        okunmamisEtiketi: metinler.gezinme_bildirim_okunmamis(bildirim),
      ),
      _Sekme(
        ikon: Icons.person_outline,
        seciliIkon: Icons.person,
        etiket: metinler.gezinme_sekme_profil,
      ),
    ];

    if (MediaQuery.sizeOf(context).width >= TayfamSizes.genisEkranEsigi) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (i) => _sekmeyeGit(ref, i),
                labelType: NavigationRailLabelType.all,
                scrollable: true,
                destinations: [
                  for (final sekme in sekmeler)
                    NavigationRailDestination(
                      icon: _SekmeIkonu(sekme: sekme, secili: false),
                      selectedIcon: _SekmeIkonu(sekme: sekme, secili: true),
                      label: Text(sekme.etiket),
                    ),
                ],
              ),
            ),
            Expanded(
              child: BildirimYenileyici(
                child: TayfaYenileyici(child: navigationShell),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: BildirimYenileyici(
        child: TayfaYenileyici(child: navigationShell),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => _sekmeyeGit(ref, i),
        destinations: [
          for (final sekme in sekmeler)
            NavigationDestination(
              icon: _SekmeIkonu(sekme: sekme, secili: false),
              selectedIcon: _SekmeIkonu(sekme: sekme, secili: true),
              label: sekme.etiket,
            ),
        ],
      ),
    );
  }
}

@immutable
class _Sekme {
  const _Sekme({
    required this.ikon,
    required this.seciliIkon,
    required this.etiket,
    this.okunmamis = 0,
    this.okunmamisEtiketi,
  });

  final IconData ikon;
  final IconData seciliIkon;
  final String etiket;
  final int okunmamis;
  final String? okunmamisEtiketi;
}

/// Sekme ikonu ve okunmamış rozeti.
///
/// Rozet yalnızca sayı 0'dan büyükken görünür. Rozetteki sayı ekran
/// okuyucudan gizlenir; yerine "3 okunmamış mesaj" gibi açıklayıcı etiket
/// okunur (ADR-0003).
class _SekmeIkonu extends StatelessWidget {
  const _SekmeIkonu({required this.sekme, required this.secili});

  final _Sekme sekme;
  final bool secili;

  /// Rozette gösterilen en büyük sayı; üstü "99+" olur.
  static const int _rozetSiniri = 99;

  @override
  Widget build(BuildContext context) {
    final ikon = Icon(secili ? sekme.seciliIkon : sekme.ikon);
    final etiket = sekme.okunmamisEtiketi;
    if (sekme.okunmamis <= 0 || etiket == null) {
      return ikon;
    }
    final metinler = AppLocalizations.of(context);
    final sayi = sekme.okunmamis > _rozetSiniri
        ? metinler.gezinme_rozet_cok
        : metinler.gezinme_rozet_sayi(sekme.okunmamis);
    return Semantics(
      label: etiket,
      child: ExcludeSemantics(
        child: Badge(label: Text(sayi), child: ikon),
      ),
    );
  }
}
