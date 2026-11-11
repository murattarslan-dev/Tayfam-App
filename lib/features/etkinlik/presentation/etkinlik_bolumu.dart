import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik oluşturmayı başlatan geri çağırma ("Etkinlik aç").
typedef EtkinlikOlusturucu = void Function(
  BuildContext context,
  String tayfaId,
);

/// Tayfa ana sayfasındaki "Yaklaşan etkinlikler" bölümü (ADR-0015 §1):
/// en yakın üç etkinliğin kartı ve "Tümü" bağlantısı.
///
/// Boşken kısa bir boş durum gösterilir. Etkinlik açabilen kullanıcıya
/// (moderatör, yönetici ya da tayfa izin veriyorsa üye) ve [olustur]
/// verildiyse "Etkinlik aç" kısayolu eklenir; kısayol yalnızca
/// kolaylıktır, yetkiyi sunucu verir (kesin kural 5). Oluşturma sihirbazı
/// etkinlik çekirdeği paketiyle gelir (issue #38).
class EtkinlikBolumu extends ConsumerWidget {
  const EtkinlikBolumu({super.key, required this.tayfaId, this.olustur});

  final String tayfaId;

  /// "Etkinlik aç" kısayolunun eylemi; `null` ise kısayol gösterilmez.
  final EtkinlikOlusturucu? olustur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final durum = ref.watch(etkinlikListesiProvider(tayfaId));
    final acabilir = ref.watch(tayfaOzetiProvider(tayfaId)).etkinlikAcabilir;
    final olustur = this.olustur;
    final liste = durum.value;
    final hata = durum.error;
    final gosterilen = liste?.ogeler.take(anaSayfaEtkinlikSayisi).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumBasligi(
          baslik: metinler.tayfa_ana_etkinlikler_baslik,
          tumuEtiketi: metinler.tayfa_ana_tum_etkinlikler,
          onTumu: () => context.go(Adresler.etkinlikler(tayfaId)),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        if (gosterilen == null && hata != null) ...[
          HataSatiri.hatadan(hata),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.invalidate(etkinlikListesiProvider(tayfaId)),
              style: TextButton.styleFrom(
                minimumSize: const Size.square(TayfamSizes.dokunmaMin),
              ),
              child: Text(metinler.tayfa_ana_tekrar_dene),
            ),
          ),
        ] else if (gosterilen == null)
          Center(
            child: CircularProgressIndicator(
              semanticsLabel: metinler.tayfa_ana_etkinlikler_yukleniyor,
            ),
          )
        else if (gosterilen.isEmpty) ...[
          Text(
            metinler.tayfa_ana_etkinlikler_bos,
            style: context.yazi.bodyLarge?.copyWith(
              color: context.renkler.metinGovde,
            ),
          ),
          if (acabilir && olustur != null) ...[
            const SizedBox(height: TayfamSpacing.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: metinler.tayfa_ana_etkinlik_ac,
                ikon: Icons.add,
                onPressed: () => olustur(context, tayfaId),
              ),
            ),
          ],
        ] else
          for (final (sira, etkinlik) in gosterilen.indexed) ...[
            if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
            EtkinlikKarti(
              etkinlik: etkinlik,
              onTap: () => context.go(Adresler.etkinlik(tayfaId, etkinlik.id)),
            ),
          ],
      ],
    );
  }
}
