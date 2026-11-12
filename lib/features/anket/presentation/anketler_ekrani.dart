import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_karti.dart';
import 'package:tayfam/features/anket/presentation/anket_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın anketleri (`/t/<tayfaId>/anketler`; ADR-0018 §5): açık ve
/// kapanmış, yeniden eskiye, sayfalı. [etkinlikId] verilirse
/// (`?etkinlik=<id>`) yalnızca o etkinliğe bağlı anketler; o zaman açılan
/// anket de etkinliğe bağlanır. Aşağı çekince yenilenir.
///
/// "Anket aç" her üyeye gösterilir; yetkiyi sunucu verir (`muted` …).
class AnketlerEkrani extends ConsumerWidget {
  const AnketlerEkrani({super.key, required this.tayfaId, this.etkinlikId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  /// Adresteki etkinlik süzgeci; biçimi modül rotasında doğrulandı.
  final String? etkinlikId;

  AnketListesiAnahtari get _anahtar =>
      (tayfaId: tayfaId, etkinlikId: etkinlikId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final saglayici = anketListesiProvider(_anahtar);
    final durum = ref.watch(saglayici);
    final simdi = ref.watch(anketSaatiProvider)().toUtc();
    final liste = durum.value;
    final hata = durum.error;
    final etkinlikte = etkinlikId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          etkinlikte ? m.anket_etkinlik_liste_baslik : m.anket_liste_baslik,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BirincilEylem(
                etiket: m.anket_ac,
                ikon: Icons.add,
                onPressed: () => unawaited(
                  anketFormunuAc(
                    context,
                    tayfaId: tayfaId,
                    etkinlikId: etkinlikId,
                  ),
                ),
              ),
            ),
            const SizedBox(height: TayfamSpacing.s16),
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
              Text(
                etkinlikte ? m.anket_etkinlik_liste_bos : m.anket_liste_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              )
            else ...[
              for (final (sira, anket) in liste.ogeler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                AnketKarti(
                  anket: anket,
                  simdi: simdi,
                  onTap: () => context.go(Adresler.anket(tayfaId, anket.id)),
                ),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                AnketTekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                Center(child: TayfamYukleniyor(etiket: m.anket_yukleniyor))
              else if (liste.dahaVar)
                Center(
                  child: TextButton(
                    onPressed: () => _dahaFazla(ref),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.square(TayfamSizes.dokunmaMin),
                    ),
                    child: Text(m.tayfa_ana_daha_fazla),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _dahaFazla(WidgetRef ref) =>
      unawaited(ref.read(anketListesiProvider(_anahtar).notifier).dahaFazla());

  /// Listeyi yeniler. Başarısız olursa eldeki liste kalır ve hata kısa
  /// bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = anketListesiProvider(_anahtar);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) anketHatasiniBildir(context, hata);
  }
}
