// CLAUDE.md ve ADR kurallarını denetleyen betik (ADR-0009, issue #9).
//
//   dart run tool/kurallar/bin/kurallar.dart [--kok <dizin>] [--liste]
//
// Hata düzeyinde bulgu varsa çıkış kodu 1'dir. GitHub Actions'ta her
// bulgu dosya ve satırıyla PR'da işaretlenir. Bilinçli istisna, bulgunun
// satırında veya hemen üstünde şu yorumla yazılır:
//
//   // kural-istisnası: <kural> — <gerekçe>

import 'dart:io';

import '../kurallar.dart';

void main(List<String> args) {
  var kok = Directory.current;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--liste':
        _listele();
        return;
      case '--kok' when i + 1 < args.length:
        kok = Directory(args[++i]);
      default:
        stderr.writeln(
          'Kullanım: dart run tool/kurallar/bin/kurallar.dart '
          '[--kok <dizin>] [--liste]',
        );
        exitCode = 64;
        return;
    }
  }

  final bulgular = denetle(girdiyiTopla(kok));
  final github = Platform.environment['GITHUB_ACTIONS'] == 'true';
  var hata = 0;
  var uyari = 0;
  for (final b in bulgular) {
    final hataMi = b.seviye == Seviye.hata;
    if (hataMi) {
      hata++;
    } else {
      uyari++;
    }
    stdout.writeln('${hataMi ? 'HATA ' : 'UYARI'} ${b.ozet}');
    if (github) {
      final komut = hataMi ? 'error' : 'warning';
      stdout.writeln(
        '::$komut file=${_ozellik(b.yol)},line=${b.satir},col=${b.sutun},'
        'title=${_ozellik('kurallar/${b.kural.ad}')}::'
        '${_veri('${b.mesaj} (Dayanak: ${b.kural.dayanak})')}',
      );
    }
  }
  stdout.writeln();
  if (bulgular.isEmpty) {
    stdout.writeln('Kurallar temiz.');
  } else {
    stdout.writeln('$hata hata, $uyari uyarı.');
  }
  if (hata > 0) {
    stdout
      ..writeln()
      ..writeln(
        'Bulguyu düzelt. Bilinçli bir istisnaysa satırın üstüne '
        '"// kural-istisnası: <kural> — <gerekçe>" yaz; istisnayı PR '
        'açıklamasında da gerekçelendir.',
      );
    exitCode = 1;
  }
}

void _listele() {
  for (final k in Kurallar.hepsi) {
    final seviye = k.seviye == Seviye.hata ? 'hata ' : 'uyarı';
    stdout
      ..writeln('${k.ad} ($seviye) — ${k.dayanak}')
      ..writeln('    ${k.aciklama}');
  }
}

/// GitHub iş akışı komutu verisinin kaçışı.
String _veri(String s) => s
    .replaceAll('%', '%25')
    .replaceAll('\r', '%0D')
    .replaceAll('\n', '%0A');

/// GitHub iş akışı komutu özelliğinin kaçışı.
String _ozellik(String s) =>
    _veri(s).replaceAll(':', '%3A').replaceAll(',', '%2C');
