import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anketin sonuçları (ADR-0018 §5) ve gizlilik vaatleri (kesin kural 7):
///
/// - Açık ankette her seçenek sayı ve çubukla gösterilir; oyu olan
///   seçeneğe dokununca oy verenler açılır ([onSecenek]).
/// - Gizli ankette seçenekler hiçbir zaman dokunulabilir değildir; oy
///   verenler istenmez.
/// - Gizli ankette oy veren sayısı [anketSonucEsigi]'nin altındaysa
///   seçenek sayıları, yüzdeleri, çubukları ve önde olan seçenek de
///   gösterilmez; yalnızca toplam ve "Sonuçlar 5 oydan sonra görünür".
/// - Kullanıcının kendi oyu (`own_option_ids`) "Senin oyun" ile işaretlenir.
class AnketSonuclari extends StatelessWidget {
  const AnketSonuclari({super.key, required this.anket, this.onSecenek});

  final Poll anket;

  /// Açık ankette oyu olan seçeneğe dokununca; gizli ankette hiç
  /// çağrılmaz.
  final ValueChanged<PollOption>? onSecenek;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final sayilar = secenekSayilariGorunur(anket);
    final onde = ondekiSecenekler(anket);
    final kendi = anket.ownOptionIds.toSet();
    final dokunma = oyVerenlerGorunur(anket) ? onSecenek : null;
    final secenekler = siraliSecenekler(anket);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (sira, secenek) in secenekler.indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
          if (sayilar)
            _SayiliSecenek(
              secenek: secenek,
              toplam: anket.voterCount,
              onde: onde.contains(secenek.id),
              kendi: kendi.contains(secenek.id),
              onTap: dokunma == null || secenek.voteCount == 0
                  ? null
                  : () => dokunma(secenek),
            )
          else
            _SayisizSecenek(
              secenek: secenek,
              kendi: kendi.contains(secenek.id),
            ),
        ],
        const SizedBox(height: TayfamSpacing.s16),
        Text(
          m.anket_oy_veren_sayisi(anket.voterCount),
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
        if (!sayilar) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.anket_esik_notu(anketSonucEsigi),
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ] else if (dokunma != null && anket.voterCount > 0) ...[
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.anket_oy_verenler_ipucu,
            style: context.yazi.bodySmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
      ],
    );
  }
}

class _SayiliSecenek extends StatelessWidget {
  const _SayiliSecenek({
    required this.secenek,
    required this.toplam,
    required this.onde,
    required this.kendi,
    this.onTap,
  });

  final PollOption secenek;
  final int toplam;
  final bool onde;
  final bool kendi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icerik = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnketCubugu(
          secenek: secenek.text,
          oy: secenek.voteCount,
          toplamOy: toplam,
          onde: onde,
        ),
        if (kendi) ...[
          const SizedBox(height: TayfamSpacing.s4),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SeninOyunEtiketi(),
          ),
        ],
      ],
    );
    final onTap = this.onTap;
    if (onTap == null) return icerik;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TayfamRadii.kartKoseleri,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
          child: icerik,
        ),
      ),
    );
  }
}

/// Eşiğin altındaki gizli ankette seçenek: yalnızca metin ve (kendi
/// oyuysa) "Senin oyun"; sayı, yüzde ya da çubuk yok.
class _SayisizSecenek extends StatelessWidget {
  const _SayisizSecenek({required this.secenek, required this.kendi});

  final PollOption secenek;
  final bool kendi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(secenek.text, style: context.yazi.bodyLarge),
        if (kendi) ...[
          const SizedBox(height: TayfamSpacing.s4),
          const SeninOyunEtiketi(),
        ],
      ],
    );
  }
}
