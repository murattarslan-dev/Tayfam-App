import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/simdi_ekrani.dart';

/// Şimdi başlat ekranının rotası (`/simdi`; App ADR-0032 §2). Kabuğun
/// üstünde tam ekran açılır. `tayfa` ve `davetli` sorgu parametreleri girdi
/// kabul edilir ve [simdiAnahtariCoz] ile doğrulanır; geçmeyen değer yok
/// sayılır (geçersiz tayfa kimliğiyle ekran anlık etkinlik açmaz, tayfasız
/// açılır).
final GoRoute simdiRotasi = GoRoute(
  path: Adresler.simdiYolu,
  builder: (context, state) {
    final sorgu = state.uri.queryParameters;
    return SimdiEkrani(
      anahtar: simdiAnahtariCoz(
        sorgu[Adresler.simdiTayfaParametresi],
        sorgu[Adresler.anlikDavetliParametresi],
      ),
    );
  },
);
