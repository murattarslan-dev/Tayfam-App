import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlikler_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Tayfa sekmesinin kökündeki rota parametresi (`shell/yonlendirici.dart`
/// ile aynı; özellikler `shell/`'i import edemez).
const String _tayfaIdParametresi = 'tayfaId';

/// Etkinlik kimliği rota parametresi.
const String _etkinlikIdParametresi = 'etkinlikId';

/// Etkinlik modülü (`events`, ADR-0002, ADR-0015 §3). Rotaları
/// `/t/<tayfaId>/` altındadır:
///
/// - `etkinlikler`: bitmemiş etkinlikler,
/// - `etkinlikler/yeni`: oluşturma sihirbazı,
/// - `etkinlikler/<etkinlikId>`: detay,
/// - `etkinlikler/<etkinlikId>/duzenle`: düzenleme.
///
/// Görünürlüğe sunucunun `modules` alanı karar verir; tayfa ana
/// sayfasındaki "Yaklaşan etkinlikler" bölümü duyuru paketindedir.
class EtkinlikModulu implements TayfaModule {
  const EtkinlikModulu();

  @override
  String get sunucuAnahtari => 'events';

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.etkinliklerYolu,
      builder: (context, state) =>
          EtkinliklerEkrani(tayfaId: _tayfaId(state)),
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
      const SizedBox.shrink();

  @override
  TayfaModuluGirisi get gezinmeGirisi => const TayfaModuluGirisi(
    ikon: Icons.event,
    etiket: _etiket,
    altYol: Adresler.etkinliklerYolu,
  );
}

String _etiket(BuildContext context) =>
    AppLocalizations.of(context).etkinlik_modul_adi;

String _tayfaId(GoRouterState state) =>
    state.pathParameters[_tayfaIdParametresi] ?? '';

String _etkinlikId(GoRouterState state) =>
    state.pathParameters[_etkinlikIdParametresi] ?? '';
