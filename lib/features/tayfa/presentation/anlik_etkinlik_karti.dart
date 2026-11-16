import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_degistirme_paneli.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anlık tayfanın ana sayfasındaki "Anlık etkinlik" kartı (ADR-0026;
/// tasarım: `docs/tasarim/29` §5). Mor bölüme taşan kartlarda, "Sıradaki"
/// etkinlik kartının üstünde durur.
///
/// - Herkese: "Etkinlik bittikten 7 gün sonra arşivlenir."
/// - Yalnızca yöneticiye (organizatör): "Arkadaş davet et", "Davet linkini
///   paylaş" ve "Bu ekiple tayfa kur". Rol arayüz sadeleştirmesidir;
///   izinleri sunucu verir (kesin kural 5). Tayfa salt okunursa (arşiv,
///   askı, silme) eylemler gösterilmez.
class AnlikEtkinlikKarti extends ConsumerWidget {
  const AnlikEtkinlikKarti({
    super.key,
    required this.tayfaId,
    required this.ozet,
  });

  final String tayfaId;
  final TayfaOzeti ozet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final arkadasDaveti = ref.watch(arkadasDavetiProvider);
    final linkDaveti = ref.watch(tayfaDavetiProvider);
    final tayfa = ozet.tayfa;
    final saltOkunur = tayfa == null || tayfaDurumu(tayfa) != null;
    final organizator = ozet.rol == Role.admin && !saltOkunur;
    return TayfamKart(
      oneCikan: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AnlikIkonKutusu(),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    m.anlik_etkinlik,
                    style: context.yazi.titleMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.anlik_kart_arsiv,
            style: context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
          ),
          if (organizator) ...[
            const SizedBox(height: TayfamSpacing.s8),
            if (arkadasDaveti != null)
              MenuSatiri(
                ikon: Icons.person_add_alt_outlined,
                tur: MenuSatiriTuru.sade,
                baslik: m.anlik_kart_arkadas_davet,
                onTap: () => unawaited(arkadasDaveti(context, tayfaId)),
              ),
            if (linkDaveti != null)
              MenuSatiri(
                ikon: Icons.link,
                tur: MenuSatiriTuru.sade,
                baslik: m.kuruldu_davet,
                aciklama: m.anlik_kart_link_aciklama,
                onTap: () => unawaited(linkDaveti(context, tayfaId)),
              ),
            MenuSatiri(
              ikon: Icons.groups_outlined,
              tur: MenuSatiriTuru.sade,
              baslik: m.anlik_kart_donustur,
              aciklama: m.anlik_kart_donustur_aciklama,
              onTap: () => context.go(Adresler.tayfaDonustur(tayfaId)),
            ),
          ],
        ],
      ),
    );
  }
}
