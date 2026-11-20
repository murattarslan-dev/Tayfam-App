/// Tayfa ana sayfası bileşenlerinin dışa açık dosyası (App ADR-0024 §6;
/// Tayfam-Api ADR-0027, #268):
///
/// - Gösterim bileşenleri ([IstatistikKartiBileseni], [HedefKartiBileseni],
///   [GeriSayimKartiBileseni], [SampiyonlarKartiBileseni],
///   [GunlukOzetiKartiBileseni]) `shell/kayitlar.dart`'taki ana sayfa
///   bileşeni kaydına eklenir. Bölümler (`upcoming`, `announcements`,
///   `polls`, `questions`) çekirdekteki `anaSayfaBolumleri`'dir.
/// - [anaSayfaDuzeniRotalari] tayfa ayarlarının altına eklenir; girişi
///   (yalnızca yönetici) [anaSayfaGirisIkonu], [anaSayfaGirisEtiketi] ve
///   [anaSayfaDuzeniAdresi] ile kurulur.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/ana_sayfa/presentation/duzen_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

export 'package:tayfam/features/ana_sayfa/presentation/gosterim_bilesenleri.dart';

/// Ana sayfa düzeni ekranının tayfa ayarları altındaki yolu.
const String anaSayfaDuzeniYolu = 'ana-sayfa';

/// [tayfaId] tayfasının ana sayfa düzeni ekranı.
String anaSayfaDuzeniAdresi(String tayfaId) =>
    '${Adresler.tayfaAyarlari(tayfaId)}/$anaSayfaDuzeniYolu';

/// Tayfa ayarlarındaki girişin ikonu.
const IconData anaSayfaGirisIkonu = Icons.dashboard_customize_outlined;

/// Tayfa ayarlarındaki girişin etiketi.
String anaSayfaGirisEtiketi(BuildContext context) =>
    AppLocalizations.of(context).anasayfa_duzen_baslik;

/// Ana sayfa düzeni ekranının rotası (tayfa ayarlarının altında).
final List<RouteBase> anaSayfaDuzeniRotalari = [
  GoRoute(
    path: anaSayfaDuzeniYolu,
    builder: (context, state) => AnaSayfaDuzenEkrani(
      tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
    ),
  ),
];
