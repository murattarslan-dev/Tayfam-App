import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa ana sayfasındaki "Duyurular" bölümü (ADR-0015 §1): önce bütün
/// sabitlenenler, sonra son üç duyuru ve "Tümü" bağlantısı.
///
/// Boşken kısa bir boş durum gösterilir; moderatör ve yöneticiye ayrıca
/// "Duyuru yaz" kısayolu. Kısayol yalnızca kolaylıktır, yetkiyi sunucu
/// verir (kesin kural 5).
class DuyuruBolumu extends ConsumerWidget {
  const DuyuruBolumu({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(duyuruListesiProvider(tayfaId));
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
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
            child: TayfamYukleniyor(etiket: metinler.duyuru_yukleniyor, gecikmeli: true,),
          )
        else if (liste.ogeler.isEmpty) ...[
          Text(
            metinler.tayfa_ana_duyurular_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          if (yonetimde) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: metinler.duyuru_yaz,
                ikon: Icons.edit_outlined,
                onPressed: () =>
                    unawaited(duyuruFormunuAc(context, tayfaId: tayfaId)),
              ),
            ),
          ],
        ] else
          for (final (sira, duyuru) in gosterilen.indexed) ...[
            if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
            DuyuruKarti(
              duyuru: duyuru,
              onTap: () => context.go(Adresler.duyuru(tayfaId, duyuru.id)),
            ),
          ],
      ],
    );
  }
}
