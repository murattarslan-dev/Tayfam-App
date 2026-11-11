import 'package:flutter/material.dart';

import 'package:tayfam/core/api/problem_messages.dart';
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
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
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
