import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/materyal/application/materyal.dart';
import 'package:tayfam/features/materyal/presentation/detay_ekrani.dart';
import 'package:tayfam/features/materyal/presentation/liste_ekrani.dart';
import 'package:tayfam/features/materyal/presentation/materyal_karti.dart';
import 'package:tayfam/features/materyal/presentation/ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Materyal rotasındaki materyal kimliği parametresinin adı.
const String materyalIdParametresi = 'materyalId';

/// Materyal kütüphanesi modülü (`materials`; ADR-0002, App ADR-0033 §2,
/// Tayfam-Api ADR-0040 §3): Eğitim tayfalarının https bağlantıları ve
/// kendi not fotoğrafları.
///
/// Rotalar `/t/<tayfaId>/materyal` (liste) ve `…/materyal/<materyalId>`
/// (detay). Ana sayfadaki kartı modül bölümü değil, `materials` ana sayfa
/// bileşenidir ([MateryalBileseni]); modül kapalıysa sunucunun `modules`
/// alanına göre görünmez.
class MateryalModulu implements TayfaModule {
  const MateryalModulu();

  @override
  String get sunucuAnahtari => Module.materials.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.materyalYolu,
      builder: (context, state) =>
          MateryalListeEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: ':$materyalIdParametresi',
          builder: (context, state) => MateryalDetayEkrani(
            tayfaId: _tayfaId(state),
            materyalId: state.pathParameters[materyalIdParametresi]!,
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
  OlusturmaSecenegi? get olusturmaSecenegi => const OlusturmaSecenegi(
    ikon: Icons.menu_book_outlined,
    baslik: _olusturBaslik,
    aciklama: _olusturAciklama,
    izinli: _herUye,
    ac: _ekle,
  );

  @override
  KurulumAdimi? get kurulumAdimi => null;

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) =>
      _yenile(ref, tayfaId);
}

String _olusturBaslik(BuildContext context) =>
    AppLocalizations.of(context).materyal_olustur;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).materyal_olustur_aciklama;

/// Her üye materyal ekleyebilir; yetkiyi sunucu verir (kesin kural 5).
bool _herUye(TayfaYetkisi yetki) => true;

void _ekle(BuildContext context, String tayfaId) =>
    unawaited(materyalFormunuAc(context, tayfaId: tayfaId));

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;

Future<void> _yenile(WidgetRef ref, String tayfaId) async {
  final liste = materyalListesiProvider(anaMateryalListesi(tayfaId));
  ref.invalidate(liste);
}

/// Ana sayfadaki "Materyaller" bileşeni (`materials`, `kind: module`): son
/// eklenenler. Ayarı yoktur.
final class MateryalBileseni implements AnaSayfaBileseni {
  const MateryalBileseni();

  @override
  String get anahtar => Module.materials.wire;

  @override
  IconData get ikon => Icons.menu_book_outlined;

  @override
  String ad(BuildContext context) => AppLocalizations.of(context).materyal_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).materyal_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      MateryalKarti(tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) => _yenile(ref, tayfaId);

  @override
  BilesenAyari? get ayar => null;
}
