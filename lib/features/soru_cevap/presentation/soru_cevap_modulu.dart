import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_bolumu.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_ekrani.dart';
import 'package:tayfam/features/soru_cevap/presentation/sorular_ekrani.dart';

/// Soru rotasındaki soru kimliği parametresinin adı.
const String soruIdParametresi = 'soruId';

/// Soru-cevap modülü (`qa`; ADR-0002, ADR-0018 §4).
///
/// Rotalar `/t/<tayfaId>/sorular` ve `/t/<tayfaId>/sorular/<soruId>`;
/// tayfa ana sayfasındaki bölümü "Son sorular"dır. Modül kapalıysa
/// sunucunun `modules` alanına göre hiç görünmez.
class SoruCevapModulu implements TayfaModule {
  const SoruCevapModulu();

  @override
  String get sunucuAnahtari => Module.qa.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.sorularYolu,
      builder: (context, state) => SorularEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: ':$soruIdParametresi',
          builder: (context, state) => SoruEkrani(
            tayfaId: _tayfaId(state),
            soruId: state.pathParameters[soruIdParametresi]!,
          ),
        ),
      ],
    ),
  ];

  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      SoruBolumu(tayfaId: tayfaId);

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    final liste = soruListesiProvider(anaSoruListesi(tayfaId));
    await ref.read(liste.notifier).yenile();
  }
}

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;

