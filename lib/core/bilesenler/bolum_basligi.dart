import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir sayfa bölümünün başlığı ve isteğe bağlı "Tümü" bağlantısı
/// (ADR-0015 §1: tayfa ana sayfasındaki etkinlik ve duyuru bölümleri).
///
/// Başlık ekran okuyucuda başlık olarak okunur. "Tümü"nün ekran okuyucu
/// etiketi [tumuEtiketi]'dir (ör. "Tüm duyurular"), böylece iki bölümün
/// bağlantıları birbirinden ayırt edilir.
class BolumBasligi extends StatelessWidget {
  const BolumBasligi({
    super.key,
    required this.baslik,
    this.tumuEtiketi,
    this.onTumu,
  });

  /// Bölümün başlığı.
  final String baslik;

  /// "Tümü" bağlantısının ekran okuyucu etiketi.
  final String? tumuEtiketi;

  /// "Tümü"ye dokununca; `null` ise bağlantı gösterilmez.
  final VoidCallback? onTumu;

  @override
  Widget build(BuildContext context) {
    final onTumu = this.onTumu;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(baslik, style: context.yazi.titleLarge),
          ),
        ),
        if (onTumu != null) ...[
          const SizedBox(width: TayfamSpacing.s8),
          OdakCercevesi(
            koseler: TayfamRadii.dugmeKoseleri,
            child: TextButton(
              onPressed: onTumu,
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                // Odak çerçevesini OdakCercevesi çizer.
                side: BorderSide.none,
              ),
              child: Text(
                AppLocalizations.of(context).tayfa_ana_tumu,
                semanticsLabel: tumuEtiketi,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
