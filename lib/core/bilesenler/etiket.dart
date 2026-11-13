import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Etiketin renk tonu. Her ton bir tint zemin ve onun "üstü" metin
/// token'ıdır; renk tek başına bilgi taşımaz, etiketin metni her zaman
/// görünür.
enum EtiketTonu {
  /// tint-brand + brand (rol: Yönetici, "Sıradaki").
  marka,

  /// tint-mango + honey (bekleme: "Onay bekliyor", "Belki", "Susturuldu").
  mango,

  /// tint-teal + #0B6B5D (rol: Moderatör, tamamlandı).
  teal,

  /// tint-nar + nar-metin (yıkıcı durum: "Banlı").
  nar;

  /// Tonun zemin ve metin renkleri.
  (Color, Color) renkler(TayfamColors r) => switch (this) {
    marka => (r.tintMarka, r.tintMarkaUstu),
    mango => (r.tintMango, r.tintMangoUstu),
    teal => (r.tintTeal, r.tintTealUstu),
    nar => (r.tintNar, r.narMetin),
  };
}

/// Etiket: tint zemin, tonun metin rengi, 13 px 700 (ADR-0004). Varsayılan
/// ton [EtiketTonu.marka]: açıkta tint-brand + brand, koyuda
/// tint-brand-dark + #CDBBFF. İsteğe bağlı [ikon] metnin solundadır ve
/// ekran okuyucudan gizlenir.
class Etiket extends StatelessWidget {
  const Etiket({
    super.key,
    required this.metin,
    this.ton = EtiketTonu.marka,
    this.ikon,
  });

  final String metin;
  final EtiketTonu ton;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final (zemin, yazi) = ton.renkler(context.renkler);
    final ikon = this.ikon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        // İkon metnin içinde (WidgetSpan): etiket dar yerde satır kırar,
        // sınırsız genişlikte de çalışır.
        child: Text.rich(
          TextSpan(
            children: [
              if (ikon != null) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: ExcludeSemantics(
                    child: Icon(ikon, size: TayfamSizes.ikonKucuk, color: yazi),
                  ),
                ),
                const WidgetSpan(child: SizedBox(width: TayfamSpacing.s4)),
              ],
              TextSpan(text: metin),
            ],
          ),
          style: context.yazi.labelMedium?.copyWith(color: yazi),
        ),
      ),
    );
  }
}
