import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';

/// "Google ile devam et" düğmesi (ADR-0012 §2): Google'ın oturum açma
/// marka kurallarına göre — açık temada "açık" biçim (beyaz zemin, #747775
/// kenar), koyu temada "koyu" biçim (#131314 zemin, #8E918F kenar); resmi
/// "G" işareti solda, Roboto Medium metin, hap biçimi. Değerler
/// [GoogleMarka]'dadır; işaret yeniden renklendirilmez.
///
/// Yükseklik giriş ekranı tasarımındaki gibi 52 dp
/// ([TayfamSizes.girisDugmesi]); dokunma alanı 48'in üstünde (ADR-0004).
/// Odak çerçevesi zemine göre (açık temada brand, koyu temada mango).
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
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final zemin = koyu ? GoogleMarka.koyuZemin : GoogleMarka.zemin;
    final metin = koyu ? GoogleMarka.koyuMetin : GoogleMarka.metin;
    final kenar = koyu ? GoogleMarka.koyuKenar : GoogleMarka.kenar;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: zemin,
          foregroundColor: metin,
          disabledBackgroundColor: zemin,
          disabledForegroundColor: metin,
          minimumSize: const Size(
            TayfamSizes.dokunmaMin,
            TayfamSizes.girisDugmesi,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GoogleMarka.yanBosluk,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(color: kenar, width: GoogleMarka.kenarKalinligi),
          textStyle: GoogleMarka.yazi.copyWith(color: metin),
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
