import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';

/// Anlık etkinlik sihirbazının rotası (`/anlik-etkinlik`; ADR-0026). Kabuğun
/// üstünde tam ekran açılır. `gun` ve `davetli` sorgu parametreleri girdi
/// kabul edilir ve [anlikBaslangicCoz] ile doğrulanır; geçmeyen değer yok
/// sayılır.
final GoRoute anlikEtkinlikRotasi = GoRoute(
  path: Adresler.anlikEtkinlikYolu,
  builder: (context, state) {
    final sorgu = state.uri.queryParameters;
    final kap = ProviderScope.containerOf(context, listen: false);
    return EtkinlikSihirbaziEkrani.anlik(
      anlikBaslangic: anlikBaslangicCoz(
        sorgu[Adresler.anlikGunParametresi],
        sorgu[Adresler.anlikDavetliParametresi],
        simdi: kap.read(etkinlikSaatiProvider)(),
      ),
    );
  },
);
