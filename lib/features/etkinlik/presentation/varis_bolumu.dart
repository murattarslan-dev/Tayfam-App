import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/varis_bildirimi.dart';
import 'package:tayfam/features/etkinlik/data/konum_servisi.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Varış bildirimi (ADR-0015 §5): pencere açıkken ve cevap "Geliyorum"
/// ise "Geldim" (yüz yüze) ya da "Katıldım" (çevrimiçi) düğmesi; katılım
/// doğrulandıysa bilgisi. Gösterilecek bir şey yoksa boş.
///
/// Konum izni yalnızca düğmeye basınca istenir. İzin reddedilirse kısa bir
/// açıklama ve ayarlara gitme seçeneği gösterilir. Hata metinleri uzaklık
/// söylemez.
class VarisBolumu extends ConsumerWidget {
  const VarisBolumu({super.key, required this.anahtar, required this.etkinlik});

  final EtkinlikAnahtari anahtar;
  final Event etkinlik;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final simdi = ref.watch(etkinlikSaatiProvider)();
    final dugme = varisDugmesiGorunur(etkinlik, simdi);
    final dogrulandi = katilimDogrulandi(etkinlik);
    if (!dugme && !dogrulandi) return const SizedBox.shrink();
    final asama = ref.watch(varisProvider(anahtar));
    final cevrimici = etkinlik.mode == EventMode.online;
    final etiket = switch (asama) {
      VarisAsamasi.konum => m.etkinlik_varis_konum_aliniyor,
      VarisAsamasi.gonderim => m.etkinlik_varis_gonderiliyor,
      null => cevrimici ? m.etkinlik_varis_katildim : m.etkinlik_varis_geldim,
    };
    return Padding(
      padding: const EdgeInsets.only(top: TayfamSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AracBasligi(metin: m.etkinlik_varis_baslik),
          const SizedBox(height: TayfamSpacing.s8),
          if (dogrulandi)
            MergeSemantics(
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: TayfamSizes.ikon,
                    color: r.metin,
                  ),
                  const SizedBox(width: TayfamSpacing.s8),
                  Expanded(
                    child: Text(
                      m.etkinlik_katilim_dogrulandi,
                      style: context.yazi.bodyLarge,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Tanıtım sayfasındaki "Buradayım": nar zemin + ink metin
            // (ADR-0004 §2a).
            OdakCercevesi(
              koseler: TayfamRadii.hapKoseleri,
              child: FilledButton.icon(
                onPressed: asama != null
                    ? null
                    : () => unawaited(_bildir(context, ref)),
                style: FilledButton.styleFrom(
                  backgroundColor: r.nar,
                  foregroundColor: r.vurguUstu,
                  minimumSize: const Size.fromHeight(TayfamSizes.dokunmaMin),
                  shape: const StadiumBorder(),
                ),
                icon: Icon(
                  cevrimici ? Icons.check_circle_outline : Icons.place,
                ),
                label: Text(etiket),
              ),
            ),
            if (!cevrimici) ...[
              const SizedBox(height: TayfamSpacing.s8),
              AracBilgisi(metin: m.etkinlik_varis_konum_notu),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _bildir(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(varisProvider(anahtar).notifier);
    final sonuc = await notifier.bildir();
    if (!context.mounted) return;
    final m = AppLocalizations.of(context);
    switch (sonuc) {
      case null:
        return;
      case VarisBasarili():
        aracBildir(context, m.etkinlik_varis_basarili);
      case VarisHatasi(:final hata):
        hataBildir(context, hata);
      case VarisKonumEngeli(:final neden):
        if (neden is KonumAlinamadi || neden is KonumAlindi) {
          aracBildir(context, m.etkinlik_konum_alinamadi);
          return;
        }
        final ayarlar = await _engelDiyalogu(context, neden);
        if (!ayarlar || !context.mounted) return;
        final acildi = await notifier.ayarlariAc(neden);
        if (!acildi && context.mounted) {
          aracBildir(context, m.etkinlik_ayarlar_acilamadi);
        }
    }
  }
}

/// Konum engelinin açıklaması; "Ayarlara git"e basılırsa `true`.
Future<bool> _engelDiyalogu(BuildContext context, KonumSonucu neden) async {
  final m = AppLocalizations.of(context);
  final (baslik, metin) = switch (neden) {
    KonumServisiKapali() => (
      m.etkinlik_konum_kapali_baslik,
      m.etkinlik_konum_kapali_metni,
    ),
    KonumYaklasik() => (
      m.etkinlik_konum_hassas_baslik,
      m.etkinlik_konum_hassas_metni,
    ),
    KonumIzniYok() || KonumAlinamadi() || KonumAlindi() => (
      m.etkinlik_konum_izni_baslik,
      m.etkinlik_konum_izni_metni,
    ),
  };
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (pencere) => AlertDialog(
      title: Text(baslik),
      scrollable: true,
      content: Text(metin),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(false),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_vazgec),
        ),
        TextButton(
          onPressed: () => Navigator.of(pencere).pop(true),
          style: TextButton.styleFrom(
            minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          ),
          child: Text(m.etkinlik_ayarlara_git),
        ),
      ],
    ),
  );
  return sonuc ?? false;
}
