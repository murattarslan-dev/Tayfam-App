import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/rozet/presentation/rozet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Rozetler" bölümü (App ADR-0033 §3; Tayfam-Api ADR-0039): profilde
/// kişisel rozetler, tayfa ana sayfasında tayfa rozetleri.
///
/// - Rozetler sunucunun sırasıyla (kazanılma sırası) çizilir; sıralama ya
///   da sayıya göre liste yoktur.
/// - Ad ve ikon katalogdan okunur; katalog gelene kadar bölüm katalog
///   yükleniyor durumunu gösterir ([KatalogBekleyici]).
/// - Her rozet satırında kazanma kuralı anlaşılır metinle yazılır.
///   Ekran okuyucu rozeti "ad, yıl" diye, ardından kuralı okur; anlam
///   renge dayanmaz (ikon süstür, ad her zaman yazılıdır).
/// - [rozetler] boşsa [bosMetin] gösterilir; o da yoksa bölüm hiç
///   çizilmez.
class RozetBolumu extends StatelessWidget {
  const RozetBolumu({
    super.key,
    required this.rozetler,
    this.bosMetin,
    this.not,
  });

  final List<EarnedBadge> rozetler;

  /// Rozet yokken bölümde gösterilen sakin not; `null` ise bölüm çizilmez.
  final String? bosMetin;

  /// Listenin altındaki küçük açıklama (ör. kendi profilinde görünürlük).
  final String? not;

  @override
  Widget build(BuildContext context) {
    final bosMetin = this.bosMetin;
    final not = this.not;
    if (rozetler.isEmpty && bosMetin == null) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinGovde,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.rozet_baslik),
        if (rozetler.isEmpty && bosMetin != null)
          Text(bosMetin, style: ikincil)
        else
          KatalogBekleyici(
            builder: (context, katalog) {
              final dil = katalogDili(context);
              return ListeKarti(
                children: [
                  for (final rozet in rozetler)
                    RozetSatiri(gorunum: rozetGorunumu(m, rozet, katalog, dil)),
                ],
              );
            },
          ),
        if (not != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            not,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bir rozetin satırı: mango zeminli ikon, ad (yıllıksa "ad · yıl") ve
/// kazanma kuralı. Dokunulmaz; ekran okuyucu satırı tek öğe olarak okur.
class RozetSatiri extends StatelessWidget {
  const RozetSatiri({super.key, required this.gorunum});

  final RozetGorunumu gorunum;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kural = gorunum.kural;
    return ListeKartiSatiri(
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: r.tintMango,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(TayfamSpacing.s8),
                  child: Icon(
                    gorunum.ikon,
                    size: TayfamSizes.ikon,
                    color: r.tintMangoUstu,
                  ),
                ),
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: rozetOkunusu(m, gorunum),
                    excludeSemantics: true,
                    child: Text(
                      rozetAdMetni(m, gorunum),
                      style: context.yazi.titleSmall?.copyWith(color: r.metin),
                    ),
                  ),
                  if (kural != null) ...[
                    const SizedBox(height: TayfamSpacing.s4),
                    Text(
                      kural,
                      style: context.yazi.bodyMedium?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
