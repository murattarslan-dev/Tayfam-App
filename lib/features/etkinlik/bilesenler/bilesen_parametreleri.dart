import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';

/// Seçim değerinin en çok uzunluğu (sözleşme: `ComponentChoice.value`).
const int bilesenSecimDegeriEnCok = 40;

/// Bir bileşende organizatöre bırakılan seçim sayısının üst sınırı
/// (sözleşme: `choices`, `maxItems: 20`).
const int bilesenSecimEnCok = 20;

/// [bilesen]'in tür içindeki anahtarı (`CatalogComponent.key`; yoksa
/// `kind`). Bileşen uçlarındaki `{component_key}` budur.
String bilesenAnahtari(CatalogComponent bilesen) => bilesen.key ?? bilesen.kind;

/// Organizatöre bırakılan bir parametre (ADR-0031 §1; Tayfam-Api ADR-0037
/// §2): tanımda değer yerine `{"organizer_choice": [...], "default": ...}`
/// taşır. Seçenekler ve varsayılan metin halindedir (tam sayı seçenek
/// rakamlarıyla: `"3"`), sözleşmedeki `ComponentChoice.value` gibi.
@immutable
final class SecimliParametre {
  const SecimliParametre({
    required this.ad,
    required this.secenekler,
    required this.varsayilan,
  });

  /// Parametrenin adı (`mode`, `format`, `best_of`).
  final String ad;

  /// Tanımdaki seçenekler, tanımdaki sırayla; en az bir tane.
  final List<String> secenekler;

  /// Organizatör seçmezse geçerli olan seçenek; [secenekler]'den biridir.
  final String varsayilan;
}

String? _secenekMetni(Object? deger) {
  final metin = switch (deger) {
    final String s => s,
    final int i => '$i',
    _ => null,
  };
  if (metin == null ||
      metin.isEmpty ||
      metin.length > bilesenSecimDegeriEnCok) {
    return null;
  }
  return metin;
}

SecimliParametre? _secimli(String ad, Object? deger) {
  if (!katalogAnahtariMi(ad) || deger is! Map<String, Object?>) return null;
  final liste = deger['organizer_choice'];
  if (liste is! List<Object?>) return null;
  final secenekler = <String>[];
  for (final oge in liste) {
    final metin = _secenekMetni(oge);
    if (metin != null && !secenekler.contains(metin)) secenekler.add(metin);
  }
  if (secenekler.isEmpty) return null;
  final varsayilan = _secenekMetni(deger['default']);
  return SecimliParametre(
    ad: ad,
    secenekler: List.unmodifiable(secenekler),
    varsayilan: varsayilan != null && secenekler.contains(varsayilan)
        ? varsayilan
        : secenekler.first,
  );
}

/// [bilesen]'in organizatöre bırakılan parametreleri, ada göre (sunucunun
/// `EventComponentState.choices` sırası). Tanım girdidir: biçimi bozuk
/// seçim listesi atlanır.
List<SecimliParametre> secimliParametreler(CatalogComponent bilesen) {
  final params = bilesen.params;
  if (params == null) return const [];
  final adlar = params.keys.toList()..sort();
  return [
    for (final ad in adlar)
      if (_secimli(ad, params[ad]) case final secimli?) secimli,
  ];
}

/// Bir bileşenin tanımdaki parametrelerini güvenle okur (ADR-0024 §3:
/// parametreler girdi kabul edilir ve doğrulanır; tanınmayan parametre yok
/// sayılır). Yanlış tipte ya da sınır dışındaki değer yokmuş gibidir.
///
/// Organizatöre bırakılan parametre ([SecimliParametre]) geçerli
/// seçimiyle okunur: [metin] ve [tamSayi] seçilen (yoksa varsayılan)
/// seçeneği verir.
@immutable
final class BilesenParametreleri {
  const BilesenParametreleri(this._ham, [this._secimler = const {}]);

  final Map<String, Object?>? _ham;
  final Map<String, String> _secimler;

  Object? _deger(String ad) {
    final ham = _ham?[ad];
    final secimli = _secimli(ad, ham);
    if (secimli == null) return ham;
    final secilen = _secimler[ad];
    return secilen != null && secimli.secenekler.contains(secilen)
        ? secilen
        : secimli.varsayilan;
  }

  /// Mantıksal parametre; yoksa [varsayilan].
  bool mantik(String ad, {bool varsayilan = false}) {
    final deger = _deger(ad);
    return deger is bool ? deger : varsayilan;
  }

  /// Tam sayı parametre; [enAz]–[enCok] dışındaysa `null`.
  int? tamSayi(String ad, {int? enAz, int? enCok}) {
    final deger = switch (_deger(ad)) {
      final int i => i,
      final String s => int.tryParse(s),
      _ => null,
    };
    if (deger == null ||
        (enAz != null && deger < enAz) ||
        (enCok != null && deger > enCok)) {
      return null;
    }
    return deger;
  }

  /// Sayı parametre (`min`, `max`, `default_target`).
  num? sayi(String ad) {
    final deger = _deger(ad);
    return deger is num ? deger : null;
  }

  /// Metin parametre; [izinli] verilirse yalnızca o değerlerden biri.
  String? metin(String ad, {Set<String>? izinli}) {
    final deger = _deger(ad);
    if (deger is! String || deger.isEmpty) return null;
    if (izinli != null && !izinli.contains(deger)) return null;
    return deger;
  }

  /// Metin listesi parametre (`presets`, `stat`); metin olmayan öğe atlanır.
  List<String> metinler(String ad) => [
    if (_deger(ad) case final List<Object?> liste)
      for (final oge in liste)
        if (oge is String && oge.isNotEmpty) oge,
  ];

  /// Tam sayı listesi parametre (`presets` saniye).
  List<int> tamSayilar(String ad) => [
    if (_deger(ad) case final List<Object?> liste)
      for (final oge in liste)
        if (oge is int) oge,
  ];

  /// Nesne listesi parametre (`log.fields`: `CatalogField` listesi).
  List<Map<String, Object?>> nesneler(String ad) => [
    if (_deger(ad) case final List<Object?> liste)
      for (final oge in liste)
        if (oge is Map<String, Object?>) oge,
  ];
}

/// Organizatörün bir bileşen için sihirbazdaki seçimi (ADR-0031 §1).
@immutable
final class BilesenSecimi {
  const BilesenSecimi({this.acik, this.secimler = const {}});

  /// `optional` bileşen açık mı; `null`: dokunulmadı (tanımdaki
  /// varsayılan).
  final bool? acik;

  /// Parametre adı → seçilen seçenek; yalnızca dokunulanlar.
  final Map<String, String> secimler;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BilesenSecimi &&
          acik == other.acik &&
          mapEquals(secimler, other.secimler);

  @override
  int get hashCode => Object.hash(
    acik,
    Object.hashAllUnordered([
      for (final e in secimler.entries) Object.hash(e.key, e.value),
    ]),
  );
}

/// Bileşen anahtarı → organizatörün seçimi.
typedef BilesenSecimleri = Map<String, BilesenSecimi>;

/// İki seçim kümesi aynı mı.
bool ayniBilesenSecimleri(BilesenSecimleri a, BilesenSecimleri b) =>
    mapEquals(a, b);

/// [bilesen] bu seçimlerle açık mı: `optional` değilse her zaman açıktır;
/// dokunulmadıysa tanımdaki varsayılan geçerlidir.
bool bilesenAcikMi(CatalogComponent bilesen, BilesenSecimleri secimler) {
  final istegeBagli = bilesen.optional;
  if (istegeBagli == null) return true;
  return secimler[bilesenAnahtari(bilesen)]?.acik ?? istegeBagli.default_;
}

/// [bilesen]'in organizatöre bırakılan her parametresinde geçerli seçenek:
/// seçilen (tanımdaki seçeneklerden biriyse) ya da varsayılan.
Map<String, String> gecerliSecimler(
  CatalogComponent bilesen,
  BilesenSecimleri secimler,
) {
  final secilen = secimler[bilesenAnahtari(bilesen)]?.secimler ?? const {};
  return {
    for (final p in secimliParametreler(bilesen))
      p.ad: p.secenekler.contains(secilen[p.ad])
          ? secilen[p.ad]!
          : p.varsayilan,
  };
}

/// [bilesen]'i açar ya da kapatır; `optional` olmayan bileşende seçimler
/// değişmez.
BilesenSecimleri bilesenAcKapa(
  BilesenSecimleri secimler,
  CatalogComponent bilesen, {
  required bool acik,
}) {
  if (bilesen.optional == null) return secimler;
  final anahtar = bilesenAnahtari(bilesen);
  return Map.unmodifiable({
    ...secimler,
    anahtar: BilesenSecimi(
      acik: acik,
      secimler: secimler[anahtar]?.secimler ?? const {},
    ),
  });
}

/// [bilesen]'in [param] parametresinde [deger]'i seçer. Organizatöre
/// bırakılmamış parametre ya da tanımda olmayan seçenek yok sayılır.
BilesenSecimleri bilesenSecimYap(
  BilesenSecimleri secimler,
  CatalogComponent bilesen,
  String param,
  String deger,
) {
  final gecerli = secimliParametreler(bilesen)
      .any((p) => p.ad == param && p.secenekler.contains(deger));
  if (!gecerli) return secimler;
  final anahtar = bilesenAnahtari(bilesen);
  final onceki = secimler[anahtar];
  return Map.unmodifiable({
    ...secimler,
    anahtar: BilesenSecimi(
      acik: onceki?.acik,
      secimler: Map.unmodifiable({...?onceki?.secimler, param: deger}),
    ),
  });
}

/// Tanımdaki bileşenler (yoksa boş); biçimi geçersiz anahtar taşıyan ya da
/// anahtarı tekrar eden bileşen atlanır (tanım girdidir).
List<CatalogComponent> turBilesenleri(CatalogEventType? tanim) {
  final gorulen = <String>{};
  return [
    for (final b in tanim?.definition.components ?? const <CatalogComponent>[])
      if (katalogAnahtariMi(b.kind) &&
          katalogAnahtariMi(bilesenAnahtari(b)) &&
          gorulen.add(bilesenAnahtari(b)))
        b,
  ];
}

List<ComponentChoice>? _secimListesi(
  CatalogComponent bilesen,
  Map<String, String> secilen,
) {
  final liste = [
    for (final p in secimliParametreler(bilesen))
      if (secilen[p.ad] case final deger? when p.secenekler.contains(deger))
        ComponentChoice(param: p.ad, value: deger),
  ];
  if (liste.isEmpty) return null;
  return liste.length > bilesenSecimEnCok
      ? liste.sublist(0, bilesenSecimEnCok)
      : liste;
}

/// Yeni etkinliğin `components` gövdesi (`EventCreateRequest.components`):
/// yalnızca organizatörün dokunduğu, tanımda karşılığı olan seçimler.
/// Gönderilmeyen bileşen sunucuda tanımdaki varsayılanla başlar; hiçbir
/// seçim yoksa `null` (alan gönderilmez).
List<EventComponentSelection>? bilesenSecimGovdesi(
  CatalogEventType? tanim,
  BilesenSecimleri secimler,
) {
  final govde = <EventComponentSelection>[];
  for (final bilesen in turBilesenleri(tanim)) {
    final anahtar = bilesenAnahtari(bilesen);
    final secim = secimler[anahtar];
    if (secim == null) continue;
    final acik = bilesen.optional == null ? null : secim.acik;
    final secilen = _secimListesi(bilesen, secim.secimler);
    if (acik == null && secilen == null) continue;
    govde.add(
      EventComponentSelection(key: anahtar, enabled: acik, choices: secilen),
    );
  }
  return govde.isEmpty ? null : govde;
}

/// Sunucudaki bileşen durumundan ([EventComponentList]) sihirbazın
/// başlangıç seçimleri (düzenleme): her bileşenin açık/kapalı hali ve
/// geçerli seçenekleri.
BilesenSecimleri durumdanSecimler(
  CatalogEventType? tanim,
  EventComponentList durum,
) {
  final durumlar = {for (final d in durum.components) d.key: d};
  final secimler = <String, BilesenSecimi>{};
  for (final bilesen in turBilesenleri(tanim)) {
    final anahtar = bilesenAnahtari(bilesen);
    final d = durumlar[anahtar];
    if (d == null) continue;
    final secenekler = {
      for (final p in secimliParametreler(bilesen)) p.ad: p.secenekler,
    };
    secimler[anahtar] = BilesenSecimi(
      acik: bilesen.optional == null ? null : d.enabled,
      secimler: Map.unmodifiable({
        for (final c in d.choices)
          if (secenekler[c.param]?.contains(c.value) ?? false) c.param: c.value,
      }),
    );
  }
  return Map.unmodifiable(secimler);
}

/// Düzenlemede değişen seçimler: bileşen anahtarı ve
/// `PUT …/components/{component_key}` gövdesi, tanımdaki sırayla. Yalnızca
/// [ilk]'e göre değişen açık/kapalı hali ve seçenekler gönderilir
/// (gönderilmeyen seçim olduğu gibi kalır).
List<(String, EventComponentSelectionRequest)> bilesenSecimDegisiklikleri(
  CatalogEventType? tanim,
  BilesenSecimleri ilk,
  BilesenSecimleri yeni,
) {
  final degisenler = <(String, EventComponentSelectionRequest)>[];
  for (final bilesen in turBilesenleri(tanim)) {
    final anahtar = bilesenAnahtari(bilesen);
    final sonra = yeni[anahtar];
    if (sonra == null) continue;
    final once = ilk[anahtar];
    final acik =
        bilesen.optional != null &&
            sonra.acik != null &&
            sonra.acik != once?.acik
        ? sonra.acik
        : null;
    final secilen = _secimListesi(bilesen, {
      for (final e in sonra.secimler.entries)
        if (once?.secimler[e.key] != e.value) e.key: e.value,
    });
    if (acik == null && secilen == null) continue;
    degisenler.add((
      anahtar,
      EventComponentSelectionRequest(enabled: acik, choices: secilen),
    ));
  }
  return degisenler;
}
