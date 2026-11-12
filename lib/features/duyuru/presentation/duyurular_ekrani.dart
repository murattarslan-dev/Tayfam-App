import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın duyuruları (`/t/<tayfaId>/duyurular`; ADR-0015 §2): önce
/// sabitlenenler, sonra yeniden eskiye, sayfalı. Aşağı çekince yenilenir.
///
/// Moderatör ve yöneticiye "Duyuru yaz" gösterilir; bu yalnızca
/// kolaylıktır, yetkiyi sunucu verir (kesin kural 5).
class DuyurularEkrani extends ConsumerWidget {
  const DuyurularEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = duyuruListesiProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final yonetimde = ref.watch(tayfaOzetiProvider(tayfaId)).yonetimde;
    final liste = durum.value;
    final hata = durum.error;
    return Scaffold(
      appBar: AppBar(title: Text(metinler.tayfa_ana_duyurular_baslik)),
      body: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            if (yonetimde) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: BirincilEylem(
                  etiket: metinler.duyuru_yaz,
                  ikon: Icons.edit_outlined,
                  onPressed: () =>
                      unawaited(duyuruFormunuAc(context, tayfaId: tayfaId)),
                ),
              ),
              const SizedBox(height: TayfamSpacing.s16),
            ],
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ] else if (liste == null)
              Center(
                child: TayfamYukleniyor(
                  boyut: TayfamSizes.yukleniyorTamEkran,
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
            else ...[
              for (final (sira, duyuru) in liste.ogeler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                DuyuruKarti(
                  duyuru: duyuru,
                  onTap: () => context.go(Adresler.duyuru(tayfaId, duyuru.id)),
                ),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                _TekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                Center(
                  child: TayfamYukleniyor(etiket: metinler.duyuru_yukleniyor),
                )
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(metinler.tayfa_ana_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(duyuruListesiProvider(tayfaId).notifier).dahaFazla());

  /// Listeyi yeniler. Yenileme başarısız olursa eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = duyuruListesiProvider(tayfaId);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) islemHatasiniBildir(context, hata);
  }
}

class _TekrarDene extends StatelessWidget {
  const _TekrarDene({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(TayfamSizes.dokunmaMin),
        ),
        child: Text(AppLocalizations.of(context).tayfa_ana_tekrar_dene),
      ),
    );
  }
}
