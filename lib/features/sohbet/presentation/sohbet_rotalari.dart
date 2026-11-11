import 'package:go_router/go_router.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ekrani.dart';
import 'package:tayfam/features/sohbet/presentation/sohbet_ekrani.dart';

/// Sohbet sekmesinin rotaları (ADR-0003): kök ve kanal ekranı. Adresteki
/// kimlikler girdi kabul edilir; UUID biçiminde değilse Sohbet köküne
/// dönülür (erişimi sunucu söyler).
GoRoute sohbetRotasi() => GoRoute(
  path: Adresler.sohbet,
  builder: (context, state) => const SohbetEkrani(),
  routes: [
    GoRoute(
      path:
          '${Adresler.sohbetKanalYolu}/:${Adresler.tayfaIdParametresi}'
          '/:$_kanalIdParametresi',
      redirect: (context, state) {
        final tayfaId = state.pathParameters[Adresler.tayfaIdParametresi];
        final kanalId = state.pathParameters[_kanalIdParametresi];
        if (tayfaId == null ||
            kanalId == null ||
            !uuidBicimindeMi(tayfaId) ||
            !uuidBicimindeMi(kanalId)) {
          return Adresler.sohbet;
        }
        return null;
      },
      builder: (context, state) => KanalEkrani(
        tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
        kanalId: state.pathParameters[_kanalIdParametresi]!,
      ),
    ),
  ],
);

const String _kanalIdParametresi = 'kanalId';
