import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/eylem_icerigi.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_avatari.dart';
import 'package:tayfam/features/tayfa/presentation/tayfa_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Tayfa kuruldu" ekranı (ADR-0014 Notlar 2026-11-13; tasarım:
/// Tayfa-Kur-Hazir): oluşturma başarılı olunca sihirbazın yerine açılır.
///
/// - Mor zeminde logo, tayfa avatarı, "<ad> kuruldu!" ve ilk 7 günde 3 üye
///   hedefi; tayfa kodu ve "Kopyala".
/// - Birincil "Davet linkini paylaş": mevcut davet linki akışı
///   (`tayfaDaveti`; varsayılan 7 gün / 10 kişi, link bir kez gösterilir,
///   token loglanmaz ve diske yazılmaz, kesin kural 9).
/// - İkincil "Tayfaya git": ana sayfa, "Tayfanı birlikte kuralım"
///   adımlarıyla. Sistem geri tuşu da ana sayfaya gider; sihirbaza
///   dönülmez.
///
/// Ekran yalnızca oluşturma yanıtındaki [tayfa] ile çizilir, ek istek
/// yapmaz. Kod yalnızca yöneticiye döner; yoksa kod kartı gösterilmez.
class TayfaKurulduEkrani extends ConsumerWidget {
  const TayfaKurulduEkrani({super.key, required this.tayfa});

  /// `POST /v1/tayfas` yanıtındaki tayfa.
  final Tayfa tayfa;

  void _tayfayaGit(BuildContext context) => context.go(
    uuidBicimindeMi(tayfa.id) ? Adresler.tayfa(tayfa.id) : Adresler.kok,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final davet = ref.watch(tayfaDavetiProvider);
    final kod = tayfa.joinCode;
    final beyaz = r.markaYuzeyUstu;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (!geriDonuldu) _tayfayaGit(context);
      },
      child: Scaffold(
        backgroundColor: r.markaYuzey,
        body: MarkaYuzeyi(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: TayfamSizes.okumaGenisligi,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          TayfamSpacing.s20,
                          TayfamSpacing.s56,
                          TayfamSpacing.s20,
                          TayfamSpacing.s24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: ExcludeSemantics(
                                child: TayfamLogo(
                                  boyut: TayfamSizes.kurulduLogosu,
                                  zemin: r.markaYuzey,
                                ),
                              ),
                            ),
                            const SizedBox(height: TayfamSpacing.s24),
                            Center(
                              child: TayfaAvatari(
                                ad: tayfa.name,
                                ilgiAlanlari: tayfa.interests,
                                cap: TayfamSizes.avatarBuyuk,
                                harfStili: yazi.displaySmall,
                              ),
                            ),
                            const SizedBox(height: TayfamSpacing.s16),
                            Semantics(
                              header: true,
                              child: Text(
                                m.kuruldu_baslik(tayfa.name),
                                textAlign: TextAlign.center,
                                style: yazi.headlineMedium?.copyWith(
                                  color: beyaz,
                                  fontWeight:
                                      TayfamTypography.buyukBaslikAgirligi,
                                ),
                              ),
                            ),
                            const SizedBox(height: TayfamSpacing.s12),
                            Text(
                              m.kuruldu_aciklama,
                              textAlign: TextAlign.center,
                              style: yazi.bodyLarge?.copyWith(color: beyaz),
                            ),
                            if (kod != null && kod.isNotEmpty) ...[
                              const SizedBox(height: TayfamSpacing.s24),
                              _KodKarti(kod: kod),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TayfamSpacing.s20,
                        TayfamSpacing.s12,
                        TayfamSpacing.s20,
                        TayfamSpacing.s24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (davet != null) ...[
                            BirincilEylem(
                              etiket: m.kuruldu_davet,
                              ikon: Icons.share_outlined,
                              markaYuzeyinde: true,
                              onPressed: () =>
                                  unawaited(davet(context, tayfa.id)),
                            ),
                            const SizedBox(height: TayfamSpacing.s12),
                          ],
                          _BeyazCerceveliEylem(
                            etiket: m.kuruldu_tayfaya_git,
                            onPressed: () => _tayfayaGit(context),
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
      ),
    );
  }
}

/// Tayfa kodu kartı (tasarım: Tayfa-Kur-Hazir): mor yüzeyin katmanında
/// "Tayfa kodu", aralıklı kod ve beyaz çerçeveli "Kopyala". Büyük yazıda
/// düğme kodun altına iner.
class _KodKarti extends ConsumerWidget {
  const _KodKarti({required this.kod});

  final String kod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final kodStili = context.yazi.headlineMedium ?? const TextStyle();
    final harfAraligi =
        (kodStili.fontSize ?? 0) * TayfamSizes.kodHarfAraligiOrani;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.markaYuzeyKatmani,
        borderRadius: TayfamRadii.kartKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                m.kuruldu_kod_baslik,
                style: context.yazi.titleSmall?.copyWith(
                  color: r.markaYuzeyUstu,
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: TayfamSpacing.s12,
              runSpacing: TayfamSpacing.s8,
              children: [
                Text(
                  kod,
                  style: kodStili.copyWith(
                    color: r.markaYuzeyUstu,
                    fontWeight: TayfamTypography.buyukBaslikAgirligi,
                    letterSpacing: harfAraligi,
                  ),
                ),
                _BeyazCerceveliEylem(
                  etiket: m.kuruldu_kopyala,
                  ikon: Icons.copy_outlined,
                  onPressed: () =>
                      unawaited(koduKopyala(context, ref, kod: kod)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Mor yüzeyde beyaz çerçeveli hap düğme ("Tayfaya git", "Kopyala").
class _BeyazCerceveliEylem extends StatelessWidget {
  const _BeyazCerceveliEylem({
    required this.etiket,
    required this.onPressed,
    this.ikon,
  });

  final String etiket;
  final VoidCallback? onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return OdakCercevesi(
      koseler: TayfamRadii.hapKoseleri,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: r.markaYuzeyUstu,
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TayfamSpacing.s16,
            vertical: TayfamSpacing.s12,
          ),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: r.markaYuzeyUstu,
            width: TayfamSizes.vurguKenari,
          ),
          textStyle: context.yazi.labelLarge,
        ),
        child: EylemIcerigi(etiket: etiket, ikon: ikon),
      ),
    );
  }
}
