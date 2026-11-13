import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// İki satırlı sohbet üst çubuğunun yüksekliği (tasarım: Kanal-Akis,
/// Birebir-Konusma: ad ve altında tayfa adı ya da "Uçtan uca şifreli").
/// Satırlar tek satırdır; yükseklik yazı ölçeğiyle büyür ki 2× yazıda
/// taşmasın. En az Material'in araç çubuğu yüksekliğidir.
double sohbetUstCubukYuksekligi(BuildContext context) {
  final olcek = MediaQuery.textScalerOf(context);
  double satir(TextStyle? stil) {
    final boyut = stil?.fontSize ?? TayfamSizes.ikon;
    return olcek.scale(boyut) * (stil?.height ?? 1);
  }

  return math.max(
    kToolbarHeight,
    satir(context.yazi.titleMedium) +
        satir(context.yazi.bodySmall) +
        TayfamSpacing.s16,
  );
}

/// Mesaj akışında günün ilk mesajının üstündeki çip (tasarım: Kanal-Akis,
/// Birebir-Konusma): tint-brand zemin, 13 px 700 ("Bugün", "Dün", tarih).
class GunAyirici extends StatelessWidget {
  const GunAyirici({super.key, required this.metin});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: r.tintMarka,
            borderRadius: TayfamRadii.hapKoseleri,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s12,
              vertical: TayfamSpacing.s4,
            ),
            child: Text(
              metin,
              textAlign: TextAlign.center,
              style: context.yazi.labelMedium?.copyWith(color: r.tintMarkaUstu),
            ),
          ),
        ),
      ),
    );
  }
}

/// Akış içinde ortalanmış sistem notu (tasarım: Birebir-Konusma "Güvenlik
/// kodu değişti"): tint-mango zemin, ikon ve metin tint-mango üstü renkte.
/// İkon süstür; anlamı metin taşır.
class SistemNotu extends StatelessWidget {
  const SistemNotu({super.key, required this.metin, required this.ikon});

  final String metin;
  final IconData ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s12,
        vertical: TayfamSpacing.s8,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: r.tintMango,
            borderRadius: TayfamRadii.onizlemeKoseleri,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TayfamSpacing.s12,
              vertical: TayfamSpacing.s8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    ikon,
                    size: TayfamSizes.ikonKucuk,
                    color: r.tintMangoUstu,
                  ),
                ),
                const SizedBox(width: TayfamSpacing.s8),
                Flexible(
                  child: Text(
                    metin,
                    style: context.yazi.labelSmall?.copyWith(
                      color: r.tintMangoUstu,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mesajın altındaki küçük ikincil satır: saat, "Görüldü", "Gönderiliyor".
class MesajAltSatiri extends StatelessWidget {
  const MesajAltSatiri({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s4,
        vertical: TayfamSpacing.s4,
      ),
      child: DefaultTextStyle.merge(
        style: context.yazi.labelSmall?.copyWith(
          color: context.renkler.metinIkincil,
          fontWeight: FontWeight.w400,
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: TayfamSpacing.s4,
          children: children,
        ),
      ),
    );
  }
}

/// Gönderilemeyen mesajın altındaki satır (tasarım: Kanal-Akis): nar-metin
/// "Gönderilemedi", "Tekrar dene" (aynı `client_request_id`) ve "Sil".
class GonderilemediSatiri extends StatelessWidget {
  const GonderilemediSatiri({
    super.key,
    required this.durum,
    required this.tekrarDene,
    required this.sil,
    required this.onTekrarDene,
    required this.onSil,
  });

  /// "Gönderilemedi".
  final String durum;

  /// "Tekrar dene" düğmesinin etiketi.
  final String tekrarDene;

  /// "Sil" düğmesinin etiketi.
  final String sil;

  final VoidCallback onTekrarDene;
  final VoidCallback onSil;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TayfamSpacing.s4,
      children: [
        Text(
          durum,
          style: context.yazi.labelMedium?.copyWith(color: r.narMetin),
        ),
        BaglantiEylemi(etiket: tekrarDene, onPressed: onTekrarDene),
        BaglantiEylemi(etiket: sil, renk: r.metinIkincil, onPressed: onSil),
      ],
    );
  }
}

/// Mesaj yazma çubuğu (tasarım: Kanal-Akis, Birebir-Konusma): kart zemin,
/// üstte çizgi; yuvarlak metin alanı ve sağda dairesel "Gönder" düğmesi.
///
/// [geriSayim] verilirse (yavaş mod) düğmenin yerinde kalan süre ("12 sn")
/// gösterilir; ekran okuyucu [geriSayimEtiketi]'ni okur. [ust] alanın
/// üstündeki bilgi satırıdır (yavaş mod, kural hatası).
///
/// Metin yalnızca [denetleyici]'nin belleğindedir; taslak hiçbir yere
/// yazılmaz (ADR-0006).
class MesajYazmaCubugu extends StatelessWidget {
  const MesajYazmaCubugu({
    super.key,
    required this.denetleyici,
    required this.ipucu,
    required this.gonderEtiketi,
    required this.onGonder,
    this.enUzun,
    this.etkin = true,
    this.ust,
    this.geriSayim,
    this.geriSayimEtiketi,
  });

  final TextEditingController denetleyici;

  /// Alan boşken görünen ipucu ("Mesaj yaz").
  final String ipucu;

  /// "Gönder" düğmesinin ipucu ve ekran okuyucu etiketi.
  final String gonderEtiketi;

  final VoidCallback? onGonder;

  /// Metnin en uzun hâli; sayaç gösterilmez.
  final int? enUzun;

  /// `false` iken alan ve düğme kapalıdır.
  final bool etkin;

  final Widget? ust;

  /// Yavaş modda düğmenin yerindeki kısa geri sayım ("12 sn").
  final String? geriSayim;

  /// Geri sayımın ekran okuyucu metni ("12 sn sonra yazabilirsin").
  final String? geriSayimEtiketi;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final ust = this.ust;
    final geriSayim = this.geriSayim;
    final alanKenari = OutlineInputBorder(
      borderRadius: TayfamRadii.hapKoseleri,
      borderSide: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
    );
    final Widget dugme;
    if (geriSayim != null) {
      dugme = Semantics(
        label: geriSayimEtiketi ?? geriSayim,
        liveRegion: true,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: r.tintMarka, shape: BoxShape.circle),
          child: SizedBox.square(
            dimension: TayfamSizes.dokunmaMin,
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  geriSayim,
                  style: context.yazi.labelMedium?.copyWith(
                    color: r.tintMarkaUstu,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      dugme = OdakCercevesi(
        koseler: TayfamRadii.hapKoseleri,
        child: IconButton(
          tooltip: gonderEtiketi,
          onPressed: etkin ? onGonder : null,
          style: IconButton.styleFrom(
            backgroundColor: r.birincilEylem,
            foregroundColor: r.birincilEylemUstu,
            disabledBackgroundColor: r.pasif,
            disabledForegroundColor: r.pasifUstu,
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          icon: const Icon(Icons.send_rounded, size: TayfamSizes.ikon),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.kart,
        border: Border(
          top: BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s12,
            vertical: TayfamSpacing.s8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ust != null) ...[
                ust,
                const SizedBox(height: TayfamSpacing.s8),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: denetleyici,
                      enabled: etkin,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: enUzun,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: context.yazi.bodyLarge?.copyWith(color: r.metin),
                      decoration: InputDecoration(
                        hintText: ipucu,
                        counterText: '',
                        filled: true,
                        fillColor: r.zemin,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: TayfamSpacing.s16,
                          vertical: TayfamSpacing.s12,
                        ),
                        border: alanKenari,
                        enabledBorder: alanKenari,
                        disabledBorder: alanKenari,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: TayfamRadii.hapKoseleri,
                          borderSide: BorderSide(
                            color: r.odak,
                            width: TayfamSizes.alanOdakKenari,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  dugme,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
