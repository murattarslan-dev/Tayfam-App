import 'dart:async';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/bildirim/application/bildirim_gruplari.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/sekme_durumu.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Okunmamış güvenlik uyarısı (`hike_overdue`; 2026-11-13 tasarım:
/// Bildirimler, karar 3): listenin en üstünde sabit nar kart. Kişinin adı,
/// etkinliğin adı, tayfa ve zaman; "Yoklamayı aç" etkinliği açar.
/// Okununca kart kalkar, bildirim listedeki yerine döner.
///
/// Ekran okuyucu kartı uyarı olarak duyurur (`liveRegion`); kartın tamamı
/// tek düğmedir.
class GuvenlikUyarisiKarti extends ConsumerWidget {
  const GuvenlikUyarisiKarti({
    super.key,
    required this.bildirim,
    required this.simdi,
    required this.onTap,
  });

  final Notification bildirim;
  final DateTime simdi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final kisi = bildirimKisiAdi(context, ref, bildirim);
    final tayfaId = bildirim.tayfaId;
    final tayfaAdi = tayfaId == null
        ? m.tayfa_adi_bilinmiyor
        : ref.watch(tayfaAdiProvider(tayfaId)) ?? m.tayfa_adi_bilinmiyor;
    final etkinlik = uyariEtkinligi(bildirim);
    final etkinlikAdi = etkinlik == null
        ? null
        : ref.watch(uyariEtkinligiProvider(etkinlik)).value;
    final zaman = bildirimZamani(m, bildirim.createdAt, simdi);
    final ayrinti = etkinlikAdi == null || etkinlikAdi.isEmpty
        ? m.bildirim_uyari_ayrinti_kisa(tayfaAdi, zaman)
        : m.bildirim_uyari_ayrinti(etkinlikAdi, tayfaAdi, zaman);
    const koseler = TayfamRadii.kartKoseleri;

    return Semantics(
      container: true,
      liveRegion: true,
      button: true,
      child: OdakCercevesi(
        koseler: koseler,
        child: Material(
          color: r.tintNar,
          shape: RoundedRectangleBorder(
            borderRadius: koseler,
            side: BorderSide(color: r.narMetin, width: TayfamSizes.vurguKenari),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(TayfamSpacing.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: TayfamSizes.ikonKutusuIkonu,
                      color: r.narMetin,
                    ),
                  ),
                  const SizedBox(width: TayfamSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.bildirim_yuruyus_donmedi(kisi),
                          style: yazi.titleMedium?.copyWith(
                            color: r.narMetin,
                            fontWeight: TayfamTypography.buyukBaslikAgirligi,
                          ),
                        ),
                        const SizedBox(height: TayfamSpacing.s4),
                        Text(
                          ayrinti,
                          style: yazi.bodySmall?.copyWith(color: r.metin),
                        ),
                        const SizedBox(height: TayfamSpacing.s8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: m.bildirim_yoklamayi_ac),
                              const WidgetSpan(
                                child: SizedBox(width: TayfamSpacing.s4),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: ExcludeSemantics(
                                  child: Icon(
                                    Icons.chevron_right,
                                    size: TayfamSizes.ikonKucuk,
                                    color: r.narMetin,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: yazi.labelLarge?.copyWith(color: r.narMetin),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bildirim izni verilmemişken listenin üstündeki mor kart (karar 5):
/// mevcut açıklama kartının metinleri ve düğmeleri. "İzin ver" sistem
/// penceresini açar; "Şimdi değil" mevcut erteleme kuralıdır (kart bir
/// daha kendiliğinden çıkmaz).
class IzinKarti extends ConsumerWidget {
  const IzinKarti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final izin = ref.read(bildirimIzniProvider.notifier);
    final kart = ref.read(izinKartiProvider.notifier);
    return Semantics(
      container: true,
      child: ClipRRect(
        borderRadius: TayfamRadii.kartKoseleri,
        child: MarkaYuzeyi(
          child: Padding(
            padding: const EdgeInsets.all(TayfamSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.notifications_none,
                        size: TayfamSizes.ikon,
                        color: r.markaYuzeyUstu,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.bildirim_izni_baslik,
                            style: context.yazi.titleMedium?.copyWith(
                              color: r.markaYuzeyUstu,
                            ),
                          ),
                          const SizedBox(height: TayfamSpacing.s4),
                          Text(
                            m.bildirim_izni_aciklama,
                            style: context.yazi.bodySmall?.copyWith(
                              color: r.markaYuzeyUstu,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TayfamSpacing.s12),
                Wrap(
                  spacing: TayfamSpacing.s8,
                  runSpacing: TayfamSpacing.s8,
                  children: [
                    BirincilEylem(
                      etiket: m.bildirim_izni_ver,
                      markaYuzeyinde: true,
                      onPressed: () {
                        kart.kapat();
                        unawaited(izin.aciklamayiKabulEt());
                      },
                    ),
                    BaglantiEylemi(
                      etiket: m.bildirim_izni_simdi_degil,
                      renk: r.markaYuzeyUstu,
                      onPressed: () {
                        kart.kapat();
                        unawaited(izin.aciklamayiReddet());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hiç bildirim yokken (karar 7): logo, "Henüz bildirimin yok." ve
/// açıklama.
class BosBildirimler extends StatelessWidget {
  const BosBildirimler({super.key});

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TayfamSpacing.s16,
        vertical: TayfamSpacing.s64,
      ),
      child: Column(
        children: [
          const TayfamLogo(boyut: TayfamSizes.logoBuyuk),
          const SizedBox(height: TayfamSpacing.s16),
          Semantics(
            header: true,
            child: Text(
              m.bildirim_bos,
              textAlign: TextAlign.center,
              style: context.yazi.titleLarge,
            ),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            m.bildirim_bos_aciklama,
            textAlign: TextAlign.center,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
        ],
      ),
    );
  }
}
