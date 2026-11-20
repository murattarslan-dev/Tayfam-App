import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/ikonlar.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Katalogda bulunmayan rozetin genel ikonu (ADR-0024 §2).
const IconData rozetGenelIkonu = Icons.military_tech;

/// Bir kazanılmış rozetin gösterimi: ad, ikon, yıl ve kazanma kuralı.
@immutable
final class RozetGorunumu {
  const RozetGorunumu({
    required this.ad,
    required this.ikon,
    required this.yil,
    required this.kural,
  });

  /// Katalogdaki ad (düz metin, kırpılmış); rozet katalogda yoksa anahtarı.
  final String ad;

  final IconData ikon;

  /// Yıllık rozette kazanıldığı takvim yılı.
  final int? yil;

  /// Kazanma kuralının anlaşılır metni; açıklanamıyorsa `null` (tanınmayan
  /// kural, katalogda bulunmayan tür ya da metrik).
  final String? kural;
}

/// [rozet]'in gösterimi. Ad ve ikon [katalog]'daki aynı anahtarlı
/// tanımdan; tanım yoksa genel ikon ve anahtar (biçimi geçersizse genel
/// ad). Emekli rozet de aynı gösterilir (kazanılmış rozet kalır).
RozetGorunumu rozetGorunumu(
  AppLocalizations m,
  EarnedBadge rozet,
  Katalog? katalog,
  String dil,
) {
  final anahtar = rozet.badgeKey;
  final tanim = katalog?.rozet(anahtar);
  final yil = rozet.year;
  return RozetGorunumu(
    ad:
        katalogAdi(tanim?.labels, dil) ??
        (katalogAnahtariMi(anahtar) ? anahtar : m.rozet_genel_ad),
    ikon: tanim == null
        ? rozetGenelIkonu
        : katalogIkonlari[tanim.icon] ?? rozetGenelIkonu,
    yil: yil != null && yil > 0 && yil < 10000 ? yil : null,
    kural: tanim == null ? null : rozetKuralMetni(m, tanim.rule, katalog, dil),
  );
}

/// Rozetin görünen adı: yıllıksa "ad · yıl".
String rozetAdMetni(AppLocalizations m, RozetGorunumu g) =>
    g.yil == null ? g.ad : m.rozet_ad_yil(g.ad, '${g.yil}');

/// Ekran okuyucunun rozeti okuyuşu: "ad, yıl" (yılsızsa yalnızca ad).
String rozetOkunusu(AppLocalizations m, RozetGorunumu g) =>
    g.yil == null ? g.ad : m.rozet_okunus_yil(g.ad, '${g.yil}');

/// Ortak metrikler (Tayfam-Api ADR-0039, uygulama notları); `duration`
/// dakikadır.
const String _sureMetrigi = 'duration';

String? _ortakMetrikAdi(AppLocalizations m, String metrik) => switch (metrik) {
  'events' => m.rozet_metrik_etkinlik,
  'attended' => m.rozet_metrik_katilim,
  'participants' => m.rozet_metrik_katilimci,
  _sureMetrigi => m.rozet_metrik_sure,
  _ => null,
};

/// [kural]'ın kullanıcıya gösterilen metni (sözleşme: `CatalogBadgeRule`).
/// Tanınmayan kural, katalogda bulunmayan tür ya da metrik için `null`:
/// rozet açıklamasız gösterilir. Tür ve bileşen adları katalog metnidir
/// (düz metin; ADR-0024 §2).
String? rozetKuralMetni(
  AppLocalizations m,
  CatalogBadgeRule kural,
  Katalog? katalog,
  String dil,
) {
  String? turAdi(String anahtar) =>
      katalogAdi(katalog?.tur(anahtar)?.labels, dil);
  final tur = kural.eventType;
  switch (kural.kind) {
    case CatalogBadgeRuleKind.first:
      if (tur == null) return m.rozet_kural_ilk;
      final ad = turAdi(tur);
      return ad == null ? null : m.rozet_kural_ilk_tur(ad);
    case CatalogBadgeRuleKind.champion:
      if (tur == null) return m.rozet_kural_sampiyon;
      final ad = turAdi(tur);
      return ad == null ? null : m.rozet_kural_sampiyon_tur(ad);
    case CatalogBadgeRuleKind.threshold:
      final esik = _esikMetni(m, kural, katalog, dil);
      if (esik == null) return null;
      return switch (kural.period ?? CatalogBadgeRulePeriod.allTime) {
        CatalogBadgeRulePeriod.allTime => m.rozet_kural_esik_toplam(
          esik.metrik,
          esik.deger,
        ),
        CatalogBadgeRulePeriod.year => m.rozet_kural_esik_yillik(
          esik.metrik,
          esik.deger,
        ),
        CatalogBadgeRulePeriod.unknown => null,
      };
    case CatalogBadgeRuleKind.unknown:
      return null;
  }
}

/// Eşik kuralının metrik adı ve birimli eşik değeri.
({String metrik, String deger})? _esikMetni(
  AppLocalizations m,
  CatalogBadgeRule kural,
  Katalog? katalog,
  String dil,
) {
  final metrik = kural.metric;
  final deger = kural.value;
  if (metrik == null || deger == null || !deger.isFinite || deger < 0) {
    return null;
  }
  final parcalar = metrik.split('.');
  if (parcalar.length == 1) {
    final ad = _ortakMetrikAdi(m, metrik);
    if (ad == null) return null;
    return (metrik: ad, deger: _ortakDeger(m, metrik, deger));
  }
  if (parcalar.length != 2) return null;
  final tanim = katalog?.tur(parcalar[0]);
  final turAdi = katalogAdi(tanim?.labels, dil);
  if (tanim == null || turAdi == null) return null;
  final anahtar = parcalar[1];
  final ortak = _ortakMetrikAdi(m, anahtar);
  if (ortak != null) {
    return (
      metrik: m.rozet_metrik_turlu(turAdi, ortak),
      deger: _ortakDeger(m, anahtar, deger),
    );
  }
  // Türün ölçüm ya da günlük bileşeni: ad bileşenin `labels`'ından, birim
  // ölçümün `unit` parametresinden.
  for (final b in tanim.definition.components ?? const <CatalogComponent>[]) {
    if (b.key != anahtar) continue;
    final ad = katalogAdi(b.labels, dil);
    if (ad == null) return null;
    final birim = b.params?['unit'];
    final birimAdi = birim is String ? katalogBirimAdi(m, birim) : null;
    final sayi = _sayi(m, deger);
    return (
      metrik: m.rozet_metrik_turlu(turAdi, ad),
      deger: birimAdi == null ? sayi : m.katalog_birimli_deger(sayi, birimAdi),
    );
  }
  return null;
}

/// Ortak metriğin eşik değeri; süre dakikadır: tam saatse "sa", değilse
/// "dk" ile yazılır.
String _ortakDeger(AppLocalizations m, String metrik, double deger) {
  if (metrik != _sureMetrigi) return _sayi(m, deger);
  if (deger >= 60 && deger % 60 == 0) {
    return m.katalog_birimli_deger(_sayi(m, deger / 60), m.katalog_birim_hour);
  }
  return m.katalog_birimli_deger(_sayi(m, deger), m.katalog_birim_minute);
}

String _sayi(AppLocalizations m, double sayi) =>
    NumberFormat.decimalPattern(m.localeName).format(sayi);
