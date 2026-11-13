import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Yıkıcı işlem düğmesi (tayfadan ayrıl, banla, çıkar, sil; ADR-0004
/// Notlar 2026-11-13): 12 px köşe, en az 48 px.
///
/// [dolu] ise onay penceresindeki son adımdır: açık temada nar-metin zemin
/// + beyaz metin (7.01:1), koyu temada #FF9FB4 zemin + ink metin (9.26:1).
/// Değilse çerçevelidir: kart zemininde nar-metin kenar ve metin (tasarım:
/// Ayar-Ana "Tayfayı sil"). [onPressed] `null` ise düğme devre dışıdır.
class YikiciEylem extends StatelessWidget {
  const YikiciEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
    this.dolu = false,
    this.semantikEtiketi,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final bool dolu;

  /// Görünen kısa etiketten farklı ekran okuyucu etiketi (ör. oturum
  /// satırındaki "Kapat" için "Oturumu kapat").
  final String? semantikEtiketi;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    const sekil = RoundedRectangleBorder(
      borderRadius: TayfamRadii.dugmeKoseleri,
    );
    const boyut = Size.square(TayfamSizes.dokunmaMin);
    const bosluk = EdgeInsets.symmetric(
      horizontal: TayfamSpacing.s16,
      vertical: TayfamSpacing.s12,
    );
    final icerik = EylemIcerigi(
      etiket: etiket,
      ikon: ikon,
      semantikEtiketi: semantikEtiketi,
    );
    return OdakCercevesi(
      koseler: TayfamRadii.dugmeKoseleri,
      child: dolu
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: r.yikiciDolgu,
                foregroundColor: r.yikiciDolguUstu,
                disabledBackgroundColor: r.pasif,
                disabledForegroundColor: r.pasifUstu,
                minimumSize: boyut,
                padding: bosluk,
                shape: sekil,
                // Odak çerçevesini OdakCercevesi çizer.
                side: BorderSide.none,
                textStyle: context.yazi.labelLarge,
              ),
              child: icerik,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: r.narMetin,
                disabledForegroundColor: r.pasifUstu,
                minimumSize: boyut,
                padding: bosluk,
                shape: sekil,
                side: BorderSide(
                  color: onPressed == null ? r.pasif : r.narMetin,
                  width: TayfamSizes.vurguKenari,
                ),
                textStyle: context.yazi.labelLarge,
              ),
              child: icerik,
            ),
    );
  }
}
