import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet balonu (ADR-0004): gelen balon tint zemin + ink metin (koyu
/// temada bubble-in-dark + beyaz), giden balon brand zemin + beyaz metin.
/// Köşeler 18 px; gönderen taraftaki alt köşe 6 px.
///
/// Ekran okuyucu balonu "kim yazdı" bilgisiyle tek parça okur. Mesaj metni
/// yalnızca ekranda ve erişilebilirlik ağacındadır; hiçbir yere yazılmaz.
class SohbetBalonu extends StatelessWidget {
  const SohbetBalonu({
    super.key,
    required this.metin,
    required this.giden,
    this.gonderen,
  });

  final String metin;

  /// `true`: kullanıcının kendi mesajı (sağda, brand zemin).
  final bool giden;

  /// Gelen mesajın gönderen adı; birebir sohbette verilmeyebilir.
  final String? gonderen;

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
    final koseler = BorderRadiusDirectional.only(
      topStart: buyuk,
      topEnd: buyuk,
      bottomStart: giden ? buyuk : kucuk,
      bottomEnd: giden ? kucuk : buyuk,
    );
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
                color: giden ? r.markaYuzey : r.gelenBalon,
                borderRadius: koseler,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s16,
                  vertical: TayfamSpacing.s12,
                ),
                child: Text(
                  metin,
                  style: context.yazi.bodyLarge?.copyWith(
                    color: giden ? r.markaYuzeyUstu : r.gelenBalonUstu,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
