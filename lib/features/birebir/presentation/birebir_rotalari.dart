import 'package:go_router/go_router.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/birebir/presentation/kisi_konusmasi_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_istekleri_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/reddedilenler_ekrani.dart';

/// Konuşma rotasındaki kimlik parametresinin adı.
const String konusmaIdParametresi = 'konusmaId';

/// Kişi rotasındaki kimlik parametresinin adı.
const String kullaniciIdParametresi = 'kullaniciId';

/// Birebir mesajın Sohbet sekmesi (`/sohbet`) altındaki rotaları
/// (ADR-0018 §9). Adresteki kimlik girdi kabul edilir: UUID biçiminde
/// değilse Sohbet sekmesine dönülür; var olup olmadığını sunucu söyler.
List<RouteBase> birebirRotalari() => [
  GoRoute(
    path: '${Adresler.birebirYolu}/:$konusmaIdParametresi',
    redirect: (context, state) =>
        _gecerli(state, konusmaIdParametresi) ? null : Adresler.sohbet,
    builder: (context, state) =>
        KonusmaEkrani(konusmaId: state.pathParameters[konusmaIdParametresi]!),
  ),
  GoRoute(
    path: '${Adresler.birebirKisiYolu}/:$kullaniciIdParametresi',
    redirect: (context, state) =>
        _gecerli(state, kullaniciIdParametresi) ? null : Adresler.sohbet,
    builder: (context, state) => KisiKonusmasiEkrani(
      kullaniciId: state.pathParameters[kullaniciIdParametresi]!,
    ),
  ),
  GoRoute(
    path: Adresler.mesajIstekleriYolu,
    builder: (context, state) => const MesajIstekleriEkrani(),
    routes: [
      GoRoute(
        path: Adresler.reddedilenlerYolu,
        builder: (context, state) => const ReddedilenlerEkrani(),
      ),
    ],
  ),
];

bool _gecerli(GoRouterState state, String parametre) {
  final deger = state.pathParameters[parametre];
  return deger != null && uuidBicimindeMi(deger);
}
