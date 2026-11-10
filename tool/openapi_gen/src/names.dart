// Sözleşmedeki adlardan Dart adları üretir (ADR-0005).

import 'errors.dart';

/// Dart'ta tanımlayıcı olarak kullanılamayan ya da kafa karıştıran
/// kelimeler. Bu adlara sonuna `_` eklenir; JSON adı korunur.
const Set<String> dartReservedWords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Model sınıflarının kendi üyeleriyle çakışan alan adları.
const Set<String> classMemberNames = {
  'fromJson',
  'hashCode',
  'noSuchMethod',
  'runtimeType',
  'toJson',
  'toString',
};

/// Üretilen enum'ların kendi üyeleriyle çakışan değer adları.
const Set<String> enumMemberNames = {
  'fromWire',
  'hashCode',
  'index',
  'name',
  'noSuchMethod',
  'runtimeType',
  'toString',
  'values',
  'wire',
};

/// Sözleşmedeki şema adlarının kullanamayacağı tip adları: Dart'ın temel
/// tipleri ve üretilen kodun kendi tipleri.
const Set<String> reservedTypeNames = {
  'ApiTransport',
  'ArgumentError',
  'bool',
  'DateTime',
  'double',
  'Duration',
  'Enum',
  'Error',
  'Exception',
  'FormatException',
  'Function',
  'Future',
  'int',
  'Iterable',
  'List',
  'Map',
  'MapEntry',
  'Never',
  'Null',
  'num',
  'Object',
  'ProblemType',
  'Record',
  'ResponseKind',
  'Set',
  'StateError',
  'Stream',
  'String',
  'Symbol',
  'Type',
  'Uri',
};

final RegExp _parcaAyirici = RegExp('[^A-Za-z0-9]+');

List<String> _parcalar(String ad) =>
    ad.split(_parcaAyirici).where((p) => p.isNotEmpty).toList();

/// `tayfa_id` → `TayfaId`, `client-config` → `ClientConfig`,
/// `getStatus` → `GetStatus`. Parçaların içindeki büyük harfler korunur.
String pascalCase(String ad) {
  final parcalar = _parcalar(ad);
  if (parcalar.isEmpty) {
    throw GenException('"$ad" adından tanımlayıcı üretilemiyor');
  }
  return parcalar.map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join();
}

/// `not_going` → `notGoing`, `invalid-request` → `invalidRequest`.
String camelCase(String ad) {
  final pascal = pascalCase(ad);
  return '${pascal[0].toLowerCase()}${pascal.substring(1)}';
}

/// `client-config` → `client_config`; dosya adları için.
String snakeCase(String ad) {
  final parcalar = _parcalar(ad);
  if (parcalar.isEmpty) {
    throw GenException('"$ad" adından dosya adı üretilemiyor');
  }
  return parcalar
      .map(
        (p) => p.replaceAllMapped(
          RegExp('(?<=[a-z0-9])([A-Z])'),
          (m) => '_${m[1]}',
        ),
      )
      .join('_')
      .toLowerCase();
}

/// [ad] ayrılmış bir kelimeyse ya da [ekYasaklar]'daysa sonuna `_` ekler;
/// rakamla başlıyorsa başına `v` koyar.
String guvenliAd(String ad, [Set<String> ekYasaklar = const {}]) {
  var sonuc = ad;
  if (RegExp('^[0-9]').hasMatch(sonuc)) {
    sonuc = 'v$sonuc';
  }
  if (dartReservedWords.contains(sonuc) || ekYasaklar.contains(sonuc)) {
    sonuc = '${sonuc}_';
  }
  return sonuc;
}

/// Alan ve parametre adı: `starts_at` → `startsAt`.
String alanAdi(String jsonAdi) =>
    guvenliAd(camelCase(jsonAdi), classMemberNames);

/// Enum değeri adı: `not_going` → `notGoing`, `switch` → `switch_`.
String enumDegerAdi(String wire) =>
    guvenliAd(camelCase(wire), enumMemberNames);

/// Dart tek tırnaklı dize sabiti.
String dartString(String deger) {
  final kacisli = deger
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r');
  return "'$kacisli'";
}
