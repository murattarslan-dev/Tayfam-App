import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kendi oyu olmayan seçeneğin çubuğundaki marka renginin saydamlığı
/// (tasarım: Anket-Sonuc; açık brand üstünde #CDBBFF'e denk).
const double _digerCubukSaydamligi = .35;

/// Anketin sonuçları (tasarım: Anket-Sonuc, Anket-Gizli; ADR-0018 §5) ve
/// gizlilik vaatleri (kesin kural 7):
///
/// - Açık ankette her seçenek yüzde, çubuk ve oy sayısıyla gösterilir; oyu
///   olan seçeneğe dokununca oy verenler açılır ([onSecenek]).
/// - Gizli ankette seçenekler hiçbir zaman dokunulabilir değildir; oy
///   verenler istenmez.
/// - Gizli ankette oy veren sayısı [anketSonucEsigi]'nin altındaysa
///   seçenek sayıları, yüzdeleri, çubukları ve önde olan seçenek de
///   gösterilmez; yalnızca toplam ve "Sonuçlar 5 oydan sonra görünür".
/// - Kullanıcının kendi oyu (`own_option_ids`) marka kenar, marka çubuk ve
///   "Senin oyun" ile işaretlenir; en çok oy alan seçeneğin metni kalındır.
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
    final ozet = [
      m.anket_oy_veren_cumlesi(anket.voterCount),
      if (dokunma != null && anket.voterCount > 0) m.anket_oy_verenler_ipucu,
    ].join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sayilar)
          Text(ozet, style: context.yazi.bodySmall)
        else
          _EsikKutusu(oyVeren: anket.voterCount),
        const SizedBox(height: TayfamSpacing.s12),
        for (final (sira, secenek) in secenekler.indexed) ...[
          if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
          if (sayilar)
            AnketSonucSecenegi(
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
      ],
    );
  }
}

/// Sonuçlardaki bir seçenek (tasarım: Anket-Sonuc): metin, kendi oyuysa
/// "Senin oyun", yüzde; altında çubuk ve oy sayısı. Yüzde oy veren kişi
/// sayısına göredir (çoklu seçimde toplam %100'ü geçebilir).
///
/// Bileşen yalnızca kendisine verilen sayıyı gösterir; gizli ankette
/// eşiği uygulamak [AnketSonuclari]'nın işidir (kesin kural 7).
class AnketSonucSecenegi extends StatelessWidget {
  const AnketSonucSecenegi({
    super.key,
    required this.secenek,
    required this.toplam,
    required this.onde,
    required this.kendi,
    this.onTap,
  });

  final PollOption secenek;

  /// Ankete oy veren kişi sayısı.
  final int toplam;

  /// En çok oyu alan seçenek mi (kalın metin).
  final bool onde;

  /// Kullanıcının kendi oyu mu (marka kenar ve çubuk, "Senin oyun").
  final bool kendi;

  final VoidCallback? onTap;

  /// Çubuğun doluluk oranı (0–1).
  double get oran =>
      toplam <= 0 ? 0.0 : (secenek.voteCount / toplam).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yuzde = (oran * 100).round();
    final yuzdeMetni = NumberFormat.percentPattern(m.localeName).format(oran);
    final anlam = [
      m.bilesen_anket_secenek_anlam(secenek.text, secenek.voteCount, yuzde),
      if (kendi) m.anket_senin_oyun,
    ].join(', ');
    final icerik = Padding(
      padding: const EdgeInsets.all(TayfamSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  secenek.text,
                  style: context.yazi.bodyLarge?.copyWith(
                    fontWeight: onde ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (kendi) ...[
                const SizedBox(width: TayfamSpacing.s8),
                const Flexible(child: SeninOyunEtiketi()),
              ],
              const SizedBox(width: TayfamSpacing.s8),
              Text(
                yuzdeMetni,
                style: context.yazi.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: TayfamSpacing.s8),
          ClipRRect(
            borderRadius: TayfamRadii.hapKoseleri,
            child: SizedBox(
              height: TayfamSizes.anketCubugu,
              child: ColoredBox(
                color: r.cizgi,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: oran,
                    heightFactor: 1,
                    child: ColoredBox(
                      color: kendi
                          ? r.marka
                          : r.marka.withValues(alpha: _digerCubukSaydamligi),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.anket_secenek_oy(secenek.voteCount),
            style: context.yazi.labelSmall?.copyWith(
              color: r.metinIkincil,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
    final onTap = this.onTap;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: r.kart,
        shape: _secenekKenari(r, kendi: kendi),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          container: true,
          button: onTap != null,
          label: anlam,
          excludeSemantics: true,
          child: onTap == null ? icerik : InkWell(onTap: onTap, child: icerik),
        ),
      ),
    );
  }
}

/// Seçenek kutusunun kenarı: kendi oyunda 2 px marka, değilse 1.5 px çizgi.
ShapeBorder _secenekKenari(TayfamColors r, {required bool kendi}) =>
    RoundedRectangleBorder(
      borderRadius: TayfamRadii.secimKoseleri,
      side: kendi
          ? BorderSide(color: r.marka, width: TayfamSizes.alanOdakKenari)
          : BorderSide(color: r.cizgi, width: TayfamSizes.vurguKenari),
    );

/// Eşiğin altındaki gizli anketin kutusu (tasarım: Anket-Gizli): toplam
/// oy veren ve "Sonuçlar 5 oydan sonra görünür".
class _EsikKutusu extends StatelessWidget {
  const _EsikKutusu({required this.oyVeren});

  final int oyVeren;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final stil = context.yazi.bodySmall?.copyWith(color: r.metin);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: TayfamRadii.secimKoseleri,
        border: Border.all(color: r.cizgi, width: TayfamSizes.vurguKenari),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.bar_chart_rounded,
                size: TayfamSizes.ikon,
                color: r.tintMarkaUstu,
              ),
            ),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: m.anket_oy_veren_cumlesi(oyVeren),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(text: m.anket_esik_notu(anketSonucEsigi)),
                  ],
                ),
                style: stil,
              ),
            ),
          ],
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
    final r = context.renkler;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: r.kart,
        shape: _secenekKenari(r, kendi: kendi),
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                secenek.text,
                style: context.yazi.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (kendi) ...[
              const SizedBox(width: TayfamSpacing.s8),
              const Flexible(child: SeninOyunEtiketi()),
            ],
          ],
        ),
      ),
    );
  }
}
