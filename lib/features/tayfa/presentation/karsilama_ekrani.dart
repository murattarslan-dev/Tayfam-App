import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfası olmayan kullanıcının Tayfa sekmesinde gördüğü karşılama ekranı
/// (ADR-0003): "Tayfa kodum var", "Tayfa oluştur" ve çok renkli tür
/// vurgusu (ADR-0004 §2a). Diğer sekmeler çalışmaya devam eder.
class KarsilamaEkrani extends StatelessWidget {
  const KarsilamaEkrani({super.key});

  /// İçeriğin en fazla genişliği; geniş ekranda okunabilir satır boyu.
  // TODO(#6): içerik genişliği tema token'ından gelecek.
  static const double _icerikGenisligi = 560;

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final yazi = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // TODO(#6): TayfamSpacing
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _icerikGenisligi),
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
                  // TODO(#6): TayfamSpacing
                  const SizedBox(height: 16),
                  const TurVurgusu(),
                  // TODO(#6): TayfamSpacing
                  const SizedBox(height: 16),
                  Text(metinler.karsilama_aciklama, style: yazi.bodyLarge),
                  // TODO(#6): TayfamSpacing
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        unawaited(context.push<void>(Adresler.tayfaKatil)),
                    child: Text(metinler.karsilama_kodum_var),
                  ),
                  // TODO(#6): TayfamSpacing
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        unawaited(context.push<void>(Adresler.tayfaOlustur)),
                    child: Text(metinler.karsilama_tayfa_olustur),
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
/// Renkler şimdilik `colorScheme`'in zemin/metin çiftlerinden sırayla
/// gelir; tema (#6) brand/nar/mango çiftlerini getirir.
// TODO(#6): TayfamColors brand/nar/mango hap renkleri ve TayfamRadii.
class TurVurgusu extends StatelessWidget {
  const TurVurgusu({super.key});

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    final renkler = Theme.of(context).colorScheme;
    final ciftler = [
      (renkler.primary, renkler.onPrimary),
      (renkler.tertiary, renkler.onTertiary),
      (renkler.secondary, renkler.onSecondary),
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
        // TODO(#6): TayfamSpacing
        spacing: 8,
        runSpacing: 8,
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
        // TODO(#6): TayfamRadii
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Padding(
        // TODO(#6): TayfamSpacing
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          metin,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: yaziRengi),
        ),
      ),
    );
  }
}
