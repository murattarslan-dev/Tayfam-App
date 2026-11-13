/// Adım adım sihirbazların ortak iskeleti (ADR-0015 Notlar 2026-11-13,
/// ADR-0014 Notlar 2026-11-13): üst çubuk, altta sabit Geri + İleri, adım
/// başlığı ve iki sütunlu ızgara. Etkinlik sihirbazı ve tayfa kurma
/// sihirbazı aynı iskeleti kullanır.
library;

import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/birincil_eylem.dart';
import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Bu yazı ölçeğinden büyükte yan yana alanlar ve iki sütunlu ızgaralar
/// alt alta iner.
const double yanYanaEnBuyukOlcek = 1.5;

/// Bu genişlikten (dp) darda yan yana alanlar alt alta iner.
const double yanYanaEnDar = 280;

/// Alanlar alt alta mı dizilmeli (dar ekran ya da büyük yazı).
bool altAltaMi(BuildContext context, double genislik) =>
    MediaQuery.textScalerOf(context).scale(1) > yanYanaEnBuyukOlcek ||
    genislik < yanYanaEnDar;

/// Sihirbazların üst çubuğu (etkinlik sihirbazı, Sihirbaz-Tur; tayfa
/// kurma, Tayfa-Kur-*): kapat (X), başlık, [adimMetni] ("Adım n / N") ve
/// N parçalı ilerleme çubuğu. Çubuk süstür; adım metni ekran okuyucuda
/// okunur.
class SihirbazUstCubugu extends StatelessWidget {
  const SihirbazUstCubugu({
    super.key,
    required this.baslik,
    required this.adimMetni,
    required this.adim,
    required this.toplam,
    required this.onKapat,
  });

  final String baslik;

  /// "Adım n / N" metni; özelliğin çevirisinden gelir.
  final String adimMetni;

  /// Gösterilen adım, 1'den.
  final int adim;
  final int toplam;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s4,
          TayfamSpacing.s4,
          TayfamSpacing.s16,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onKapat,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s4),
                // Büyük yazıda adım metni başlığın altına iner.
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TayfamSpacing.s8,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(baslik, style: context.yazi.titleMedium),
                      ),
                      Text(
                        adimMetni,
                        style: context.yazi.labelLarge?.copyWith(
                          color: r.metinIkincil,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: TayfamSpacing.s12,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 1; i <= toplam; i++) ...[
                      if (i > 1) const SizedBox(width: TayfamSpacing.s4),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: i <= adim ? r.marka : r.cizgi,
                            borderRadius: TayfamRadii.hapKoseleri,
                          ),
                          child: const SizedBox(
                            height: TayfamSizes.ilerlemeParcasi,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sihirbazın altta sabit eylem çubuğu (tasarım: Sihirbaz-Bilgi): üstte
/// ince çizgi; [onGeri] verilirse solda çerçeveli "Geri", sağda birincil
/// eylem. İkisi eşit genişliktedir.
class SihirbazAltCubugu extends StatelessWidget {
  const SihirbazAltCubugu({
    super.key,
    required this.ileriEtiketi,
    required this.onIleri,
    this.geriEtiketi,
    this.onGeri,
  });

  final String ileriEtiketi;
  final VoidCallback? onIleri;
  final String? geriEtiketi;

  /// `null` ise "Geri" gösterilmez.
  final VoidCallback? onGeri;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final geriEtiketi = this.geriEtiketi;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.kenarMobil,
            vertical: TayfamSpacing.s12,
          ),
          child: Row(
            children: [
              if (onGeri != null && geriEtiketi != null) ...[
                Expanded(
                  child: CerceveliHapEylem(
                    etiket: geriEtiketi,
                    notr: true,
                    onPressed: onGeri,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
              ],
              Expanded(
                child: BirincilEylem(etiket: ileriEtiketi, onPressed: onIleri),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adımın soru başlığı ve isteğe bağlı açıklaması (tasarım: "Ne tür bir
/// etkinlik?", "Tayfanın adı ne?").
class AdimBasligi extends StatelessWidget {
  const AdimBasligi({super.key, required this.baslik, this.aciklama});

  final String baslik;
  final String? aciklama;

  @override
  Widget build(BuildContext context) {
    final aciklama = this.aciklama;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(baslik, style: context.yazi.headlineMedium),
        ),
        if (aciklama != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            aciklama,
            style: context.yazi.bodyMedium?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ],
      ],
    );
  }
}

/// İki sütunlu ızgara (tür kutuları, ilgi alanı kartları); dar ekranda ve
/// büyük yazıda tek sütun.
class IkiSutunluIzgara extends StatelessWidget {
  const IkiSutunluIzgara({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, kisit) {
        final genislik = altAltaMi(context, kisit.maxWidth)
            ? kisit.maxWidth
            : (kisit.maxWidth - TayfamSpacing.s8) / 2;
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final cocuk in children)
              SizedBox(width: genislik, child: cocuk),
          ],
        );
      },
    );
  }
}
