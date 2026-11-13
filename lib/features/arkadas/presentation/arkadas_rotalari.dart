import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_bul_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_istekleri_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/engellenenler_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/katilim_gecmisi.dart';
import 'package:tayfam/features/arkadas/presentation/kisi_profili_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/tayfa_davetleri_ekrani.dart';

/// Profil sekmesinin kökü (`/profil`) altındaki arkadaşlık rotaları
/// (ADR-0018 §7): `arkadaslar` (altında `bul`, `istekler`,
/// `engellenenler`), `tayfa-davetleri` ve `katilimlarim` (kendi katılım
/// geçmişinin tamamı).
final List<RouteBase> arkadasRotalari = [
  GoRoute(
    path: Adresler.arkadaslarYolu,
    builder: (context, state) => const ArkadaslarEkrani(),
    routes: [
      GoRoute(
        path: Adresler.arkadasBulYolu,
        builder: (context, state) => const ArkadasBulEkrani(),
      ),
      GoRoute(
        path: Adresler.arkadasIstekleriYolu,
        builder: (context, state) => const ArkadasIstekleriEkrani(),
      ),
      GoRoute(
        path: Adresler.engellenenlerYolu,
        builder: (context, state) => const EngellenenlerEkrani(),
      ),
    ],
  ),
  GoRoute(
    path: Adresler.tayfaDavetleriYolu,
    builder: (context, state) => const TayfaDavetleriEkrani(),
  ),
  GoRoute(
    path: Adresler.katilimlarimYolu,
    builder: (context, state) => const KatilimlarimEkrani(),
  ),
];

/// Kişi profilinin üst düzey rotası (`/kisi/:kullaniciId`). Sekmelerin
/// üstünde açılır; bildirimden, üye listesinden, sohbetten gidilebilir.
/// Adresteki kimliği ekran doğrular.
final GoRoute kisiProfiliRotasi = GoRoute(
  path: '${Adresler.kisiOneki}/:${Adresler.kisiIdParametresi}',
  builder: (context, state) => KisiProfiliEkrani(
    kullaniciId: state.pathParameters[Adresler.kisiIdParametresi]!,
  ),
);
