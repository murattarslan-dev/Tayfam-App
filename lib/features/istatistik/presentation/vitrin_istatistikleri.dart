import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/istatistik/presentation/istatistik_listesi.dart';
import 'package:tayfam/features/rozet/rozet.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Keşfet kartındaki istatistik vitrini (Tayfam-Api ADR-0026 §3, ADR-0039
/// §3): tayfanın tüm zamanlar toplamları ve rozetleri. Kişi, tarih, yer ve
/// yıl kırılımı yoktur; tayfalar arası sıralama yoktur.
///
/// Sunucu vitrini yalnızca gösterilecekse döndürür (`showcase` alanı);
/// alan yoksa bu bölüm hiç çizilmez ("henüz yok" denmez). Gösterilebilen
/// metrik ve rozet yoksa da yer kaplamaz.
class VitrinIstatistikleri extends StatelessWidget {
  const VitrinIstatistikleri({super.key, required this.vitrin});

  final TayfaShowcase vitrin;

  @override
  Widget build(BuildContext context) {
    if (vitrin.stats.isEmpty && vitrin.badges.isEmpty) {
      return const SizedBox.shrink();
    }
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vitrin.stats.isNotEmpty) ...[
          BolumEtiketi(baslik: m.istatistik_vitrin_baslik),
          IstatistikListesi(statlar: vitrin.stats),
        ],
        if (vitrin.badges.isNotEmpty) RozetBolumu(rozetler: vitrin.badges),
      ],
    );
  }
}
