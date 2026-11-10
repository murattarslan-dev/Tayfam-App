import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/tayfa/application/katilim_notifier.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Kodla katılma sayfasını alttan açar (ADR-0014 §3). Üyelik hemen etkin
/// olursa sayfa kapanır ve tayfanın ana sayfası [context]'in
/// yönlendiricisiyle açılır.
Future<void> kodlaKatilmaSayfasiniAc(BuildContext context) async {
  final tayfaId = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const KodlaKatilmaSayfasi(),
  );
  if (tayfaId != null && context.mounted) {
    context.go(Adresler.tayfa(tayfaId));
  }
}

/// Kodla katılma sayfası: tek bir kod alanı (büyük/küçük harf duyarsız,
/// baştaki ve sondaki boşluklar atılır, en çok 32 karakter).
///
/// Etkin üyelikte sayfa tayfa kimliğiyle kapanır; bekleyen üyelikte
/// "İsteğin gönderildi" gösterilir.
class KodlaKatilmaSayfasi extends ConsumerStatefulWidget {
  const KodlaKatilmaSayfasi({super.key});

  @override
  ConsumerState<KodlaKatilmaSayfasi> createState() =>
      _KodlaKatilmaSayfasiState();
}

class _KodlaKatilmaSayfasiState extends ConsumerState<KodlaKatilmaSayfasi> {
  final TextEditingController _kod = TextEditingController();

  @override
  void dispose() {
    _kod.dispose();
    super.dispose();
  }

  void _gonder() =>
      unawaited(ref.read(katilimProvider.notifier).katil(_kod.text));

  @override
  Widget build(BuildContext context) {
    final metinler = AppLocalizations.of(context);
    ref.listen(katilimProvider, (_, sonraki) {
      final tayfaId = sonraki.tayfaId;
      if (sonraki.sonuc == KatilimSonucu.etkin && tayfaId != null) {
        Navigator.of(context).pop(tayfaId);
      }
    });
    final durum = ref.watch(katilimProvider);
    final yazi = context.yazi;
    return Padding(
      // Klavye açılınca alan görünür kalsın.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TayfamSpacing.kenarMobil,
          0,
          TayfamSpacing.kenarMobil,
          TayfamSpacing.s24,
        ),
        child: durum.sonuc == KatilimSonucu.bekliyor
            ? _Gonderildi(metinler: metinler)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      metinler.katilim_baslik,
                      style: yazi.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s8),
                  Text(
                    metinler.katilim_aciklama,
                    style: yazi.bodyLarge?.copyWith(
                      color: context.renkler.metinGovde,
                    ),
                  ),
                  const SizedBox(height: TayfamSpacing.s16),
                  TextField(
                    controller: _kod,
                    enabled: !durum.gonderiliyor,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: katilimKoduEnCok,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _gonder(),
                    decoration: InputDecoration(
                      labelText: metinler.katilim_kod_etiketi,
                      errorText: durum.kodHatali
                          ? metinler.katilim_kod_hata
                          : null,
                    ),
                  ),
                  if (durum.hata case final hata?) ...[
                    const SizedBox(height: TayfamSpacing.s8),
                    HataSatiri.hatadan(hata),
                  ],
                  const SizedBox(height: TayfamSpacing.s16),
                  BirincilEylem(
                    etiket: metinler.katilim_gonder,
                    onPressed: durum.gonderiliyor ? null : _gonder,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Gonderildi extends StatelessWidget {
  const _Gonderildi({required this.metinler});

  final AppLocalizations metinler;

  @override
  Widget build(BuildContext context) {
    final yazi = context.yazi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            metinler.katilim_gonderildi_baslik,
            style: yazi.headlineSmall,
          ),
        ),
        const SizedBox(height: TayfamSpacing.s8),
        Text(
          metinler.katilim_gonderildi_aciklama,
          style: yazi.bodyLarge?.copyWith(color: context.renkler.metinGovde),
        ),
        const SizedBox(height: TayfamSpacing.s24),
        BirincilEylem(
          etiket: metinler.katilim_tamam,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
