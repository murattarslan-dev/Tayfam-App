import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/kontrast.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Logonun biçimi (Notion: Marka → Logo).
enum LogoVaryanti {
  /// Ana logo: dört renkli blok; L parçası zemine göre renklenir.
  tamRenk,

  /// Bloklar daireye kesilmiş; avatar, sticker ve yuvarlak alanlar için.
  rozet,

  /// Tek renk: bildirim simgesi, kaşe, baskı.
  tekRenk,
}

/// Tayfam logosu ("Dörtlü", 2026-11-12): dört renkli blok; aralarındaki
/// boşluk kuyruklu küçük bir "t" çizer (Notion: Marka, Tasarım
/// Standartları → Logo kullanımı).
///
/// `assets/marka/logo/` altındaki SVG'lerin yollarıyla birebir çizilir;
/// SVG paketi yoktur ([LogoBoyaci]). Blok renkleri sabittir (sol üst
/// mango, sağ üst nar, sağ alt turkuaz); L parçası [zemin]'e göre seçilir:
/// açık zeminde brand, koyu zeminde brand-dark, mor zeminde #FAF8FF
/// ([TayfamLogoRenkleri.lParcasi]). Zemin verilmezse temanın sayfa zemini
/// kullanılır; böylece açık ve koyu tema farkını bileşen kendisi uygular.
///
/// [TayfamLogo.yazili] yanına küçük harfle "tayfam" yazar; simge
/// [TayfamSizes.logoYaziEsigi]'nin (24 px) altındaysa yazı gösterilmez.
/// Boyut [TayfamSizes.logoEnKucuk]'ten (16 px) küçük olamaz.
///
/// Logo bir görseldir: ekran okuyucu tek bir "Tayfam" görseli olarak okur;
/// yazı sistemin yazı büyütme ayarıyla ölçeklenmez (oranı bozulmasın diye),
/// dar alanda bütün logo orantılı küçülür.
class TayfamLogo extends StatelessWidget {
  /// Tam renk simge.
  const TayfamLogo({
    super.key,
    this.boyut = TayfamSizes.logoYaziEsigi,
    this.zemin,
    this.baslik = false,
  }) : varyant = LogoVaryanti.tamRenk,
       yazili = false,
       renk = null,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Tam renk simge + "tayfam" yazısı.
  const TayfamLogo.yazili({
    super.key,
    this.boyut = TayfamSizes.logoBuyuk,
    this.zemin,
    this.baslik = false,
  }) : varyant = LogoVaryanti.tamRenk,
       yazili = true,
       renk = null,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Rozet: bloklar daireye kesilmiş; zeminden bağımsız (L brand).
  const TayfamLogo.rozet({
    super.key,
    this.boyut = TayfamSizes.logoYaziEsigi,
    this.baslik = false,
  }) : varyant = LogoVaryanti.rozet,
       yazili = false,
       zemin = null,
       renk = null,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Tek renk simge; [renk] verilmezse çevredeki ikon rengi.
  const TayfamLogo.tekRenk({
    super.key,
    this.boyut = TayfamSizes.logoYaziEsigi,
    this.renk,
    this.baslik = false,
  }) : varyant = LogoVaryanti.tekRenk,
       yazili = false,
       zemin = null,
       assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Simgenin kenar uzunluğu (kare).
  final double boyut;

  /// Logonun durduğu zeminin rengi; verilmezse temanın sayfa zemini
  /// (`TayfamColors.zemin`). Mor marka yüzeyinde `markaYuzey` verilir.
  final Color? zemin;

  /// Tek renk biçimin rengi.
  final Color? renk;

  /// Ekran başlığı olarak okunsun mu (açılış ve giriş ekranı).
  final bool baslik;

  /// "tayfam" yazısı gösterilsin mi.
  final bool yazili;

  /// Logonun biçimi.
  final LogoVaryanti varyant;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final zemin = this.zemin ?? r.zemin;
    final renkler = switch (varyant) {
      LogoVaryanti.tamRenk => LogoRenkleri.zemineGore(zemin),
      LogoVaryanti.rozet => LogoRenkleri.rozet,
      LogoVaryanti.tekRenk => LogoRenkleri.tek(
        renk ?? IconTheme.of(context).color ?? r.metin,
      ),
    };
    final simge = CustomPaint(
      size: Size.square(boyut),
      painter: LogoBoyaci(
        renkler: renkler,
        rozet: varyant == LogoVaryanti.rozet,
      ),
    );

    final Widget logo;
    if (yazili && boyut >= TayfamSizes.logoYaziEsigi) {
      logo = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            simge,
            SizedBox(width: boyut * TayfamSizes.logoYaziBoslukOrani),
            LogoYazisi(
              punto: boyut * TayfamSizes.logoYaziOrani,
              renk: logoYaziRengi(r, zemin),
            ),
          ],
        ),
      );
    } else {
      logo = simge;
    }

    return Semantics(
      container: true,
      label: metinler.bilesen_logo_etiketi,
      image: true,
      header: baslik,
      excludeSemantics: true,
      child: logo,
    );
  }
}

/// Küçük harfli "tayfam" yazı logosu (Notion: Marka; yazı şimdilik
/// fonttan gelir). Görseldir: sistem yazı ölçeğiyle büyümez.
class LogoYazisi extends StatelessWidget {
  const LogoYazisi({super.key, required this.punto, required this.renk});

  /// Punto boyu.
  final double punto;

  /// Yazı rengi ([logoYaziRengi]).
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context).bilesen_logo_yazisi,
      maxLines: 1,
      softWrap: false,
      textScaler: TextScaler.noScaling,
      style: context.yazi.displayLarge?.copyWith(
        color: renk,
        fontSize: punto,
        fontWeight: TayfamTypography.buyukBaslikAgirligi,
        letterSpacing: punto * TayfamSizes.logoHarfAraligiOrani,
        height: 1,
      ),
    );
  }
}

/// "tayfam" yazısının [zemin] üzerindeki rengi: ana metin (açık temada ink)
/// ya da mor yüzeyin üstündeki beyaz; zeminle daha iyi ayrışanı.
Color logoYaziRengi(TayfamColors r, Color zemin) {
  final metin = r.metin;
  final beyaz = r.markaYuzeyUstu;
  return kontrastOrani(beyaz, zemin) > kontrastOrani(metin, zemin)
      ? beyaz
      : metin;
}

/// Logonun dört bloğu.
enum LogoBlogu {
  /// Sol üst (mango).
  mango,

  /// Sağ üst (nar).
  nar,

  /// Sağ alt (turkuaz).
  turkuaz,

  /// Büyük L parçası (brand / brand-dark / #FAF8FF).
  l,
}

/// Dört bloğun renkleri.
@immutable
final class LogoRenkleri {
  const LogoRenkleri({
    required this.mango,
    required this.nar,
    required this.turkuaz,
    required this.l,
  });

  /// Tam renk logo, [zemin] üzerinde.
  factory LogoRenkleri.zemineGore(Color zemin) => LogoRenkleri(
    mango: TayfamLogoRenkleri.mango,
    nar: TayfamLogoRenkleri.nar,
    turkuaz: TayfamLogoRenkleri.turkuaz,
    l: TayfamLogoRenkleri.lParcasi(zemin),
  );

  /// Dört blok aynı renkte (tek renk logo).
  const LogoRenkleri.tek(Color renk)
    : mango = renk,
      nar = renk,
      turkuaz = renk,
      l = renk;

  /// Rozet: L her zaman brand.
  static const LogoRenkleri rozet = LogoRenkleri(
    mango: TayfamLogoRenkleri.mango,
    nar: TayfamLogoRenkleri.nar,
    turkuaz: TayfamLogoRenkleri.turkuaz,
    l: TayfamLogoRenkleri.lAcikZemin,
  );

  final Color mango;
  final Color nar;
  final Color turkuaz;
  final Color l;

  /// [blok]'un rengi.
  Color blok(LogoBlogu blok) => switch (blok) {
    LogoBlogu.mango => mango,
    LogoBlogu.nar => nar,
    LogoBlogu.turkuaz => turkuaz,
    LogoBlogu.l => l,
  };

  @override
  bool operator ==(Object other) =>
      other is LogoRenkleri &&
      other.mango == mango &&
      other.nar == nar &&
      other.turkuaz == turkuaz &&
      other.l == l;

  @override
  int get hashCode => Object.hash(mango, nar, turkuaz, l);
}

/// Bir bloğun animasyon anındaki hali: kendi merkezine göre ölçek,
/// logonun 100 birimlik kutusunda öteleme ve saydamlık. CSS'teki
/// `transform-box: fill-box; transform-origin: center` ile aynıdır.
@immutable
final class BlokHali {
  const BlokHali({
    this.olcek = 1,
    this.kayma = Offset.zero,
    this.saydamlik = 1,
  });

  /// Durağan hal.
  static const BlokHali normal = BlokHali();

  /// Bloğun kendi merkezine göre ölçeği.
  final double olcek;

  /// Öteleme (logo kutusunun 100 birimi üzerinden).
  final Offset kayma;

  /// 0 (görünmez) – 1 (tam).
  final double saydamlik;

  @override
  bool operator ==(Object other) =>
      other is BlokHali &&
      other.olcek == olcek &&
      other.kayma == kayma &&
      other.saydamlik == saydamlik;

  @override
  int get hashCode => Object.hash(olcek, kayma, saydamlik);
}

/// Logonun yolları (viewBox 100). `assets/marka/logo/*.svg` dosyalarındaki
/// `d` değerleriyle birebir aynıdır; test denetler. Android ikon kaynakları
/// da aynı yolları kullanır (`tool/ikon/ikon_uret.py`).
abstract final class LogoYollari {
  /// SVG viewBox kenarı.
  static const double kutu = 100;

  /// Ana logonun blokları.
  static const Map<LogoBlogu, String> tamRenk = {
    LogoBlogu.mango:
        'M16 14 H32 Q40 14 40 22 V26 Q40 32 34 32 H14 Q8 32 8 26 V22 '
        'Q8 14 16 14 Z',
    LogoBlogu.nar:
        'M60 14 H84 Q92 14 92 22 V26 Q92 32 86 32 H58 Q52 32 52 26 V22 '
        'Q52 14 60 14 Z',
    LogoBlogu.turkuaz:
        'M60 44 H84 Q92 44 92 52 V56 Q92 64 84 64 H64 Q52 64 52 52 '
        'Q52 44 60 44 Z',
    LogoBlogu.l:
        'M18 44 H30 Q40 44 40 54 V64 Q40 76 52 76 H84 Q92 76 92 84 '
        'Q92 92 84 92 H18 Q8 92 8 82 V54 Q8 44 18 44 Z',
  };

  /// Rozetin blokları (daireye kesilir).
  static const Map<LogoBlogu, String> rozet = {
    LogoBlogu.mango: 'M0 0 H40 V26 Q40 32 34 32 H0 Z',
    LogoBlogu.nar: 'M52 0 H100 V32 H58 Q52 32 52 26 Z',
    LogoBlogu.turkuaz: 'M60 44 H100 V64 H64 Q52 64 52 52 Q52 44 60 44 Z',
    LogoBlogu.l: 'M0 44 H30 Q40 44 40 54 V64 Q40 76 52 76 H100 V100 H0 Z',
  };

  /// Rozetin kesildiği daire: merkez (50, 50), yarıçap 48.
  static const double rozetYaricapi = 48;

  /// Bloğun ölçek/öteleme merkezi: ana logodaki yolunun sınır kutusunun
  /// ortası (CSS `transform-box: fill-box`).
  static const Map<LogoBlogu, Offset> merkezler = {
    LogoBlogu.mango: Offset(24, 23),
    LogoBlogu.nar: Offset(72, 23),
    LogoBlogu.turkuaz: Offset(72, 54),
    LogoBlogu.l: Offset(50, 68),
  };
}

/// Logonun kullandığı SVG yol alt kümesini (`M`, `L`, `H`, `V`, `Q`, `Z`;
/// mutlak koordinat) [Path]'e çevirir. Başka komut [FormatException]'dır.
Path svgYolu(String d) {
  final parcalar = [
    for (final m in RegExp(r'[A-Za-z]|-?\d+(?:\.\d+)?').allMatches(d)) m[0]!,
  ];
  final yol = Path();
  var x = 0.0;
  var y = 0.0;
  var i = 0;
  var komut = '';
  double sayi() {
    if (i >= parcalar.length) {
      throw const FormatException('Eksik koordinat');
    }
    final deger = double.tryParse(parcalar[i++]);
    if (deger == null) {
      throw const FormatException('Koordinat bekleniyordu');
    }
    return deger;
  }

  while (i < parcalar.length) {
    if (double.tryParse(parcalar[i]) == null) {
      komut = parcalar[i++];
    }
    switch (komut) {
      case 'M':
        x = sayi();
        y = sayi();
        yol.moveTo(x, y);
        // SVG: M'den sonraki koordinat çiftleri L sayılır.
        komut = 'L';
      case 'L':
        x = sayi();
        y = sayi();
        yol.lineTo(x, y);
      case 'H':
        x = sayi();
        yol.lineTo(x, y);
      case 'V':
        y = sayi();
        yol.lineTo(x, y);
      case 'Q':
        final kx = sayi();
        final ky = sayi();
        x = sayi();
        y = sayi();
        yol.quadraticBezierTo(kx, ky, x, y);
      case 'Z':
        yol.close();
        komut = '';
      default:
        throw const FormatException('Desteklenmeyen yol komutu');
    }
  }
  return yol;
}

final Map<LogoBlogu, Path> _tamRenkYollari = {
  for (final MapEntry(:key, :value) in LogoYollari.tamRenk.entries)
    key: svgYolu(value),
};

final Map<LogoBlogu, Path> _rozetYollari = {
  for (final MapEntry(:key, :value) in LogoYollari.rozet.entries)
    key: svgYolu(value),
};

/// Logoyu `assets/marka/logo/` SVG'lerinin yollarıyla (viewBox 100) çizer.
///
/// [haller] her bloğun animasyon anındaki halidir (splash ve yükleniyor
/// animasyonları); verilmeyen blok durağandır. Çizim sırası splash
/// animasyonundaki gibidir: L, mango, nar, turkuaz (bloklar üst üste
/// binmez).
class LogoBoyaci extends CustomPainter {
  const LogoBoyaci({
    required this.renkler,
    this.rozet = false,
    this.haller = const {},
  });

  /// Blok renkleri.
  final LogoRenkleri renkler;

  /// Rozet biçimi mi.
  final bool rozet;

  /// Blokların anlık hali.
  final Map<LogoBlogu, BlokHali> haller;

  /// Çizim sırası.
  static const List<LogoBlogu> sira = [
    LogoBlogu.l,
    LogoBlogu.mango,
    LogoBlogu.nar,
    LogoBlogu.turkuaz,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const kutu = LogoYollari.kutu;
    final olcek = size.shortestSide / kutu;
    canvas
      ..save()
      ..translate(
        (size.width - kutu * olcek) / 2,
        (size.height - kutu * olcek) / 2,
      )
      ..scale(olcek);
    if (rozet) {
      canvas.clipPath(
        Path()..addOval(
          Rect.fromCircle(
            center: const Offset(kutu / 2, kutu / 2),
            radius: LogoYollari.rozetYaricapi,
          ),
        ),
      );
    }
    final yollar = rozet ? _rozetYollari : _tamRenkYollari;
    for (final blok in sira) {
      final hal = haller[blok] ?? BlokHali.normal;
      if (hal.saydamlik <= 0) {
        continue;
      }
      final renk = renkler.blok(blok);
      final merkez = LogoYollari.merkezler[blok]!;
      canvas
        ..save()
        ..translate(merkez.dx + hal.kayma.dx, merkez.dy + hal.kayma.dy)
        ..scale(hal.olcek)
        ..translate(-merkez.dx, -merkez.dy)
        ..drawPath(
          yollar[blok]!,
          Paint()
            ..color = renk.withValues(
              alpha: renk.a * hal.saydamlik.clamp(0, 1),
            ),
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoBoyaci eski) {
    return eski.renkler != renkler ||
        eski.rozet != rozet ||
        !_ayniHaller(eski.haller, haller);
  }

  static bool _ayniHaller(
    Map<LogoBlogu, BlokHali> a,
    Map<LogoBlogu, BlokHali> b,
  ) {
    for (final blok in LogoBlogu.values) {
      if ((a[blok] ?? BlokHali.normal) != (b[blok] ?? BlokHali.normal)) {
        return false;
      }
    }
    return true;
  }
}
