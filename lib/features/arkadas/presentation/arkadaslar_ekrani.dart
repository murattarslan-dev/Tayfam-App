import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/arkadas/application/arkadaslar_notifier.dart';
import 'package:tayfam/features/arkadas/application/tayfa_davetleri_notifier.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Arkadaşlar (`/profil/arkadaslar`; ADR-0018 §7): arkadaş ekleme,
/// istekler ve engellenenler girişleri, arkadaş listesi. Kişiye dokununca
/// profili açılır; arkadaşlıktan çıkarma ve engelleme oradadır.
class ArkadaslarEkrani extends ConsumerWidget {
  const ArkadaslarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(arkadaslarProvider);
    final gelenVar = ref.watch(gelenIstekVarProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(m.arkadas_baslik),
        actions: [
          IconButton(
            onPressed: () => unawaited(context.push(Adresler.arkadasBul)),
            tooltip: m.arkadas_ekle,
            icon: const Icon(Icons.person_add_alt),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(gelenIstekVarProvider);
          await ref.read(arkadaslarProvider.notifier).yenile();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            TayfamKart(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GirisSatiri(
                    ikon: Icons.person_add_alt,
                    etiket: m.arkadas_ekle,
                    onTap: () => unawaited(context.push(Adresler.arkadasBul)),
                  ),
                  GirisSatiri(
                    ikon: Icons.mark_email_unread_outlined,
                    etiket: m.arkadas_istekler,
                    rozet: gelenVar,
                    rozetEtiketi: m.arkadas_istek_bekliyor,
                    onTap: () =>
                        unawaited(context.push(Adresler.arkadasIstekleri)),
                  ),
                  GirisSatiri(
                    ikon: Icons.block,
                    etiket: m.arkadas_engellenenler,
                    onTap: () =>
                        unawaited(context.push(Adresler.engellenenler)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: TayfamSpacing.s24),
            BolumBasligi(baslik: m.arkadas_liste_baslik),
            const SizedBox(height: TayfamSpacing.s8),
            ListeDurumu(
              deger: durum.value,
              hata: durum.error,
              onTekrar: () => ref.invalidate(arkadaslarProvider),
              icerik: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (liste.ogeler.isEmpty) BosMetin(m.arkadas_liste_bos),
                  for (final arkadas in liste.ogeler)
                    _ArkadasSatiri(arkadas: arkadas),
                  const SizedBox(height: TayfamSpacing.s16),
                  SayfaSonu(
                    dahaVar: liste.dahaVar,
                    yukleniyor: liste.dahaYukleniyor,
                    hata: liste.dahaHatasi,
                    onDaha: () => unawaited(
                      ref.read(arkadaslarProvider.notifier).dahaFazla(),
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

class _ArkadasSatiri extends StatelessWidget {
  const _ArkadasSatiri({required this.arkadas});

  final Friend arkadas;

  @override
  Widget build(BuildContext context) {
    return GirisSatiri(
      ikon: Icons.person_outline,
      etiket: arkadas.displayName,
      onTap: () => kisiyiAc(context, arkadas.userId),
    );
  }
}

/// Profil sekmesindeki arkadaşlık girişleri (ADR-0018 §7): "Arkadaşlar"
/// (gelen istek varsa rozetli) ve "Tayfa davetleri" (bekleyen davet varsa
/// rozetli). Profil ekranı bu kartı kendi bölümleri arasına koyar.
class ArkadaslikGirisleri extends ConsumerWidget {
  const ArkadaslikGirisleri({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final gelenIstek = ref.watch(gelenIstekVarProvider).value ?? false;
    final gelenDavet = ref.watch(gelenDavetVarProvider).value ?? false;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GirisSatiri(
            ikon: Icons.group_outlined,
            etiket: m.arkadas_baslik,
            rozet: gelenIstek,
            rozetEtiketi: m.arkadas_istek_bekliyor,
            onTap: () => unawaited(context.push(Adresler.arkadaslar)),
          ),
          GirisSatiri(
            ikon: Icons.mail_outline,
            etiket: m.arkadas_davetler_baslik,
            rozet: gelenDavet,
            rozetEtiketi: m.arkadas_davet_bekliyor,
            onTap: () => unawaited(context.push(Adresler.tayfaDavetleri)),
          ),
        ],
      ),
    );
  }
}
