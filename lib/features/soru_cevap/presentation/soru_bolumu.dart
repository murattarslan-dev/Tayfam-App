import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasındaki "Son sorular" bölümü (ADR-0018 Genel, ADR-0015
/// Notlar 2026-11-13; tasarım: Ana-Tam-Sayfa): en son [anaSayfaSoruSayisi]
/// sorunun kısa satırı (başlık, "3 cevap · dün") ve "Tümü" bağlantısı.
/// Boşken kısa bir boş durum gösterilir; "Soru sor" ana sayfanın
/// "Oluştur" sayfasındadır.
class SoruBolumu extends ConsumerWidget {
  const SoruBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = soruListesiProvider(anaSoruListesi(tayfaId));
    final durum = ref.watch(saglayici);
    final simdi = ref.watch(simdiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: metinler.soru_bolum_baslik,
          tumuEtiketi: metinler.soru_tum_sorular,
          onTumu: () => context.go(Adresler.sorular(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(saglayici),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(metinler.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(
              etiket: metinler.soru_yukleniyor,
              gecikmeli: true,
            ),
          )
        else if (liste.ogeler.isEmpty)
          Text(
            metinler.soru_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          )
        else
          ListeKarti(
            children: [
              for (final soru in liste.ogeler.take(anaSayfaSoruSayisi))
                SoruSatiri(
                  soru: soru,
                  simdi: simdi,
                  onTap: () => context.go(Adresler.soru(tayfaId, soru.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Ana sayfadaki kısa soru satırı.
class SoruSatiri extends StatelessWidget {
  const SoruSatiri({
    super.key,
    required this.soru,
    required this.simdi,
    this.onTap,
  });

  final Question soru;

  /// Göreli zamanın hesaplandığı an.
  final DateTime simdi;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final yazi = context.yazi;
    return ListeKartiSatiri(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(soru.title, style: yazi.titleMedium),
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            m.soru_satir_ozet(
              m.soru_cevap_sayisi(soru.answerCount),
              goreliGecmis(m, soru.createdAt, simdi),
            ),
            style: yazi.labelSmall?.copyWith(
              color: context.renkler.metinIkincil,
            ),
          ),
        ],
      ),
    );
  }
}
