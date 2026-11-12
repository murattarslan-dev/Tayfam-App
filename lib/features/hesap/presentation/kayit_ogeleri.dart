import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

// Kayıt sihirbazının ("Tayfam'la tanışma") ortak parçaları (ADR-0012 §3;
// tasarım: Kayit-*.dc.html). Logo ortak `TayfamLogo` bileşenidir.

/// İlerleme göstergesinin blok renkleri: ilk [doluSayisi] blok logonun
/// kendi renginde (zemine göre; L açıkta brand, koyuda brand-dark),
/// kalanlar çizgi renginde (line / line-dark).
LogoRenkleri kayitIlerlemeRenkleri(TayfamColors r, {required int doluSayisi}) {
  final tam = LogoRenkleri.zemineGore(r.zemin);
  Color renk(LogoBlogu blok) =>
      blok.index < doluSayisi ? tam.blok(blok) : r.cizgi;
  return LogoRenkleri(
    mango: renk(LogoBlogu.mango),
    nar: renk(LogoBlogu.nar),
    turkuaz: renk(LogoBlogu.turkuaz),
    l: renk(LogoBlogu.l),
  );
}

class _BlokRenkTween extends Tween<LogoRenkleri> {
  _BlokRenkTween({super.end});

  @override
  LogoRenkleri lerp(double t) => LogoRenkleri.lerp(begin!, end!, t);
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
    final hedef = kayitIlerlemeRenkleri(r, doluSayisi: adim);
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo burada süstür; anlamı yanındaki "Adım N / 4" taşır.
          ExcludeSemantics(
            child: TweenAnimationBuilder<LogoRenkleri>(
              tween: _BlokRenkTween(end: hedef),
              duration: hareketsiz ? Duration.zero : TayfamMotion.uzun,
              curve: TayfamMotion.egri,
              builder: (context, renkler, _) => TayfamLogo(
                boyut: TayfamSizes.kayitIlerlemeLogosu,
                renkler: renkler,
              ),
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
    final metinler = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Avatar süstür; balonlar "Tayfam yazdı" diye okunur.
        const ExcludeSemantics(
          child: TayfamLogo.rozet(boyut: TayfamSizes.tayfamAvatari),
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
