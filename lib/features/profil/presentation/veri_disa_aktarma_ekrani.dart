import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/profil/application/veri_disa_aktarma_notifier.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_bicimi.dart';
import 'package:tayfam/features/profil/presentation/profil_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// [hata]'nın veri dışa aktarma ekranındaki metni. Problem `type`'ları
/// (`data-export-*`, `reauthentication-required`, `unavailable`) ortak
/// eşlemeden gelir; `title` / `detail` gösterilmez.
String disaAktarmaHatasiMetni(AppLocalizations m, Object hata) =>
    switch (hata) {
      DisaAktarmaHatasi(:final tur) => switch (tur) {
        DisaAktarmaHataTuru.bicim => m.disa_aktarma_hata_bicim,
        DisaAktarmaHataTuru.indirilemedi => m.disa_aktarma_hata_indirilemedi,
        DisaAktarmaHataTuru.cozulemedi => m.disa_aktarma_hata_cozulemedi,
        DisaAktarmaHataTuru.desteklenmiyor =>
          m.disa_aktarma_hata_desteklenmiyor,
      },
      _ => profilHatasiMetni(m, hata),
    };

/// "Verilerimi indir" (KVKK veri dışa aktarma; ADR-0022): neyin
/// hazırlandığı, talep düğmesi ya da bir sonraki talep tarihi, son 30
/// günün talepleri ve hazır olanın "İndir" düğmesi. `data_export_ready`
/// bildirimine dokununca da bu ekran açılır.
class VeriDisaAktarmaEkrani extends ConsumerWidget {
  const VeriDisaAktarmaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final eylem = ref.watch(disaAktarmaEylemProvider);
    final hata = eylem.hata;
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinIkincil,
    );
    return Scaffold(
      appBar: AppBar(title: Text(metinler.disa_aktarma_baslik)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(disaAktarmaListesiProvider.notifier).yenile(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TayfamSizes.okumaGenisligi,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      metinler.disa_aktarma_giris,
                      style: context.yazi.bodyLarge,
                    ),
                    const SizedBox(height: TayfamSpacing.s12),
                    Text(metinler.disa_aktarma_birebir_notu, style: ikincil),
                    const SizedBox(height: TayfamSpacing.s8),
                    Text(metinler.disa_aktarma_dosya_notu, style: ikincil),
                    if (hata != null) ...[
                      const SizedBox(height: TayfamSpacing.s16),
                      HataSatiri(metin: disaAktarmaHatasiMetni(metinler, hata)),
                    ],
                    const SizedBox(height: TayfamSpacing.s24),
                    const _TalepBolumu(),
                    const SizedBox(height: TayfamSpacing.s24),
                    BolumBasligi(baslik: metinler.disa_aktarma_talepler_baslik),
                    const SizedBox(height: TayfamSpacing.s8),
                    const _TalepListesi(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Talep düğmesi; süren talep ya da 30 günlük sınır varsa yerine açıklama.
/// Karar sunucudadır (kesin kural 5): düğme gizlense de sunucu
/// `data-export-in-progress` / `data-export-limit` döner.
class _TalepBolumu extends ConsumerWidget {
  const _TalepBolumu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final liste = ref.watch(disaAktarmaListesiProvider).value;
    final eylem = ref.watch(disaAktarmaEylemProvider);
    if (liste == null) return const SizedBox.shrink();
    if (eylem.islem == DisaAktarmaIslemi.talep) {
      return SizedBox(
        height: TayfamSizes.dokunmaMin,
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: metinler.disa_aktarma_talep_suruyor,
          ),
        ),
      );
    }
    if (liste.suruyor) {
      return Text(
        metinler.disa_aktarma_hazirlaniyor,
        style: context.yazi.bodyMedium,
      );
    }
    final sonraki = liste.sonrakiTalep;
    if (sonraki != null && sonraki.isAfter(ref.watch(simdiProvider)())) {
      return Text(
        metinler.disa_aktarma_sonraki_talep(_zaman(metinler, sonraki)),
        style: context.yazi.bodyMedium,
      );
    }
    return BirincilEylem(
      etiket: metinler.disa_aktarma_talep_et,
      ikon: Icons.inventory_2_outlined,
      onPressed: eylem.suruyor
          ? null
          : () => unawaited(
              ref.read(disaAktarmaEylemProvider.notifier).talepAc(),
            ),
    );
  }
}

class _TalepListesi extends ConsumerWidget {
  const _TalepListesi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    switch (ref.watch(disaAktarmaListesiProvider)) {
      case AsyncData(:final value) when value.talepler.isEmpty:
        return Text(
          metinler.disa_aktarma_bos,
          style: context.yazi.bodyMedium?.copyWith(
            color: context.renkler.metinIkincil,
          ),
        );
      case AsyncData(:final value):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final talep in value.talepler) ...[
              _TalepKarti(talep: talep),
              const SizedBox(height: TayfamSpacing.s12),
            ],
          ],
        );
      case AsyncError(:final error):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri(metin: disaAktarmaHatasiMetni(metinler, error)),
            const SizedBox(height: TayfamSpacing.s8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => ref.invalidate(disaAktarmaListesiProvider),
                child: Text(metinler.disa_aktarma_tekrar_dene),
              ),
            ),
          ],
        );
      case AsyncLoading():
        return Center(
          child: CircularProgressIndicator(
            semanticsLabel: metinler.disa_aktarma_yukleniyor,
          ),
        );
    }
  }
}

/// Tek talep: durum, zamanlar, boyut, başarısızlık sebebi ve "İndir".
class _TalepKarti extends ConsumerWidget {
  const _TalepKarti({required this.talep});

  final DataExport talep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final eylem = ref.watch(disaAktarmaEylemProvider);
    final ikincil = context.yazi.bodyMedium?.copyWith(
      color: context.renkler.metinIkincil,
    );
    final sonGun = talep.expiresAt;
    final indirildi = talep.downloadedAt;
    final boyut = talep.sizeBytes;
    final hazir = talep.status == DataExportStatus.ready;
    final indiriliyor =
        eylem.islem == DisaAktarmaIslemi.indirme && eylem.talepId == talep.id;
    return TayfamKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Etiket(metin: _durumAdi(metinler, talep.status)),
          ),
          const SizedBox(height: TayfamSpacing.s8),
          Text(
            metinler.disa_aktarma_talep_zamani(
              _zaman(metinler, talep.requestedAt),
            ),
            style: context.yazi.bodyMedium,
          ),
          if (hazir && sonGun != null)
            Text(
              metinler.disa_aktarma_son_gun(_zaman(metinler, sonGun)),
              style: ikincil,
            ),
          if (indirildi != null)
            Text(
              metinler.disa_aktarma_indirildi(_zaman(metinler, indirildi)),
              style: ikincil,
            ),
          if (hazir && boyut != null)
            Text(_boyut(metinler, boyut), style: ikincil),
          if (talep.status == DataExportStatus.failed) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(_sebep(metinler, talep.failureReason), style: ikincil),
          ],
          if (hazir) ...[
            const SizedBox(height: TayfamSpacing.s12),
            if (indiriliyor)
              SizedBox(
                height: TayfamSizes.dokunmaMin,
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: metinler.disa_aktarma_indiriliyor,
                  ),
                ),
              )
            else
              Builder(
                builder: (dugme) => BirincilEylem(
                  etiket: metinler.disa_aktarma_indir,
                  ikon: Icons.download_outlined,
                  onPressed: eylem.suruyor
                      ? null
                      : () => unawaited(
                          ref
                              .read(disaAktarmaEylemProvider.notifier)
                              .indir(talep, konum: _konum(dugme)),
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// [dugme]'nin ekrandaki yeri (iPad'de paylaşım menüsü için).
Rect? _konum(BuildContext dugme) {
  final kutu = dugme.findRenderObject();
  return kutu is RenderBox && kutu.hasSize
      ? kutu.localToGlobal(Offset.zero) & kutu.size
      : null;
}

String _zaman(AppLocalizations m, DateTime an) =>
    DateFormat.yMMMd(m.localeName).add_Hm().format(an.toLocal());

String _boyut(AppLocalizations m, int bayt) {
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bayt < mb) {
    final sayi = NumberFormat.decimalPattern(m.localeName);
    return m.disa_aktarma_boyut_kb(sayi.format((bayt / kb).ceil()));
  }
  final sayi = NumberFormat.decimalPatternDigits(
    locale: m.localeName,
    decimalDigits: 1,
  );
  return m.disa_aktarma_boyut_mb(sayi.format(bayt / mb));
}

String _durumAdi(AppLocalizations m, DataExportStatus durum) => switch (durum) {
  DataExportStatus.pending => m.disa_aktarma_durum_bekliyor,
  DataExportStatus.processing => m.disa_aktarma_durum_hazirlaniyor,
  DataExportStatus.ready => m.disa_aktarma_durum_hazir,
  DataExportStatus.expired => m.disa_aktarma_durum_suresi_doldu,
  DataExportStatus.failed => m.disa_aktarma_durum_basarisiz,
  DataExportStatus.unknown => m.disa_aktarma_durum_bilinmiyor,
};

String _sebep(AppLocalizations m, DataExportFailureReason? sebep) =>
    switch (sebep) {
      DataExportFailureReason.unavailable =>
        m.disa_aktarma_basarisiz_unavailable,
      DataExportFailureReason.tooLarge => m.disa_aktarma_basarisiz_too_large,
      DataExportFailureReason.timeout => m.disa_aktarma_basarisiz_timeout,
      DataExportFailureReason.failed ||
      DataExportFailureReason.unknown ||
      null => m.disa_aktarma_basarisiz_genel,
    };
