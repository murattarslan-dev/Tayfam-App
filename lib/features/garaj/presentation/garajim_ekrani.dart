import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart' show bildirimGoster;
import 'package:tayfam/l10n/app_localizations.dart';

/// Profildeki "Garajım" (`/profil/garaj`; App ADR-0033 §2, Tayfam-Api
/// ADR-0040 §4): kişinin tek garajı, eklenme sırasıyla; en çok 10 araç.
/// Her aracın menüsünde "Düzenle" ve "Sil" (onaylı, geri alınamaz).
/// "Araç ekle" sunucu `caller_can_add` derse görünür.
///
/// Garajın hangi tayfada görüneceği tayfanın garaj sayfasından seçilir;
/// burada yalnızca kural anlatılır.
class GarajimEkrani extends ConsumerWidget {
  const GarajimEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final durum = ref.watch(garajimProvider);
    final garaj = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(m.garaj_garajim)),
      floatingActionButton: garaj?.callerCanAdd ?? false
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(garajFormunuAc(context)),
              icon: const Icon(Icons.add),
              label: Text(m.garaj_arac_ekle),
            )
          : null,
      body: TayfamYenile(
        onRefresh: () => _yenile(ref),
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
                // Alttaki "Araç ekle" düğmesi son aracı örtmesin.
                TayfamSpacing.s64 + TayfamSpacing.s40,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.visibility_outlined,
                        size: TayfamSizes.ikon,
                        color: r.metinIkincil,
                      ),
                    ),
                    const SizedBox(width: TayfamSpacing.s8),
                    Expanded(
                      child: Text(
                        m.garaj_gorunurluk_kurali,
                        style: context.yazi.bodySmall?.copyWith(
                          color: r.metinGovde,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TayfamSpacing.s16),
                if (garaj == null && hata != null)
                  YuklemeHatasi(
                    hata: hata,
                    onTekrarDene: () => ref.invalidate(garajimProvider),
                  )
                else if (garaj == null)
                  Center(
                    child: TayfamYukleniyor(
                      boyut: TayfamSizes.yukleniyorTamEkran,
                      etiket: m.garaj_yukleniyor,
                      gecikmeli: true,
                    ),
                  )
                else if (garaj.vehicles.isEmpty)
                  TayfamKart(
                    child: Text(
                      m.garaj_bos_kendi,
                      style: context.yazi.bodyMedium?.copyWith(
                        color: r.metinGovde,
                      ),
                    ),
                  )
                else ...[
                  ListeKarti(
                    children: [
                      for (final arac in garaj.vehicles)
                        GarajAraci(
                          key: ValueKey(arac.id),
                          arac: arac,
                          menu: arac.callerCanEdit
                              ? _AracMenusu(arac: arac)
                              : null,
                        ),
                    ],
                  ),
                  if (!garaj.callerCanAdd) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    Text(
                      m.garaj_sinir(garajEnCok),
                      style: context.yazi.bodySmall?.copyWith(
                        color: r.metinIkincil,
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
}

/// Garajı yeniden okur; hata ekranda gösterilir, yenileme göstergesi
/// yine kapanır.
Future<void> _yenile(WidgetRef ref) async {
  ref.invalidate(garajimProvider);
  try {
    await ref.read(garajimProvider.future);
  } on Exception {
    return;
  }
}

enum _Islem { duzenle, sil }

/// Kendi aracının menüsü: "Düzenle" ve "Sil".
class _AracMenusu extends ConsumerStatefulWidget {
  const _AracMenusu({required this.arac});

  final GarageVehicle arac;

  @override
  ConsumerState<_AracMenusu> createState() => _AracMenusuState();
}

class _AracMenusuState extends ConsumerState<_AracMenusu> {
  bool _mesgul = false;

  Future<void> _islem(_Islem islem) async {
    final m = AppLocalizations.of(context);
    switch (islem) {
      case _Islem.duzenle:
        await garajFormunuAc(context, duzenlenen: widget.arac);
      case _Islem.sil:
        final onay = await garajYikiciOnay(
          context,
          baslik: m.garaj_sil_baslik,
          metin: m.garaj_sil_metni,
          eylem: m.garaj_sil,
        );
        if (!onay || !mounted) return;
        final bildirim = ScaffoldMessenger.of(context);
        setState(() => _mesgul = true);
        try {
          await ref.read(garajIslemleriProvider).sil(widget.arac.id);
          bildirimGoster(bildirim, m.garaj_silindi);
        } on Exception catch (hata) {
          if (mounted) hataBildir(context, hata);
        } finally {
          if (mounted) setState(() => _mesgul = false);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    return PopupMenuButton<_Islem>(
      tooltip: m.garaj_secenekler(aracAdi(widget.arac)),
      icon: const Icon(Icons.more_vert),
      enabled: !_mesgul,
      onSelected: (islem) => unawaited(_islem(islem)),
      itemBuilder: (_) => [
        PopupMenuItem(value: _Islem.duzenle, child: Text(m.garaj_duzenle)),
        PopupMenuItem(value: _Islem.sil, child: Text(m.garaj_sil)),
      ],
    );
  }
}

/// Profildeki "Garajım" girişi: araç sayısıyla; dokununca Garajım açılır.
/// Garaj okunamazsa sayı gösterilmez, giriş yine çalışır.
class GarajGirisi extends ConsumerWidget {
  const GarajGirisi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final sayi = ref.watch(garajimProvider).value?.vehicles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(baslik: m.garaj_bolum),
        ListeKarti(
          children: [
            MenuSatiri.kartta(
              ikon: garajIkonu,
              baslik: m.garaj_garajim,
              aciklama: switch (sayi) {
                null => null,
                0 => m.garaj_bos_kisa,
                final int n => m.garaj_arac_sayisi(n),
              },
              sag: const SatirOku(),
              onTap: () => unawaited(context.push(Adresler.garajim)),
            ),
          ],
        ),
      ],
    );
  }
}
