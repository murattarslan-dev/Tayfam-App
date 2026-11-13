/// Cihazlar özelliğinin dışa açık dosyası (ADR-0002): QR ile cihaz
/// eşleştirme ekranları ve uçtan uca şifreli mesaj geçmişinin uyarıları
/// (ADR-0020 "Geçmiş arşivi, eşleştirme ve yenileme").
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/cihazlar/presentation/bu_cihazi_bagla_ekrani.dart';
import 'package:tayfam/features/cihazlar/presentation/cihaz_bagla_ekrani.dart';

export 'package:tayfam/features/cihazlar/presentation/cihaz_uyarilari.dart'
    show
        CihazBaglamaGirisi,
        EskiArsivBilgisi,
        EskiMesajlarOkunamiyor,
        TekCihazBilgisi,
        tekCihazCikisOnayi,
        tekCihazCikisUyarisi;

/// Profil sekmesinin kökü (`/profil`) altındaki eşleştirme rotaları.
final List<RouteBase> cihazlarRotalari = [
  GoRoute(
    path: Adresler.cihazBaglaYolu,
    builder: (context, state) => const CihazBaglaEkrani(),
  ),
  GoRoute(
    path: Adresler.buCihaziBaglaYolu,
    builder: (context, state) => const BuCihaziBaglaEkrani(),
  ),
];
