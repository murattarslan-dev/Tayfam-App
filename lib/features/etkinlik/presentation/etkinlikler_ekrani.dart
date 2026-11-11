import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir tayfanın bitmemiş etkinlikleri (`/t/<tayfaId>/etkinlikler`,
/// ADR-0015 §3): başlangıca göre, sayfalı; iptal edilenler soluk ve
/// etiketli. Aşağı çekince yenilenir. Yetkiliye "Etkinlik aç" düğmesi
/// gösterilir; kararı sunucu verir.
class EtkinliklerEkrani extends ConsumerWidget {
  const EtkinliklerEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulanmıştır).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final liste = ref.watch(etkinlikListesiProvider(tayfaId));
    final acabilir = ref.watch(etkinlikAcabilirProvider(tayfaId)).value;
    final notifier = ref.read(etkinlikListesiProvider(tayfaId).notifier);
    return Scaffold(
      appBar: AppBar(title: Text(m.etkinlik_modul_adi)),
      floatingActionButton: acabilir == true
          ? FloatingActionButton.extended(
              onPressed: () => context.go(Adresler.etkinlikOlustur(tayfaId)),
              icon: const Icon(Icons.add),
              label: Text(m.etkinlik_ac),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: notifier.yenile,
        child: liste.when(
          data: (sayfali) => _Liste(
            tayfaId: tayfaId,
            sayfali: sayfali,
            onDahaFazla: () => unawaited(notifier.dahaFazla()),
          ),
          error: (hata, _) => _Durum(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HataSatiri.hatadan(hata),
                const SizedBox(height: TayfamSpacing.s16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton(
                    onPressed: () => unawaited(notifier.yenile()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.etkinlik_tekrar_dene),
                  ),
                ),
              ],
            ),
          ),
          loading: () =>
              const _Durum(child: Center(child: CircularProgressIndicator())),
        ),
      ),
    );
  }
}

/// Aşağı çekerek yenilemenin her durumda çalışması için kaydırılabilir
/// tek parça içerik.
class _Durum extends StatelessWidget {
  const _Durum({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [child],
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({
    required this.tayfaId,
    required this.sayfali,
    required this.onDahaFazla,
  });

  final String tayfaId;
  final SayfaliListe<Event> sayfali;
  final VoidCallback onDahaFazla;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final etkinlikler = sayfali.ogeler;
    if (etkinlikler.isEmpty) {
      return _Durum(
        child: Text(
          m.etkinlik_liste_bos,
          style: context.yazi.bodyLarge?.copyWith(
            color: context.renkler.metinGovde,
          ),
        ),
      );
    }
    final hata = sayfali.hata;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        TayfamSpacing.kenarMobil,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.kenarMobil,
        TayfamSpacing.s64 + TayfamSpacing.s32,
      ),
      itemCount: etkinlikler.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: TayfamSpacing.s12),
      itemBuilder: (context, i) {
        if (i < etkinlikler.length) {
          final etkinlik = etkinlikler[i];
          return EtkinlikSatiri(
            etkinlik: etkinlik,
            onTap: () => context.go(Adresler.etkinlik(tayfaId, etkinlik.id)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hata != null) ...[
              HataSatiri.hatadan(hata),
              const SizedBox(height: TayfamSpacing.s8),
            ],
            if (sayfali.yukleniyor)
              const Center(child: CircularProgressIndicator())
            else if (sayfali.dahaVar)
              Align(
                child: OutlinedButton(
                  onPressed: onDahaFazla,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                  ),
                  child: Text(m.etkinlik_daha_fazla),
                ),
              ),
          ],
        );
      },
    );
  }
}
