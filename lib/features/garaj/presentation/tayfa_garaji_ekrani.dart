import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/garajim_ekrani.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/features/sikayet/sikayet.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show bildirimGoster;
import 'package:tayfam/features/tayfa/tayfa.dart' show tayfaOzetiProvider;
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın garajı (`/t/<tayfaId>/garaj`; App ADR-0033 §2, Tayfam-Api
/// ADR-0040 §4): üstte "Garajımı bu tayfada göster" anahtarı (tayfa
/// başına; varsayılanı sunucu verir), altında bu tayfada görünen araçlar,
/// en yeni önce, sayfalı. Aşağı çekince yenilenir.
///
/// Başkasının aracında "Şikâyet et"; sunucu `caller_can_remove` derse
/// "Kaldır" (moderatör, onaylı, geri alınamaz). Yetkiyi sunucu verir
/// (kesin kural 5). Modül kapalıysa sunucunun `module-disabled` hatası
/// gösterilir.
class TayfaGarajiEkrani extends ConsumerStatefulWidget {
  const TayfaGarajiEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  ConsumerState<TayfaGarajiEkrani> createState() => _TayfaGarajiEkraniState();
}

class _TayfaGarajiEkraniState extends ConsumerState<TayfaGarajiEkrani> {
  bool _ayarlaniyor = false;

  Future<void> _gorunurlukAyarla(bool gorunur) async {
    final m = AppLocalizations.of(context);
    final bildirim = ScaffoldMessenger.of(context);
    setState(() => _ayarlaniyor = true);
    try {
      await ref
          .read(garajIslemleriProvider)
          .gorunurlukAyarla(widget.tayfaId, gorunur: gorunur);
      bildirimGoster(
        bildirim,
        gorunur ? m.garaj_gorunur_yapildi : m.garaj_gizlendi,
      );
    } on Exception catch (hata) {
      if (mounted) hataBildir(context, hata);
    } finally {
      if (mounted) setState(() => _ayarlaniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final saglayici = tayfaGarajiProvider(widget.tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final gorunur = durum.hasValue && ref.read(saglayici.notifier).gorunur;
    final tayfaAdi = ref.watch(tayfaOzetiProvider(widget.tayfaId)).ad;
    return Scaffold(
      appBar: AppBar(
        title: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.garaj_ad),
              if (tayfaAdi != null)
                Text(
                  tayfaAdi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.yazi.bodySmall,
                ),
            ],
          ),
        ),
      ),
      body: TayfamYenile(
        onRefresh: _yenile,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TayfamSizes.okumaGenisligi,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s8,
                TayfamSpacing.kenarMobil,
                TayfamSpacing.s40,
              ),
              children: [
                if (liste == null && hata != null)
                  YuklemeHatasi(
                    hata: hata,
                    onTekrarDene: () => ref.invalidate(saglayici),
                  )
                else if (liste == null)
                  Center(
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.yukleniyorTamEkran,
                      etiket: m.garaj_yukleniyor,
                      gecikmeli: true,
                    ),
                  )
                else ...[
                  ListeKarti(
                    children: [
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: TayfamSpacing.s16,
                          vertical: TayfamSpacing.s4,
                        ),
                        title: Text(
                          m.garaj_bu_tayfada_goster,
                          style: context.yazi.titleMedium,
                        ),
                        subtitle: Text(
                          m.garaj_bu_tayfada_goster_aciklama,
                          style: context.yazi.bodySmall,
                        ),
                        value: gorunur,
                        onChanged: _ayarlaniyor
                            ? null
                            : (yeni) => unawaited(_gorunurlukAyarla(yeni)),
                      ),
                      MenuSatiri.kartta(
                        ikon: garajIkonu,
                        baslik: m.garaj_garajimi_duzenle,
                        sag: const SatirOku(),
                        onTap: () => unawaited(
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const GarajimEkrani(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  if (liste.ogeler.isEmpty)
                    TayfamKart(
                      child: Text(
                        m.garaj_bos_tayfa,
                        style: context.yazi.bodyMedium?.copyWith(
                          color: context.renkler.metinGovde,
                        ),
                      ),
                    )
                  else
                    ListeKarti(
                      children: [
                        for (final arac in liste.ogeler)
                          GarajAraci(
                            key: ValueKey(arac.id),
                            arac: arac,
                            sahibiGoster: true,
                            menu: _TayfaAracMenusu(
                              tayfaId: widget.tayfaId,
                              arac: arac,
                            ),
                          ),
                      ],
                    ),
                  if (liste.dahaHatasi case final dahaHatasi?) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri.hatadan(dahaHatasi),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_tekrar_dene,
                        onPressed: _dahaFazla,
                      ),
                    ),
                  ] else if (liste.dahaYukleniyor) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    Center(child: TayfamYukleniyor(etiket: m.garaj_yukleniyor)),
                  ] else if (liste.dahaVar) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Center(
                      child: BaglantiEylemi(
                        etiket: m.tayfa_ana_daha_fazla,
                        onPressed: _dahaFazla,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dahaFazla() => unawaited(
    ref.read(tayfaGarajiProvider(widget.tayfaId).notifier).dahaFazla(),
  );

  /// Listeyi yeniler; başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir.
  Future<void> _yenile() async {
    final saglayici = tayfaGarajiProvider(widget.tayfaId);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !mounted) return;
    if (ref.read(saglayici).hasValue) {
      yenilemeHatasiBildir(
        context,
        hata,
        tekrarDene: () => unawaited(_yenile()),
      );
    }
  }
}

enum _Islem { kaldir, sikayet }

/// Tayfa garajındaki bir aracın menüsü: başkasının aracında "Şikâyet et",
/// sunucu izin verirse "Kaldır". Kendi aracında menü yoktur (düzenleme
/// Garajım'dadır).
class _TayfaAracMenusu extends ConsumerStatefulWidget {
  const _TayfaAracMenusu({required this.tayfaId, required this.arac});

  final String tayfaId;
  final GarageVehicle arac;

  @override
  ConsumerState<_TayfaAracMenusu> createState() => _TayfaAracMenusuState();
}

class _TayfaAracMenusuState extends ConsumerState<_TayfaAracMenusu> {
  bool _mesgul = false;

  Future<void> _islem(_Islem islem) async {
    final m = AppLocalizations.of(context);
    switch (islem) {
      case _Islem.kaldir:
        final onay = await garajYikiciOnay(
          context,
          baslik: m.garaj_kaldir_baslik,
          metin: m.garaj_kaldir_metni,
          eylem: m.garaj_kaldir,
        );
        if (!onay || !mounted) return;
        final bildirim = ScaffoldMessenger.of(context);
        setState(() => _mesgul = true);
        try {
          await ref
              .read(garajIslemleriProvider)
              .kaldir(widget.tayfaId, widget.arac.id);
          bildirimGoster(bildirim, m.garaj_kaldirildi);
        } on Exception catch (hata) {
          if (mounted) hataBildir(context, hata);
        } finally {
          if (mounted) setState(() => _mesgul = false);
        }
      case _Islem.sikayet:
        await sikayetSayfasiniAc(
          context,
          SikayetHedefi.tayfada(
            tayfaId: widget.tayfaId,
            tur: ReportTargetType.garageVehicle,
            id: widget.arac.id,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final benim = ref.watch(kendisiMiProvider(widget.arac.ownerUserId));
    final islemler = [
      if (widget.arac.callerCanRemove) _Islem.kaldir,
      if (!benim) _Islem.sikayet,
    ];
    if (islemler.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<_Islem>(
      tooltip: m.garaj_secenekler(aracAdi(widget.arac)),
      icon: const Icon(Icons.more_vert),
      enabled: !_mesgul,
      onSelected: (islem) => unawaited(_islem(islem)),
      itemBuilder: (_) => [
        for (final islem in islemler)
          PopupMenuItem(
            value: islem,
            child: Text(switch (islem) {
              _Islem.kaldir => m.garaj_kaldir,
              _Islem.sikayet => m.garaj_sikayet_et,
            }),
          ),
      ],
    );
  }
}
