import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/kutuphane/application/kutuphane.dart';
import 'package:tayfam/features/kutuphane/presentation/kalem_ekrani.dart';
import 'package:tayfam/features/kutuphane/presentation/kutuphane_karti.dart';
import 'package:tayfam/features/kutuphane/presentation/liste_ekrani.dart';
import 'package:tayfam/features/kutuphane/presentation/odunclerim_ekrani.dart';
import 'package:tayfam/features/kutuphane/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ortak kütüphane modülü (`library`; ADR-0002, App ADR-0033 §2,
/// Tayfam-Api ADR-0040 §1).
///
/// Rotalar `/t/<tayfaId>/kutuphane` (liste), `…/kutuphane/odunclerim` ve
/// `…/kutuphane/<kalemId>` (detay). Ana sayfadaki kartı modül bölümü değil,
/// `library` ana sayfa bileşenidir ([KutuphaneBileseni]); modül kapalıysa
/// sunucunun `modules` alanına göre görünmez.
class KutuphaneModulu implements TayfaModule {
  const KutuphaneModulu();

  @override
  String get sunucuAnahtari => Module.library_.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.kutuphaneYolu,
      builder: (context, state) =>
          KutuphaneListeEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: odunclerimYolu,
          builder: (context, state) =>
              OdunclerimEkrani(tayfaId: _tayfaId(state)),
        ),
        GoRoute(
          path: ':$kalemIdParametresi',
          builder: (context, state) => KalemEkrani(
            tayfaId: _tayfaId(state),
            kalemId: state.pathParameters[kalemIdParametresi]!,
          ),
        ),
      ],
    ),
  ];

  /// Kart ana sayfa bileşeni kaydından çizilir; modülün ayrı bölümü yok.
  @override
  Widget anaSayfaKarti(BuildContext context, String tayfaId) =>
      const SizedBox.shrink();

  @override
  Widget? anaSayfaOneCikan(BuildContext context, String tayfaId) => null;

  @override
  OlusturmaSecenegi? get olusturmaSecenegi => null;

  @override
  KurulumAdimi? get kurulumAdimi => null;

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    ref.invalidate(kalemlerProvider);
  }
}

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;

/// Ana sayfadaki "Ortak eşya" bileşeni (`library`, `kind: module`). Kartı
/// `GET …/library/items`'tan çizer; ayarı yoktur.
final class KutuphaneBileseni implements AnaSayfaBileseni {
  const KutuphaneBileseni();

  @override
  String get anahtar => 'library';

  @override
  IconData get ikon => Icons.inventory_2_outlined;

  @override
  String ad(BuildContext context) => AppLocalizations.of(context).kutuphane_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).kutuphane_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      KutuphaneKarti(tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) async {
    ref.invalidate(kalemlerProvider);
  }

  @override
  BilesenAyari? get ayar => null;
}
