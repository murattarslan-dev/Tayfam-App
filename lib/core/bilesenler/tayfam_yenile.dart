import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Çekip yenileme (tasarım: 24-cekip-yenileme; issue #189). Material'ın
/// `RefreshIndicator`'ının yerine uygulamadaki tek yenileme bileşenidir;
/// aynı arayüzü sunar ([onRefresh], [child]).
///
/// Çekince sayfanın kendisi aşağı kayar (Android'de de: kaydırma fiziği
/// bileşen içinde `BouncingScrollPhysics`'e çevrilir; direnç çektikçe
/// artar). Yukarıda açılan boşlukta logonun blokları sırayla yerine oturur
/// (mango → nar → turkuaz → L; ilerleme çekme mesafesinin
/// [TayfamSizes.yenileEsigi]'ne oranıdır). Eşik geçilince logo tamamlanır,
/// hafif titreşim olur ve metin "Bırak, yenilensin" olur. Bırakınca boşluk
/// [TayfamSizes.yenileBoslugu]'na oturur ve Dalga ([TayfamYukleniyor])
/// oynar; [onRefresh] bitince içerik yukarı kayarak yerine döner. Eşik
/// geçilmeden bırakılırsa yenileme olmaz.
///
/// Başlık çubuğu bileşenin dışında kaldığı için sabittir. Mor üst bölümlü
/// ekranlarda (tayfa ana sayfası) [zemin] olarak mor yüzey verilir:
/// boşluk o renge boyanır, L beyaz çizilir.
///
/// "Hareketi azalt" açıkken bloklar animasyonsuz yerine oturur, yenilenirken
/// statik logo ve "Yükleniyor" görünür, dönüş anındadır. Ekran okuyucuda
/// "Yenile" özel eylemi yenilemeyi başlatır; yenilenirken "Yükleniyor" bir
/// kez (canlı bölge) okunur.
class TayfamYenile extends StatefulWidget {
  const TayfamYenile({
    super.key,
    required this.onRefresh,
    required this.child,
    this.zemin,
  });

  /// Yenileme işi; bitene kadar Dalga oynar.
  final RefreshCallback onRefresh;

  /// Dikey kaydırılabilir içerik (liste ya da kaydırma görünümü). İçerik
  /// ekranı doldurmasa da çekilebilmesi için listede
  /// `physics: AlwaysScrollableScrollPhysics()` verilir.
  final Widget child;

  /// Açılan boşluğun rengi; verilmezse boşluk saydamdır (sayfa zemini).
  final Color? zemin;

  @override
  State<TayfamYenile> createState() => _TayfamYenileState();
}

class _TayfamYenileState extends State<TayfamYenile>
    with SingleTickerProviderStateMixin {
  /// Yenilenirken tutulan boşluğun oranı (0: yok, 1: 72 dp).
  late final AnimationController _tutma = AnimationController(vsync: this);

  /// Liste başının ne kadar aşağı çekildiği (dp).
  double _cekme = 0;

  /// Kullanıcı şu anda parmağıyla çekiyor mu.
  bool _cekiliyor = false;

  /// Bu çekişte eşik geçildi mi (titreşim bir kez).
  bool _esikGecildi = false;

  bool _yenileniyor = false;

  bool get _hareketsiz => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _tutma.dispose();
    super.dispose();
  }

  bool _bildirim(ScrollNotification n) {
    final m = n.metrics;
    if (n.depth != 0 || m.axisDirection != AxisDirection.down) {
      return false;
    }
    final asim = math.max(0.0, m.minScrollExtent - m.pixels);
    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        _cekiliyor = !_yenileniyor;
      } else if (_cekiliyor) {
        // Bırakıldı; karar son sürükleme konumuna göre verilir.
        _birak();
      }
    } else if (n is ScrollEndNotification && _cekiliyor) {
      _birak();
    }
    if (_cekiliyor) {
      final esikte = asim >= TayfamSizes.yenileEsigi;
      if (esikte && !_esikGecildi) {
        unawaited(HapticFeedback.lightImpact());
      }
      _esikGecildi = esikte;
    }
    if (asim != _cekme) {
      setState(() => _cekme = asim);
    }
    return false;
  }

  void _birak() {
    _cekiliyor = false;
    final yenile = _esikGecildi && _cekme >= TayfamSizes.yenileEsigi;
    _esikGecildi = false;
    if (yenile) {
      unawaited(_yenile(acilsin: false));
    }
  }

  Future<void> _yenile({required bool acilsin}) async {
    if (_yenileniyor) {
      return;
    }
    setState(() => _yenileniyor = true);
    if (acilsin && !_hareketsiz) {
      unawaited(
        _tutma.animateTo(
          1,
          duration: TayfamMotion.yenileOturma,
          curve: TayfamMotion.egri,
        ),
      );
    } else {
      // Bırakıldığında liste zaten eşiğin ötesinde; geri sekerken 72 dp'de
      // durur.
      _tutma.value = 1;
    }
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _yenileniyor = false);
        if (_hareketsiz) {
          _tutma.value = 0;
        } else {
          await _tutma.animateTo(
            0,
            duration: TayfamMotion.yenileDonus,
            curve: TayfamMotion.egri,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final zemin = widget.zemin;
    final ustBosluk = MediaQuery.paddingOf(context).top;
    final yenileEylemi = CustomSemanticsAction(label: metinler.bilesen_yenile);
    final icerik = NotificationListener<ScrollNotification>(
      onNotification: _bildirim,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          // Yalnızca sekme fiziği; "her zaman kaydırılabilir" listenin
          // kendisinde verilir. Burada verilseydi içerideki çok satırlı
          // metin alanları da dikey sürüklemeyi yakalardı.
          physics: const BouncingScrollPhysics(),
          overscroll: false,
        ),
        child: widget.child,
      ),
    );

    return Semantics(
      container: true,
      customSemanticsActions: {
        yenileEylemi: () => unawaited(_yenile(acilsin: true)),
      },
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _tutma,
          builder: (context, cocuk) {
            final tutulan = _tutma.value * TayfamSizes.yenileBoslugu;
            final bosluk = math.max(_cekme, tutulan);
            final kayma = math.max(0.0, tutulan - _cekme);
            // Çocuk sayısı ve sırası sabit kalır; yoksa liste yeniden
            // kurulur ve kaydırma konumu kaybolur.
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bosluk > 0 ? ustBosluk + bosluk : 0,
                  child: zemin == null
                      ? const SizedBox.shrink()
                      : ColoredBox(color: zemin),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, kayma),
                    child: cocuk,
                  ),
                ),
                Positioned(
                  top: ustBosluk,
                  left: 0,
                  right: 0,
                  height: bosluk,
                  child: IgnorePointer(
                    child: ClipRect(
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: double.infinity,
                        child: bosluk > 0 || _yenileniyor
                            ? _Gosterge(
                                ilerleme: _cekme / TayfamSizes.yenileEsigi,
                                yenileniyor: _yenileniyor,
                                zemin: zemin,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: icerik,
        ),
      ),
    );
  }
}

/// Boşluktaki logo ve metin.
class _Gosterge extends StatelessWidget {
  const _Gosterge({
    required this.ilerleme,
    required this.yenileniyor,
    required this.zemin,
  });

  final double ilerleme;
  final bool yenileniyor;
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    final mor = zemin != null;
    final logoZemini = zemin ?? r.zemin;
    final stil = context.yazi.labelSmall;

    if (yenileniyor) {
      return Semantics(
        container: true,
        liveRegion: true,
        label: metinler.bilesen_yukleniyor,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TayfamYukleniyor(boyut: TayfamSizes.yenileLogo, zemin: logoZemini),
            if (hareketsiz) ...[
              const SizedBox(height: TayfamSpacing.s4),
              Text(
                metinler.bilesen_yukleniyor,
                style: stil?.copyWith(
                  color: mor ? r.markaYuzeyUstu : r.metinIkincil,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final p = ilerleme.clamp(0.0, 1.0);
    final hazir = ilerleme >= 1;
    final boyut = hareketsiz
        ? TayfamSizes.yenileLogo
        : lerpDouble(
            TayfamSizes.yenileLogoKucuk,
            TayfamSizes.yenileLogoBuyuk,
            p,
          )!;
    final Color renk;
    if (mor) {
      renk = r.markaYuzeyUstu;
    } else {
      renk = hazir ? r.marka : r.metinIkincil;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: CustomPaint(
            size: Size.square(boyut),
            painter: CekmeLogosuBoyaci(
              ilerleme: p,
              renkler: LogoRenkleri.zemineGore(logoZemini),
              adimli: hareketsiz,
            ),
          ),
        ),
        const SizedBox(height: TayfamSpacing.s4),
        Text(
          hazir ? metinler.bilesen_yenile_birak : metinler.bilesen_yenile_cek,
          style: stil?.copyWith(color: renk),
        ),
      ],
    );
  }
}

/// Bloğun çekme ilerlemesindeki yeri: 0 (taslak) – 1 (yerinde).
///
/// Dört blok ilerlemeyi sırayla ([yukleniyorSirasi]: mango → nar → turkuaz
/// → L) dörde böler. [adimli] ("hareketi azalt") ise blok ara hal olmadan
/// payı dolunca yerine oturur.
double yenileBlokIlerlemesi(
  LogoBlogu blok,
  double ilerleme, {
  bool adimli = false,
}) {
  final pay =
      (ilerleme.clamp(0.0, 1.0) * yukleniyorSirasi.length -
              yukleniyorSirasi.indexOf(blok))
          .clamp(0.0, 1.0);
  if (adimli) {
    return pay >= 1 ? 1 : 0;
  }
  return pay;
}

final Map<LogoBlogu, Path> _yollar = {
  for (final MapEntry(:key, :value) in LogoYollari.tamRenk.entries)
    key: svgYolu(value),
};

/// Çekerken logoyu çizer: yerine oturmamış blok kesikli taslak, oturan blok
/// %70'ten büyüyerek dolar (tasarım: Yenile-Cekiliyor, Yenile-Esik).
class CekmeLogosuBoyaci extends CustomPainter {
  const CekmeLogosuBoyaci({
    required this.ilerleme,
    required this.renkler,
    this.adimli = false,
  });

  /// Çekme mesafesinin eşiğe oranı (0–1).
  final double ilerleme;

  /// Blok renkleri.
  final LogoRenkleri renkler;

  /// "Hareketi azalt": bloklar ara hal olmadan oturur.
  final bool adimli;

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
    for (final blok in LogoBoyaci.sira) {
      final t = TayfamMotion.egri.transform(
        yenileBlokIlerlemesi(blok, ilerleme, adimli: adimli),
      );
      final renk = renkler.blok(blok);
      final yol = _yollar[blok]!;
      if (t < 1) {
        canvas.drawPath(
          _kesikli(yol),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = TayfamSizes.yenileTaslakKalinligi
            ..color = renk.withValues(
              alpha: renk.a * TayfamSizes.yenileTaslakSaydamligi * (1 - t),
            ),
        );
      }
      if (t > 0) {
        final merkez = LogoYollari.merkezler[blok]!;
        final blokOlcegi = lerpDouble(
          TayfamSizes.yenileBlokBaslangicOlcegi,
          1,
          t,
        )!;
        canvas
          ..save()
          ..translate(merkez.dx, merkez.dy)
          ..scale(blokOlcegi)
          ..translate(-merkez.dx, -merkez.dy)
          ..drawPath(yol, Paint()..color = renk.withValues(alpha: renk.a * t))
          ..restore();
      }
    }
    canvas.restore();
  }

  static Path _kesikli(Path yol) {
    const parca = TayfamSizes.yenileTaslakParcasi;
    final sonuc = Path();
    for (final olcu in yol.computeMetrics()) {
      for (var d = 0.0; d < olcu.length; d += parca * 2) {
        sonuc.addPath(
          olcu.extractPath(d, math.min(d + parca, olcu.length)),
          Offset.zero,
        );
      }
    }
    return sonuc;
  }

  @override
  bool shouldRepaint(CekmeLogosuBoyaci eski) =>
      eski.ilerleme != ilerleme ||
      eski.renkler != renkler ||
      eski.adimli != adimli;
}
