import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';

/// Birincil ve ikincil eylemin ortak içeriği: isteğe bağlı ikon ve
/// büyük yazı ölçeğinde satıra sarılan etiket.
class EylemIcerigi extends StatelessWidget {
  const EylemIcerigi({super.key, required this.etiket, this.ikon});

  final String etiket;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final metin = Text(etiket, textAlign: TextAlign.center);
    final ikon = this.ikon;
    if (ikon == null) {
      return metin;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Görünür etiketin yanındaki ikon süstür; ekran okuyucu atlar.
        ExcludeSemantics(child: Icon(ikon, size: TayfamSizes.ikon)),
        const SizedBox(width: TayfamSpacing.s8),
        Flexible(child: metin),
      ],
    );
  }
}
