import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfası olmayan kullanıcının Tayfa sekmesinde gördüğü karşılama ekranı
/// (ADR-0003): "Tayfa kodum var", "Tayfa oluştur" ve çok renkli tür
/// vurgusu (ADR-0004 §2a). Diğer sekmeler çalışmaya devam eder.
///
/// Onay bekleyen katılma isteği varsa her biri için bir bilgi kartı
/// gösterilir; bekleyen tayfanın yalnızca adı görünür (ADR-0014 §2). Tayfa
/// listesi alınamadıysa hata ve "Tekrar dene" gösterilir.
class KarsilamaEkrani extends ConsumerWidget {
  const KarsilamaEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    final durum = ref.watch(tayfalarimProvider);
    final liste = durum.value;
    final bekleyenler = bekleyenTayfalar(liste ?? const []);
    final hata = liste == null ? durum.error : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TayfamSizes.okumaGenisligi,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      metinler.karsilama_baslik,
                      style: yazi.headlineMedium,
                    ),
                  ),
                  if (hata != null) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    HataSatiri.hatadan(hata),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => unawaited(
                          ref.read(tayfalarimProvider.notifier).yenile(),
                        ),
                        child: Text(metinler.tayfa_tekrar_dene),
                      ),
                    ),
                  ],
                  for (final bekleyen in bekleyenler) ...[
                    const SizedBox(height: TayfamSpacing.s16),
                    BekleyenIstekKarti(ad: bekleyen.name),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  const TurVurgusu(),
                  const SizedBox(height: TayfamSpacing.s16),
                  Text(
                    metinler.karsilama_aciklama,
                    style: yazi.bodyLarge?.copyWith(
                      color: context.renkler.metinGovde,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s24),
                  BirincilEylem(
                    etiket: metinler.karsilama_kodum_var,
                    ikon: Icons.vpn_key_outlined,
                    onPressed: () =>
                        unawaited(kodlaKatilmaSayfasiniAc(context)),
                  ),
                  const SizedBox(height: TayfamSpacing.s12),
                  IkincilEylem(
                    etiket: metinler.karsilama_tayfa_olustur,
                    ikon: Icons.add_circle_outline,
                    onPressed: () =>
                        unawaited(context.push<void>(Adresler.tayfaOlustur)),
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

/// Onay bekleyen katılma isteğinin bilgi kartı (ADR-0014 §2).
class BekleyenIstekKarti extends StatelessWidget {
  const BekleyenIstekKarti({super.key, required this.ad});

  /// Bekleyen tayfanın adı; boşsa genel ad gösterilir.
  final String ad;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
    return TayfamKart(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(child: Icon(Icons.hourglass_top_outlined)),
          const SizedBox(width: TayfamSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metinler.karsilama_bekleyen_baslik,
                  style: yazi.titleMedium,
                ),
                const SizedBox(height: TayfamSpacing.s4),
                Text(
                  metinler.karsilama_bekleyen_aciklama(
                    ad.isEmpty ? metinler.tayfa_adi_bilinmiyor : ad,
                  ),
                  style: yazi.bodyMedium?.copyWith(
                    color: context.renkler.metinGovde,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Etkinlik türlerinin renkli haplar içinde yazıldığı vurgu (ADR-0004 §2a;
/// yalnızca karşılama ve boş durum ekranlarında).
///
/// Haplar sırayla brand (beyaz metin), nar ve mango (ink metin) zeminlidir;
/// renkler iki temada da aynıdır.
class TurVurgusu extends StatelessWidget {
  const TurVurgusu({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final r = context.renkler;
    final ciftler = [
      (r.markaYuzey, r.markaYuzeyUstu),
      (r.nar, r.vurguUstu),
      (r.mango, r.vurguUstu),
    ];
    final turler = [
      metinler.karsilama_tur_konvoy,
      metinler.karsilama_tur_kamp,
      metinler.karsilama_tur_yuruyus,
      metinler.karsilama_tur_balik,
      metinler.karsilama_tur_oyun,
      metinler.karsilama_tur_spor,
    ];
    return Semantics(
      container: true,
      label: metinler.karsilama_turler_etiketi,
      child: Wrap(
        spacing: TayfamSpacing.s8,
        runSpacing: TayfamSpacing.s8,
        children: [
          for (var i = 0; i < turler.length; i++)
            _TurHapi(
              metin: turler[i],
              zemin: ciftler[i % ciftler.length].$1,
              yaziRengi: ciftler[i % ciftler.length].$2,
            ),
        ],
      ),
    );
  }
}

class _TurHapi extends StatelessWidget {
  const _TurHapi({
    required this.metin,
    required this.zemin,
    required this.yaziRengi,
  });

  final String metin;
  final Color zemin;
  final Color yaziRengi;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: zemin,
        borderRadius: TayfamRadii.hapKoseleri,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s12,
          vertical: TayfamSpacing.s4,
        ),
        child: Text(
          metin,
          style: context.yazi.titleMedium?.copyWith(color: yaziRengi),
        ),
      ),
    );
  }
}
