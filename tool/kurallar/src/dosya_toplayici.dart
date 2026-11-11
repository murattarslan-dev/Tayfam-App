// Repodaki denetlenecek dosyaları okur.

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'android_metinleri.dart';
import 'denetci.dart';

/// [kok] dizinindeki repodan denetim girdisini toplar: lib/ altındaki
/// bütün .dart dosyaları, pubspec.yaml, lib/l10n/*.arb ve push
/// bildirimlerinin Android string kaynağı.
DenetimGirdisi girdiyiTopla(Directory kok) {
  final kokYolu = kok.absolute.path;
  String goreli(String yol) =>
      yol.substring(kokYolu.length + 1).replaceAll(r'\', '/');

  final dart = <String, String>{};
  final arb = <String, String>{};
  final lib = Directory('$kokYolu/lib');
  if (lib.existsSync()) {
    for (final varlik in lib.listSync(recursive: true, followLinks: false)) {
      if (varlik is! File) {
        continue;
      }
      final yol = goreli(varlik.path);
      if (yol.endsWith('.dart')) {
        dart[yol] = varlik.readAsStringSync();
      } else if (yol.startsWith('lib/l10n/') && yol.endsWith('.arb')) {
        arb[yol] = varlik.readAsStringSync();
      }
    }
  }
  final pubspecDosyasi = File('$kokYolu/pubspec.yaml');
  final pubspec = pubspecDosyasi.existsSync()
      ? pubspecDosyasi.readAsStringSync()
      : null;
  final androidDosyasi = File('$kokYolu/$androidMetinDosyasi');
  return DenetimGirdisi(
    dartDosyalari: dart,
    pubspec: pubspec,
    arbDosyalari: arb,
    androidMetinleri: androidDosyasi.existsSync()
        ? androidDosyasi.readAsStringSync()
        : null,
    paketAdi: _paketAdi(pubspec) ?? 'tayfam',
  );
}

String? _paketAdi(String? pubspec) {
  if (pubspec == null) {
    return null;
  }
  final belge = loadYaml(pubspec);
  if (belge is! Map<Object?, Object?>) {
    return null;
  }
  final ad = belge['name'];
  return ad is String ? ad : null;
}
