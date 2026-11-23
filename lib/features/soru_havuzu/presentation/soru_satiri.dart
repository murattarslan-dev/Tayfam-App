import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/ders_konu_etiketi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Soru havuzundaki bir sorunun liste satırı (havuz listesi, ana sayfa
/// kartı, etkinliğe bağlı sorular): ders/konu etiketleri, metnin ilk
/// satırları (metinsiz soruda "Fotoğraflı soru"), fotoğraf sayısı ve cevap
/// sayısı. Bütün satır tek dokunma alanıdır ve ekran okuyucuya tek öğe
/// olarak okunur.
class HavuzSoruSatiri extends StatelessWidget {
  const HavuzSoruSatiri({
    super.key,
    required this.ders,
    required this.konu,
    required this.metin,
    required this.fotografSayisi,
    required this.cevapSayisi,
    required this.onTap,
    this.satirSayisi = 3,
  });

  final String? ders;
  final String? konu;
  final String metin;
  final int fotografSayisi;
  final int cevapSayisi;
  final VoidCallback onTap;

  /// Metnin en çok satır sayısı.
  final int satirSayisi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kirpik = metin.trim();
    final ikincil = yazi.bodySmall?.copyWith(color: r.metinIkincil);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s16,
              vertical: TayfamSpacing.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DersKonuEtiketleri(ders: ders, konu: konu),
                const SizedBox(height: TayfamSpacing.s8),
                Text(
                  kirpik.isEmpty ? m.soru_havuzu_fotografli_soru : kirpik,
                  maxLines: satirSayisi,
                  overflow: TextOverflow.ellipsis,
                  style: yazi.bodyLarge?.copyWith(
                    color: kirpik.isEmpty ? r.metinGovde : r.metin,
                  ),
                ),
                const SizedBox(height: TayfamSpacing.s8),
                Wrap(
                  spacing: TayfamSpacing.s12,
                  runSpacing: TayfamSpacing.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (fotografSayisi > 0)
                      _Bilgi(
                        ikon: Icons.photo_outlined,
                        metin: m.soru_havuzu_fotograf_sayisi(fotografSayisi),
                        stil: ikincil,
                      ),
                    _Bilgi(
                      ikon: Icons.chat_bubble_outline,
                      metin: m.soru_cevap_sayisi(cevapSayisi),
                      stil: ikincil,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bilgi extends StatelessWidget {
  const _Bilgi({required this.ikon, required this.metin, required this.stil});

  final IconData ikon;
  final String metin;
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            ikon,
            size: TayfamSizes.ikonKucuk,
            color: context.renkler.metinIkincil,
          ),
        ),
        const SizedBox(width: TayfamSpacing.s4),
        Flexible(child: Text(metin, style: stil)),
      ],
    );
  }
}
