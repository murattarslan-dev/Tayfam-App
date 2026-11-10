// Bağımlılık raporu (ADR-0009 zorunlu kontrol 5): iki pubspec.lock
// arasındaki eklenen, kaldırılan ve sürümü değişen paketler ile
// paketlerin lisansları. Rapor CI işinin çıktısıdır; PR'a yorum yazılmaz.

import 'package:yaml/yaml.dart';

/// pubspec.lock'taki bir paket.
final class KilitPaketi {
  const KilitPaketi({
    required this.ad,
    required this.surum,
    required this.kaynak,
    required this.bagimlilik,
  });

  final String ad;
  final String surum;

  /// `hosted`, `sdk`, `git` veya `path`.
  final String kaynak;

  /// `direct main`, `direct dev`, `transitive` …
  final String bagimlilik;
}

/// Bir pubspec.lock'u okur. Boş metin boş kilit sayılır (ör. ilk kez
/// eklenen kilit dosyası).
Map<String, KilitPaketi> kilidiOku(String metin) {
  if (metin.trim().isEmpty) {
    return {};
  }
  final belge = loadYaml(metin);
  if (belge is! Map<Object?, Object?>) {
    throw const FormatException('pubspec.lock bir YAML eşlemi değil');
  }
  final paketler = belge['packages'];
  final sonuc = <String, KilitPaketi>{};
  if (paketler is! Map<Object?, Object?>) {
    return sonuc;
  }
  for (final MapEntry(:key, :value) in paketler.entries) {
    if (key is! String || value is! Map<Object?, Object?>) {
      continue;
    }
    sonuc[key] = KilitPaketi(
      ad: key,
      surum: '${value['version'] ?? ''}',
      kaynak: '${value['source'] ?? ''}',
      bagimlilik: '${value['dependency'] ?? ''}',
    );
  }
  return sonuc;
}

/// Kilitteki SDK kısıtları (`sdks:` bölümü).
Map<String, String> sdkKisitlari(String metin) {
  if (metin.trim().isEmpty) {
    return {};
  }
  final belge = loadYaml(metin);
  if (belge is! Map<Object?, Object?>) {
    return {};
  }
  final sdks = belge['sdks'];
  if (sdks is! Map<Object?, Object?>) {
    return {};
  }
  return {
    for (final MapEntry(:key, :value) in sdks.entries) '$key': '$value',
  };
}

enum DegisiklikTuru { eklendi, kaldirildi, surumDegisti, kaynakDegisti }

/// İki kilit arasındaki bir paket değişikliği.
final class Degisiklik {
  const Degisiklik({required this.tur, this.onceki, this.sonraki});

  final DegisiklikTuru tur;
  final KilitPaketi? onceki;
  final KilitPaketi? sonraki;

  String get ad => (sonraki ?? onceki)!.ad;
}

/// [onceki] ve [sonraki] kilitlerini karşılaştırır; ada göre sıralı.
List<Degisiklik> kilitleriKarsilastir(
  Map<String, KilitPaketi> onceki,
  Map<String, KilitPaketi> sonraki,
) {
  final adlar = {...onceki.keys, ...sonraki.keys}.toList()..sort();
  final sonuc = <Degisiklik>[];
  for (final ad in adlar) {
    final o = onceki[ad];
    final s = sonraki[ad];
    if (o == null) {
      sonuc.add(Degisiklik(tur: DegisiklikTuru.eklendi, sonraki: s));
    } else if (s == null) {
      sonuc.add(Degisiklik(tur: DegisiklikTuru.kaldirildi, onceki: o));
    } else if (o.surum != s.surum) {
      sonuc.add(
        Degisiklik(tur: DegisiklikTuru.surumDegisti, onceki: o, sonraki: s),
      );
    } else if (o.kaynak != s.kaynak) {
      sonuc.add(
        Degisiklik(tur: DegisiklikTuru.kaynakDegisti, onceki: o, sonraki: s),
      );
    }
  }
  return sonuc;
}

/// Bilinmeyen lisans etiketi.
const String bilinmeyenLisans = 'bilinmiyor';

/// SDK'dan gelen paketlerin etiketi (Flutter/Dart SDK lisansı).
const String sdkLisansi = 'SDK';

/// Platform sahibinin onayı gerekmeden kabul edilen lisanslar.
const Set<String> izinVericiLisanslar = {
  'MIT',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'Apache-2.0',
  'ISC',
  'Zlib',
  'Unlicense',
  sdkLisansi,
};

/// LICENSE metninden lisansı tahmin eder. Sezgiseldir; emin olamazsa
/// [bilinmeyenLisans] döner.
String lisansiTani(String metin) {
  final m = metin.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (m.contains('gnu affero general public license')) {
    return 'AGPL';
  }
  if (m.contains('gnu lesser general public license')) {
    return 'LGPL';
  }
  if (m.contains('gnu general public license')) {
    return 'GPL';
  }
  if (m.contains('mozilla public license')) {
    return 'MPL-2.0';
  }
  if (m.contains('apache license') && m.contains('version 2.0')) {
    return 'Apache-2.0';
  }
  if (m.contains('permission is hereby granted, free of charge')) {
    return 'MIT';
  }
  if (m.contains('redistribution and use in source and binary forms')) {
    return m.contains('neither the name') || m.contains('may not be used')
        ? 'BSD-3-Clause'
        : 'BSD-2-Clause';
  }
  if (m.contains('permission to use, copy, modify, and/or distribute')) {
    return 'ISC';
  }
  if (m.contains('this software is provided \'as-is\'') &&
      m.contains('altered source versions must be plainly marked')) {
    return 'Zlib';
  }
  if (m.contains('free and unencumbered software released into the public')) {
    return 'Unlicense';
  }
  return bilinmeyenLisans;
}

/// Raporun uyarıları: eklenen veya sürümü değişen ve lisansı izin verici
/// olmayan (ya da tanınmayan) paketler.
List<String> lisansUyarilari(
  List<Degisiklik> degisiklikler,
  Map<String, String> lisanslar,
) {
  return [
    for (final d in degisiklikler)
      if (d.sonraki != null &&
          !izinVericiLisanslar.contains(lisanslar[d.ad] ?? bilinmeyenLisans))
        "'${d.ad}' ${d.sonraki!.surum}: lisans "
            "${lisanslar[d.ad] ?? bilinmeyenLisans}; izin verici değil veya "
            'tanınmadı, platform sahibi incelemeli (CLAUDE.md kesin kural 8).',
  ];
}

String _turAdi(DegisiklikTuru tur) => switch (tur) {
  DegisiklikTuru.eklendi => 'eklendi',
  DegisiklikTuru.kaldirildi => 'kaldırıldı',
  DegisiklikTuru.surumDegisti => 'sürüm değişti',
  DegisiklikTuru.kaynakDegisti => 'kaynak değişti',
};

/// Markdown rapor.
String raporOlustur({
  required List<Degisiklik> degisiklikler,
  required Map<String, KilitPaketi> sonraki,
  required Map<String, String> lisanslar,
  Map<String, String> oncekiSdk = const {},
  Map<String, String> sonrakiSdk = const {},
}) {
  final r = StringBuffer()
    ..writeln('## Bağımlılık raporu')
    ..writeln();
  if (degisiklikler.isEmpty) {
    r.writeln('`pubspec.lock`\'ta paket değişikliği yok.');
  } else {
    int say(DegisiklikTuru t) => degisiklikler.where((d) => d.tur == t).length;
    r
      ..writeln(
        '`pubspec.lock`: ${say(DegisiklikTuru.eklendi)} eklendi, '
        '${say(DegisiklikTuru.surumDegisti)} sürümü değişti, '
        '${say(DegisiklikTuru.kaynakDegisti)} kaynağı değişti, '
        '${say(DegisiklikTuru.kaldirildi)} kaldırıldı.',
      )
      ..writeln()
      ..writeln('| Paket | Değişiklik | Önceki | Sonraki | Bağımlılık | Lisans |')
      ..writeln('| --- | --- | --- | --- | --- | --- |');
    for (final d in degisiklikler) {
      final p = d.sonraki ?? d.onceki!;
      final lisans = d.sonraki == null ? '—' : lisanslar[d.ad] ?? '—';
      r.writeln(
        '| `${d.ad}` | ${_turAdi(d.tur)} | ${d.onceki?.surum ?? '—'} | '
        '${d.sonraki?.surum ?? '—'} | ${p.bagimlilik} | $lisans |',
      );
    }
  }
  final sdkAdlari = {...oncekiSdk.keys, ...sonrakiSdk.keys}.toList()..sort();
  for (final ad in sdkAdlari) {
    if (oncekiSdk[ad] != sonrakiSdk[ad]) {
      r
        ..writeln()
        ..writeln(
          'SDK kısıtı değişti: `$ad` ${oncekiSdk[ad] ?? '—'} → '
          '${sonrakiSdk[ad] ?? '—'}',
        );
    }
  }

  final gruplar = <String, List<String>>{};
  for (final ad in sonraki.keys) {
    gruplar.putIfAbsent(lisanslar[ad] ?? bilinmeyenLisans, () => []).add(ad);
  }
  final lisansAdlari = gruplar.keys.toList()..sort();
  r
    ..writeln()
    ..writeln('### Lisans özeti (bütün paketler)')
    ..writeln()
    ..writeln('| Lisans | Paket sayısı | Paketler |')
    ..writeln('| --- | --- | --- |');
  for (final lisans in lisansAdlari) {
    final adlar = gruplar[lisans]!..sort();
    final isaret = izinVericiLisanslar.contains(lisans) ? '' : ' ⚠';
    r.writeln('| $lisans$isaret | ${adlar.length} | ${adlar.join(', ')} |');
  }
  return r.toString();
}
