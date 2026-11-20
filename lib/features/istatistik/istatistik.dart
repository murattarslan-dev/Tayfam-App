/// İstatistik özelliğinin dışa açık dosyası (Tayfam-Api ADR-0026, #250):
///
/// - [istatistikRotalari] tayfa rotasının (`/t/<tayfaId>`) altına eklenir:
///   tayfa istatistikleri ekranı (yıl seçimi, toplamlar, kişisel katkılar).
/// - [IstatistikBolumu] profildeki kişisel istatistikler (arkadaşlık
///   paketi), [VitrinIstatistikleri] Keşfet kartındaki vitrin (Keşfet
///   paketi) içindir.
///
/// Metrik adları ortak metriklerde çeviri, türe bağlı metriklerde
/// katalogdaki tür ve bileşen adlarıdır (düz metin; ADR-0024 §2).
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/istatistik/presentation/tayfa_istatistik_ekrani.dart';

export 'package:tayfam/features/istatistik/application/tayfa_istatistikleri.dart'
    show tayfaIstatistikleriProvider;
export 'package:tayfam/features/istatistik/data/istatistik_deposu.dart'
    show tumZamanlar;
export 'package:tayfam/features/istatistik/presentation/istatistik_listesi.dart'
    show IstatistikBolumu, IstatistikNotu, IstatistikSatiri;
export 'package:tayfam/features/istatistik/presentation/istatistik_metinleri.dart'
    show MetrikGorunumu, istatistikSayisi, metrikGorunumuAnahtarla;
export 'package:tayfam/features/istatistik/presentation/vitrin_istatistikleri.dart'
    show VitrinIstatistikleri;

/// Tayfa istatistiklerinin tayfa rotası altındaki rotası.
final List<RouteBase> istatistikRotalari = [
  GoRoute(
    path: Adresler.istatistikYolu,
    builder: (context, state) => TayfaIstatistikEkrani(
      tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
    ),
  ),
];
