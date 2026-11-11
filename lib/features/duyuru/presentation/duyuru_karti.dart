import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir duyurunun listedeki kartı (ADR-0015 §2): sabitlendiyse raptiye ve
/// "Sabitlendi" etiketi, başlık, gövdenin ilk satırları ve yayın zamanı.
///
/// Gövde düz metindir; markdown ya da HTML yorumlanmaz, bağlantılar
/// dokunulabilir değildir. Kartın tamamı tek bir düğmedir ve duyurunun
/// ekranını açar.
class DuyuruKarti extends StatelessWidget {
  const DuyuruKarti({super.key, required this.duyuru, this.onTap});

  final Announcement duyuru;

  /// Dokununca; `null` ise kart dokunulmaz.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final govde = duyuru.body.trim();
    return TayfamKart(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (duyuru.pinned) ...[
            const SabitEtiketi(),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          Text(duyuru.title, style: yazi.titleMedium),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              govde,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s8),
          DuyuruTarihi(zaman: duyuru.createdAt),
        ],
      ),
    );
  }
}

/// Sabitlenmiş duyurunun raptiye ikonu ve "Sabitlendi" etiketi. Renk tek
/// başına bilgi taşımaz; etiket metni her zaman görünür.
class SabitEtiketi extends StatelessWidget {
  const SabitEtiketi({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.push_pin_outlined,
            size: TayfamSizes.ikonKucuk,
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s4),
        Flexible(
          child: Etiket(metin: AppLocalizations.of(context).duyuru_sabit),
        ),
      ],
    );
  }
}

/// Duyurunun yayın günü ve saati, cihazın saatine göre (ADR-0008).
class DuyuruTarihi extends StatelessWidget {
  const DuyuruTarihi({super.key, required this.zaman});

  /// Sunucudan gelen zaman (UTC).
  final DateTime zaman;

  @override
  Widget build(BuildContext context) {
    final yerel = zaman.toLocal();
    return Text(
      AppLocalizations.of(context).duyuru_tarih(yerel, yerel),
      style: context.yazi.bodySmall?.copyWith(
        color: context.renkler.metinIkincil,
      ),
    );
  }
}
