import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfası olmayan kullanıcının Tayfa sekmesinde gördüğü karşılama ekranı
/// (ADR-0003): "Tayfa kodum var", "Tayfa oluştur" ve çok renkli tür
/// vurgusu (ADR-0004 §2a). Diğer sekmeler çalışmaya devam eder.
class KarsilamaEkrani extends StatelessWidget {
  const KarsilamaEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final yazi = context.yazi;
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
                        unawaited(context.push<void>(Adresler.tayfaKatil)),
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
