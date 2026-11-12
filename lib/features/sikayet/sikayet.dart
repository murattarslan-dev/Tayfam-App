/// Şikâyet ve tayfa moderasyonu özelliğinin dışa açık dosyası (ADR-0002,
/// ADR-0018 §8):
///
/// - ortak "Şikâyet et" sayfası ([sikayetSayfasiniAc], [SikayetHedefi]);
///   içerik menüleri bunu tek satırla çağırır,
/// - birebir mesaj şikâyeti ([birebirMesajiSikayetEt]; sohbet paketi
///   mesajın kimliği ve cihazdaki metniyle çağırır),
/// - tayfa ayarları altındaki moderasyon kuyruğu: rotası
///   ([moderasyonRotalari], `tayfaYonetimRotalari(ekRotalar:)`'a verilir)
///   ve ayarlar ekranındaki girişinin parçaları ([moderasyonGirisIkonu],
///   [moderasyonGirisEtiketi], [moderasyonAdresi]; `shell/kayitlar.dart`
///   bunlarla `yonetimEkGirisleriProvider`'ı override eder).
///
/// Şikâyet özelliği tayfa yönetimini import etmez (o, tayfa menüsündeki
/// "Tayfayı şikâyet et" için bunu import eder; döngü olmaz).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/sikayet/presentation/moderasyon_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

export 'package:tayfam/core/api/gen/models.dart' show ReportTargetType;
export 'package:tayfam/features/sikayet/application/sikayet_hedefi.dart'
    show SikayetHedefi;
export 'package:tayfam/features/sikayet/presentation/moderasyon_ekrani.dart'
    show moderasyonAdresi;
export 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart'
    show gerekceMetni;
export 'package:tayfam/features/sikayet/presentation/sikayet_sayfasi.dart'
    show birebirMesajiSikayetEt, sikayetSayfasiniAc;

/// Moderasyon kuyruğunun `ayarlar/` altındaki rotası.
final List<RouteBase> moderasyonRotalari = [
  GoRoute(
    path: moderasyonYolu,
    builder: (context, state) => ModerasyonKuyruguEkrani(
      tayfaId: state.pathParameters[Adresler.tayfaIdParametresi]!,
    ),
  ),
];

/// Ayarlar ekranındaki moderasyon kuyruğu girişinin ikonu.
const IconData moderasyonGirisIkonu = Icons.flag_outlined;

/// Ayarlar ekranındaki moderasyon kuyruğu girişinin etiketi.
String moderasyonGirisEtiketi(BuildContext context) =>
    AppLocalizations.of(context).sikayet_kuyruk_baslik;
