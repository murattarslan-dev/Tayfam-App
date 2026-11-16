import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/application/anlik_davet.dart';
import 'package:tayfam/features/etkinlik/presentation/anlik/arkadas_secimi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Anlık tayfada "Arkadaş davet et" (ADR-0026; tasarım: `docs/tasarim/29`
/// §5): arkadaş seçimi alttan sayfada, altta "Davet et (n)". Bütün davetler
/// gidince sayfa kapanır ve kısa bildirim gösterilir; hata varsa sayfa
/// açık kalır, başarıyla davet edilenler seçimden çıkar.
///
/// Tayfa ana sayfasındaki anlık etkinlik kartı bunu `arkadasDavetiProvider`
/// kaydıyla açar (tayfa özelliği etkinlik özelliğini import edemez).
Future<void> anlikArkadasDavetEt(BuildContext context, String tayfaId) async {
  final m = AppLocalizations.of(context);
  final bildirim = ScaffoldMessenger.of(context);
  final sayi = await altSayfaAc<int>(
    context,
    builder: (_) => AnlikDavetSayfasi(tayfaId: tayfaId),
  );
  if (sayi == null || sayi == 0) return;
  bildirim
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m.anlik_davet_gitti(sayi))));
}

/// "Arkadaş davet et" sayfasının içeriği.
class AnlikDavetSayfasi extends ConsumerWidget {
  const AnlikDavetSayfasi({super.key, required this.tayfaId});

  final String tayfaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = AppLocalizations.of(context);
    final provider = anlikDavetProvider(tayfaId);
    ref.listen(provider, (_, sonraki) {
      final gonderilen = sonraki.gonderilen;
      if (gonderilen != null) Navigator.of(context).pop(gonderilen);
    });
    final durum = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final hata = durum.hata;
    return AltSayfaIcerigi(
      baslik: m.anlik_davet_sayfa_baslik,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: TayfamSpacing.s8),
          child: ArkadasSecimi(
            secili: durum.secili,
            onDegistir: durum.gonderiliyor ? null : notifier.degistir,
          ),
        ),
        if (hata != null) ...[
          const SizedBox(height: TayfamSpacing.s12),
          HataSatiri.hatadan(hata),
        ],
        const SizedBox(height: TayfamSpacing.s16),
        BirincilEylem(
          etiket: m.anlik_davet_gonder(durum.secili.length),
          ikon: Icons.send_outlined,
          onPressed: durum.gonderiliyor || durum.secili.isEmpty
              ? null
              : () => unawaited(notifier.gonder()),
        ),
      ],
    );
  }
}
