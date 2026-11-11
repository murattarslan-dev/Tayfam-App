import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/reddedilenler_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Reddedilen mesaj istekleri (ADR-0018 §9). Listeyi yalnızca kullanıcı
/// görür. "Listeden çıkar" isteği yeniden mesaj isteklerine taşır;
/// gönderene bildirim gitmez.
class ReddedilenlerEkrani extends ConsumerWidget {
  const ReddedilenlerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(reddedilenlerProvider);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.birebir_reddedilenler)),
      body: RefreshIndicator(
        onRefresh: () async {
          final hata = await ref.read(reddedilenlerProvider.notifier).yenile();
          if (hata != null &&
              context.mounted &&
              ref.read(reddedilenlerProvider).hasValue) {
            birebirHatasiniBildir(context, hata);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            BirebirAciklama(m.birebir_reddedilenler_aciklama),
            const Divider(),
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              BirebirTekrarDene(
                onPressed: () => ref.invalidate(reddedilenlerProvider),
              ),
            ] else if (liste == null)
              BirebirYukleniyor(etiket: m.birebir_yukleniyor)
            else ...[
              if (liste.ogeler.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TayfamSpacing.s16,
                  ),
                  child: BirebirAciklama(m.birebir_reddedilenler_bos),
                ),
              for (final r in liste.ogeler) _ReddedilenSatiri(istek: r),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                BirebirTekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                BirebirYukleniyor(etiket: m.birebir_yukleniyor)
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.birebir_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(reddedilenlerProvider.notifier).dahaFazla());
}

class _ReddedilenSatiri extends ConsumerWidget {
  const _ReddedilenSatiri({required this.istek});

  final DeclinedRequest istek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yerel = istek.declinedAt.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KullaniciAdiMetni(
            kullaniciId: istek.senderUserId,
            style: context.yazi.titleMedium?.copyWith(color: r.metin),
          ),
          Text(
            m.birebir_reddedilen_tarih(yerel),
            style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
          ),
          TextButton(
            onPressed: () => unawaited(_cikar(context, ref)),
            style: TextButton.styleFrom(
              minimumSize: const Size.square(TayfamSizes.dokunmaMin),
            ),
            child: Text(m.birebir_listeden_cikar),
          ),
        ],
      ),
    );
  }

  Future<void> _cikar(BuildContext context, WidgetRef ref) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    final hata = await ref
        .read(reddedilenlerProvider.notifier)
        .listedenCikar(istek.conversationId);
    birebirSonucunuBildir(bildirim, m, hata, m.birebir_listeden_cikarildi);
  }
}
