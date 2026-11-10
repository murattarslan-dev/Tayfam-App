import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Etiket: tint-brand zemin, brand metin, 13 px 700 (ADR-0004).
/// Koyu temada tint-brand-dark zemin + #CDBBFF metin.
class Etiket extends StatelessWidget {
  const Etiket({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.tintMarka,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Text(
          metin,
          style: context.yazi.labelMedium?.copyWith(color: r.tintMarkaUstu),
        ),
      ),
    );
  }
}
