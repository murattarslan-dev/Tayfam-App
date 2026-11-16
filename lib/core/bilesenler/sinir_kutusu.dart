import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tema.dart';

/// Sınır hatası kutusu (tasarım: Tayfa-Kur-Limit; anlık etkinlikte de,
/// `docs/tasarim/29`): tint-nar zeminde hata ikonu, nar-metin renginde
/// kalın [baslik] ve ardından [metin]. Ekran okuyucuya canlı bölge olarak
/// okunur. Günlük ya da eşzamanlı sınır aşıldığında, girilenlerin durduğunu
/// söyleyen yerlerde kullanılır; diğer hatalar `HataSatiri` ile gösterilir.
class SinirKutusu extends StatelessWidget {
  const SinirKutusu({super.key, required this.baslik, required this.metin});

  final String baslik;
  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi.bodyMedium?.copyWith(color: r.metin);
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: r.tintNar,
          borderRadius: TayfamRadii.secimKoseleri,
        ),
        child: Padding(
          padding: const EdgeInsets.all(TayfamSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: TayfamSizes.ikon,
                  color: r.narMetin,
                ),
              ),
              const SizedBox(width: TayfamSpacing.s8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: baslik,
                        style: TextStyle(
                          color: r.narMetin,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: metin),
                    ],
                  ),
                  style: yazi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
