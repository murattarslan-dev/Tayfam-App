import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_formu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet sekmesinin Kanallar bölümü: aktif tayfanın görebildiğin
/// kanalları ve okunmamış sayıları (ADR-0018 §9). Yönetim kanalını yalnızca
/// yönetim görür; listeyi sunucu süzer. "Kanal aç" yalnızca yönetime
/// gösterilir; bu kolaylıktır, yetkiyi sunucu verir (kesin kural 5).
class KanalListesi extends ConsumerWidget {
  const KanalListesi({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = kanallarProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    final liste = durum.value;
    final hata = durum.error;
    return RefreshIndicator(
      onRefresh: () async {
        final hata = await ref.read(saglayici.notifier).yenile();
        if (hata != null && context.mounted && ref.read(saglayici).hasValue) {
          hataBildir(context, hata);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s16),
        children: [
          if (yonetimde)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TayfamSpacing.kenarMobil,
                0,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s16,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: BirincilEylem(
                  etiket: m.sohbet_kanal_ac,
                  ikon: Icons.add,
                  onPressed: () =>
                      unawaited(kanalFormunuAc(context, tayfaId: tayfaId)),
                ),
              ),
            ),
          if (liste == null && hata != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HataSatiri.hatadan(hata),
                  TextButton(
                    onPressed: () => ref.invalidate(saglayici),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.sohbet_tekrar_dene),
                  ),
                ],
              ),
            )
          else if (liste == null)
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: m.sohbet_kanallar_yukleniyor,
              ),
            )
          else if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TayfamSpacing.kenarMobil,
              ),
              child: Text(
                m.sohbet_kanallar_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              ),
            )
          else
            for (final kanal in liste)
              KanalSatiri(
                kanal: kanal,
                onTap: () => context.go(Adresler.kanal(tayfaId, kanal.id)),
              ),
        ],
      ),
    );
  }
}

/// Kanal listesindeki bir satır: ad, yönetim ya da arşiv etiketi ve
/// okunmamış rozeti ("99+" üstü).
class KanalSatiri extends StatelessWidget {
  const KanalSatiri({super.key, required this.kanal, required this.onTap});

  final Channel kanal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final arsivde = kanal.archivedAt != null;
    final yonetim = kanal.visibility == ChannelVisibility.staff;
    final okunmamis = arsivde ? 0 : (kanal.unreadCount ?? 0);
    final etiketler = [
      if (yonetim) m.sohbet_kanal_yonetim,
      if (arsivde) m.sohbet_kanal_arsivde,
    ];
    return ListTile(
      minTileHeight: TayfamSizes.dokunmaMin,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.kenarMobil,
      ),
      leading: Icon(
        arsivde
            ? Icons.inventory_2_outlined
            : (yonetim ? Icons.lock_outline : Icons.tag),
        color: r.metinIkincil,
      ),
      title: Text(
        kanal.name,
        style: context.yazi.titleMedium?.copyWith(
          color: arsivde ? r.metinIkincil : r.metin,
        ),
      ),
      subtitle: etiketler.isEmpty
          ? null
          : Text(
              etiketler.join(' · '),
              style: context.yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
      trailing: okunmamis > 0
          ? Semantics(
              label: m.sohbet_kanal_okunmamis(okunmamis),
              child: ExcludeSemantics(
                child: Badge(
                  label: Text(
                    okunmamis >= okunmamisUstSinir
                        ? m.gezinme_rozet_cok
                        : m.gezinme_rozet_sayi(okunmamis),
                  ),
                ),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
