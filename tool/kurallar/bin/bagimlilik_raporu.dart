// Bağımlılık ve lisans raporu (ADR-0009 zorunlu kontrol 5, issue #9).
//
//   dart run tool/kurallar/bin/bagimlilik_raporu.dart \
//     --onceki <eski pubspec.lock> [--sonraki pubspec.lock]
//
// `flutter pub get`'ten sonra çalıştırılır: lisanslar
// .dart_tool/package_config.json'daki paket dizinlerinden okunur. Rapor
// standart çıktıya ve varsa $GITHUB_STEP_SUMMARY'ye yazılır. İzin verici
// olmayan veya tanınmayan lisanslı yeni/değişen paket uyarı olarak
// işaretlenir; iş yalnızca dosyalar okunamazsa başarısız olur.

import 'dart:convert';
import 'dart:io';

import '../kurallar.dart';

void main(List<String> args) {
  String? oncekiYol;
  var sonrakiYol = 'pubspec.lock';
  for (var i = 0; i + 1 < args.length; i += 2) {
    switch (args[i]) {
      case '--onceki':
        oncekiYol = args[i + 1];
      case '--sonraki':
        sonrakiYol = args[i + 1];
    }
  }
  if (oncekiYol == null) {
    stderr.writeln(
      'Kullanım: dart run tool/kurallar/bin/bagimlilik_raporu.dart '
      '--onceki <eski pubspec.lock> [--sonraki pubspec.lock]',
    );
    exitCode = 64;
    return;
  }

  final oncekiDosya = File(oncekiYol);
  final oncekiMetin = oncekiDosya.existsSync()
      ? oncekiDosya.readAsStringSync()
      : '';
  final sonrakiMetin = File(sonrakiYol).readAsStringSync();
  final onceki = kilidiOku(oncekiMetin);
  final sonraki = kilidiOku(sonrakiMetin);
  final degisiklikler = kilitleriKarsilastir(onceki, sonraki);
  final lisanslar = _lisanslar(sonraki);

  final rapor = raporOlustur(
    degisiklikler: degisiklikler,
    sonraki: sonraki,
    lisanslar: lisanslar,
    oncekiSdk: sdkKisitlari(oncekiMetin),
    sonrakiSdk: sdkKisitlari(sonrakiMetin),
  );
  stdout.writeln(rapor);
  final ozet = Platform.environment['GITHUB_STEP_SUMMARY'];
  if (ozet != null && ozet.isNotEmpty) {
    File(ozet).writeAsStringSync(rapor, mode: FileMode.append);
  }
  final github = Platform.environment['GITHUB_ACTIONS'] == 'true';
  for (final uyari in lisansUyarilari(degisiklikler, lisanslar)) {
    stdout.writeln(github ? '::warning title=bagimliliklar::$uyari' : uyari);
  }
}

/// package_config.json'daki paket dizinlerinden lisansları okur.
Map<String, String> _lisanslar(Map<String, KilitPaketi> paketler) {
  final sonuc = <String, String>{};
  final yapilandirma = File('.dart_tool/package_config.json');
  if (!yapilandirma.existsSync()) {
    return sonuc;
  }
  final belge = jsonDecode(yapilandirma.readAsStringSync());
  if (belge is! Map<String, Object?>) {
    return sonuc;
  }
  final liste = belge['packages'];
  if (liste is! List<Object?>) {
    return sonuc;
  }
  final taban = yapilandirma.absolute.uri;
  for (final p in liste) {
    if (p is! Map<String, Object?>) {
      continue;
    }
    final ad = p['name'];
    final kok = p['rootUri'];
    if (ad is! String || kok is! String) {
      continue;
    }
    final paket = paketler[ad];
    if (paket == null) {
      continue;
    }
    if (paket.kaynak == 'sdk') {
      sonuc[ad] = sdkLisansi;
      continue;
    }
    final dizin = Directory.fromUri(
      taban.resolve(kok.endsWith('/') ? kok : '$kok/'),
    );
    sonuc[ad] = _dizinLisansi(dizin);
  }
  return sonuc;
}

const List<String> _lisansDosyalari = [
  'LICENSE',
  'LICENSE.md',
  'LICENSE.txt',
  'LICENCE',
  'COPYING',
  'license',
];

String _dizinLisansi(Directory dizin) {
  for (final ad in _lisansDosyalari) {
    final dosya = File('${dizin.path}/$ad');
    if (dosya.existsSync()) {
      return lisansiTani(dosya.readAsStringSync());
    }
  }
  return bilinmeyenLisans;
}
