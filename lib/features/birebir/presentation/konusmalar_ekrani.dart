import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/presentation/birebir_ortak.dart';
import 'package:tayfam/features/birebir/presentation/konusma_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Sohbet sekmesinin Birebir bölümü (ADR-0018 §9): mesaj isteklerine
/// giriş ve konuşmalar (son mesaja göre, sayfalı). Aşağı çekince ve
/// uygulama ön plana dönünce yenilenir. Sohbet sekmesinin
/// `birebirBolumuProvider` yuvasına konur (`shell/kayitlar.dart`).
class BirebirSekmesi extends ConsumerWidget {
  const BirebirSekmesi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnPlanaDonunce(
      onResume: () =>
          unawaited(ref.read(konusmaListesiProvider.notifier).yenile()),
      child: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: const [BirebirKonusmalarListesi()],
        ),
      ),
    );
  }

  /// Listeyi yeniler. Başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final hata = await ref.read(konusmaListesiProvider.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(konusmaListesiProvider).hasValue) {
      birebirHatasiniBildir(context, hata);
    }
  }
}

/// Birebir konuşmalar: mesaj istekleri girişi ve konuşmalar. Kaydırılan
/// bir listenin içine konur.
class BirebirKonusmalarListesi extends ConsumerWidget {
  const BirebirKonusmalarListesi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final durum = ref.watch(konusmaListesiProvider);
    final istekSayisi = ref.watch(mesajIstekleriProvider).length;
    final liste = durum.value;
    final hata = durum.error;
    final konusmalar = [
      for (final k in liste?.ogeler ?? const <Conversation>[])
        if (k.status != ConversationStatus.requestReceived) k,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IstekleriAc(sayi: istekSayisi),
        const Divider(),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          BirebirTekrarDene(
            onPressed: () => ref.invalidate(konusmaListesiProvider),
          ),
        ] else if (liste == null)
          BirebirYukleniyor(etiket: m.birebir_yukleniyor)
        else ...[
          if (konusmalar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s16),
              child: BirebirAciklama(m.birebir_bos),
            ),
          for (final k in konusmalar)
            KonusmaSatiri(
              konusma: k,
              onTap: () => context.go(Adresler.birebirKonusma(k.id)),
            ),
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            HataSatiri.hatadan(dahaHatasi),
            BirebirTekrarDene(onPressed: () => _dahaFazla(ref)),
          ] else if (liste.dahaYukleniyor)
            BirebirYukleniyor(etiket: m.birebir_yukleniyor)
          else if (liste.dahaVar)
            Center(
              child: TextButton(
                onPressed: () => _dahaFazla(ref),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.birebir_daha_fazla),
              ),
            ),
        ],
      ],
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(konusmaListesiProvider.notifier).dahaFazla());
}

/// "Mesaj istekleri" girişi; bekleyen istek varsa sayısı rozetle
/// gösterilir.
class _IstekleriAc extends StatelessWidget {
  const _IstekleriAc({required this.sayi});

  final int sayi;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    return InkWell(
      onTap: () => context.go(Adresler.mesajIstekleri),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: TayfamSizes.dokunmaMin),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TayfamSpacing.s12),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.mark_email_unread_outlined, color: r.metin),
              ),
              const SizedBox(width: TayfamSpacing.s12),
              Expanded(
                child: Text(
                  m.birebir_istekler_baslik,
                  style: context.yazi.titleMedium?.copyWith(color: r.metin),
                ),
              ),
              if (sayi > 0)
                Semantics(
                  label: m.birebir_istekler_sayisi(sayi),
                  excludeSemantics: true,
                  child: Badge(
                    label: Text(
                      sayi > rozetEnCok
                          ? m.gezinme_rozet_cok
                          : m.gezinme_rozet_sayi(sayi),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
