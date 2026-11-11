import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_cevap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir sorunun listedeki kartı (ADR-0018 §4): etiketler, başlık, gövdenin
/// ilk satırları, yazar ve zaman, cevap sayısı.
///
/// Gövde düz metindir; markdown ya da HTML yorumlanmaz. Kartın tamamı tek
/// bir düğmedir ve sorunun ekranını açar.
class SoruKarti extends StatelessWidget {
  const SoruKarti({super.key, required this.soru, this.onTap});

  final Question soru;

  /// Dokununca; `null` ise kart dokunulmaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final govde = soru.body.trim();
    return TayfamKart(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (soru.tags.isNotEmpty) ...[
            SoruEtiketleri(etiketler: soru.tags),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          Text(soru.title, style: yazi.titleMedium),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              govde,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s8),
          YazarSatiri(yazarId: soru.authorUserId, zaman: soru.createdAt),
          const SizedBox(height: TayfamSpacing.s4),
          CevapSayisi(sayi: soru.answerCount),
        ],
      ),
    );
  }
}

/// Sorunun cevap sayısı: ikon ve metin ("3 cevap", "Henüz cevap yok").
class CevapSayisi extends StatelessWidget {
  const CevapSayisi({super.key, required this.sayi});

  final int sayi;

  @override
  Widget build(BuildContext context) {
    final renk = context.renkler.metinIkincil;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.chat_bubble_outline,
            size: TayfamSizes.ikonKucuk,
            color: renk,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s4),
        Flexible(
          child: Text(
            AppLocalizations.of(context).soru_cevap_sayisi(sayi),
            style: context.yazi.bodySmall?.copyWith(color: renk),
          ),
        ),
      ],
    );
  }
}
