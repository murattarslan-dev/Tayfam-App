import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart' hide Material;
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/garaj/application/garaj.dart';
import 'package:tayfam/features/garaj/presentation/garaj_karti.dart';
import 'package:tayfam/features/garaj/presentation/ortak.dart';
import 'package:tayfam/features/garaj/presentation/tayfa_garaji_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Üye garajı modülü (`garage`; ADR-0002, App ADR-0033 §2, Tayfam-Api
/// ADR-0040 §4): üyelerin bu tayfada gösterdiği garajlar. Garajın kendisi
/// kişiye aittir ve profildedir (`/profil/garaj`).
///
/// Rota `/t/<tayfaId>/garaj`. Ana sayfadaki kartı modül bölümü değil,
/// `garage` ana sayfa bileşenidir ([GarajBileseni]); modül kapalıysa
/// sunucunun `modules` alanına göre görünmez.
class GarajModulu implements TayfaModule {
  const GarajModulu();

  @override
  String get sunucuAnahtari => Module.garage.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: Adresler.tayfaGarajiYolu,
      builder: (context, state) => TayfaGarajiEkrani(
        tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
      ),
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
    ikon: garajIkonu,
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
    AppLocalizations.of(context).garaj_olustur;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).garaj_olustur_aciklama;

/// Araç kişinin kendi garajına eklenir; sınırı sunucu verir.
bool _herUye(TayfaYetkisi yetki) => true;

void _ekle(BuildContext context, String tayfaId) =>
    unawaited(garajFormunuAc(context));

Future<void> _yenile(WidgetRef ref, String tayfaId) async {
  ref.invalidate(tayfaGarajiProvider(tayfaId));
}

/// Ana sayfadaki "Garaj" bileşeni (`garage`, `kind: module`): bu tayfada
/// görünen son araçlar. Ayarı yoktur.
final class GarajBileseni implements AnaSayfaBileseni {
  const GarajBileseni();

  @override
  String get anahtar => Module.garage.wire;

  @override
  IconData get ikon => garajIkonu;

  @override
  String ad(BuildContext context) => AppLocalizations.of(context).garaj_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).garaj_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      GarajKarti(tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) => _yenile(ref, tayfaId);

  @override
  BilesenAyari? get ayar => null;
}
