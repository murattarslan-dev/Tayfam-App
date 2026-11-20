import 'package:flutter/material.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_bekleyici.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/istatistik/presentation/istatistik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [statlar]'dan gösterilebilenlerin satırları (sunucunun sırasıyla);
/// katalogda karşılığı olmayan metrik atlanır.
List<({MetrikGorunumu gorunum, int? etkinlik})> istatistikSatirlari(
  AppLocalizations m,
  List<TayfaStat> statlar,
  Katalog katalog,
  String dil,
) => [
  for (final stat in statlar)
    if (metrikGorunumu(m, stat, katalog, dil) case final gorunum?)
      (
        gorunum: gorunum,
        etkinlik: etkinlikSayisiYazilir(stat) ? stat.eventCount : null,
      ),
];

/// İstatistik listesi (tayfa toplamları, profil, vitrin): [ListeKarti]
/// içinde her metrik bir satır. Grafik yoktur; anlam renge dayanmaz, her
/// değer metin olarak yazılır ve ekran okuyucu satırı "ad, değer, kaç
/// etkinlikten" diye tek öğe olarak okur. Metrik adları katalogdan
/// okunur; katalog gelene kadar [KatalogBekleyici] yükleniyor durumunu
/// gösterir. Gösterilebilen satır yoksa [bosMetin] (o da yoksa hiçbir
/// şey) çizilir.
class IstatistikListesi extends StatelessWidget {
  const IstatistikListesi({super.key, required this.statlar, this.bosMetin});

  final List<TayfaStat> statlar;

  /// Gösterilecek satır yokken yazılan sakin not.
  final String? bosMetin;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return KatalogBekleyici(
      builder: (context, katalog) {
        final satirlar = istatistikSatirlari(
          m,
          statlar,
          katalog,
          katalogDili(context),
        );
        final bosMetin = this.bosMetin;
        if (satirlar.isEmpty) {
          return bosMetin == null
              ? const SizedBox.shrink()
              : IstatistikNotu(metin: bosMetin, ikincil: false);
        }
        return ListeKarti(
          children: [
            for (final s in satirlar)
              ListeKartiSatiri(
                child: IstatistikSatiri(
                  gorunum: s.gorunum,
                  etkinlikSayisi: s.etkinlik,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Bir istatistiğin satırı: metriğin adı, altında büyük değer ve (varsa)
/// "4 etkinlikten". Dokunulmaz; ekran okuyucu satırı tek öğe olarak okur,
/// süreyi "12 saat 30 dakika" diye.
class IstatistikSatiri extends StatelessWidget {
  const IstatistikSatiri({
    super.key,
    required this.gorunum,
    this.etkinlikSayisi,
    this.kisi,
  });

  final MetrikGorunumu gorunum;

  /// Değere katkı veren etkinlik sayısı; `null` ise yazılmaz.
  final int? etkinlikSayisi;

  /// Adın yerine gösterilen öğe (kişisel katkıda kişinin adı); verilirse
  /// metrik adı yazılmaz.
  final Widget? kisi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final sayi = etkinlikSayisi;
    final kisi = this.kisi;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle.merge(
            style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            child: kisi ?? Text(gorunum.ad),
          ),
          const SizedBox(height: TayfamSpacing.s4),
          Semantics(
            label: gorunum.okunus,
            excludeSemantics: true,
            child: Text(
              gorunum.deger,
              style: yazi.titleLarge?.copyWith(color: r.metin),
            ),
          ),
          if (sayi != null)
            Text(
              m.istatistik_etkinlik_sayisi(sayi),
              style: yazi.bodySmall?.copyWith(color: r.metinIkincil),
            ),
        ],
      ),
    );
  }
}

/// İstatistik bölümlerindeki küçük not ya da sakin boş metin.
class IstatistikNotu extends StatelessWidget {
  const IstatistikNotu({super.key, required this.metin, this.ikincil = true});

  final String metin;

  /// Küçük ikincil not mu (değilse gövde metni).
  final bool ikincil;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Text(
      metin,
      style: ikincil
          ? context.yazi.bodySmall?.copyWith(color: r.metinIkincil)
          : context.yazi.bodyMedium?.copyWith(color: r.metinGovde),
    );
  }
}

/// Profildeki "İstatistikler" bölümü (Tayfam-Api ADR-0026 §4): kişinin
/// bütün tayfalarındaki tüm zamanlar toplamı. Alan yoksa sunucu
/// göstermiyordur; bölümü çağıran hiç çizmez. Liste boşsa [bosMetin]
/// gösterilir; o da yoksa bölüm çizilmez.
class IstatistikBolumu extends StatelessWidget {
  const IstatistikBolumu({
    super.key,
    required this.statlar,
    this.bosMetin,
    this.not,
  });

  final List<TayfaStat> statlar;

  /// İstatistik yokken bölümde gösterilen sakin not; `null` ise bölüm
  /// çizilmez.
  final String? bosMetin;

  /// Listenin altındaki küçük açıklama (kendi profilinde görünürlük).
  final String? not;

  @override
  Widget build(BuildContext context) {
    final bosMetin = this.bosMetin;
    final not = this.not;
    if (statlar.isEmpty && bosMetin == null) return const SizedBox.shrink();
    final m = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.istatistik_baslik),
        if (statlar.isEmpty && bosMetin != null)
          IstatistikNotu(metin: bosMetin, ikincil: false)
        else
          IstatistikListesi(statlar: statlar, bosMetin: bosMetin),
        if (not != null) ...[
          const SizedBox(height: TayfamSpacing.s8),
          IstatistikNotu(metin: not),
        ],
      ],
    );
  }
}
