// OpenAPI üreticisi (ADR-0005).
//
//   dart run tool/openapi_gen/bin/openapi_gen.dart \
//     --spec <gateway.yaml> --out lib/core/api/gen [--commit <sha>]
//
// Kaynak bilgisi (repo, commit, yol) --commit/--repo/--spec-path ile
// verilir; verilmezse çıktı dizinindeki mevcut SOURCE dosyasından okunur.
// Sözleşmenin yeni bir commit'ine geçmek için --commit verilir.
//
// Çıktı dizinindeki eski üretilmiş dosyalar silinir, yenileri yazılır ve
// `dart format` ile biçimlendirilir.

import 'dart:io';

import '../openapi_gen.dart';

const String _usage =
    'Kullanım: dart run tool/openapi_gen/bin/openapi_gen.dart '
    '--spec <yol> --out <dizin> [--commit <sha>] [--repo <sahip/repo>] '
    '[--spec-path <yol>] [--import-base <package:…>]';

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on GenException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  } on FormatException catch (e) {
    stderr
      ..writeln('openapi_gen: ${e.message}')
      ..writeln(_usage);
    exitCode = 64;
  }
}

Future<void> _run(List<String> args) async {
  final options = _parseArgs(args);
  final specPath = options['spec'];
  final outPath = options['out'];
  if (specPath == null || outPath == null) {
    throw const FormatException('--spec ve --out zorunlu');
  }
  final outDir = Directory(outPath);
  final source = _source(options, outDir);

  final result = generate(
    File(specPath).readAsStringSync(),
    source: source,
    importBase: options['import-base'] ?? 'package:tayfam/core/api/gen',
  );
  for (final warning in result.warnings) {
    stderr.writeln('uyarı: $warning');
  }

  _removeGenerated(outDir);
  final written = <String>[];
  for (final MapEntry(key: path, value: content) in result.files.entries) {
    final file = File('${outDir.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    if (path.endsWith('.dart')) written.add(file.path);
  }

  final format = await Process.run(Platform.resolvedExecutable, [
    'format',
    ...written,
  ]);
  if (format.exitCode != 0) {
    stderr
      ..write(format.stdout)
      ..write(format.stderr);
    throw GenException('dart format başarısız (çıkış ${format.exitCode})');
  }

  stdout
    ..writeln(
      'openapi_gen: ${result.operationCount} işlem, '
      '${result.problemTypeCount} hata kodu, ${result.files.length} dosya '
      '→ ${outDir.path}',
    )
    ..writeln('kaynak: ${source.repo}@${source.commit} ${source.path}');
  for (final skipped in result.skippedOperations) {
    stdout.writeln('üretilmedi (WebSocket): $skipped');
  }
}

Map<String, String> _parseArgs(List<String> args) {
  const known = {
    'spec',
    'out',
    'commit',
    'repo',
    'spec-path',
    'import-base',
  };
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') || !known.contains(arg.substring(2))) {
      throw FormatException('bilinmeyen argüman: $arg');
    }
    if (i + 1 >= args.length) {
      throw FormatException('$arg için değer eksik');
    }
    options[arg.substring(2)] = args[++i];
  }
  return options;
}

/// Kaynak bilgisini argümanlardan, yoksa mevcut SOURCE dosyasından alır.
SpecSource _source(Map<String, String> options, Directory outDir) {
  final existing = <String, String>{};
  final sourceFile = File('${outDir.path}/SOURCE');
  if (sourceFile.existsSync()) {
    for (final line in sourceFile.readAsLinesSync()) {
      final index = line.indexOf(': ');
      if (line.startsWith('#') || index < 0) continue;
      existing[line.substring(0, index)] = line.substring(index + 2).trim();
    }
  }
  final repo =
      options['repo'] ?? existing['repo'] ?? 'murattarslan-dev/tayfam-api';
  final commit = options['commit'] ?? existing['commit'];
  final path =
      options['spec-path'] ?? existing['path'] ?? 'api/openapi/gateway.yaml';
  if (commit == null) {
    throw const FormatException('--commit verilmeli (SOURCE dosyası yok)');
  }
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    throw FormatException('commit 40 karakterlik SHA olmalı: $commit');
  }
  if (!RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(repo)) {
    throw FormatException('repo sahip/ad biçiminde olmalı: $repo');
  }
  return SpecSource(repo: repo, commit: commit, path: path);
}

/// Çıktı dizinindeki, bu üreticinin yazdığı dosyaları siler; elle konmuş
/// dosyalara dokunmaz.
void _removeGenerated(Directory outDir) {
  if (!outDir.existsSync()) return;
  final files = outDir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    if (name == 'SOURCE') {
      file.deleteSync();
      continue;
    }
    if (!name.endsWith('.dart')) continue;
    final lines = file.readAsLinesSync();
    if (lines.isNotEmpty && lines.first == generatedHeader) {
      file.deleteSync();
    }
  }
}
