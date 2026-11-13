import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/profil/application/hesap_ayarlari_notifier.dart';
import 'package:tayfam/features/profil/application/profil_tamamlama.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/features/profil/presentation/tanitim_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Tanıtım bilgilerin" (`/profil/tanitim`; tasarım: Profil-Tanitim;
/// issue #186): profil tamamlama alanları tek tek ve şu anki değerleriyle
/// ("Paylaşmak istemiyorum", "Eklenmedi"); her satır formun ilgili adımını
/// tek başına açar. Altta Gizlilik: "Kim görür" (formun son adımı) ve
/// "Doğum günün" (alttan sayfa; issue #185).
class TanitimBilgileriEkrani extends ConsumerWidget {
  const TanitimBilgileriEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(hesapAyarlariProvider);
    return Scaffold(
      appBar: AppBar(title: Text(m.profil_tanitim_baslik)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: switch (durum) {
              AsyncData(:final value) => _Icerik(hesap: value),
              AsyncError(:final error) => ListView(
                padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
                children: [
                  HataSatiri(metin: profilHatasiMetni(m, error)),
                  const SizedBox(height: TayfamSpacing.s8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => ref.invalidate(hesapAyarlariProvider),
                      child: Text(m.profil_tekrar_dene),
                    ),
                  ),
                ],
              ),
              AsyncLoading() => Center(
                child: TayfamYukleniyor(
                  boyut: TayfamSizes.yukleniyorTamEkran,
                  etiket: m.profil_yukleniyor,
                  gecikmeli: true,
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Icerik extends ConsumerWidget {
  const _Icerik({required this.hesap});

  final Account hesap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s8,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s4),
          child: Text(
            m.profil_tanitim_aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ),
        BolumEtiketi(baslik: m.profil_tanitim_bilgiler),
        ListeKarti(
          children: [
            for (final adim in TamamlamaAdimi.values)
              if (adim.alan case final alan?)
                MenuSatiri.kartta(
                  key: ValueKey('tanitim-${adim.yol}'),
                  baslik: adimAdi(m, adim),
                  aciklama: alanOzeti(m, hesap, alan),
                  sag: const SatirOku(),
                  onTap: () => unawaited(
                    context.push(Adresler.tanitimAdimi(adim.yol)),
                  ),
                ),
          ],
        ),
        BolumEtiketi(baslik: m.disa_aktarma_profil_bolum),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              key: const ValueKey('tanitim-kim-gorur'),
              ikon: Icons.visibility_outlined,
              baslik: m.profil_tanitim_kim_gorur,
              aciklama: tanitimGorunurlukAdi(m, hesap.aboutVisibility),
              sag: const SatirOku(),
              onTap: () => unawaited(
                context.push(
                  Adresler.tanitimAdimi(TamamlamaAdimi.gorunurluk.yol),
                ),
              ),
            ),
            MenuSatiri.kartta(
              key: const ValueKey('tanitim-dogum-gunu'),
              ikon: Icons.cake_outlined,
              baslik: m.profil_dogum_gunu,
              aciklama: dogumGunuAciklamasi(m, hesap.birthdayVisibility),
              sag: const SatirOku(),
              onTap: () => unawaited(dogumGunuSec(context, ref, hesap)),
            ),
          ],
        ),
      ],
    );
  }
}
