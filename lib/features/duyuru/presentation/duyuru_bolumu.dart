import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasındaki "Duyurular" bölümü (ADR-0015 §1, Notlar
/// 2026-11-13; tasarım: Ana-Tam-Sayfa): önce bütün sabitlenenler, sonra
/// son [anaSayfaDuyuruSayisi] duyuru ve "Tümü" bağlantısı. Satırda
/// "Sabitlendi" etiketi, başlık, gövdenin ilk iki satırı ve göreli zaman
/// ("2 gün önce"); yazar adı gösterilmez (sözleşmede yalnızca kimlik var).
///
/// Boşken kısa bir boş durum gösterilir; "Duyuru yaz" kısayolu bölümde
/// değil, ana sayfanın "Oluştur" sayfasındadır.
class DuyuruBolumu extends ConsumerWidget {
  const DuyuruBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(duyuruListesiProvider(tayfaId));
    final simdi = ref.watch(simdiProvider)();
    final liste = durum.value;
    final hata = durum.error;
    final gosterilen = liste == null
        ? const <Announcement>[]
        : anaSayfaDuyurulari(liste.ogeler);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: metinler.tayfa_ana_duyurular_baslik,
          tumuEtiketi: metinler.tayfa_ana_tum_duyurular,
          onTumu: () => context.go(Adresler.duyurular(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (liste == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(duyuruListesiProvider(tayfaId)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(metinler.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else if (liste == null)
          Center(
            child: TayfamYukleniyor(
              etiket: metinler.duyuru_yukleniyor,
              gecikmeli: true,
            ),
          )
        else if (liste.ogeler.isEmpty)
          Text(
            metinler.tayfa_ana_duyurular_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          )
        else
          ListeKarti(
            children: [
              for (final duyuru in gosterilen)
                DuyuruSatiri(
                  duyuru: duyuru,
                  simdi: simdi,
                  onTap: () => context.go(Adresler.duyuru(tayfaId, duyuru.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Ana sayfadaki kısa duyuru satırı. Gövde düz metindir; markdown ya da
/// HTML yorumlanmaz (ADR-0015 §2).
class DuyuruSatiri extends StatelessWidget {
  const DuyuruSatiri({
    super.key,
    required this.duyuru,
    required this.simdi,
    this.onTap,
  });

  final Announcement duyuru;

  /// Göreli zamanın hesaplandığı an.
  final DateTime simdi;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = AppLocalizations.of(context);
    final r = context.renkler;
    final yazi = context.yazi;
    final govde = duyuru.body.trim();
    return ListeKartiSatiri(
      onTap: onTap,
      icBosluk: const EdgeInsets.all(TayfamSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (duyuru.pinned) ...[
            Etiket(
              metin: m.duyuru_sabit,
              ton: EtiketTonu.mango,
              ikon: Icons.push_pin_outlined,
            ),
            const SizedBox(height: TayfamSpacing.s8),
          ],
          Text(duyuru.title, style: yazi.titleMedium),
          if (govde.isNotEmpty) ...[
            const SizedBox(height: TayfamSpacing.s4),
            Text(
              govde,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: yazi.bodyMedium?.copyWith(color: r.metinGovde),
            ),
          ],
          const SizedBox(height: TayfamSpacing.s4),
          Text(
            goreliGecmis(m, duyuru.createdAt, simdi),
            style: yazi.labelSmall?.copyWith(color: r.metinIkincil),
          ),
        ],
      ),
    );
  }
}
