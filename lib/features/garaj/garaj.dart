/// Üye garajı özelliğinin dışa açık dosyası (App ADR-0033 §2; Tayfam-Api
/// ADR-0040 §4, #272):
///
/// - [GarajModulu] tayfa modül kaydına (`garage`; tayfa garajı rotası,
///   "Oluştur" girişi),
/// - [GarajBileseni] ana sayfa bileşeni kaydına (`garage` kartı) eklenir
///   (`shell/kayitlar.dart`).
/// - [garajRotalari] `/profil` rotasının altına eklenir; [GarajGirisi]
///   profildeki "Garajım" girişidir.
/// - [GarajdanSecim] etkinliğin araç formundaki "Garajımdan seç"
///   listesidir; [garajimProvider] kendi garajını verir.
library;

import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/garaj/presentation/garajim_ekrani.dart';

export 'package:tayfam/features/garaj/application/garaj.dart'
    show aracAdi, garajimProvider;
export 'package:tayfam/features/garaj/presentation/garaj_modulu.dart'
    show GarajBileseni, GarajModulu;
export 'package:tayfam/features/garaj/presentation/garajdan_secim.dart'
    show GarajdanSecim;
export 'package:tayfam/features/garaj/presentation/garajim_ekrani.dart'
    show GarajGirisi;

/// Profil altındaki garaj rotaları: Garajım.
final List<RouteBase> garajRotalari = [
  GoRoute(
    path: Adresler.garajimYolu,
    builder: (context, state) => const GarajimEkrani(),
  ),
];
