import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfanın yaklaşan etkinlikleri (`/t/<tayfaId>/etkinlikler`): başlangıç
/// zamanına göre, sayfalı; aşağı çekince yenilenir. Tayfa ana sayfasındaki
/// "Tümü" bağlantısı burayı açar.
///
/// Kartlar bu pakette salt okunurdur; etkinlik çekirdeği (issue #38) detay,
/// oluşturma ve katılımı ekler.
class EtkinliklerEkrani extends ConsumerWidget {
  const EtkinliklerEkrani({super.key, required this.tayfaId});

  /// Adresteki tayfa kimliği (biçimi yönlendiricide doğrulandı).
  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metinler = AppLocalizations.of(context);
    final saglayici = etkinlikListesiProvider(tayfaId);
    final durum = ref.watch(saglayici);
    final liste = durum.value;
    final hata = durum.error;
    final yukleniyor = Center(
      child: CircularProgressIndicator(
        semanticsLabel: metinler.tayfa_ana_etkinlikler_yukleniyor,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(metinler.tayfa_ana_etkinlikler_baslik)),
      body: RefreshIndicator(
        onRefresh: () => _yenile(context, ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
          children: [
            if (liste == null && hata != null) ...[
              HataSatiri.hatadan(hata),
              _TekrarDene(onPressed: () => ref.invalidate(saglayici)),
            ] else if (liste == null)
              yukleniyor
            else if (liste.ogeler.isEmpty)
              Text(
                metinler.tayfa_ana_etkinlikler_bos,
                style: context.yazi.bodyLarge?.copyWith(
                  color: context.renkler.metinGovde,
                ),
              )
            else ...[
              for (final (sira, etkinlik) in liste.ogeler.indexed) ...[
                if (sira > 0) const SizedBox(height: TayfamSpacing.s12),
                EtkinlikKarti(etkinlik: etkinlik),
              ],
              const SizedBox(height: TayfamSpacing.s16),
              if (liste.dahaHatasi case final dahaHatasi?) ...[
                HataSatiri.hatadan(dahaHatasi),
                _TekrarDene(onPressed: () => _dahaFazla(ref)),
              ] else if (liste.dahaYukleniyor)
                yukleniyor
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

  void _dahaFazla(WidgetRef ref) => unawaited(
    ref.read(etkinlikListesiProvider(tayfaId).notifier).dahaFazla(),
  );

  /// Listeyi yeniler. Yenileme başarısız olursa eldeki liste kalır ve
  /// hata kısa bildirimle gösterilir; liste yoksa hata satırı görünür.
  Future<void> _yenile(BuildContext context, WidgetRef ref) async {
    final saglayici = etkinlikListesiProvider(tayfaId);
    final hata = await ref.read(saglayici.notifier).yenile();
    if (hata == null || !context.mounted) return;
    if (ref.read(saglayici).hasValue) hataBildir(context, hata);
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
