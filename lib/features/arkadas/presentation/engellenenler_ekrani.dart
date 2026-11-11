import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Engellenen kullanıcılar (`/profil/arkadaslar/engellenenler`; ADR-0018
/// §7). Engeli kaldırmak onaylıdır; arkadaşlık geri gelmez.
class EngellenenlerEkrani extends ConsumerWidget {
  const EngellenenlerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(engellenenlerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(m.arkadas_engellenenler)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(engellenenlerProvider.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            Text(
              m.arkadas_engellenenler_aciklama,
              style: context.yazi.bodyMedium?.copyWith(
                color: context.renkler.metinGovde,
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(engellenenlerProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty)
                    BosMetin(m.arkadas_engellenenler_bos),
                  for (final (sira, kisi) in liste.ogeler.indexed) ...[
                    if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                    _EngelKarti(kisi: kisi),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () => unawaited(
                      ref.read(engellenenlerProvider.notifier).dahaFazla(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngelKarti extends ConsumerStatefulWidget {
  const _EngelKarti({required this.kisi});

  final BlockedUser kisi;

  @override
  ConsumerState<_EngelKarti> createState() => _EngelKartiState();
}

class _EngelKartiState extends ConsumerState<_EngelKarti> {
  bool _gonderiliyor = false;

  Future<void> _kaldir() async {
    final m = AppLocalizations.of(context);
    final bildirici = SonucBildirici.al(context);
    final onay = await onayIste(
      context,
      baslik: m.arkadas_engel_kaldir_baslik,
      aciklama: m.arkadas_engel_kaldir_aciklama,
      onay: m.arkadas_engel_kaldir,
    );
    if (!onay || !mounted) return;
    setState(() => _gonderiliyor = true);
    final hata = await ref
        .read(engellenenlerProvider.notifier)
        .engeliKaldir(widget.kisi.userId);
    if (mounted) setState(() => _gonderiliyor = false);
    bildirici.bildir(hata, m.arkadas_engel_kaldirildi);
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final kisi = widget.kisi;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            kisi.displayName ?? m.kullanici_silinmis,
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.arkadas_engel_zamani(kisi.blockedAt.toLocal()),
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IkincilEylem(
              etiket: m.arkadas_engel_kaldir,
              ikon: Icons.lock_open,
              onPressed: _gonderiliyor ? null : () => unawaited(_kaldir()),
            ),
          ),
        ],
      ),
    );
  }
}
