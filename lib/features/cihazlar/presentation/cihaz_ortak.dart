import 'package:flutter/material.dart';

import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [hata]'nın eşleştirme ekranlarındaki metni: istemcinin tespit ettiği
/// eşleştirme hataları kendi metinleriyle, API hataları ortak eşlemeyle
/// (`title` / `detail` gösterilmez).
String cihazHataMetni(AppLocalizations m, Object hata) => switch (hata) {
  EslemeHatasi(:final tur) => switch (tur) {
    EslemeHataTuru.qrGecersiz => m.cihaz_hata_qr_gecersiz,
    EslemeHataTuru.kendiCihazi => m.cihaz_hata_kendi_cihazi,
    EslemeHataTuru.cihazBulunamadi => m.cihaz_hata_cihaz_bulunamadi,
    EslemeHataTuru.anahtarUyusmuyor => m.cihaz_hata_anahtar_uyusmuyor,
    EslemeHataTuru.eslestirilmemis => m.cihaz_hata_eslestirilmemis,
    EslemeHataTuru.suresiDoldu => m.cihaz_hata_suresi_doldu,
    EslemeHataTuru.cevapGecersiz => m.cihaz_hata_cevap_gecersiz,
    EslemeHataTuru.anahtarYenilendi => m.cihaz_hata_anahtar_yenilendi,
  },
  _ => hataMetni(m, hata),
};

/// Eşleştirme ekranlarının ortak iskeleti: başlık, okunabilir genişlikte
/// kaydırılabilir gövde.
class CihazEkrani extends StatelessWidget {
  const CihazEkrani({super.key, required this.baslik, required this.children});

  final String baslik;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(baslik)),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.s24,
          TayfamSpacing.s4,
          TayfamSpacing.s24,
          TayfamSpacing.s32,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

/// İkincil renkte açıklama metni.
class CihazAciklamasi extends StatelessWidget {
  const CihazAciklamasi(this.metin, {super.key});

  final String metin;

  @override
  Widget build(BuildContext context) => Text(
    metin,
    style: context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinIkincil,
    ),
  );
}

/// Sonuç ekranının ikon tonu (tasarım: Cihaz-Basarili, Cihaz-Hata,
/// Cihaz-Kamera-Izni).
enum CihazSonucTonu {
  /// tint-teal daire, teal tik: eşleştirme tamamlandı ya da gönderildi.
  basarili,

  /// tint-nar daire, nar-metin uyarı üçgeni: eşleştirme olmadı.
  hata,

  /// tint-brand yuvarlak köşeli kutu, marka renginde kamera: izin gerekli.
  izin,
}

/// Eşleştirmenin sonuç ve izin ekranları: ortada büyük ikon, başlık ve
/// açıklama; altta eylemler (birincil önce).
///
/// Başlık belirince ekran okuyucu okur (canlı bölge). [ustBaslik] verilirse
/// üstte geri düğmeli başlık çubuğu gösterilir (kamera izni ekranı).
class CihazSonucEkrani extends StatelessWidget {
  const CihazSonucEkrani({
    super.key,
    required this.ton,
    required this.baslik,
    required this.aciklama,
    required this.eylemler,
    this.ustBaslik,
  });

  final CihazSonucTonu ton;
  final String baslik;
  final String aciklama;
  final List<Widget> eylemler;
  final String? ustBaslik;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final ustBaslik = this.ustBaslik;
    final (zemin, renk, ikon, koseler) = switch (ton) {
      CihazSonucTonu.basarili => (
        r.tintTeal,
        r.tintTealUstu,
        Icons.check_rounded,
        TayfamRadii.hapKoseleri,
      ),
      CihazSonucTonu.hata => (
        r.tintNar,
        r.narMetin,
        Icons.warning_amber_rounded,
        TayfamRadii.hapKoseleri,
      ),
      CihazSonucTonu.izin => (
        r.tintMarka,
        r.tintMarkaUstu,
        Icons.photo_camera_outlined,
        TayfamRadii.sonucKutusuKoseleri,
      ),
    };
    return Scaffold(
      appBar: ustBaslik == null ? null : AppBar(title: Text(ustBaslik)),
      body: SafeArea(
        child: Center(
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
                      ustBaslik == null
                          ? TayfamSpacing.s64
                          : TayfamSpacing.s40,
                      TayfamSpacing.s24,
                      TayfamSpacing.s24,
                    ),
                    child: Column(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: TayfamSizes.sonucIkonu,
                            height: TayfamSizes.sonucIkonu,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: zemin,
                              borderRadius: koseler,
                            ),
                            child: Icon(
                              ikon,
                              color: renk,
                              size: TayfamSizes.sonucIkonuIcerik,
                            ),
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s24),
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(
                            baslik,
                            textAlign: TextAlign.center,
                            style: context.yazi.displayLarge,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s12),
                        Text(
                          aciklama,
                          textAlign: TextAlign.center,
                          style: context.yazi.bodyLarge?.copyWith(
                            color: r.metinGovde,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TayfamSpacing.s20,
                    0,
                    TayfamSpacing.s20,
                    TayfamSpacing.s24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, eylem) in eylemler.indexed) ...[
                        if (i > 0) const SizedBox(height: TayfamSpacing.s8),
                        eylem,
                      ],
                    ],
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

/// Sonuç ekranındaki ikincil, zeminsiz eylem ("Kapat", "Tekrar tara"):
/// gövde renginde, tam genişlikte.
class CihazIkincilEylem extends StatelessWidget {
  const CihazIkincilEylem({
    super.key,
    required this.etiket,
    required this.onPressed,
  });

  final String etiket;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => BaglantiEylemi(
    etiket: etiket,
    renk: context.renkler.metinGovde,
    onPressed: onPressed,
  );
}
