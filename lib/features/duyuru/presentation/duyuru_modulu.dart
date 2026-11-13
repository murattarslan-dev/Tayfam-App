import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/duyuru/application/duyuru_listesi_notifier.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_bolumu.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ekrani.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ortak.dart';
import 'package:tayfam/features/duyuru/presentation/duyurular_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Duyuru rotasındaki duyuru kimliği parametresinin adı.
const String duyuruIdParametresi = 'duyuruId';

/// Duyuru modülü (`announcements`; ADR-0002, ADR-0015 §2).
///
/// Rotalar `/t/<tayfaId>/duyurular` ve `/t/<tayfaId>/duyurular/<duyuruId>`;
/// tayfa ana sayfasındaki bölümü "Duyurular"dır. Modül kapalıysa sunucunun
/// `modules` alanına göre hiç görünmez.
class DuyuruModulu implements TayfaModule {
  const DuyuruModulu();

  @override
  String get sunucuAnahtari => Module.announcements.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.duyurularYolu,
      builder: (context, state) => DuyurularEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: ':$duyuruIdParametresi',
          builder: (context, state) => DuyuruEkrani(
            tayfaId: _tayfaId(state),
            duyuruId: state.pathParameters[duyuruIdParametresi]!,
          ),
        ),
      ],
    ),
  ];

  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      DuyuruBolumu(tayfaId: tayfaId);

  @override
  Widget? anaSayfaOneCikan(BuildContext context, String tayfaId) => null;

  @override
  OlusturmaSecenegi? get olusturmaSecenegi => const OlusturmaSecenegi(
    ikon: Icons.campaign_outlined,
    baslik: _olusturBaslik,
    aciklama: _olusturAciklama,
    izinli: _duyuruYazabilir,
    ac: _duyuruYaz,
  );

  @override
  KurulumAdimi? get kurulumAdimi => const KurulumAdimi(
    baslik: _kurulumBaslik,
    aciklama: _kurulumAciklama,
    tamamMi: _sabitDuyuruVar,
    ac: _duyuruYaz,
  );

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    await ref.read(duyuruListesiProvider(tayfaId).notifier).yenile();
  }
}

String _olusturBaslik(BuildContext context) =>
    AppLocalizations.of(context).duyuru_yaz;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).duyuru_olustur_aciklama;

String _kurulumBaslik(BuildContext context) =>
    AppLocalizations.of(context).duyuru_kurulum_baslik;

String _kurulumAciklama(BuildContext context) =>
    AppLocalizations.of(context).duyuru_kurulum_aciklama;

/// Duyuruyu moderatör ve yönetici yazar (ADR-0015 §2). Yalnızca sadeleştirir.
bool _duyuruYazabilir(TayfaYetkisi yetki) => yetki.yonetimde;

void _duyuruYaz(BuildContext context, String tayfaId) =>
    unawaited(duyuruFormunuAc(context, tayfaId: tayfaId));

/// Kurulum adımı: sabitlenmiş en az bir duyuru var (sunucudan gelen liste).
bool? _sabitDuyuruVar(WidgetRef ref, String tayfaId) => ref
    .watch(duyuruListesiProvider(tayfaId))
    .value
    ?.ogeler
    .any((d) => d.pinned);

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;
