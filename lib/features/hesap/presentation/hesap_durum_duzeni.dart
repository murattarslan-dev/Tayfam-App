import 'package:flutter/material.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tema.dart';

/// Hesap durum ekranlarının ortak düzeni (tasarım: 20-hesap-durumlari;
/// Hesap-Onay, Hesap-Guncelleme, Hesap-Kisitli): üstte küçük logo, büyük
/// ikon kutusu, ortalanmış başlık ve açıklama, isteğe bağlı ek içerik;
/// altta sabit eylemler.
///
/// İçerik kayar (2× yazıda taşmaz); eylemler ekranın altında kalır. Geniş
/// ekranda içerik okuma genişliğinde, ortadadır.
class HesapDurumDuzeni extends StatelessWidget {
  const HesapDurumDuzeni({
    super.key,
    required this.ikon,
    required this.ikonZemini,
    required this.ikonRengi,
    required this.baslik,
    required this.aciklama,
    this.icerik,
    this.eylemler = const [],
    this.ustBosluk = TayfamSpacing.s64 + TayfamSpacing.s56,
  });

  /// Büyük ikon kutusundaki ikon.
  final IconData ikon;

  /// İkon kutusunun zemini (tint-brand, tint-mango ya da tint-nar).
  final Color ikonZemini;

  /// İkonun rengi (kutunun zeminiyle eşleşen "üstü" rengi).
  final Color ikonRengi;

  final String baslik;
  final String aciklama;

  /// Açıklamanın altındaki ek içerik (yeniden onayda "oku" satırları ve
  /// onay kutusu).
  final Widget? icerik;

  /// Alttaki eylemler, yukarıdan aşağı.
  final List<Widget> eylemler;

  /// Logonun üstündeki boşluk (tasarımda yeniden onayda 64, diğerlerinde
  /// 120 px).
  final double ustBosluk;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yazi = context.yazi;
    final icerik = this.icerik;
    return Scaffold(
      backgroundColor: r.zemin,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      TayfamSpacing.s24,
                      ustBosluk,
                      TayfamSpacing.s24,
                      TayfamSpacing.s24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: TayfamLogo(boyut: TayfamSizes.durumLogosu),
                        ),
                        const SizedBox(height: TayfamSpacing.s40),
                        Center(
                          child: HesapDurumIkonu(
                            ikon: ikon,
                            zemin: ikonZemini,
                            renk: ikonRengi,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s24),
                        Semantics(
                          header: true,
                          child: Text(
                            baslik,
                            textAlign: TextAlign.center,
                            style: yazi.headlineMedium,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s16),
                        Text(
                          aciklama,
                          textAlign: TextAlign.center,
                          style: yazi.bodyLarge?.copyWith(color: r.metinGovde),
                        ),
                        if (icerik != null) ...[
                          const SizedBox(height: TayfamSpacing.s24),
                          icerik,
                        ],
                      ],
                    ),
                  ),
                ),
                if (eylemler.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TayfamSpacing.s20,
                      0,
                      TayfamSpacing.s20,
                      TayfamSpacing.s32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: eylemler,
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

/// Durum ekranının büyük ikon kutusu: 96 px, 30 px köşe, 46 px ikon. Süstür;
/// anlamı başlık taşır, bu yüzden ekran okuyucudan gizlidir.
class HesapDurumIkonu extends StatelessWidget {
  const HesapDurumIkonu({
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
        width: TayfamSizes.durumIkonKutusu,
        height: TayfamSizes.durumIkonKutusu,
        decoration: BoxDecoration(
          color: zemin,
          borderRadius: TayfamRadii.durumKutusuKoseleri,
        ),
        alignment: Alignment.center,
        child: Icon(ikon, color: renk, size: TayfamSizes.durumIkonu),
      ),
    );
  }
}

/// "… oku" satırı (tasarım: Hesap-Onay): kart zemini, çizgi rengi kenar,
/// 16 px köşe; solda belge ikonu, sağda "dışarıda açılır" işareti. Satırın
/// tamamı tek düğmedir; metni sistem tarayıcısında açar.
class OkumaSatiri extends StatelessWidget {
  const OkumaSatiri({super.key, required this.etiket, required this.onTap});

  final String etiket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.secimKoseleri,
      child: Material(
        color: r.kart,
        shape: RoundedRectangleBorder(
          borderRadius: TayfamRadii.secimKoseleri,
          side: BorderSide(color: r.cizgi),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TayfamSizes.okumaSatiri,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TayfamSpacing.s12,
                  vertical: TayfamSpacing.s8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: TayfamSizes.ikon,
                      color: r.tintMarkaUstu,
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Text(etiket, style: context.yazi.titleSmall),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Icon(
                      Icons.open_in_new,
                      size: TayfamSizes.ikonOrta,
                      color: r.metinIkincil,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek onay kutusu ve etiketi (tasarım: Hesap-Onay); ikisi birlikte tek
/// öğe olarak okunur, etikete dokunmak da kutuyu değiştirir. [degisti]
/// `null` ise kutu devre dışıdır (gönderim sürerken).
class OnayKutusuSatiri extends StatelessWidget {
  const OnayKutusuSatiri({
    super.key,
    required this.etiket,
    required this.isaretli,
    required this.degisti,
  });

  final String etiket;
  final bool isaretli;
  final ValueChanged<bool>? degisti;

  @override
  Widget build(BuildContext context) {
    final degisti = this.degisti;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isaretli,
            onChanged: degisti == null
                ? null
                : (deger) => degisti(deger ?? false),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: degisti == null ? null : () => degisti(!isaretli),
              child: Padding(
                padding: const EdgeInsets.only(top: TayfamSpacing.s12),
                child: Text(
                  etiket,
                  style: context.yazi.bodySmall?.copyWith(
                    color: context.renkler.metin,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
