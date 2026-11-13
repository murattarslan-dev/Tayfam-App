import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_bolumu.dart';
import 'package:tayfam/features/anket/presentation/anket_ekrani.dart';
import 'package:tayfam/features/anket/presentation/anketler_ekrani.dart';

/// Anket rotasındaki anket kimliği parametresinin adı.
const String anketIdParametresi = 'anketId';

/// Anket modülü (`polls`; ADR-0002, ADR-0018 §5).
///
/// Rotalar `/t/<tayfaId>/anketler` (isteğe bağlı `?etkinlik=<id>`
/// süzgeciyle) ve `/t/<tayfaId>/anketler/<anketId>`; tayfa ana sayfasındaki
/// bölümü "Açık anketler"dir. Modül kapalıysa sunucunun `modules` alanına
/// göre hiç görünmez.
class AnketModulu implements TayfaModule {
  const AnketModulu();

  @override
  String get sunucuAnahtari => Module.polls.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.anketlerYolu,
      builder: (context, state) => AnketlerEkrani(
        tayfaId: _tayfaId(state),
        etkinlikId: anketEtkinlikSuzgeci(state.uri),
      ),
      routes: [
        GoRoute(
          path: ':$anketIdParametresi',
          builder: (context, state) => AnketEkrani(
            tayfaId: _tayfaId(state),
            anketId: state.pathParameters[anketIdParametresi] ?? '',
          ),
        ),
      ],
    ),
  ];

  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      AnketBolumu(tayfaId: tayfaId);

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    await ref
        .read(
          anketListesiProvider((tayfaId: tayfaId, etkinlikId: null)).notifier,
        )
        .yenile();
  }
}

/// Adresteki etkinlik süzgeci (`?etkinlik=<id>`). Adres girdi kabul edilir:
/// UUID biçiminde değilse süzgeç yok sayılır.
String? anketEtkinlikSuzgeci(Uri adres) {
  final deger = adres.queryParameters[Adresler.anketEtkinlikParametresi];
  return deger != null && uuidBicimindeMi(deger) ? deger : null;
}

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi] ?? '';

