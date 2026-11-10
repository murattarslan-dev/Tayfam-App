// OpenAPI üreticisinin kütüphane girişi (ADR-0005). Komut satırı:
// bin/openapi_gen.dart. Testler bu dosyayı doğrudan kullanır.

import 'src/emitter.dart';
import 'src/parser.dart';

export 'src/emitter.dart' show SpecSource, generatedHeader;
export 'src/errors.dart' show GenException;
export 'src/model.dart';
export 'src/parser.dart' show parseSpec;

/// Bir üretimin sonucu.
final class GenResult {
  const GenResult({
    required this.files,
    required this.warnings,
    required this.operationCount,
    required this.problemTypeCount,
    required this.skippedOperations,
  });

  /// Çıktı dizinine göreli yol → içerik, yola göre sıralı.
  final Map<String, String> files;

  /// Üretimi durdurmayan bulgular (örneğin şemada tanınmayan anahtar).
  final List<String> warnings;
  final int operationCount;
  final int problemTypeCount;

  /// Bilerek üretilmeyen işlemler (WebSocket).
  final List<String> skippedOperations;
}

/// [specYaml]'dan kodu üretir. Desteklenmeyen yapıda `GenException`.
GenResult generate(
  String specYaml, {
  required SpecSource source,
  String importBase = 'package:tayfam/core/api/gen',
}) {
  final model = parseSpec(specYaml);
  return GenResult(
    files: emitAll(model, importBase: importBase, source: source),
    warnings: List.unmodifiable(model.warnings),
    operationCount: model.operations.length,
    problemTypeCount: model.problemTypes.length,
    skippedOperations: List.unmodifiable(model.skippedOperations),
  );
}
