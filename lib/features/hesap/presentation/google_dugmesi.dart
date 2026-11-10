import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';

/// "Google ile devam et" düğmesi (ADR-0012 §2): Google'ın oturum açma
/// marka kurallarındaki açık biçim — beyaz zemin, ince gri kenar, resmi
/// "G" işareti solda, Roboto Medium metin, hap biçimi. Değerler
/// [GoogleMarka]'dadır; işaret yeniden renklendirilmez.
///
/// Dokunma alanı en az 48 dp'dir (ADR-0004); odak çerçevesi mor yüzeyde
/// mangodur.
class GoogleIleDevamDugmesi extends StatelessWidget {
  const GoogleIleDevamDugmesi({
    super.key,
    required this.etiket,
    required this.onPressed,
  });

  final String etiket;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: GoogleMarka.zemin,
          foregroundColor: GoogleMarka.metin,
          disabledBackgroundColor: GoogleMarka.zemin,
          disabledForegroundColor: GoogleMarka.metin,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: GoogleMarka.yanBosluk,
          ),
          shape: const StadiumBorder(),
          side: const BorderSide(
            color: GoogleMarka.kenar,
            width: GoogleMarka.kenarKalinligi,
          ),
          textStyle: GoogleMarka.yazi,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Görünür etiketin yanındaki işaret; ekran okuyucu atlar.
            ExcludeSemantics(
              child: Image.asset(
                GoogleMarka.logoVarligi,
                width: GoogleMarka.logo,
                height: GoogleMarka.logo,
              ),
            ),
            const SizedBox(width: GoogleMarka.logoMetinArasi),
            Flexible(child: Text(etiket, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}
