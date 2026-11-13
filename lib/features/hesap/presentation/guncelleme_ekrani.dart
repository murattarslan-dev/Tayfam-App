import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/presentation/hesap_durum_duzeni.dart';
import 'package:tayfam/features/hesap/presentation/hesap_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Güncelleme gerekli" (ADR-0012 §1.1; tasarım Hesap-Guncelleme): sürüm
/// platformun en düşük desteklenen sürümünün altında ya da bir istek
/// `client-outdated` aldı. Mango ikon; başka bir şey yapılamaz. Android'de
/// "Google Play'de güncelle" Play sayfasını açar (iOS'ta App Store metni ve
/// bağlantısı iOS işiyle gelir).
class GuncellemeEkrani extends ConsumerWidget {
  const GuncellemeEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return HesapDurumDuzeni(
      ikon: Icons.download_rounded,
      ikonZemini: r.tintMango,
      ikonRengi: r.tintMangoUstu,
      baslik: m.hesap_guncelleme_baslik,
      aciklama: m.hesap_guncelleme_aciklama,
      eylemler: [
        if (android)
          BirincilEylem(
            etiket: m.hesap_guncelleme_magaza,
            onPressed: () => disBaglantiyiAc(context, ref, playMagazaAdresi),
          ),
      ],
    );
  }
}
