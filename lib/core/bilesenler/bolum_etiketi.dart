import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Liste kartlarının üstündeki küçük bölüm başlığı (tasarım: Profil-Ana,
/// Ayar-Ana): 15 px 700, ikincil renk; sağında isteğe bağlı bir öğe
/// (bağlantı, çip). Başlık ekran okuyucuda başlık olarak okunur.
///
/// Üstte 24, altta 8 px boşluk bırakır. Dar ekranda ve büyük yazıda sağdaki
/// öğe alt satıra iner.
class BolumEtiketi extends StatelessWidget {
  const BolumEtiketi({super.key, required this.baslik, this.sag});

  final String baslik;

  /// Başlığın sağındaki öğe (ör. "Arkadaş ekle" bağlantısı, görünürlük
  /// çipi).
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final sag = this.sag;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TayfamSpacing.s4,
        TayfamSpacing.s24,
        TayfamSpacing.s4,
        TayfamSpacing.s8,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s4,
        children: [
          Semantics(
            header: true,
            child: Text(
              baslik,
              style: context.yazi.titleSmall?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
          ),
          ?sag,
        ],
      ),
    );
  }
}
