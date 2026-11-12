import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açılış ekranının (splash) içeriği: ortada logo, altta "tayfam" yazı
/// logosu (Design: Splash açık / koyu, Splash animasyonu; issue #100).
///
/// Native açılış ekranıyla (Android `splash_*`, iOS `LaunchScreen`) aynı
/// yerleşim ve renklerdedir; Flutter'ın ilk karesinde logo bloklarla
/// kurulur: önce L (0 ms), sonra mango (80 ms), nar (140 ms) ve turkuaz
/// (200 ms) dışarıdan hafif taşarak gelir (her blok 420 ms); yazı 520 ms'de
/// 300 ms'lik bir yükselmeyle belirir ([TayfamMotion]). Animasyon bir kez
/// oynar. "Hareketi azalt" açıksa (`MediaQuery.disableAnimationsOf`)
/// animasyon yoktur, logo doğrudan görünür.
///
/// Zemin [zemin]'dir (açılış ekranında `acilisZemini`); L parçası ve yazı
/// rengi ona göre seçilir. Logo ekran okuyucuda tek bir "Tayfam" görseli
/// ve başlıktır; yazı süstür.
class AcilisLogosu extends StatefulWidget {
  const AcilisLogosu({super.key, required this.zemin});

  /// Logonun durduğu zemin.
  final Color zemin;

  @override
  State<AcilisLogosu> createState() => _AcilisLogosuState();
}

class _AcilisLogosuState extends State<AcilisLogosu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _denetci = AnimationController(
    vsync: this,
    duration: TayfamMotion.acilisToplam,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _denetci.value = 1;
    } else if (_denetci.isDismissed) {
      _denetci.forward();
    }
  }

  @override
  void dispose() {
    _denetci.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final renkler = LogoRenkleri.zemineGore(widget.zemin);
    final yaziRengi = logoYaziRengi(r, widget.zemin);
    return AnimatedBuilder(
      animation: _denetci,
      builder: (context, _) {
        final gecen = TayfamMotion.acilisToplam * _denetci.value;
        final yazi = acilisYaziHali(gecen);
        return Stack(
          children: [
            Center(
              child: Semantics(
                container: true,
                label: metinler.bilesen_logo_etiketi,
                image: true,
                header: true,
                excludeSemantics: true,
                child: CustomPaint(
                  size: const Size.square(TayfamSizes.logoSplash),
                  painter: LogoBoyaci(
                    renkler: renkler,
                    haller: {
                      for (final blok in LogoBlogu.values)
                        blok: acilisBlokHali(blok, gecen),
                    },
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: TayfamSpacing.s56),
                child: ExcludeSemantics(
                  child: Opacity(
                    opacity: yazi.saydamlik,
                    child: Transform.translate(
                      offset: Offset(0, yazi.kayma),
                      child: LogoYazisi(
                        punto: TayfamSizes.acilisYaziPuntosu,
                        renk: yaziRengi,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Blokların animasyon başındaki hali (Design: Splash animasyonu, CSS
/// `@keyframes`): logonun 100 birimlik kutusunda öteleme ve ölçek; hepsi
/// görünmez başlar.
const Map<LogoBlogu, BlokHali> acilisBaslangiclari = {
  LogoBlogu.l: BlokHali(olcek: .7, kayma: Offset(-6, 8), saydamlik: 0),
  LogoBlogu.mango: BlokHali(olcek: .5, kayma: Offset(-14, -14), saydamlik: 0),
  LogoBlogu.nar: BlokHali(olcek: .5, kayma: Offset(14, -14), saydamlik: 0),
  LogoBlogu.turkuaz: BlokHali(olcek: .5, kayma: Offset(16, 6), saydamlik: 0),
};

/// [blok]'un açılış animasyonunun [gecen] anındaki hali.
BlokHali acilisBlokHali(LogoBlogu blok, Duration gecen) {
  final gecikme = switch (blok) {
    LogoBlogu.l => TayfamMotion.acilisL,
    LogoBlogu.mango => TayfamMotion.acilisMango,
    LogoBlogu.nar => TayfamMotion.acilisNar,
    LogoBlogu.turkuaz => TayfamMotion.acilisTurkuaz,
  };
  final t = _ilerleme(gecen - gecikme, TayfamMotion.acilisBlok);
  if (t >= 1) {
    return BlokHali.normal;
  }
  // Eğri sonda 1'i aşar (taşma); ölçek ve öteleme bunu izler, saydamlık
  // boyacıda 0–1'e sıkıştırılır (CSS'teki gibi).
  final e = TayfamMotion.acilisEgrisi.transform(t);
  final bas = acilisBaslangiclari[blok]!;
  return BlokHali(
    olcek: bas.olcek + (1 - bas.olcek) * e,
    kayma: bas.kayma * (1 - e),
    saydamlik: bas.saydamlik + (1 - bas.saydamlik) * e,
  );
}

/// "tayfam" yazısının açılış animasyonunun [gecen] anındaki saydamlığı ve
/// dikey kayması (px; aşağıdan yukarı).
({double saydamlik, double kayma}) acilisYaziHali(Duration gecen) {
  final t = _ilerleme(
    gecen - TayfamMotion.acilisYaziGecikmesi,
    TayfamMotion.acilisYazi,
  );
  final e = TayfamMotion.acilisYaziEgrisi.transform(t);
  return (saydamlik: e, kayma: TayfamSizes.acilisYaziKaymasi * (1 - e));
}

double _ilerleme(Duration gecen, Duration sure) {
  if (gecen <= Duration.zero) {
    return 0;
  }
  return (gecen.inMicroseconds / sure.inMicroseconds).clamp(0.0, 1.0);
}
