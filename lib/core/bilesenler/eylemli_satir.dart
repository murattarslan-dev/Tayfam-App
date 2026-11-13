import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Büyük yazı ölçeğinde (bu oranın üstünde) [EylemliSatir]'ın eylemi
/// metnin altına iner; yan yana sığmaz.
const double _yanYanaEnBuyukOlcek = 1.3;

/// [ListeKarti] içinde kişi ve tek eylem satırı (tasarım: Engellenenler,
/// Reddedilenler): solda avatar, ortada ad ve alt metin (tarih), sağda
/// çerçeveli eylem ("Engeli kaldır", "Listeden çıkar"). En az 72 px.
///
/// Büyük yazıda eylem metnin altına iner. Satırın kendisi dokunulmaz;
/// ekran okuyucu ad ve alt metni birlikte, eylemi ayrı düğme olarak okur.
class EylemliSatir extends StatelessWidget {
  const EylemliSatir({
    super.key,
    required this.oncu,
    required this.baslik,
    required this.eylem,
    this.alt,
  });

  /// Soldaki öğe (avatar). Süstür; ekran okuyucudan gizlenir.
  final Widget oncu;

  /// Ad (ör. `Text` ya da adı önbellekten okuyan bir widget).
  final Widget baslik;

  /// Adın altındaki ikincil metin (ör. "2 Kasım 2026 tarihinde engellendi").
  final String? alt;

  /// Sağdaki (büyük yazıda alttaki) eylem.
  final Widget eylem;

  @override
  Widget build(BuildContext context) {
    final alt = this.alt;
    final yanYana =
        MediaQuery.textScalerOf(context).scale(1) <= _yanYanaEnBuyukOlcek;
    final metinler = Semantics(
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: context.yazi.titleMedium,
            child: baslik,
          ),
          if (alt != null)
            Text(
              alt,
              style: context.yazi.bodySmall?.copyWith(
                color: context.renkler.metinIkincil,
              ),
            ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSizes.konusmaSatiri),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s16,
          vertical: TayfamSpacing.s8,
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: oncu),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: yanYana
                  ? metinler
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        metinler,
                        const SizedBox(height: TayfamSpacing.s8),
                        eylem,
                      ],
                    ),
            ),
            if (yanYana) ...[const SizedBox(width: TayfamSpacing.s8), eylem],
          ],
        ),
      ),
    );
  }
}
