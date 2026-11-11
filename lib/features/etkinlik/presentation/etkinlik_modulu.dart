import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_listesi_notifier.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_bolumu.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlikler_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik modülü (`events`; ADR-0002, ADR-0015 §1, §3).
///
/// Rotaları `/t/<tayfaId>/` altındadır: `etkinlikler` (liste),
/// `etkinlikler/yeni` (oluşturma sihirbazı), `etkinlikler/<etkinlikId>`
/// (detay) ve `etkinlikler/<etkinlikId>/duzenle`. Tayfa ana sayfasındaki
/// bölümü "Yaklaşan etkinlikler"dir. Modül kapalıysa sunucunun `modules`
/// alanına göre hiç görünmez. [olustur] verilince boş bölümde "Etkinlik
/// aç" kısayolu görünür ([etkinlikOlusturmayiAc]).
class EtkinlikModulu implements TayfaModule {
  const EtkinlikModulu({this.olustur});

  /// "Etkinlik aç" kısayolunun eylemi; `null` ise kısayol yok.
  final EtkinlikOlusturucu? olustur;

  @override
  String get sunucuAnahtari => Module.events.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.etkinliklerYolu,
      builder: (context, state) => EtkinliklerEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: Adresler.etkinlikOlusturYolu,
          builder: (context, state) =>
              EtkinlikSihirbaziEkrani(tayfaId: _tayfaId(state)),
        ),
        GoRoute(
          path: ':$_etkinlikIdParametresi',
          builder: (context, state) => EtkinlikDetayEkrani(
            tayfaId: _tayfaId(state),
            etkinlikId: _etkinlikId(state),
          ),
          routes: [
            GoRoute(
              path: Adresler.etkinlikDuzenleYolu,
              builder: (context, state) => EtkinlikDuzenlemeEkrani(
                tayfaId: _tayfaId(state),
                etkinlikId: _etkinlikId(state),
              ),
            ),
          ],
        ),
      ],
    ),
  ];

  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      EtkinlikBolumu(tayfaId: tayfaId, olustur: olustur);

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    await ref.read(etkinlikListesiProvider(tayfaId).notifier).yenile();
  }

  @override
  TayfaModuluGirisi get gezinmeGirisi => const TayfaModuluGirisi(
    ikon: Icons.event_outlined,
    etiket: _etiket,
    altYol: Adresler.etkinliklerYolu,
  );
}

String _etiket(BuildContext context) =>
    AppLocalizations.of(context).tayfa_ana_etkinlikler_baslik;

/// Etkinlik kimliği rota parametresi.
const String _etkinlikIdParametresi = 'etkinlikId';

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi] ?? '';

String _etkinlikId(GoRouterState state) =>
    state.pathParameters[_etkinlikIdParametresi] ?? '';

/// "Etkinlik aç" kısayolunun eylemi: oluşturma sihirbazını açar
/// (ADR-0015 §1, §3). `shell/kayitlar.dart` modüle bununla verir.
void etkinlikOlusturmayiAc(BuildContext context, String tayfaId) =>
    context.go(Adresler.etkinlikOlustur(tayfaId));
