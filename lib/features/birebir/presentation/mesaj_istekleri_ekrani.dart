import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/konusma_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Size gelen mesaj istekleri (`request_received`; ADR-0018 §9) ve
/// reddedilenlere giriş. İsteğe dokununca konuşma açılır; orada kabul,
/// ret ya da cevap yazılır. İstekler konuşma listesinden ayrılır;
/// listenin henüz okunmamış sayfaları "Daha fazla göster" ile okunur.
class MesajIstekleriEkrani extends ConsumerWidget {
  const MesajIstekleriEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(konusmaListesiProvider);
    final istekler = ref.watch(mesajIstekleriProvider);
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.birebir_istekler_baslik)),
      body: RefreshIndicator(
        onRefresh: () async {
          final hata = await ref.read(konusmaListesiProvider.notifier).yenile();
          if (hata != null && context.mounted) {
            birebirHatasiniBildir(context, hata);
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            BirebirAciklama(m.birebir_istekler_aciklama),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IkincilEylem(
                etiket: m.birebir_reddedilenler,
                ikon: Icons.block_outlined,
                onPressed: () => context.go(Adresler.reddedilenler),
              ),
            ),
            const Divider(),
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              BirebirTekrarDene(
                onPressed: () => ref.invalidate(konusmaListesiProvider),
              ),
            ] else if (liste == null)
              BirebirYukleniyor(etiket: m.birebir_yukleniyor)
            else ...[
              if (istekler.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TayfamSpacing.s16,
                  ),
                  child: BirebirAciklama(m.birebir_istekler_bos),
                ),
              for (final k in istekler)
                KonusmaSatiri(
                  konusma: k,
                  onTap: () => context.go(Adresler.birebirKonusma(k.id)),
                ),
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
      unawaited(ref.read(konusmaListesiProvider.notifier).dahaFazla());
}
