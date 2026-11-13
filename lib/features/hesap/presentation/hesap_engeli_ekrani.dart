import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/application/hesap_engeli.dart';
import 'package:tayfam/features/hesap/presentation/hesap_durum_duzeni.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Hesabın kısıtlandı" / "Hesabın kapatıldı" (ADR-0012 §2; tasarım
/// Hesap-Kisitli): giriş `account-sanctioned` (ya da `age-blocked`) ile
/// kapandığında giriş ekranının yerine gösterilir. Nar ikon, mevcut metin ve
/// tek eylem "Çıkış yap".
///
/// Oturum açılmamıştır (giriş isteği reddedildi); "Çıkış yap" yalnızca
/// bellekteki engeli bırakır ve giriş ekranına döner (başka bir Google
/// hesabıyla girmek için). Hesabın kısıtlı olduğuna yine sunucu karar
/// verir; aynı hesapla yeniden girilirse engel tekrar gelir.
class HesapEngeliEkrani extends ConsumerWidget {
  const HesapEngeliEkrani({super.key, required this.engel});

  final HesapEngeli engel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return HesapDurumDuzeni(
      ikon: Icons.block,
      ikonZemini: r.tintNar,
      ikonRengi: r.narMetin,
      baslik: switch (engel) {
        HesapEngeli.yasSiniri => m.hesap_engel_yas_baslik,
        HesapEngeli.kisitlandi => m.hesap_engel_kisit_baslik,
      },
      aciklama: switch (engel) {
        HesapEngeli.yasSiniri => m.hesap_engel_yas_aciklama,
        HesapEngeli.kisitlandi => m.hesap_engel_kisit_aciklama,
      },
      eylemler: [
        BirincilEylem(
          etiket: m.hesap_cikis_yap,
          onPressed: () => ref.read(hesapEngeliProvider.notifier).temizle(),
        ),
      ],
    );
  }
}
