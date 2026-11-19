import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kataloğa ihtiyaç duyan bir bölümü katalog gelince çizer (ADR-0024 §1):
/// açılınca katalog elde yoksa okutur; gelene kadar yükleniyor durumu,
/// okunamazsa hata ve "Tekrar dene" gösterir. Katalog eldeyse doğrudan
/// [builder] çizilir.
class KatalogBekleyici extends ConsumerStatefulWidget {
  const KatalogBekleyici({super.key, required this.builder});

  final Widget Function(BuildContext context, Katalog katalog) builder;

  @override
  ConsumerState<KatalogBekleyici> createState() => _KatalogBekleyiciState();
}

class _KatalogBekleyiciState extends ConsumerState<KatalogBekleyici> {
  @override
  void initState() {
    super.initState();
    final katalog = ref.read(katalogProvider.notifier);
    // Durum derleme sırasında değiştirilmez; bir sonraki mikro görevde.
    unawaited(Future<void>.microtask(katalog.gerekli));
  }

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(katalogProvider);
    final katalog = durum.value;
    if (katalog != null) return widget.builder(context, katalog);
    if (durum.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HataSatiri(metin: m.katalog_yuklenemedi),
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: CerceveliHapEylem(
                etiket: m.katalog_tekrar_dene,
                onPressed: () =>
                    unawaited(ref.read(katalogProvider.notifier).yenile()),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s24),
      child: Center(child: TayfamYukleniyor(etiket: m.katalog_yukleniyor)),
    );
  }
}
