import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// "Etkinlik açıldı" (ADR-0026; tasarım: `docs/tasarim/29` §3): anlık
/// etkinlik oluşturulunca sihirbazın yerine açılır. "Tayfa kuruldu"
/// ekranının (Tayfa-Kur-Hazir) iskeletidir.
///
/// - Mor zeminde logo, etkinlik türü çipi, "`<başlık>` hazır!" ve davet
///   edilen arkadaş sayısına göre açıklama.
/// - Birincil "Davet linkini paylaş": mevcut davet linki akışı
///   (`tayfaDaveti`; link bir kez gösterilir, token loglanmaz ve diske
///   yazılmaz, kesin kural 9). Akış kayıtlı değilse gösterilmez.
/// - İkincil "Etkinliğe git". Sistem geri tuşu da etkinliğe gider;
///   sihirbaza dönülmez.
///
/// Ekran yalnızca oluşturma yanıtıyla ([sonuc]) çizilir; ek istek yapmaz.
/// Tayfa kodu gösterilmez: anlık tayfada kodla katılım yoktur.
class AnlikAcildiEkrani extends ConsumerWidget {
  const AnlikAcildiEkrani({
    super.key,
    required this.sonuc,
    required this.davetliSayisi,
  });

  /// `POST /v1/instant-events` yanıtı.
  final InstantEvent sonuc;

  /// Doğrudan davet edilen arkadaş sayısı.
  final int davetliSayisi;

  void _etkinligeGit(BuildContext context) {
    final tayfaId = sonuc.tayfa.id;
    final etkinlikId = sonuc.event.id;
    context.go(
      uuidBicimindeMi(tayfaId) && uuidBicimindeMi(etkinlikId)
          ? Adresler.etkinlik(tayfaId, etkinlikId)
          : Adresler.kok,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final davet = ref.watch(tayfaDavetiProvider);
    final beyaz = r.markaYuzeyUstu;
    final etkinlik = sonuc.event;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (geriDonuldu, _) {
        if (!geriDonuldu) _etkinligeGit(context);
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
                            Center(child: EtkinlikTuruCipi(tur: etkinlik.type)),
                            const SizedBox(height: TayfamSpacing.s16),
                            Semantics(
                              header: true,
                              child: Text(
                                m.anlik_acildi_baslik(etkinlik.title),
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
                              davetliSayisi > 0
                                  ? m.anlik_acildi_davetli(davetliSayisi)
                                  : m.anlik_acildi_davetsiz,
                              textAlign: TextAlign.center,
                              style: yazi.bodyLarge?.copyWith(color: beyaz),
                            ),
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
                                  unawaited(davet(context, sonuc.tayfa.id)),
                            ),
                            const SizedBox(height: TayfamSpacing.s12),
                          ],
                          BeyazCerceveliEylem(
                            etiket: m.anlik_acildi_git,
                            onPressed: () => _etkinligeGit(context),
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
