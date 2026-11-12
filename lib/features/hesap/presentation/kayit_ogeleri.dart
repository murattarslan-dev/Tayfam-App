import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Kayıt sihirbazının ("Tayfam'la tanışma") ortak parçaları (ADR-0012 §3;
// tasarım: Kayit-*.dc.html).
//
// Logo blokları burada küçük, özel bir çizimle çizilir: ortak `TayfamLogo`
// bileşeni (feat/marka-logo-ikon) henüz main'de değil. O birleşince
// ilerleme göstergesi, avatar ve hoş geldin logosu ona geçirilecek.

/// Logonun dört bloğunun renkleri, saat yönünde: sol üst (mango), sağ üst
/// (nar), sağ alt (turkuaz), L parçası.
@immutable
final class KayitBlokRenkleri {
  const KayitBlokRenkleri(this.mango, this.nar, this.turkuaz, this.l);

  final Color mango;
  final Color nar;
  final Color turkuaz;
  final Color l;

  /// İlk [doluSayisi] blok kendi renginde, kalanlar çizgi renginde
  /// (ilerleme göstergesi: adım 1'de yalnız mango, 4'te dördü de).
  factory KayitBlokRenkleri.ilerleme(
    TayfamColors r, {
    required int doluSayisi,
  }) {
    Color renk(int sira, Color dolu) => sira < doluSayisi ? dolu : r.cizgi;
    return KayitBlokRenkleri(
      renk(0, r.mango),
      renk(1, r.nar),
      renk(2, r.teal),
      renk(3, r.marka),
    );
  }

  /// Bütün bloklar dolu; L parçası [l].
  factory KayitBlokRenkleri.tam(TayfamColors r, {required Color l}) =>
      KayitBlokRenkleri(r.mango, r.nar, r.teal, l);

  static KayitBlokRenkleri lerp(
    KayitBlokRenkleri a,
    KayitBlokRenkleri b,
    double t,
  ) {
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return KayitBlokRenkleri(
      l(a.mango, b.mango),
      l(a.nar, b.nar),
      l(a.turkuaz, b.turkuaz),
      l(a.l, b.l),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KayitBlokRenkleri &&
      other.mango == mango &&
      other.nar == nar &&
      other.turkuaz == turkuaz &&
      other.l == l;

  @override
  int get hashCode => Object.hash(mango, nar, turkuaz, l);
}

class _BlokRenkTween extends Tween<KayitBlokRenkleri> {
  _BlokRenkTween({super.end});

  @override
  KayitBlokRenkleri lerp(double t) => KayitBlokRenkleri.lerp(begin!, end!, t);
}

/// Logonun dört bloğunu çizer (viewBox 100). [rozet] ise bloklar daireye
/// kesilir (avatar). Yollar tasarımdaki SVG'lerle birebirdir.
class KayitLogoBoyaci extends CustomPainter {
  const KayitLogoBoyaci({required this.renkler, this.rozet = false});

  final KayitBlokRenkleri renkler;
  final bool rozet;

  static const double _kutu = 100;

  /// Tasarımdaki SVG yolunu çizer. Yalnızca mutlak `M`, `H`, `V`, `Q` ve
  /// `Z` komutları kullanılır (Kayit-*.dc.html).
  static Path _svg(String d) {
    final parcalar = d.split(' ');
    final yol = Path();
    var x = 0.0;
    var y = 0.0;
    var i = 0;
    double sayi() => double.parse(parcalar[i++]);
    while (i < parcalar.length) {
      final komut = parcalar[i];
      final harf = komut[0];
      final ilk = komut.length > 1 ? double.parse(komut.substring(1)) : null;
      i++;
      double ilkSayi() => ilk ?? sayi();
      switch (harf) {
        case 'M':
          x = ilkSayi();
          y = sayi();
          yol.moveTo(x, y);
        case 'H':
          x = ilkSayi();
          yol.lineTo(x, y);
        case 'V':
          y = ilkSayi();
          yol.lineTo(x, y);
        case 'Q':
          final kx = ilkSayi();
          final ky = sayi();
          x = sayi();
          y = sayi();
          yol.quadraticBezierTo(kx, ky, x, y);
        case 'Z':
          yol.close();
      }
    }
    return yol;
  }

  // Tam logo: sol üst, sağ üst, sağ alt, L.
  static final List<Path> _tam = [
    _svg(
      'M16 14 H32 Q40 14 40 22 V26 Q40 32 34 32 H14 Q8 32 8 26 V22 Q8 14 16 14 Z',
    ),
    _svg(
      'M60 14 H84 Q92 14 92 22 V26 Q92 32 86 32 H58 Q52 32 52 26 V22 Q52 14 60 14 Z',
    ),
    _svg(
      'M60 44 H84 Q92 44 92 52 V56 Q92 64 84 64 H64 Q52 64 52 52 Q52 44 60 44 Z',
    ),
    _svg(
      'M18 44 H30 Q40 44 40 54 V64 Q40 76 52 76 H84 Q92 76 92 84 '
      'Q92 92 84 92 H18 Q8 92 8 82 V54 Q8 44 18 44 Z',
    ),
  ];

  // Rozet: bloklar kenara taşar, daireyle kesilir (avatar).
  static final List<Path> _rozet = [
    _svg('M0 0 H40 V26 Q40 32 34 32 H0 Z'),
    _svg('M52 0 H100 V32 H58 Q52 32 52 26 Z'),
    _svg('M60 44 H100 V64 H64 Q52 64 52 52 Q52 44 60 44 Z'),
    _svg('M0 44 H30 Q40 44 40 54 V64 Q40 76 52 76 H100 V100 H0 Z'),
  ];

  static final Path _daire = Path()
    ..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 48));

  @override
  void paint(Canvas canvas, Size size) {
    final olcek = size.shortestSide / _kutu;
    canvas
      ..save()
      ..translate(
        (size.width - _kutu * olcek) / 2,
        (size.height - _kutu * olcek) / 2,
      )
      ..scale(olcek);
    if (rozet) canvas.clipPath(_daire);
    final yollar = rozet ? _rozet : _tam;
    final liste = [renkler.mango, renkler.nar, renkler.turkuaz, renkler.l];
    for (var i = 0; i < yollar.length; i++) {
      canvas.drawPath(yollar[i], Paint()..color = liste[i]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KayitLogoBoyaci eski) =>
      eski.renkler != renkler || eski.rozet != rozet;
}

/// Logonun dört bloğu; görseldir, ekran okuyucu atlar (anlamı yanındaki
/// metin taşır).
class KayitLogosu extends StatelessWidget {
  const KayitLogosu({
    super.key,
    required this.boyut,
    required this.renkler,
    this.rozet = false,
  });

  final double boyut;
  final KayitBlokRenkleri renkler;
  final bool rozet;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(boyut),
        painter: KayitLogoBoyaci(renkler: renkler, rozet: rozet),
      ),
    );
  }
}

/// Üstteki ilerleme göstergesi: logonun dört bloğu ve "Adım N / 4".
///
/// Adım 1'de yalnız mango, 2'de + nar, 3'te + turkuaz, 4'te + mor L dolu;
/// dolmayanlar çizgi rengindedir. Renklenme [TayfamMotion.uzun] sürede
/// yumuşakça olur; "hareketi azalt" açıksa anında. Ekran okuyucu yalnızca
/// "Adım N / 4" metnini okur.
class KayitIlerlemesi extends StatelessWidget {
  const KayitIlerlemesi({super.key, required this.adim, required this.toplam});

  /// 1'den başlayan adım.
  final int adim;
  final int toplam;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final hareketsiz = MediaQuery.disableAnimationsOf(context);
    final hedef = KayitBlokRenkleri.ilerleme(r, doluSayisi: adim);
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<KayitBlokRenkleri>(
            tween: _BlokRenkTween(end: hedef),
            duration: hareketsiz ? Duration.zero : TayfamMotion.uzun,
            curve: TayfamMotion.egri,
            builder: (context, renkler, _) => KayitLogosu(
              boyut: TayfamSizes.kayitIlerlemeLogosu,
              renkler: renkler,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Flexible(
            child: Text(
              metinler.hesap_kayit_adim(adim, toplam),
              style: context.yazi.labelMedium?.copyWith(color: r.metinIkincil),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tayfam'ın konuştuğu sohbet balonları: rozet logolu avatar ve gelen
/// balonlar (açık temada tint-brand, koyu temada bubble-in-dark).
class TayfamKonusuyor extends StatelessWidget {
  const TayfamKonusuyor({super.key, required this.balonlar});

  final List<String> balonlar;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        KayitLogosu(
          boyut: TayfamSizes.tayfamAvatari,
          rozet: true,
          renkler: KayitBlokRenkleri.tam(r, l: r.marka),
        ),
        const SizedBox(width: TayfamSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (sira, balon) in balonlar.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s8),
                SohbetBalonu(
                  metin: balon,
                  giden: false,
                  gonderen: metinler.bilesen_logo_etiketi,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kullanıcının bir önceki adımdaki cevabı (sağda giden balon).
class GidenCevap extends StatelessWidget {
  const GidenCevap({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) => SohbetBalonu(metin: metin, giden: true);
}

/// Alanın üstündeki etiket (15 px, 600–700).
class AlanEtiketi extends StatelessWidget {
  const AlanEtiketi({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    return Text(metin, style: context.yazi.titleSmall);
  }
}

/// Hap biçimli, çerçeveli eylem (tasarımda "Düzelt", "Kapat", "Kendi
/// tayfamı kur"). Açık zeminde brand çerçeve ve metin; mor marka
/// yüzeyinde ([markaYuzeyinde]) beyaz.
class CerceveliEylem extends StatelessWidget {
  const CerceveliEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.markaYuzeyinde = false,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final bool markaYuzeyinde;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final renk = markaYuzeyinde ? r.markaYuzeyUstu : r.marka;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: renk,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s24,
            vertical: TayfamSpacing.s12,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(color: renk, width: TayfamSizes.vurguKenari),
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket),
      ),
    );
  }
}

/// Bilgi ekranı ve pencerelerdeki ikon kutusu (yuvarlak köşeli kare).
class IkonKutusu extends StatelessWidget {
  const IkonKutusu({
    super.key,
    required this.ikon,
    required this.zemin,
    required this.renk,
  });

  final IconData ikon;
  final Color zemin;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: TayfamSizes.ikonKutusu,
        height: TayfamSizes.ikonKutusu,
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: TayfamRadii.onizlemeKoseleri,
        ),
        alignment: Alignment.center,
        child: Icon(ikon, color: renk, size: TayfamSizes.ikonKutusuIkonu),
      ),
    );
  }
}

/// Kayıt alanlarının ortak görünümü: 12 px köşe, iki kalınlıkta kenar
/// (odakta brand, hatada nar), kart zemini; hata [HataSatiri] ile.
InputDecoration kayitAlanGorunumu(
  BuildContext context, {
  String? ipucu,
  String? yardim,
  String? hata,
}) {
  final r = context.renkler;
  OutlineInputBorder kenar(Color renk, double kalinlik) => OutlineInputBorder(
    borderRadius: TayfamRadii.dugmeKoseleri,
    borderSide: BorderSide(color: renk, width: kalinlik),
  );
  return InputDecoration(
    hintText: ipucu,
    helperText: yardim,
    helperMaxLines: 4,
    // Hata metni ana metin rengindedir (vurgu renkleri metin rengi olmaz);
    // kenar nar olur.
    error: hata == null ? null : HataSatiri(metin: hata),
    filled: true,
    fillColor: r.kart,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: TayfamSpacing.s16,
      vertical: TayfamSpacing.s16,
    ),
    enabledBorder: kenar(r.girisKenari, TayfamSizes.vurguKenari),
    focusedBorder: kenar(r.marka, TayfamSizes.alanOdakKenari),
    errorBorder: kenar(r.nar, TayfamSizes.alanOdakKenari),
    focusedErrorBorder: kenar(r.nar, TayfamSizes.alanOdakKenari),
    disabledBorder: kenar(r.cizgi, TayfamSizes.vurguKenari),
  );
}
