import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Yükleniyor animasyonu "Dalga" (Design: Yükleniyor, A · Dalga; issue
/// #102): logonun kendisi; ayrı bir spinner yoktur.
///
/// Bloklar saat yönünde (mango → nar → turkuaz → L) 175 ms arayla, 1400
/// ms'lik sonsuz bir döngüde turun %20'sinde %70'e küçülüp %45 saydamlığa
/// iner, %40'ında geri gelir (ease-in-out; [TayfamMotion]). Boyutlar:
/// düğme içinde 22 px ([TayfamSizes.yukleniyorDugme]), satırda ve bölümde
/// 32 px (varsayılan), tam ekranda 72 px ([TayfamSizes.yukleniyorTamEkran]).
///
/// Renkler [zemin]'e göre seçilir (L parçası: açıkta brand, koyuda
/// brand-dark, mor zeminde #FAF8FF); verilmezse temanın sayfa zemini.
/// Mango ya da nar zeminde (örneğin koyu temadaki birincil eylem) bloklar
/// kaybolacağı için [tekRenk] verilir.
///
/// Ekran okuyucu [etiket]'i (verilmezse "Yükleniyor") okur. "Hareketi
/// azalt" açıksa animasyon durur, statik logo görünür; tam ekran boyutunda
/// altında etiket de yazılır.
///
/// 1 saniyeden kısa beklemelerde göstermemek için [gecikmeli] kullanılır:
/// gecikme boyunca yer tutulur ve ekran okuyucu etiketi yine okunur, ama
/// animasyon görünmez.
class TayfamYukleniyor extends StatefulWidget {
  const TayfamYukleniyor({
    super.key,
    this.boyut = TayfamSizes.yukleniyorSatir,
    this.zemin,
    this.tekRenk,
    this.etiket,
    this.gecikmeli = false,
  }) : assert(boyut >= TayfamSizes.logoEnKucuk);

  /// Logonun kenarı.
  final double boyut;

  /// Durduğu zemin; L parçasının rengini belirler.
  final Color? zemin;

  /// Verilirse dört blok bu renkte çizilir.
  final Color? tekRenk;

  /// Ekran okuyucu etiketi; verilmezse "Yükleniyor".
  final String? etiket;

  /// [TayfamMotion.yukleniyorGecikmesi] dolana kadar görünmesin mi.
  final bool gecikmeli;

  @override
  State<TayfamYukleniyor> createState() => _TayfamYukleniyorState();
}

class _TayfamYukleniyorState extends State<TayfamYukleniyor>
    with TickerProviderStateMixin {
  late final AnimationController _denetci = AnimationController(
    vsync: this,
    duration: TayfamMotion.yukleniyorDongu,
  );

  /// Gecikmeyi sayar. Zamanlayıcı yerine ticker: uygulamada fark yok, ama
  /// test ortamında `pumpAndSettle` gecikme boyunca kareleri ilerletir
  /// (eski `CircularProgressIndicator` davranışıyla aynı).
  AnimationController? _gecikme;
  late bool _gorunur = !widget.gecikmeli;
  bool _hareketsiz = false;

  @override
  void initState() {
    super.initState();
    if (widget.gecikmeli) {
      _gecikme =
          AnimationController(
              vsync: this,
              duration: TayfamMotion.yukleniyorGecikmesi,
            )
            ..addStatusListener((durum) {
              if (durum == AnimationStatus.completed && mounted) {
                setState(() => _gorunur = true);
                _oynat();
              }
            })
            ..forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hareketsiz = MediaQuery.disableAnimationsOf(context);
    _oynat();
  }

  void _oynat() {
    if (_hareketsiz || !_gorunur) {
      _denetci
        ..stop()
        ..value = 0;
    } else if (!_denetci.isAnimating) {
      _denetci.repeat();
    }
  }

  @override
  void dispose() {
    _gecikme?.dispose();
    _denetci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final etiket = widget.etiket ?? metinler.bilesen_yukleniyor;
    final tekRenk = widget.tekRenk;
    final renkler = tekRenk != null
        ? LogoRenkleri.tek(tekRenk)
        : LogoRenkleri.zemineGore(widget.zemin ?? r.zemin);

    final Widget icerik;
    if (!_gorunur) {
      icerik = SizedBox.square(dimension: widget.boyut);
    } else {
      final logo = AnimatedBuilder(
        animation: _denetci,
        builder: (context, _) {
          final gecen = TayfamMotion.yukleniyorDongu * _denetci.value;
          return CustomPaint(
            size: Size.square(widget.boyut),
            painter: LogoBoyaci(
              renkler: renkler,
              haller: _hareketsiz
                  ? const {}
                  : {
                      for (final blok in LogoBlogu.values)
                        blok: yukleniyorBlokHali(blok, gecen),
                    },
            ),
          );
        },
      );
      icerik = _hareketsiz && widget.boyut >= TayfamSizes.yukleniyorTamEkran
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                logo,
                const SizedBox(height: TayfamSpacing.s12),
                Text(etiket, style: context.yazi.bodySmall),
              ],
            )
          : logo;
    }

    return Semantics(
      container: true,
      label: etiket,
      excludeSemantics: true,
      child: icerik,
    );
  }
}

/// Dalgada blokların sırası: saat yönünde, sol üstten başlayarak.
const List<LogoBlogu> yukleniyorSirasi = [
  LogoBlogu.mango,
  LogoBlogu.nar,
  LogoBlogu.turkuaz,
  LogoBlogu.l,
];

/// [blok]'un dalgadaki hali; [gecen] döngünün başından beri geçen süre.
///
/// Her blok sırasındaki yeri kadar ([TayfamMotion.yukleniyorAralik]) geç
/// başlar; döngü sonsuz olduğu için bu bir faz farkıdır. Turun ilk
/// %20'sinde küçülüp solar, %40'ına kadar geri gelir, kalanında durağandır.
BlokHali yukleniyorBlokHali(LogoBlogu blok, Duration gecen) {
  final dongu = TayfamMotion.yukleniyorDongu.inMicroseconds;
  final gecikme =
      TayfamMotion.yukleniyorAralik.inMicroseconds *
      yukleniyorSirasi.indexOf(blok);
  final faz = ((gecen.inMicroseconds - gecikme) % dongu) / dongu;
  const tepe = TayfamMotion.yukleniyorTepe;
  const bitis = TayfamMotion.yukleniyorBitis;
  final double derinlik;
  if (faz < tepe) {
    derinlik = TayfamMotion.yukleniyorEgrisi.transform(faz / tepe);
  } else if (faz < bitis) {
    derinlik =
        1 -
        TayfamMotion.yukleniyorEgrisi.transform((faz - tepe) / (bitis - tepe));
  } else {
    return BlokHali.normal;
  }
  return BlokHali(
    olcek: 1 - (1 - TayfamSizes.yukleniyorEnKucukOlcek) * derinlik,
    saydamlik: 1 - (1 - TayfamSizes.yukleniyorEnAzSaydamlik) * derinlik,
  );
}
