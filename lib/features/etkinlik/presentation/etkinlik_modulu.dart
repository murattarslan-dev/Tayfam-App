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
import 'package:tayfam/features/etkinlik/presentation/siradaki_etkinlik_karti.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Etkinlik modülü (`events`; ADR-0002, ADR-0015 §1, §3).
///
/// Rotaları `/t/<tayfaId>/` altındadır: `etkinlikler` (liste),
/// `etkinlikler/yeni` (oluşturma sihirbazı), `etkinlikler/<etkinlikId>`
/// (detay) ve `etkinlikler/<etkinlikId>/duzenle`. Tayfa ana sayfasındaki
/// bölümü "Yaklaşan etkinlikler"dir; mor üst bölüme taşan "Sıradaki"
/// kartı da bu modülündür. Modül kapalıysa sunucunun `modules` alanına göre
/// hiç görünmez. [olustur] verilince ana sayfanın "Oluştur" sayfasında
/// "Etkinlik aç" ve yeni tayfanın kurulum kartında "İlk etkinliği aç"
/// görünür ([etkinlikOlusturmayiAc]).
class EtkinlikModulu implements TayfaModule {
  const EtkinlikModulu({this.olustur});

  /// "Etkinlik aç"ın eylemi; `null` ise seçenek yok.
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
      EtkinlikBolumu(tayfaId: tayfaId);

  @override
  Widget? anaSayfaOneCikan(BuildContext context, String tayfaId) =>
      SiradakiEtkinlikKarti(tayfaId: tayfaId);

  @override
  OlusturmaSecenegi? get olusturmaSecenegi {
    final olustur = this.olustur;
    if (olustur == null) return null;
    return OlusturmaSecenegi(
      ikon: Icons.event_outlined,
      baslik: _olusturBaslik,
      aciklama: _olusturAciklama,
      izinli: _etkinlikAcabilir,
      ac: olustur,
    );
  }

  @override
  KurulumAdimi? get kurulumAdimi {
    final olustur = this.olustur;
    if (olustur == null) return null;
    return KurulumAdimi(
      baslik: _kurulumBaslik,
      aciklama: _kurulumAciklama,
      tamamMi: _etkinlikVar,
      ac: olustur,
    );
  }

  @override
  Future<void> anaSayfayiYenile(WidgetRef ref, String tayfaId) async {
    await ref.read(etkinlikListesiProvider(tayfaId).notifier).yenile();
  }
}

String _olusturBaslik(BuildContext context) =>
    AppLocalizations.of(context).tayfa_ana_etkinlik_ac;

String _olusturAciklama(BuildContext context) =>
    AppLocalizations.of(context).etkinlik_olustur_aciklama;

String _kurulumBaslik(BuildContext context) =>
    AppLocalizations.of(context).etkinlik_kurulum_baslik;

String _kurulumAciklama(BuildContext context) =>
    AppLocalizations.of(context).etkinlik_kurulum_aciklama;

/// Moderatör, yönetici ya da tayfa izin veriyorsa her üye (sözleşme:
/// `members_can_create_events`). Yalnızca sadeleştirir.
bool _etkinlikAcabilir(TayfaYetkisi yetki) =>
    yetki.yonetimde || yetki.uyelerEtkinlikAcabilir;

/// Kurulum adımı: tayfanın en az bir yaklaşan etkinliği var (sunucudan
/// gelen liste; yalnızca bellek).
bool? _etkinlikVar(WidgetRef ref, String tayfaId) =>
    ref.watch(etkinlikListesiProvider(tayfaId)).value?.ogeler.isNotEmpty;

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
