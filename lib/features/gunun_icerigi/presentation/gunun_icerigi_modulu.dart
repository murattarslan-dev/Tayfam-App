import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/features/gunun_icerigi/application/gunun_icerigi.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/gunun_icerigi_karti.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/havuz_ekrani.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/ortak.dart';
import 'package:tayfam/features/gunun_icerigi/presentation/silinenler_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Günün içeriği modülü (`daily`; ADR-0002, Tayfam-Api ADR-0027 §5).
///
/// Rotalar `/t/<tayfaId>/gunun-icerigi` (havuz) ve
/// `/t/<tayfaId>/gunun-icerigi/silinenler`. Ana sayfadaki kartı modül
/// bölümü değil, `daily` ana sayfa bileşenidir ([GununIcerigiBileseni]);
/// modül kapalıysa sunucunun `modules` alanına göre "Oluştur"da da
/// görünmez.
class GununIcerigiModulu implements TayfaModule {
  const GununIcerigiModulu();

  @override
  String get sunucuAnahtari => Module.daily.wire;

  @override
  List<RouteBase> get rotalar => [
    GoRoute(
      path: gununIcerigiYolu,
      builder: (context, state) => HavuzEkrani(tayfaId: _tayfaId(state)),
      routes: [
        GoRoute(
          path: silinenlerYolu,
          builder: (context, state) =>
              SilinenlerEkrani(tayfaId: _tayfaId(state)),
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
    ikon: Icons.format_quote,
    baslik: _olusturBaslik,
    aciklama: _olusturAciklama,
    izinli: _yonetebilir,
    ac: _havuzuAc,
  );

  @override
  KurulumAdimi? get kurulumAdimi => null;

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    ref.invalidate(bugunkuIcerikProvider(tayfaId));
  }
}

String _tayfaId(GoRouterState state) =>
    state.pathParameters[Adresler.tayfaIdParametresi]!;

String _olusturBaslik(BuildContext context) =>
    AppLocalizations.of(context).gunun_icerigi_olustur_baslik;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).gunun_icerigi_olustur_aciklama;

/// Yalnızca sadeleştirir; yetkiyi sunucu verir (kesin kural 5).
bool _yonetebilir(TayfaYetkisi yetki) => yetki.yonetimde;

void _havuzuAc(BuildContext context, String tayfaId) =>
    context.go(gununIcerigiAdresi(tayfaId));

/// Ana sayfadaki "Günün içeriği" bileşeni (`daily`, `kind: module`).
/// Kartı `GET …/daily/today`'den çizer; ayarı yoktur.
final class GununIcerigiBileseni implements AnaSayfaBileseni {
  const GununIcerigiBileseni();

  @override
  String get anahtar => 'daily';

  @override
  IconData get ikon => Icons.format_quote;

  @override
  String ad(BuildContext context) =>
      AppLocalizations.of(context).gunun_icerigi_ad;

  @override
  String aciklama(BuildContext context) =>
      AppLocalizations.of(context).gunun_icerigi_aciklama;

  @override
  Widget kart(BuildContext context, String tayfaId, HomeWidget bilesen) =>
      GununIcerigiKarti(tayfaId: tayfaId);

  @override
  Future<void> yenile(WidgetRef ref, String tayfaId) async {
    ref.invalidate(bugunkuIcerikProvider(tayfaId));
  }

  @override
  BilesenAyari? get ayar => null;
}
