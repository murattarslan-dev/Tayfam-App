import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/oy_verenler_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Açık (gizli olmayan) ankette [secenek]'e oy verenleri alttan sayfada
/// gösterir (tasarım: Anket-Oy-Verenler; ADR-0018 §5). Gizli ankette
/// hiçbir şey yapmaz: sayfa açılmaz, istek gitmez (kesin kural 7).
Future<void> oyVerenleriGoster(
  BuildContext context, {
  required String tayfaId,
  required Poll anket,
  required PollOption secenek,
}) async {
  if (!oyVerenlerGorunur(anket)) return;
  await altSayfaAc<void>(
    context,
    builder: (_) => OyVerenlerSayfasi(
      anahtar: (tayfaId: tayfaId, anket: anket, secenekId: secenek.id),
      secenek: secenek,
    ),
  );
}

/// Bir seçeneğe oy verenlerin listesi: başlıkta seçenek ve oy sayısı,
/// satırlarda avatar ve görünen ad (kendi satırında "(sen)"), en eski oy
/// önce, sayfalı.
class OyVerenlerSayfasi extends ConsumerWidget {
  const OyVerenlerSayfasi({
    super.key,
    required this.anahtar,
    required this.secenek,
  });

  final OyVerenlerAnahtari anahtar;
  final PollOption secenek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final saglayici = oyVerenlerProvider(anahtar);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    return AltSayfaIcerigi(
      ust: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          TayfamSpacing.s8,
          0,
          TayfamSpacing.s8,
          TayfamSpacing.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(secenek.text, style: context.yazi.headlineSmall),
            ),
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              m.anket_oy_veren_sayisi(secenek.voteCount),
              style: context.yazi.bodySmall,
            ),
          ],
        ),
      ),
      children: [
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          AnketTekrarDene(onPressed: () => ref.invalidate(saglayici)),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(
              boyut: TayfamSizes.yukleniyorTamEkran,
              etiket: m.anket_yukleniyor,
              gecikmeli: true,
            ),
          )
        else if (liste.ogeler.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
            child: Text(m.anket_oy_verenler_bos, style: context.yazi.bodyLarge),
          )
        else ...[
          for (final (sira, oy) in liste.ogeler.indexed) ...[
            if (sira > 0)
              Divider(
                height: TayfamSizes.kenar,
                thickness: TayfamSizes.kenar,
                color: r.cizgi,
              ),
            _OyVerenSatiri(kullaniciId: oy.userId),
          ],
          if (liste.dahaHatasi case final dahaHatasi?) ...[
            HataSatiri.hatadan(dahaHatasi),
            AnketTekrarDene(
              onPressed: () =>
                  unawaited(ref.read(saglayici.notifier).dahaFazla()),
            ),
          ] else if (liste.dahaYukleniyor)
            Center(child: TayfamYukleniyor(etiket: m.anket_yukleniyor))
          else if (liste.dahaVar)
            Center(
              child: TextButton(
                onPressed: () =>
                    unawaited(ref.read(saglayici.notifier).dahaFazla()),
                style: TextButton.styleFrom(
                  minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                ),
                child: Text(m.tayfa_ana_daha_fazla),
              ),
            ),
        ],
      ],
    );
  }
}

/// Oy verenin satırı: avatar ve görünen ad; kullanıcının kendisiyse
/// "(sen)". Ad önbellekten istenir.
class _OyVerenSatiri extends ConsumerWidget {
  const _OyVerenSatiri({required this.kullaniciId});

  final String kullaniciId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    ref.read(kullaniciAdlariProvider.notifier).iste(kullaniciId);
    final bilinen = ref.watch(
      kullaniciAdlariProvider.select((adlar) => adlar[kullaniciId]),
    );
    final ad = switch (bilinen) {
      null => m.kullanici_genel,
      KullaniciAdi(:final ad?) => ad,
      KullaniciAdi() => m.kullanici_silinmis,
    };
    final kendisi = ref.watch(kendisiMiProvider(kullaniciId));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: TayfamSpacing.s56),
      child: Padding(
        padding: const EdgeInsets.all(TayfamSpacing.s8),
        child: Row(
          children: [
            KimlikAvatari(kullaniciId: kullaniciId),
            const SizedBox(width: TayfamSpacing.s12),
            Expanded(
              child: Text(
                kendisi ? m.anket_oy_veren_sen(ad) : ad,
                style: context.yazi.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
