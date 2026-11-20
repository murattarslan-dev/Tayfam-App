import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/metin/sure.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Bir istatistik satırının gösterimi: metriğin adı, değeri ve değerin
/// ekran okuyucu metni.
@immutable
final class MetrikGorunumu {
  const MetrikGorunumu({
    required this.ad,
    required this.deger,
    required this.okunus,
  });

  /// Metriğin adı: ortak metrikte çeviri, türe bağlı metrikte katalogdaki
  /// tür ve bileşen adları (düz metin; ADR-0024 §2).
  final String ad;

  /// Türkçe biçimli değer (`1.250`, `12,5 km`, süre `12:30:00`).
  final String deger;

  /// Değerin ekran okuyucu metni (süre "12 saat 30 dakika" diye okunur).
  final String okunus;
}

/// Ortak metriklerin anahtarları (sözleşme: `TayfaStatMetricKey`).
const String _etkinlikMetrigi = 'events';
const String _sureMetrigi = 'duration';

String? _ortakMetrikAdi(AppLocalizations m, String anahtar) =>
    switch (anahtar) {
      _etkinlikMetrigi => m.istatistik_metrik_events,
      'attended' => m.istatistik_metrik_attended,
      'participants' => m.istatistik_metrik_participants,
      _sureMetrigi => m.istatistik_metrik_duration,
      _ => null,
    };

/// Değere katkı veren etkinlik sayısı satırda yazılır mı: `events`
/// metriğinde sayı değerin kendisidir, yazılmaz.
bool etkinlikSayisiYazilir(TayfaStat stat) =>
    stat.metricKey.split('.').last != _etkinlikMetrigi ||
    stat.source != TayfaStatSource.common;

/// [stat]'ın gösterimi; metrik tanınmıyorsa (bilinmeyen kaynak ya da
/// ortak metrik, katalogda bulunmayan tür, bileşen ya da alan) `null`:
/// satır gösterilmez.
MetrikGorunumu? metrikGorunumu(
  AppLocalizations m,
  TayfaStat stat,
  Katalog? katalog,
  String dil,
) => metrikGorunumuAnahtarla(
  m,
  anahtar: stat.metricKey,
  kaynak: stat.source,
  deger: stat.value,
  katalog: katalog,
  dil: dil,
);

/// Anahtar, kaynak ve değerle [metrikGorunumu] (kişisel katkılar için).
///
/// Anahtar biçimleri (sözleşme: `TayfaStatMetricKey`): ortak metrik
/// (`events`, `attended`, `participants`, `duration` dakika), türün ortak
/// metriği (`<tür>.<metrik>`), ölçüm (`<tür>.<ölçüm>`, birimi tür
/// tanımında) ya da günlük istatistiği (`<tür>.<günlük>.<stat>`; stat
/// `count`, `distinct_<alan>`, `sum_<alan>`). Türün ortak metriği ile aynı
/// adlı ölçümü kaynak ayırır.
MetrikGorunumu? metrikGorunumuAnahtarla(
  AppLocalizations m, {
  required String anahtar,
  required TayfaStatSource kaynak,
  required double deger,
  required Katalog? katalog,
  required String dil,
}) {
  if (!deger.isFinite) return null;
  final parcalar = anahtar.split('.');
  switch (kaynak) {
    case TayfaStatSource.common:
      final metrik = parcalar.last;
      final ad = _ortakMetrikAdi(m, metrik);
      if (ad == null || parcalar.length > 2) return null;
      final (metin, okunus) = _ortakDeger(m, metrik, deger);
      if (parcalar.length == 1) {
        return MetrikGorunumu(ad: ad, deger: metin, okunus: okunus);
      }
      final turAdi = _turAdi(katalog, parcalar.first, dil);
      if (turAdi == null) return null;
      return MetrikGorunumu(
        ad: m.istatistik_metrik_turlu(turAdi, ad),
        deger: metin,
        okunus: okunus,
      );
    case TayfaStatSource.measure:
      if (parcalar.length != 2) return null;
      final tur = katalog?.tur(parcalar.first);
      final turAdi = _turAdi(katalog, parcalar.first, dil);
      final olcum = _bilesen(tur, 'measure', parcalar[1]);
      final olcumAdi = katalogAdi(olcum?.labels, dil);
      if (turAdi == null || olcum == null || olcumAdi == null) return null;
      final birim = olcum.params?['unit'];
      final metin = _birimli(m, deger, birim is String ? birim : null);
      return MetrikGorunumu(
        ad: m.istatistik_metrik_turlu(turAdi, olcumAdi),
        deger: metin,
        okunus: metin,
      );
    case TayfaStatSource.log:
      if (parcalar.length != 3) return null;
      final tur = katalog?.tur(parcalar.first);
      final turAdi = _turAdi(katalog, parcalar.first, dil);
      final gunluk = _bilesen(tur, 'log', parcalar[1]);
      final gunlukAdi = katalogAdi(gunluk?.labels, dil);
      if (turAdi == null || gunluk == null || gunlukAdi == null) return null;
      final gunlukMetrigi = _gunlukMetrigi(
        m,
        gunluk,
        gunlukAdi,
        parcalar[2],
        dil,
      );
      if (gunlukMetrigi == null) return null;
      final metin = _birimli(m, deger, gunlukMetrigi.birim);
      return MetrikGorunumu(
        ad: m.istatistik_metrik_turlu(turAdi, gunlukMetrigi.ad),
        deger: metin,
        okunus: metin,
      );
    case TayfaStatSource.unknown:
      return null;
  }
}

String? _turAdi(Katalog? katalog, String anahtar, String dil) =>
    katalogAdi(katalog?.tur(anahtar)?.labels, dil);

/// Türün tanımındaki [tur] türünde, [anahtar] anahtarlı bileşen.
CatalogComponent? _bilesen(CatalogEventType? tur, String kind, String anahtar) {
  for (final b in tur?.definition.components ?? const <CatalogComponent>[]) {
    if (b.kind == kind && b.key == anahtar) return b;
  }
  return null;
}

/// Günlük istatistiğinin adı ve (toplamda) alanın birimi.
({String ad, String? birim})? _gunlukMetrigi(
  AppLocalizations m,
  CatalogComponent gunluk,
  String gunlukAdi,
  String stat,
  String dil,
) {
  if (stat == 'count') {
    return (ad: m.istatistik_gunluk_kayit(gunlukAdi), birim: null);
  }
  const farkli = 'distinct_';
  const toplam = 'sum_';
  final bool toplamMi;
  final String alanAnahtari;
  if (stat.startsWith(farkli)) {
    toplamMi = false;
    alanAnahtari = stat.substring(farkli.length);
  } else if (stat.startsWith(toplam)) {
    toplamMi = true;
    alanAnahtari = stat.substring(toplam.length);
  } else {
    return null;
  }
  final alan = _gunlukAlani(gunluk, alanAnahtari);
  if (alan == null) return null;
  final alanAdi = katalogAdi(alan.labels, dil);
  if (alanAdi == null) return null;
  return toplamMi
      ? (ad: m.istatistik_gunluk_toplam(gunlukAdi, alanAdi), birim: alan.unit)
      : (ad: m.istatistik_gunluk_farkli(gunlukAdi, alanAdi), birim: null);
}

/// Günlük bileşeninin `fields` parametresindeki [anahtar] alanı; tanım
/// bozuksa `null`.
CatalogField? _gunlukAlani(CatalogComponent gunluk, String anahtar) {
  final alanlar = gunluk.params?['fields'];
  if (alanlar is! List<Object?>) return null;
  for (final ham in alanlar) {
    if (ham is! Map<String, Object?> || ham['key'] != anahtar) continue;
    try {
      return CatalogField.fromJson(ham);
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// Ortak metriğin değeri ve okunuşu: süre dakikadır ve `sureMetni` ile
/// yazılır; diğerleri sayıdır.
(String, String) _ortakDeger(AppLocalizations m, String metrik, double deger) {
  if (metrik == _sureMetrigi) {
    final saniye = deger * Duration.secondsPerMinute;
    return (sureMetni(m, saniye), sureOkunusu(m, saniye));
  }
  final sayi = istatistikSayisi(m, deger);
  return (sayi, sayi);
}

/// Birimli değer (`12,5 km`); birim tanınmıyorsa yalnızca sayı.
String _birimli(AppLocalizations m, double deger, String? birim) {
  final sayi = istatistikSayisi(m, deger);
  final birimAdi = katalogBirimAdi(m, birim);
  return birimAdi == null ? sayi : m.katalog_birimli_deger(sayi, birimAdi);
}

/// Türkçe biçimli sayı (`1.250`, `12,5`; en çok 3 ondalık).
String istatistikSayisi(AppLocalizations m, double sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);
