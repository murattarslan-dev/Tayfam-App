import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/ana_sayfa/data/ana_sayfa_deposu.dart';

/// Bir gösterim bileşeninin sorgusu: tayfa ve bileşen anahtarı.
typedef AnaSayfaVeriSorgusu = ({String tayfaId, String anahtar});

/// Bir gösterim bileşeninin verisi (`GET …/home-widgets/{key}/data`).
/// Yalnızca bellektedir (ADR-0006); kart ekrandan kalkınca bırakılır.
/// Etkin üye olmayan `tayfa-not-found`, ana sayfanın göstermediği bileşen
/// `home-widget-not-found` alır; yetki sunucudadır (kesin kural 5).
class AnaSayfaVerisiNotifier extends AsyncNotifier<HomeWidgetData> {
  AnaSayfaVerisiNotifier(this.sorgu);

  final AnaSayfaVeriSorgusu sorgu;

  @override
  Future<HomeWidgetData> build() =>
      ref.read(anaSayfaDeposuProvider).veri(sorgu.tayfaId, sorgu.anahtar);

  /// Veriyi yeniden okur (ana sayfa aşağı çekilince). Okunamazsa eldeki
  /// veri kalır; elde veri yoksa hata gösterilir.
  Future<void> yenile() async {
    try {
      final veri = await ref
          .read(anaSayfaDeposuProvider)
          .veri(sorgu.tayfaId, sorgu.anahtar);
      if (ref.mounted) state = AsyncData(veri);
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
    }
  }
}

/// Gösterim bileşeni verisi; hata otomatik yeniden denenmez.
final anaSayfaVerisiProvider = AsyncNotifierProvider.autoDispose
    .family<AnaSayfaVerisiNotifier, HomeWidgetData, AnaSayfaVeriSorgusu>(
      AnaSayfaVerisiNotifier.new,
      name: 'anaSayfaVerisiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
