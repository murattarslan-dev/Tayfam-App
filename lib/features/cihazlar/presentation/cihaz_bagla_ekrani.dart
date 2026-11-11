import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/application/qr_tarama_notifier.dart';
import 'package:tayfam/features/cihazlar/data/ayarlar_acici.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/features/cihazlar/presentation/qr_tarayici.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Cihaz bağla" (eşleştirilmiş cihaz): yeni telefondaki QR'ı okutur,
/// doğrular ve geçmiş anahtarlarını şifreli gönderir.
///
/// Kamera yalnızca bu ekranda ve tarama durumundayken açılır; izin de
/// ilk kez burada istenir. Reddedilirse açıklama ve (iOS'ta) ayarlara
/// gitme düğmesi gösterilir.
class CihazBaglaEkrani extends ConsumerWidget {
  const CihazBaglaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(qrTaramaProvider);
    final notifier = ref.read(qrTaramaProvider.notifier);
    final ayarlar = ref.watch(ayarlarAciciProvider);
    final tekrar = BirincilEylem(
      etiket: metinler.cihaz_tara_tekrar,
      ikon: Icons.qr_code_scanner,
      onPressed: notifier.tekrarTara,
    );

    return CihazEkrani(
      baslik: metinler.cihaz_bagla_baslik,
      children: [
        CihazAciklamasi(metinler.cihaz_tara_talimat),
        const SizedBox(height: TayfamSpacing.s24),
        ...switch (durum) {
          QrTaraniyor() => [
            ClipRRect(
              borderRadius: TayfamRadii.onizlemeKoseleri,
              child: AspectRatio(
                aspectRatio: 1,
                child: ref.watch(qrTarayiciProvider)(
                  kodOkundu: (metin) => unawaited(notifier.kodOkundu(metin)),
                  izinReddedildi: notifier.izinReddedildi,
                  acilamadi: notifier.kameraAcilamadi,
                ),
              ),
            ),
          ],
          QrIsleniyor() => [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: metinler.cihaz_tara_isleniyor,
              ),
            ),
          ],
          QrGonderildi() => [
            Text(metinler.cihaz_tara_basarili, style: context.yazi.titleMedium),
            const SizedBox(height: TayfamSpacing.s16),
            BirincilEylem(
              etiket: metinler.cihaz_tamam,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
          QrKameraIzniYok() => [
            Text(
              metinler.cihaz_kamera_izin_baslik,
              style: context.yazi.titleMedium,
            ),
            const SizedBox(height: TayfamSpacing.s8),
            CihazAciklamasi(metinler.cihaz_kamera_izin_aciklama),
            const SizedBox(height: TayfamSpacing.s16),
            if (ayarlar.destekleniyor) ...[
              BirincilEylem(
                etiket: metinler.cihaz_ayarlari_ac,
                ikon: Icons.settings_outlined,
                onPressed: () => unawaited(ayarlar.ac()),
              ),
              const SizedBox(height: TayfamSpacing.s8),
              IkincilEylem(
                etiket: metinler.cihaz_tara_tekrar,
                onPressed: notifier.tekrarTara,
              ),
            ] else
              tekrar,
          ],
          QrKameraAcilamadi() => [
            HataSatiri(metin: metinler.cihaz_kamera_hatasi),
            const SizedBox(height: TayfamSpacing.s16),
            tekrar,
          ],
          QrTaramaHatasi(:final hata) => [
            HataSatiri(metin: cihazHataMetni(metinler, hata)),
            const SizedBox(height: TayfamSpacing.s16),
            tekrar,
          ],
        },
      ],
    );
  }
}
