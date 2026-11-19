// Katalog ikon haritasının anahtar listesini yazar ya da karşılaştırır
// (ADR-0024 §2).
//
//   dart run tool/katalog_ikonlari/bin/katalog_ikonlari.dart
//   dart run tool/katalog_ikonlari/bin/katalog_ikonlari.dart \
//     --karsilastir <liste dosyası>
//
// Argümansız: `lib/core/katalog/ikonlar.dart`'taki anahtarları satır satır,
// sıralı yazar (Tayfam-Api platform panelinin ikon listesi bundan
// üretilir). `--karsilastir`: satır başına bir anahtar taşıyan dosyayla
// (Tayfam-Api'deki liste) karşılaştırır; fark varsa 1 ile çıkar.

import 'dart:io';

import '../katalog_ikonlari.dart';

void main(List<String> args) {
  if (args.isNotEmpty && (args.length != 2 || args[0] != '--karsilastir')) {
    stderr.writeln(
      'Kullanım: dart run tool/katalog_ikonlari/bin/katalog_ikonlari.dart '
      '[--karsilastir <liste dosyası>]',
    );
    exitCode = 64;
    return;
  }
  final List<String> istemci;
  try {
    istemci = ikonAnahtarlari(File(ikonHaritasiDosyasi).readAsStringSync());
  } on IkonHaritasiHatasi catch (hata) {
    stderr.writeln(hata);
    exitCode = 1;
    return;
  }
  if (args.isEmpty) {
    istemci.forEach(stdout.writeln);
    return;
  }
  final fark = ikonlariKarsilastir(
    istemci,
    listeAnahtarlari(File(args[1]).readAsStringSync()),
  );
  if (fark.ayni) {
    stdout.writeln('İkon listeleri aynı (${istemci.length} ikon).');
    return;
  }
  for (final anahtar in fark.eksik) {
    stderr.writeln('listede yok (istemcide var): $anahtar');
  }
  for (final anahtar in fark.fazla) {
    stderr.writeln('istemcide yok (listede var): $anahtar');
  }
  exitCode = 1;
}
