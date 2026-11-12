import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/application/qr_gosterim_notifier.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_kodu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Bu cihazı bağla" (yeni cihaz): eşleştirme QR'ı, 10 dakikalık geri
/// sayım ve süre dolunca "Yeni kod al". Diğer telefon kodu okutunca
/// eşleştirme kendiliğinden tamamlanır.
class BuCihaziBaglaEkrani extends ConsumerWidget {
  const BuCihaziBaglaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(qrGosterimProvider);
    void yenile() => unawaited(ref.read(qrGosterimProvider.notifier).yenile());

    return CihazEkrani(
      baslik: metinler.cihaz_bu_cihazi_bagla_baslik,
      children: [
        CihazAciklamasi(metinler.cihaz_qr_talimat),
        const SizedBox(height: TayfamSpacing.s24),
        ...switch (durum) {
          QrHazirlaniyor() => [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: metinler.cihaz_qr_hazirlaniyor,
              ),
            ),
          ],
          QrGosteriliyor(:final metin, :final kalan) => [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TayfamSizes.okumaGenisligi / 2,
                ),
                child: ClipRRect(
                  borderRadius: TayfamRadii.onizlemeKoseleri,
                  child: QrKodu(
                    metin: metin,
                    etiket: metinler.cihaz_qr_etiketi,
                  ),
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
            Text(
              metinler.cihaz_qr_kalan(_sure(kalan)),
              textAlign: TextAlign.center,
              style: context.yazi.titleMedium,
            ),
          ],
          QrSuresiDoldu() => [
            Text(
              metinler.cihaz_qr_suresi_doldu,
              style: context.yazi.titleMedium,
            ),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: metinler.cihaz_qr_yenile,
              ikon: Icons.refresh,
              onPressed: yenile,
            ),
          ],
          QrTamamlandi() => [
            Text(metinler.cihaz_qr_tamamlandi, style: context.yazi.titleMedium),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: metinler.cihaz_tamam,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
          QrGosterimHatasi(:final hata) => [
            HataSatiri(metin: cihazHataMetni(metinler, hata)),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: metinler.cihaz_qr_yenile,
              ikon: Icons.refresh,
              onPressed: yenile,
            ),
          ],
        },
      ],
    );
  }
}

/// `9:05` biçiminde kalan süre.
String _sure(Duration kalan) {
  final saniye = (kalan.inMilliseconds / 1000).ceil();
  final dakika = saniye ~/ 60;
  return '$dakika:${(saniye % 60).toString().padLeft(2, '0')}';
}
