import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet balonunun görünümü.
enum BalonTuru {
  /// Tanıtım ve kayıt sohbeti (ADR-0004): gelen balon tint zemin.
  olagan,

  /// Mesaj akışı (2026-11-13 tasarım: Kanal-Akis, Birebir-Konusma): gelen
  /// balon kart zemin + çizgi kenar, ana metin rengi.
  akis,

  /// Silinmiş mesaj: akış balonu, italik ikincil metin ("Bu mesaj
  /// silindi").
  silinmis,

  /// Gönderilemeyen giden mesaj: tint-nar zemin + nar-metin kenar, ana
  /// metin rengi (ADR-0004 Notlar 2026-11-13).
  gonderilemedi,
}

/// Sohbet balonu (ADR-0004): gelen balon tint zemin + ink metin (koyu
/// temada bubble-in-dark + beyaz), giden balon brand zemin + beyaz metin.
/// Köşeler 18 px; gönderen taraftaki alt köşe 6 px ([kuyruk]).
///
/// Mesaj akışında ([BalonTuru.akis]) gelen balon kart zemin ve çizgi
/// kenarlıdır; aynı yazarın ardışık mesajlarında yalnızca grubun son
/// balonunun kuyruğu vardır, kanalda grubun ilk balonunda gönderenin adı
/// yazar ([adGoster]).
///
/// Ekran okuyucu balonu "kim yazdı" bilgisiyle tek parça okur. Mesaj metni
/// yalnızca ekranda ve erişilebilirlik ağacındadır; hiçbir yere yazılmaz.
class SohbetBalonu extends StatelessWidget {
  const SohbetBalonu({
    super.key,
    required this.metin,
    required this.giden,
    this.gonderen,
    this.tur = BalonTuru.olagan,
    this.kuyruk = true,
    this.adGoster = false,
  });

  final String metin;

  /// `true`: kullanıcının kendi mesajı (sağda, brand zemin).
  final bool giden;

  /// Gelen mesajın gönderen adı; birebir sohbette verilmeyebilir.
  final String? gonderen;

  final BalonTuru tur;

  /// Gönderen taraftaki alt köşe küçük (6 px); grubun ortasındaki
  /// balonlarda `false`.
  final bool kuyruk;

  /// Gelen balonun başında [gonderen]'in adı yazar (kanal akışında grubun
  /// ilk balonu).
  final bool adGoster;

  /// Ekran okuyucunun balondan önce okuduğu "kim yazdı" bilgisi.
  String _kim(AppLocalizations metinler) {
    final gonderen = this.gonderen;
    if (giden) {
      return metinler.bilesen_sohbet_giden;
    }
    if (gonderen == null) {
      return metinler.bilesen_sohbet_gelen_adsiz;
    }
    return metinler.bilesen_sohbet_gelen(gonderen);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final metinler = AppLocalizations.of(context);
    final kim = _kim(metinler);
    const buyuk = Radius.circular(TayfamRadii.balon);
    const kucuk = Radius.circular(TayfamRadii.balonKuyruk);
    final kuyrukKosesi = kuyruk ? kucuk : buyuk;
    final koseler = BorderRadiusDirectional.only(
      topStart: buyuk,
      topEnd: buyuk,
      bottomStart: giden ? buyuk : kuyrukKosesi,
      bottomEnd: giden ? kuyrukKosesi : buyuk,
    );
    final (zemin, yazi, kenar) = switch (tur) {
      BalonTuru.gonderilemedi => (
        r.tintNar,
        r.metin,
        BorderSide(color: r.narMetin, width: TayfamSizes.vurguKenari),
      ),
      BalonTuru.silinmis => (
        r.kart,
        r.metinIkincil,
        BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      _ when giden => (r.markaYuzey, r.markaYuzeyUstu, BorderSide.none),
      BalonTuru.akis => (
        r.kart,
        r.metin,
        BorderSide(color: r.cizgi, width: TayfamSizes.kenar),
      ),
      BalonTuru.olagan => (r.gelenBalon, r.gelenBalonUstu, BorderSide.none),
    };
    final gonderen = this.gonderen;
    final ad = adGoster && !giden && gonderen != null ? gonderen : null;
    final govdeStili = context.yazi.bodyLarge?.copyWith(
      color: yazi,
      fontStyle: tur == BalonTuru.silinmis ? FontStyle.italic : null,
    );
    final Widget icerik = ad == null
        ? Text(metin, style: govdeStili)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ad, balonun ekran okuyucu etiketinde zaten okunur.
              ExcludeSemantics(
                child: Text(
                  ad,
                  style: context.yazi.labelMedium?.copyWith(
                    color: r.tintMarkaUstu,
                  ),
                ),
              ),
              Text(metin, style: govdeStili),
            ],
          );
    final akista = tur != BalonTuru.olagan;
    return LayoutBuilder(
      builder: (context, kisit) => Align(
        alignment: giden
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kisit.maxWidth * TayfamSizes.balonEnFazlaOran,
          ),
          child: Semantics(
            container: true,
            label: kim,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: zemin,
                borderRadius: koseler,
                border: kenar == BorderSide.none
                    ? null
                    : Border.fromBorderSide(kenar),
              ),
              child: Padding(
                padding: akista
                    ? const EdgeInsets.symmetric(
                        horizontal: TayfamSpacing.s12,
                        vertical: TayfamSpacing.s8,
                      )
                    : const EdgeInsets.symmetric(
                        horizontal: TayfamSpacing.s16,
                        vertical: TayfamSpacing.s12,
                      ),
                child: icerik,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
