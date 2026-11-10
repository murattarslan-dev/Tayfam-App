import 'package:flutter_test/flutter_test.dart';

import '../../../tool/kurallar/kurallar.dart';

const String _onceki = '''
packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.5.0"
  eski_paket:
    dependency: transitive
    description:
      name: eski_paket
      url: "https://pub.dev"
    source: hosted
    version: "0.1.0"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.10.0 <4.0.0"
  flutter: ">=3.38.0"
''';

const String _sonraki = '''
packages:
  http:
    dependency: "direct main"
    description:
      name: http
      url: "https://pub.dev"
    source: hosted
    version: "1.6.0"
  yeni_paket:
    dependency: "direct main"
    description:
      name: yeni_paket
      url: "https://pub.dev"
    source: hosted
    version: "2.0.0"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.13.0 <4.0.0"
  flutter: ">=3.38.0"
''';

const String _mit = '''
Copyright (c) 2026 Örnek

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software...
''';

const String _bsd = '''
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Neither the name of Google Inc. nor the names of its contributors
''';

void main() {
  test('kilit okunur; boş metin boş kilittir', () {
    final kilit = kilidiOku(_onceki);
    expect(kilit.keys, unorderedEquals(['http', 'eski_paket', 'flutter']));
    expect(kilit['http']!.surum, '1.5.0');
    expect(kilit['http']!.bagimlilik, 'direct main');
    expect(kilit['flutter']!.kaynak, 'sdk');
    expect(kilidiOku(''), isEmpty);
    expect(sdkKisitlari(_sonraki)['dart'], '>=3.13.0 <4.0.0');
  });

  test('eklenen, kaldırılan ve sürümü değişen paketler', () {
    final d = kilitleriKarsilastir(kilidiOku(_onceki), kilidiOku(_sonraki));
    expect(d.map((x) => (x.ad, x.tur)), [
      ('eski_paket', DegisiklikTuru.kaldirildi),
      ('http', DegisiklikTuru.surumDegisti),
      ('yeni_paket', DegisiklikTuru.eklendi),
    ]);
  });

  test('lisans tanıma', () {
    expect(lisansiTani(_mit), 'MIT');
    expect(lisansiTani(_bsd), 'BSD-3-Clause');
    expect(
      lisansiTani('Apache License\n  Version 2.0, January 2004'),
      'Apache-2.0',
    );
    expect(lisansiTani('GNU AFFERO GENERAL PUBLIC LICENSE'), 'AGPL');
    expect(lisansiTani('GNU GENERAL PUBLIC LICENSE Version 3'), 'GPL');
    expect(lisansiTani('Mozilla Public License Version 2.0'), 'MPL-2.0');
    expect(lisansiTani('Tüm hakları saklıdır.'), bilinmeyenLisans);
  });

  test('izin verici olmayan yeni paket uyarı üretir', () {
    final d = kilitleriKarsilastir(kilidiOku(_onceki), kilidiOku(_sonraki));
    final uyarilar = lisansUyarilari(d, {
      'http': 'BSD-3-Clause',
      'yeni_paket': 'GPL',
      'flutter': sdkLisansi,
    });
    expect(uyarilar, hasLength(1));
    expect(uyarilar.single, contains('yeni_paket'));
    expect(uyarilar.single, contains('GPL'));
  });

  test('rapor değişiklikleri, SDK kısıtını ve lisans özetini listeler', () {
    final sonraki = kilidiOku(_sonraki);
    final rapor = raporOlustur(
      degisiklikler: kilitleriKarsilastir(kilidiOku(_onceki), sonraki),
      sonraki: sonraki,
      lisanslar: {'http': 'BSD-3-Clause', 'yeni_paket': 'MIT'},
      oncekiSdk: sdkKisitlari(_onceki),
      sonrakiSdk: sdkKisitlari(_sonraki),
    );
    expect(rapor, contains('1 eklendi, 1 sürümü değişti'));
    expect(rapor, contains('| `http` | sürüm değişti | 1.5.0 | 1.6.0 |'));
    expect(rapor, contains('| `eski_paket` | kaldırıldı | 0.1.0 | — |'));
    expect(rapor, contains('SDK kısıtı değişti: `dart`'));
    expect(rapor, contains('| BSD-3-Clause | 1 | http |'));
    expect(rapor, contains('| bilinmiyor ⚠ | 1 | flutter |'));
  });

  test('değişiklik yoksa söylenir', () {
    final kilit = kilidiOku(_sonraki);
    final rapor = raporOlustur(
      degisiklikler: kilitleriKarsilastir(kilit, kilit),
      sonraki: kilit,
      lisanslar: const {},
    );
    expect(rapor, contains('paket değişikliği yok'));
  });
}
