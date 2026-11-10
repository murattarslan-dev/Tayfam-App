import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';

/// pubspec'te kayıtlı ağırlık → dosya ve o dosyadaki "m" harfinin ilerleme
/// genişliği (1000 birim/em; fonttools ile ölçüldü). Her örnek farklı
/// genişlikte olduğu için çizilen metnin genişliği hangi dosyanın
/// seçildiğini gösterir.
const _ornekler = {
  400: ('assets/fonts/BricolageGrotesque-Regular.ttf', 893),
  600: ('assets/fonts/BricolageGrotesque-SemiBold.ttf', 927),
  700: ('assets/fonts/BricolageGrotesque-Bold.ttf', 943),
  // Büyük başlık: wght 750 / opsz 28 örneği 800 yuvasında.
  800: ('assets/fonts/BricolageGrotesque-Baslik750.ttf', 937),
};

/// Test fontu (FlutterTest) her harfi 1 em genişlikte çizer; Bricolage
/// yüklenmemişse genişlik 1000 çıkar ve test başarısız olur.
double _mGenisligi(TextStyle stil) {
  final boyaci = TextPainter(
    text: TextSpan(text: 'm', style: stil.copyWith(fontSize: 1000)),
    textDirection: TextDirection.ltr,
  )..layout();
  final genislik = boyaci.width;
  boyaci.dispose();
  return genislik;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final yukleyici = FontLoader(TayfamTypography.aile);
    for (final (dosya, _) in _ornekler.values) {
      final bayt = File(dosya).readAsBytesSync();
      yukleyici.addFont(Future.value(ByteData.sublistView(bayt)));
    }
    await yukleyici.load();
  });

  test('pubspec yalnızca bu dört örneği doğru ağırlıkla kaydeder', () {
    final kaynak = File('pubspec.yaml').readAsStringSync();
    final pubspec = loadYaml(kaynak) as YamlMap;
    final aileler = (pubspec['flutter'] as YamlMap)['fonts'] as YamlList;
    expect(aileler, hasLength(1));
    final aile = aileler.single as YamlMap;
    expect(aile['family'], TayfamTypography.aile);
    final dosyalar = (aile['fonts'] as YamlList).cast<YamlMap>();
    final kayitlar = {
      for (final k in dosyalar) k['weight'] as int: k['asset'] as String,
    };
    final beklenen = _ornekler.map((agirlik, o) => MapEntry(agirlik, o.$1));
    expect(kayitlar, beklenen);
    for (final dosya in kayitlar.values) {
      expect(File(dosya).existsSync(), isTrue, reason: dosya);
    }
    // SIL OFL 1.1 lisansı fontların yanında.
    final lisans = File('assets/fonts/OFL.txt').readAsStringSync();
    expect(lisans, contains('SIL Open Font License, Version 1.1'));
  });

  for (final giris in _ornekler.entries) {
    final agirlik = giris.key;
    final (dosya, ilerleme) = giris.value;
    test('w$agirlik → ${dosya.split('/').last}', () {
      final stil = TextStyle(
        fontFamily: TayfamTypography.aile,
        fontWeight: FontWeight.values.firstWhere((w) => w.value == agirlik),
      );
      expect(_mGenisligi(stil), closeTo(ilerleme, 1));
    });
  }

  test('tema stilleri doğru dosyayla çizilir', () {
    final t = TayfamTheme.acik().textTheme;
    expect(_mGenisligi(t.bodyLarge!), closeTo(893, 1));
    expect(_mGenisligi(t.labelSmall!), closeTo(927, 1));
    expect(_mGenisligi(t.titleLarge!), closeTo(943, 1));
    expect(_mGenisligi(t.headlineLarge!), closeTo(937, 1));
  });
}
