import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Profil → Hesap bölümündeki cihaz bağlama girişi. Eşleştirilmiş cihazda
/// "Cihaz bağla" (QR okut), eşleştirilmemiş ve hesabın eşleştirilmiş başka
/// cihazı varsa "Bu cihazı bağla" (QR göster). E2E yoksa hiçbir şey
/// göstermez.
class CihazBaglamaGirisi extends ConsumerWidget {
  const CihazBaglamaGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final bilgi = ref.watch(gecmisCihazBilgisiProvider);
    if (bilgi == null) return const SizedBox.shrink();
    if (bilgi.eslestirilmis) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.qr_code_scanner),
        title: Text(metinler.cihaz_bagla_baslik),
        subtitle: Text(metinler.cihaz_bagla_aciklama),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(Adresler.cihazBagla),
      );
    }
    if (!bilgi.baskaEslestirilmisVar) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.qr_code_2),
      title: Text(metinler.cihaz_bu_cihazi_bagla_baslik),
      subtitle: Text(metinler.cihaz_bu_cihazi_bagla_aciklama),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(Adresler.buCihaziBagla),
    );
  }
}

/// Çıkış onayına eklenen uyarının metni: bu telefon geçmiş anahtarını
/// taşıyan tek cihazsa, değilse `null` (araştırma §3.11).
String? tekCihazCikisUyarisi(BuildContext context, WidgetRef ref) =>
    ref.read(tekCihazUyarisiProvider)
    ? AppLocalizations.of(context).cihaz_cikis_tek_cihaz_uyarisi
    : null;

/// Çıkış onayı: tek cihaz uyarısı gerekiyorsa uyarıyla onay penceresi
/// gösterir ve sonucu döner; gerekmiyorsa sormadan `true` döner (mevcut
/// çıkış davranışı değişmez).
Future<bool> tekCihazCikisOnayi(BuildContext context, WidgetRef ref) async {
  final uyari = tekCihazCikisUyarisi(context, ref);
  if (uyari == null) return true;
  final metinler = AppLocalizations.of(context);
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(metinler.cihaz_cikis_onay_baslik),
      content: SingleChildScrollView(child: Text(uyari)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          child: Text(metinler.cihaz_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          child: Text(metinler.cihaz_cikis_yap),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}

/// İlk E2E açılışında bir kez gösterilen "mesaj geçmişin yalnızca bu
/// telefonda" bilgi kartı. Kapatılınca bir daha gösterilmez.
class TekCihazBilgiKarti extends ConsumerWidget {
  const TekCihazBilgiKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goster = ref.watch(tekCihazBilgisiProvider).value ?? false;
    if (!goster) return const SizedBox.shrink();
    final metinler = AppLocalizations.of(context);
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            metinler.cihaz_tek_cihaz_bilgi_baslik,
            style: context.yazi.titleMedium,
          ),
          const SizedBox(height: TayfamSpacing.s8),
          CihazAciklamasi(metinler.cihaz_tek_cihaz_bilgi),
          const SizedBox(height: TayfamSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => unawaited(
                ref.read(tekCihazBilgisiProvider.notifier).goruldu(),
              ),
              child: Text(metinler.cihaz_anladim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yeni geçmiş anahtarı alındığında (hesabın önceki bir anahtarı vardı)
/// bir kez gösterilen bilgi: eski şifreli mesajlar bu cihazda okunamaz.
class EskiArsivBilgisi extends ConsumerWidget {
  const EskiArsivBilgisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goster = ref.watch(
      gecmisYoneticisiProvider.select((d) => d.eskiArsivOkunamaz),
    );
    if (!goster) return const SizedBox.shrink();
    final metinler = AppLocalizations.of(context);
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CihazAciklamasi(metinler.cihaz_eski_arsiv_okunamaz),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: ref
                  .read(gecmisYoneticisiProvider.notifier)
                  .eskiArsivBilgisiGoruldu,
              child: Text(metinler.cihaz_anladim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konuşmanın başında, eski mesajlar bu cihazda okunamıyorsa gösterilen
/// boş durum satırı. Bu cihaz QR ile eşleşebilirse "Bu cihazı bağla"
/// önerilir.
class EskiMesajlarOkunamiyor extends ConsumerWidget {
  const EskiMesajlarOkunamiyor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final eslestirilebilir = ref.watch(qrOnerisiProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock_clock_outlined,
              size: TayfamSizes.ikon,
              color: context.renkler.metinIkincil,
            ),
            const SizedBox(width: TayfamSpacing.s8),
            Expanded(
              child: CihazAciklamasi(metinler.cihaz_eski_mesajlar_okunamiyor),
            ),
          ],
        ),
        if (eslestirilebilir)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => context.go(Adresler.buCihaziBagla),
              child: Text(metinler.cihaz_eski_mesajlar_eslestir),
            ),
          ),
      ],
    );
  }
}
