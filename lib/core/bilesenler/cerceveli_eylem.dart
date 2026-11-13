import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

/// Çerçeveli hap düğme (tasarım: Profil-Arkadaslar "Kodumu paylaş",
/// Kisi-Profili "Tayfaya davet et", Profil-Ana "Çıkış yap"): kart zemin,
/// 1.5 px kenar, en az 48 px.
///
/// Varsayılan görünüm marka tonudur: kenar ve metin tint-brand üstü
/// (açıkta brand, koyuda #CDBBFF). [notr] ise kenar çizgi rengi, metin ana
/// metin rengidir ("Çıkış yap"). [onPressed] `null` ise devre dışıdır.
class CerceveliEylem extends StatelessWidget {
  const CerceveliEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
    this.notr = false,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final bool notr;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final renk = notr ? r.metin : r.tintMarkaUstu;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: r.kart,
          foregroundColor: renk,
          disabledForegroundColor: r.pasifUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s20,
            vertical: TayfamSpacing.s12,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: onPressed == null ? r.pasif : (notr ? r.cizgi : renk),
            width: TayfamSizes.vurguKenari,
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket, ikon: ikon),
      ),
    );
  }
}

/// Metin bağlantısı biçiminde düğme (tasarım: "Arkadaş ekle", "Tümünü
/// gör", "Başkaları nasıl görüyor", "Hesabı sil"): zeminsiz, 15 px 700,
/// en az 48 px dokunma alanı. Renk verilmezse tint-brand üstü (açıkta
/// brand, koyuda #CDBBFF); yıkıcı bağlantıda nar-metin verilir.
class BaglantiEylemi extends StatelessWidget {
  const BaglantiEylemi({
    super.key,
    required this.etiket,
    required this.onPressed,
    this.ikon,
    this.renk,
    this.semantikEtiketi,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;
  final Color? renk;

  /// Görünen metinden farklı bir ekran okuyucu etiketi (ör. "Tüm
  /// katılımların").
  final String? semantikEtiketi;

  @override
  Widget build(BuildContext context) {
    final renk = this.renk ?? context.renkler.tintMarkaUstu;
    final semantikEtiketi = this.semantikEtiketi;
    final icerik = EylemIcerigi(etiket: etiket, ikon: ikon);
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: renk,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s12),
          shape: const StadiumBorder(),
          // Odak çerçevesini OdakCercevesi çizer.
          side: BorderSide.none,
          textStyle: context.yazi.labelLarge,
        ),
        child: semantikEtiketi == null
            ? icerik
            : Semantics(
                label: semantikEtiketi,
                excludeSemantics: true,
                child: icerik,
              ),
      ),
    );
  }
}
