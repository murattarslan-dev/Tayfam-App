import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Bir tayfanın ya da profilin seçebileceği en çok ilgi alanı (sözleşme:
/// `interests`, `maxItems: 20`).
const int ilgiAlaniEnCok = 20;

/// Seçim listesinde gösterilen ilgi alanları: katalogdaki aktif ilgi
/// alanları ve [secili]'deki emekli ilgi alanları (yeni seçilemez ama onu
/// daha önce seçmiş tayfada ve profilde görünmeye devam eder; sözleşme
/// `InterestKey`). Sıra kataloğun sırasıdır.
List<CatalogInterest> gosterilenIlgiAlanlari(
  Katalog katalog,
  Iterable<String> secili,
) => [
  for (final ilgi in katalog.ilgiAlanlari)
    if (ilgi.status == CatalogStatus.active || secili.contains(ilgi.key)) ilgi,
];

/// [secili]'yi kataloğun sırasına dizer; katalogda olmayan anahtarlar
/// sonda, verildikleri sırayla kalır (silinmezler: son söz sunucunundur).
List<String> ilgiAlanlariniSirala(Katalog? katalog, Iterable<String> secili) {
  final kume = secili.toSet();
  if (katalog == null) return kume.toList();
  return [
    for (final ilgi in katalog.ilgiAlanlari)
      if (kume.remove(ilgi.key)) ilgi.key,
    ...kume,
  ];
}

/// İlgi alanı seçimi (çoklu): katalogdaki ilgi alanlarının çipleri
/// (ADR-0024 §2). Katalog gelene kadar yükleniyor, okunamazsa "Tekrar
/// dene" gösterilir ([KatalogBekleyici]).
///
/// [onDegisti] dokunulan ilgi alanının anahtarıyla çağrılır; seçimi
/// çağıran tutar. `null` ise çipler kapalıdır. Emekli ilgi alanı yalnızca
/// seçiliyse gösterilir ve yalnızca kaldırılabilir; [ilgiAlaniEnCok]
/// seçime ulaşılınca seçili olmayanlar kapanır.
class IlgiAlaniSecimi extends StatelessWidget {
  const IlgiAlaniSecimi({
    super.key,
    required this.secili,
    required this.onDegisti,
  });

  final Set<String> secili;
  final ValueChanged<String>? onDegisti;

  @override
  Widget build(BuildContext context) {
    final onDegisti = this.onDegisti;
    return KatalogBekleyici(
      builder: (context, katalog) {
        final dil = katalogDili(context);
        final dolu = secili.length >= ilgiAlaniEnCok;
        return Wrap(
          spacing: TayfamSpacing.s8,
          runSpacing: TayfamSpacing.s8,
          children: [
            for (final ilgi in gosterilenIlgiAlanlari(katalog, secili))
              IlgiCipi(
                gorunum: ilgiAlaniGorunumu(ilgi.key, katalog, dil),
                yedekAd: ilgi.key,
                secili: secili.contains(ilgi.key),
                onDegisti:
                    onDegisti == null || (dolu && !secili.contains(ilgi.key))
                    ? null
                    : () => onDegisti(ilgi.key),
              ),
          ],
        );
      },
    );
  }
}

/// İlgi alanı çipi (ADR-0004 Notlar, 2026-11-10): ilgi alanının ikonu ve
/// adı her zaman görünür. Seçiliyken kendi dolgusu, üstünde metin rengi ve
/// onay işareti; seçili değilken kenarlı hap. Ad ve ikon katalogdan
/// ([gorunum]); renk tek başına bilgi taşımaz.
class IlgiCipi extends StatelessWidget {
  const IlgiCipi({
    super.key,
    required this.gorunum,
    required this.yedekAd,
    required this.secili,
    required this.onDegisti,
  });

  final KatalogGorunumu gorunum;

  /// Katalogda adı yoksa gösterilen metin (anahtar).
  final String yedekAd;
  final bool secili;
  final VoidCallback? onDegisti;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final cift = context.turRenkleri.cift(gorunum.renk);
    final yaziRengi = secili ? cift.ustu : r.metin;
    final onDegisti = this.onDegisti;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              gorunum.ikon,
              size: TayfamSizes.ikonKucuk,
              color: yaziRengi,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s4),
          Flexible(child: Text(gorunum.ad ?? yedekAd)),
        ],
      ),
      selected: secili,
      onSelected: onDegisti == null ? null : (_) => onDegisti(),
      showCheckmark: true,
      checkmarkColor: cift.ustu,
      selectedColor: cift.dolgu,
      labelStyle: context.yazi.labelLarge?.copyWith(color: yaziRengi),
      side: secili
          ? BorderSide.none
          : BorderSide(color: r.girisKenari, width: TayfamSizes.kenar),
      shape: const StadiumBorder(),
    );
  }
}
