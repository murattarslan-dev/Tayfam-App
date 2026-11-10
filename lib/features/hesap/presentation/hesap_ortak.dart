import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/hesap_hatasi.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [h] hatasının çeviri dosyasındaki metni.
String hesapHatasiMetni(AppLocalizations m, HesapHatasi h) => switch (h) {
  HesapHatasi.baglantiYok => m.hesap_hata_baglanti_yok,
  HesapHatasi.cokFazlaDeneme => m.hesap_hata_cok_fazla_deneme,
  HesapHatasi.webDesteklenmiyor => m.hesap_hata_web,
  HesapHatasi.googleGirisi => m.hesap_hata_google,
  HesapHatasi.metinlerGuncellendi => m.hesap_hata_metinler_guncellendi,
  HesapHatasi.gecersizDogumTarihi => m.hesap_hata_dogum_tarihi,
  HesapHatasi.gecersizAd => m.hesap_hata_ad,
  HesapHatasi.genel => m.hesap_hata_genel,
};

/// Uyarı ikonu ve metinden oluşan hata satırı. Ekran okuyucu metni
/// belirdiği anda okur (canlı bölge). Hata metni ana metin rengindedir
/// (vurgu renkleri metin rengi olmaz, ADR-0004); mor yüzeyde [renk] ile
/// beyaz verilir.
class HataMetni extends StatelessWidget {
  const HataMetni({super.key, required this.metin, this.renk});

  final String metin;

  /// Metin ve ikon rengi; verilmezse `context.renkler.metin`.
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final renk = this.renk ?? context.renkler.metin;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              color: renk,
              size: TayfamSizes.ikon,
            ),
          ),
          const SizedBox(width: TayfamSpacing.s8),
          Expanded(
            child: Text(
              metin,
              style: context.yazi.bodySmall?.copyWith(color: renk),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yazı logo: küçük harfle "tayfam" (Notion: Marka; vektör logo gelene
/// kadar fonttan).
class YaziLogo extends StatelessWidget {
  const YaziLogo({super.key, this.renk});

  /// Verilmezse ana metin rengi.
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        AppLocalizations.of(context).hesap_yazi_logo,
        textAlign: TextAlign.center,
        style: context.yazi.displayLarge?.copyWith(
          color: renk ?? context.renkler.metin,
        ),
      ),
    );
  }
}

/// Hukuki metnin sürümlü sayfasını (ya da mağaza sayfasını) tarayıcıda
/// açan bağlantı düğmesi.
class DisBaglantiDugmesi extends ConsumerWidget {
  const DisBaglantiDugmesi({
    super.key,
    required this.etiket,
    required this.adres,
  });

  final String etiket;
  final Uri adres;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () => disBaglantiyiAc(context, ref, adres),
        icon: const Icon(Icons.open_in_new, size: TayfamSizes.ikon),
        label: Text(etiket),
      ),
    );
  }
}

/// [adres]'i uygulamanın dışında açar; açılamazsa kısa bir bildirim
/// gösterir. Adres log'a yazılmaz.
Future<void> disBaglantiyiAc(
  BuildContext context,
  WidgetRef ref,
  Uri adres,
) async {
  final bildirim = ScaffoldMessenger.of(context);
  final metin = AppLocalizations.of(context).hesap_baglanti_acilamadi;
  final acildi = await ref.read(disBaglantiAciciProvider).ac(adres);
  if (!acildi) bildirim.showSnackBar(SnackBar(content: Text(metin)));
}

/// Ekranın bilgileri (metin sürümleri) yüklenirken ilerleme göstergesi;
/// yüklenemediyse hata ve "Tekrar dene".
class YuklemeDurumu extends StatelessWidget {
  const YuklemeDurumu({
    super.key,
    required this.yukleniyor,
    required this.hata,
    required this.tekrarDene,
  });

  final bool yukleniyor;
  final Object? hata;
  final VoidCallback tekrarDene;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final hata = this.hata;
    if (yukleniyor || hata == null) {
      return Center(
        child: CircularProgressIndicator(
          semanticsLabel: metinler.hesap_acilis_yukleniyor,
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataMetni(metin: hesapHatasiMetni(metinler, hesapHatasiOku(hata))),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: metinler.hesap_tekrar_dene,
              onPressed: tekrarDene,
            ),
          ],
        ),
      ),
    );
  }
}
