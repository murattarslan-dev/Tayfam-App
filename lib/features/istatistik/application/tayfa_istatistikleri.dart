import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/istatistik/data/istatistik_deposu.dart';

/// Tayfa istatistiklerinin sorgusu: tayfa ve dönem ([tumZamanlar] ya da
/// takvim yılı).
typedef IstatistikSorgusu = ({String tayfaId, int yil});

/// Bir tayfanın seçili dönemdeki istatistikleri (`GET …/stats`). Yalnızca
/// bellektedir (ADR-0006) ve ekran kapanınca bırakılır. Etkin üye
/// olmayan `tayfa-not-found` alır; yetki sunucudadır (kesin kural 5).
class TayfaIstatistikleriNotifier extends AsyncNotifier<TayfaStats> {
  TayfaIstatistikleriNotifier(this.sorgu);

  final IstatistikSorgusu sorgu;

  @override
  Future<TayfaStats> build() =>
      ref.read(istatistikDeposuProvider).tayfa(sorgu.tayfaId, sorgu.yil);
}

/// Tayfa istatistikleri; hata otomatik yeniden denenmez.
final tayfaIstatistikleriProvider = AsyncNotifierProvider.autoDispose
    .family<TayfaIstatistikleriNotifier, TayfaStats, IstatistikSorgusu>(
      TayfaIstatistikleriNotifier.new,
      name: 'tayfaIstatistikleriProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
