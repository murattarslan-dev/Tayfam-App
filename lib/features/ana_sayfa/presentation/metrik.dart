import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/features/istatistik/istatistik.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Ana sayfa metriğinin kaynağı. Ana sayfa verisi (`HomeMetricValue`)
/// kaynağı taşımaz; anahtardan çıkarılır (sözleşme: `TayfaStatMetricKey`):
/// tek parça ortak metrik, üç parça günlük istatistiği; iki parça türün
/// tanımında o anahtarlı bir ölçüm varsa ölçüm, yoksa türün ortak
/// metriğidir.
TayfaStatSource metrikKaynagi(String anahtar, Katalog? katalog) {
  final parcalar = anahtar.split('.');
  switch (parcalar.length) {
    case 1:
      return TayfaStatSource.common;
    case 2:
      final tur = katalog?.tur(parcalar.first);
      for (final b in tur?.definition.components ?? const <CatalogComponent>[]) {
        if (b.kind == 'measure' && b.key == parcalar[1]) {
          return TayfaStatSource.measure;
        }
      }
      return TayfaStatSource.common;
    case 3:
      return TayfaStatSource.log;
    default:
      return TayfaStatSource.unknown;
  }
}

/// Ana sayfadaki bir metriğin gösterimi (adı, değeri, okunuşu); metrik bu
/// sürümde tanınmıyorsa `null`.
MetrikGorunumu? anaSayfaMetrigi(
  AppLocalizations m, {
  required String anahtar,
  required double deger,
  required Katalog? katalog,
  required String dil,
}) => metrikGorunumuAnahtarla(
  m,
  anahtar: anahtar,
  kaynak: metrikKaynagi(anahtar, katalog),
  deger: deger,
  katalog: katalog,
  dil: dil,
);

/// Değere katkı veren etkinlik sayısı yazılır mı: ortak `events`
/// metriğinde sayı değerin kendisidir, yazılmaz.
bool etkinlikSayisiYazilsin(String anahtar, Katalog? katalog) =>
    anahtar.split('.').last != 'events' ||
    metrikKaynagi(anahtar, katalog) != TayfaStatSource.common;
