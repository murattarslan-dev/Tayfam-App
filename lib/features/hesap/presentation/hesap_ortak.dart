import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/problem_messages.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [hata]'nın giriş, kayıt ve onay ekranlarındaki metni.
///
/// Google girişinin istemcideki hataları bu özelliğin kendi metinleriyle;
/// API ve bağlantı hataları ortak eşlemeyle ([hataMetni], ADR-0005 §4)
/// gösterilir. Sunucunun `title` / `detail` metni gösterilmez.
String hesapHatasiMetni(AppLocalizations m, Object hata) => switch (hata) {
  GoogleGirisHatasi(desteklenmiyor: true) => m.hesap_hata_web,
  GoogleGirisHatasi() => m.hesap_hata_google,
  _ => hataMetni(m, hata),
};

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
        child: TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran, etiket: metinler.hesap_acilis_yukleniyor, gecikmeli: true,),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri(metin: hesapHatasiMetni(metinler, hata)),
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
