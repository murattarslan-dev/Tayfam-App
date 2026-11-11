import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/bildirim_listesi_notifier.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bildirimler sekmesi (`/bildirimler`; ADR-0018 §3): bütün tayfaların
/// bildirimleri tek listede, en yeni önce, sayfalı. Aşağı çekince
/// yenilenir; okunmamış varken "Hepsini okundu say" gösterilir.
///
/// Bildirime dokununca okundu işaretlenir ve hedefi açılır
/// ([bildirimAdresi]); hedefin ekranı yoksa yalnızca okundu işaretlenir.
class BildirimlerEkrani extends ConsumerStatefulWidget {
  const BildirimlerEkrani({super.key});

  @override
  ConsumerState<BildirimlerEkrani> createState() => _BildirimlerEkraniState();
}

class _BildirimlerEkraniState extends ConsumerState<BildirimlerEkrani> {
  bool _hepsiIsleniyor = false;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(bildirimListesiProvider);
    final sayi = ref.watch(okunmamisBildirimProvider).value ?? 0;
    final liste = durum.value;
    final hata = durum.error;
    final okunmamisVar =
        sayi > 0 || (liste?.ogeler.any((b) => !b.read) ?? false);
    return Scaffold(
      appBar: AppBar(title: Text(m.gezinme_sekme_bildirimler)),
      body: RefreshIndicator(
        onRefresh: _yenile,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
              children: [
                if (liste == null && hata != null) ...[
                  HataSatiri.hatadan(hata),
                  _MetinDugmesi(
                    etiket: m.tayfa_ana_tekrar_dene,
                    onPressed: () => ref.invalidate(bildirimListesiProvider),
                  ),
                ] else if (liste == null)
                  Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: m.bildirim_yukleniyor,
                    ),
                  )
                else if (liste.ogeler.isEmpty)
                  Text(
                    m.bildirim_bos,
                    style: context.yazi.bodyLarge?.copyWith(
                      color: context.renkler.metinGovde,
                    ),
                  )
                else ...[
                  if (okunmamisVar) ...[
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _MetinDugmesi(
                        etiket: m.bildirim_hepsini_okundu_say,
                        ikon: Icons.done_all,
                        onPressed: _hepsiIsleniyor ? null : _hepsiniOkunduSay,
                      ),
                    ),
                    const SizedBox(height: TayfamSpacing.s8),
                  ],
                  for (final (sira, bildirim) in liste.ogeler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    BildirimKarti(
                      bildirim: bildirim,
                      onTap: () => _ac(bildirim),
                    ),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  if (liste.dahaHatasi case final dahaHatasi?) ...[
                    HataSatiri.hatadan(dahaHatasi),
                    _MetinDugmesi(
                      etiket: m.tayfa_ana_tekrar_dene,
                      onPressed: _dahaFazla,
                    ),
                  ] else if (liste.dahaYukleniyor)
                    Center(
                      child: CircularProgressIndicator(
                        semanticsLabel: m.bildirim_yukleniyor,
                      ),
                    )
                  else if (liste.dahaVar)
                    Center(
                      child: _MetinDugmesi(
                        etiket: m.tayfa_ana_daha_fazla,
                        onPressed: _dahaFazla,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bildirimi okundu işaretler ve hedefini açar. Hedef yoksa yalnızca
  /// okundu işaretlenir.
  void _ac(Notification bildirim) {
    unawaited(
      ref.read(bildirimListesiProvider.notifier).okunduIsaretle(bildirim.id),
    );
    final adres = bildirimAdresi(bildirim);
    if (adres != null) context.go(adres);
  }

  void _dahaFazla() =>
      unawaited(ref.read(bildirimListesiProvider.notifier).dahaFazla());

  Future<void> _hepsiniOkunduSay() async {
    setState(() => _hepsiIsleniyor = true);
    final hata = await ref
        .read(bildirimListesiProvider.notifier)
        .hepsiniOkunduSay();
    if (!mounted) return;
    setState(() => _hepsiIsleniyor = false);
    if (hata != null && hata is! OturumYok) hataBildir(context, hata);
  }

  /// Listeyi ve rozeti yeniler. Liste yenilenemezse eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile() async {
    final rozet = ref.read(okunmamisBildirimProvider.notifier).yenile();
    final hata = await ref.read(bildirimListesiProvider.notifier).yenile();
    await rozet;
    if (!mounted) return;
    if (hata == null || hata is OturumYok) return;
    if (ref.read(bildirimListesiProvider).hasValue) hataBildir(context, hata);
  }
}

class _MetinDugmesi extends StatelessWidget {
  const _MetinDugmesi({required this.etiket, this.ikon, this.onPressed});

  final String etiket;
  final IconData? ikon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final stil = TextButton.styleFrom(
      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
    );
    final ikon = this.ikon;
    if (ikon == null) {
      return TextButton(
        onPressed: onPressed,
        style: stil,
        child: Text(etiket),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      style: stil,
      icon: Icon(ikon),
      label: Text(etiket),
    );
  }
}
