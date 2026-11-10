// Ara gösterimden Dart kaynağı üretir (ADR-0005).
//
// Çıktı belirleyicidir: tipler ve gruplar ada göre sıralanır, alanlar ve
// işlemler sözleşmedeki sırayla yazılır, zaman damgası yoktur. Biçim
// `dart format`'a bırakılır (bin/openapi_gen.dart).

import 'model.dart';
import 'names.dart';

/// Üretilen her dosyanın ilk satırı.
const String generatedHeader =
    '// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.';

/// Sözleşmenin kaynağı; `SOURCE` dosyasına yazılır.
final class SpecSource {
  const SpecSource({
    required this.repo,
    required this.commit,
    required this.path,
  });

  final String repo;
  final String commit;
  final String path;
}

/// [model]'den çıktı dosyalarını üretir: göreli yol → içerik, yola göre
/// sıralı. [importBase] örneğin `package:tayfam/core/api/gen`.
Map<String, String> emitAll(
  ApiModel model, {
  required String importBase,
  required SpecSource source,
}) {
  final groups = <String, List<OperationDef>>{};
  for (final op in model.operations) {
    groups.putIfAbsent(op.group, () => []).add(op);
  }
  final groupNames = groups.keys.toList()..sort();
  final files = <String, String>{
    'SOURCE': _source(source),
    'api.dart': _api(groupNames, importBase),
    'models.dart': _models(model),
    'problem_type.dart': _problemType(model.problemTypes),
    'transport.dart': _transport,
    for (final group in groupNames)
      'apis/${apiFileName(group)}': _apiClass(
        group,
        groups[group]!,
        model,
        importBase,
      ),
  };
  final paths = files.keys.toList()..sort();
  return {for (final path in paths) path: files[path]!};
}

/// `direct-messages` → `DirectMessagesApi`.
String apiClassName(String group) => '${pascalCase(group)}Api';

/// `direct-messages` → `direct_messages_api.dart`.
String apiFileName(String group) => '${snakeCase(group)}_api.dart';

String _source(SpecSource source) =>
    '# ÜRETİLMİŞ — elle düzenleme; tool/openapi_gen yazar (ADR-0005).\n'
    'repo: ${source.repo}\n'
    'commit: ${source.commit}\n'
    'path: ${source.path}\n';

// ------------------------------------------------------------------ yardımcı

void _doc(StringBuffer out, List<String> lines, String indent) {
  for (final line in lines) {
    out.writeln(line.isEmpty ? '$indent///' : '$indent/// $line');
  }
}

// --------------------------------------------------------------------- api

String _api(List<String> groupNames, String importBase) {
  final out = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln()
    ..writeln('/// Üretilen API kodunun dışa açık dosyası (ADR-0005).')
    ..writeln('library;')
    ..writeln();
  for (final group in groupNames) {
    out.writeln("export '$importBase/apis/${apiFileName(group)}';");
  }
  out
    ..writeln("export '$importBase/models.dart';")
    ..writeln("export '$importBase/problem_type.dart';")
    ..writeln(
      "export '$importBase/transport.dart' show ApiTransport, ResponseKind;",
    );
  return out.toString();
}

// ------------------------------------------------------------------- enum

void _enum(
  StringBuffer out, {
  required String name,
  required List<String> doc,
  required List<String> wires,
}) {
  _doc(out, doc, '');
  out.writeln('enum $name {');
  for (final wire in wires) {
    if (wire == 'unknown') continue;
    out.writeln('  ${enumDegerAdi(wire)}(${dartString(wire)}),');
  }
  if (wires.contains('unknown')) {
    out
      ..writeln()
      ..writeln(
        '  /// Sözleşmedeki `unknown`; tanınmayan değerler de buna düşer.',
      )
      ..writeln("  unknown('unknown');");
  } else {
    out
      ..writeln()
      ..writeln('  /// Sözleşmede yok: okunurken tanınmayan değer.')
      ..writeln('  /// Sunucuya hiçbir zaman gönderilmez.')
      ..writeln('  unknown(null);');
  }
  out
    ..writeln()
    ..writeln('  const $name(this._wire);')
    ..writeln()
    ..writeln('  final String? _wire;')
    ..writeln()
    ..writeln(
      '  /// JSON\'daki değer. Sözleşmede olmayan [unknown] gönderilemez;',
    )
    ..writeln('  /// [StateError] fırlatır.')
    ..writeln('  String get wire =>')
    ..writeln(
      "      _wire ?? (throw StateError('$name.unknown gönderilemez'));",
    )
    ..writeln()
    ..writeln('  /// [wire] değerinden okur; tanınmayan değer [unknown] olur.')
    ..writeln('  static $name fromWire(String wire) {')
    ..writeln('    for (final value in values) {')
    ..writeln('      if (value._wire == wire) {')
    ..writeln('        return value;')
    ..writeln('      }')
    ..writeln('    }')
    ..writeln('    return unknown;')
    ..writeln('  }')
    ..writeln('}');
}

// ----------------------------------------------------------------- models

String _models(ApiModel model) {
  final out = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln()
    ..writeln('/// Sözleşmedeki şemalar ve satır içi tipleri (ADR-0005).')
    ..writeln('///')
    ..writeln('/// Modeller değişmezdir. Okurken tanınmayan JSON alanları yok')
    ..writeln('/// sayılır; yazarken `null` alanlar yazılmaz. Zamanlar UTC.')
    ..writeln('/// `toString` bilerek üretilmez: alan değerleri log\'a')
    ..writeln('/// düşmesin (CLAUDE.md kesin kural 3).')
    ..writeln('library;')
    ..writeln();
  final names = {...model.enums.keys, ...model.classes.keys}.toList()..sort();
  for (final name in names) {
    final enumDef = model.enums[name];
    if (enumDef != null) {
      _enum(out, name: name, doc: enumDef.doc, wires: enumDef.wires);
    } else {
      _class(out, model.classes[name]!);
    }
    out.writeln();
  }
  out.write(_modelHelpers);
  return out.toString();
}

bool _isCollection(TypeRef type) => type is ListRef || type is MapRef;

void _class(StringBuffer out, ClassDef def) {
  final name = def.name;
  _doc(out, def.doc, '');
  out
    ..writeln('final class $name {')
    ..write('  const $name(');
  if (def.fields.isEmpty) {
    out.writeln(');');
  } else {
    out.writeln('{');
    for (final field in def.fields) {
      final prefix = field.isRequired ? 'required ' : '';
      out.writeln('    ${prefix}this.${field.dartName},');
    }
    out.writeln('  });');
  }

  // fromJson
  out
    ..writeln()
    ..writeln('  /// JSON nesnesinden okur; tanınmayan alanlar yok sayılır.')
    ..writeln('  /// Eksik ya da yanlış tipte zorunlu alan [FormatException]')
    ..writeln(
      '  /// fırlatır (mesajda değer değil, yalnızca alan adı vardır).',
    );
  if (def.fields.isEmpty) {
    out.writeln(
      '  factory $name.fromJson(Map<String, Object?> json) => const $name();',
    );
  } else {
    out.writeln(
      '  factory $name.fromJson(Map<String, Object?> json) => $name(',
    );
    for (final field in def.fields) {
      final at = dartString('$name.${field.jsonName}');
      final raw = 'json[${dartString(field.jsonName)}]';
      final String value;
      if (field.isRequired) {
        value = _decode(field.type, raw, at, 0);
      } else {
        value =
            'switch ($raw) { null => null, final Object v => '
            '${_decode(field.type, 'v', at, 0)} }';
      }
      out.writeln('    ${field.dartName}: $value,');
    }
    out.writeln('  );');
  }

  // alanlar
  for (final field in def.fields) {
    out.writeln();
    _doc(out, field.doc, '  ');
    final nullable = field.isRequired ? '' : '?';
    out.writeln('  final ${field.type.dart}$nullable ${field.dartName};');
  }

  // toJson
  out
    ..writeln()
    ..writeln('  /// JSON nesnesine yazar; `null` alanlar yazılmaz.')
    ..writeln('  Map<String, Object?> toJson() => <String, Object?>{');
  for (final field in def.fields) {
    final key = dartString(field.jsonName);
    if (field.isRequired) {
      out.writeln('    $key: ${_encode(field.type, field.dartName, 0)},');
    } else {
      out.writeln(
        '    if (${field.dartName} case final value?) '
        '$key: ${_encode(field.type, 'value', 0)},',
      );
    }
  }
  out.writeln('  };');

  // == ve hashCode
  out
    ..writeln()
    ..writeln('  @override')
    ..writeln('  bool operator ==(Object other) =>')
    ..write('      identical(this, other) || other is $name');
  for (final field in def.fields) {
    final f = field.dartName;
    out.write(
      _isCollection(field.type)
          ? ' && _deepEquals($f, other.$f)'
          : ' && $f == other.$f',
    );
  }
  out
    ..writeln(';')
    ..writeln()
    ..writeln('  @override')
    ..write('  int get hashCode => Object.hashAll(<Object?>[');
  out.write(
    def.fields
        .map(
          (f) =>
              _isCollection(f.type) ? '_deepHash(${f.dartName})' : f.dartName,
        )
        .join(', '),
  );
  out
    ..writeln(']);')
    ..writeln('}');
}

/// JSON değerini ([expr], tipi `Object`) [type]'a çeviren ifade.
String _decode(TypeRef type, String expr, String at, int depth) {
  switch (type) {
    case PrimitiveRef(:final kind):
      final helper = switch (kind) {
        Primitive.string => '_readString',
        Primitive.integer => '_readInt',
        Primitive.number => '_readDouble',
        Primitive.boolean => '_readBool',
        Primitive.dateTime => '_readDateTime',
      };
      return '$helper($expr, $at)';
    case EnumRef(:final name):
      return '$name.fromWire(_readString($expr, $at))';
    case ClassRef(:final name):
      return '$name.fromJson(_readObject($expr, $at))';
    case ListRef(:final item):
      final e = 'e$depth';
      return 'List<${item.dart}>.unmodifiable(_readList($expr, $at).map('
          '(Object? $e) => ${_decode(item, e, at, depth + 1)}))';
    case MapRef(:final value):
      final k = 'k$depth';
      final e = 'e$depth';
      return 'Map<String, ${value.dart}>.unmodifiable(_readObject($expr, $at)'
          '.map((String $k, Object? $e) => '
          'MapEntry($k, ${_decode(value, e, at, depth + 1)})))';
  }
}

/// Dart değerini ([expr]) JSON'a çeviren ifade.
String _encode(TypeRef type, String expr, int depth) {
  switch (type) {
    case PrimitiveRef(kind: Primitive.dateTime):
      return '$expr.toUtc().toIso8601String()';
    case PrimitiveRef():
      return expr;
    case EnumRef():
      return '$expr.wire';
    case ClassRef():
      return '$expr.toJson()';
    case ListRef(:final item):
      final e = 'e$depth';
      return '<Object?>[for (final $e in $expr) ${_encode(item, e, depth + 1)}]';
    case MapRef(:final value):
      final e = 'e$depth';
      return '<String, Object?>{for (final $e in $expr.entries) '
          '$e.key: ${_encode(value, '$e.value', depth + 1)}}';
  }
}

const String _modelHelpers = r'''
// -------------------------------------------------------------- yardımcılar
// Hata mesajları yalnızca alan yolunu taşır, değeri değil (kesin kural 3).

Never _invalid(String at) => throw FormatException('Geçersiz JSON alanı: $at');

String _readString(Object? value, String at) =>
    value is String ? value : _invalid(at);

int _readInt(Object? value, String at) => value is int ? value : _invalid(at);

double _readDouble(Object? value, String at) =>
    value is num ? value.toDouble() : _invalid(at);

bool _readBool(Object? value, String at) =>
    value is bool ? value : _invalid(at);

/// Yalnızca saat dilimli (`Z` ya da `+03:00`) zamanlar kabul edilir; sonuç UTC.
DateTime _readDateTime(Object? value, String at) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null || !parsed.isUtc) {
    _invalid(at);
  }
  return parsed;
}

Map<String, Object?> _readObject(Object? value, String at) =>
    value is Map<String, Object?> ? value : _invalid(at);

List<Object?> _readList(Object? value, String at) =>
    value is List<Object?> ? value : _invalid(at);

bool _deepEquals(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !_deepEquals(entry.value, b[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

int _deepHash(Object? value) => switch (value) {
  List<Object?>() => Object.hashAll(value.map(_deepHash)),
  Map<String, Object?>() => Object.hashAllUnordered(
    value.entries.map((e) => Object.hash(e.key, _deepHash(e.value))),
  ),
  _ => value.hashCode,
};
''';

// ----------------------------------------------------------- problem_type

String _problemType(List<String> codes) {
  final out = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln()
    ..writeln('/// Sözleşmedeki hata kodları (ADR-0005).')
    ..writeln('library;')
    ..writeln();
  _enum(
    out,
    name: 'ProblemType',
    doc: const [
      'Problem yanıtının `type` alanındaki kod: '
          '`https://tayfam.app/problems/<kod>`.',
      '',
      'Kaynak: `components.responses.Problem` → `x-problem-types`.',
      'Bilinmeyen kod [unknown] olur ve genel hata metnine düşer.',
    ],
    wires: codes,
  );
  return out.toString();
}

// -------------------------------------------------------------- uç sınıfı

String _apiClass(
  String group,
  List<OperationDef> operations,
  ApiModel model,
  String importBase,
) {
  final className = apiClassName(group);
  final body = StringBuffer();
  for (final op in operations) {
    body.writeln();
    _operation(body, op, model);
  }
  final usesModels = operations.any(
    (op) =>
        op.response is JsonResponse ||
        op.body != null ||
        op.params.any((p) => p.type is EnumRef),
  );
  final out = StringBuffer()
    ..writeln(generatedHeader)
    ..writeln();
  if (usesModels) out.writeln("import '$importBase/models.dart';");
  out
    ..writeln("import '$importBase/transport.dart';")
    ..writeln()
    ..writeln('/// Yol kaynağı `$group` olan uçlar.')
    ..writeln('final class $className {')
    ..writeln('  const $className(this._transport);')
    ..writeln()
    ..writeln('  final ApiTransport _transport;')
    ..write(body)
    ..writeln('}');
  return out.toString();
}

String _paramValue(ParamDef param, String expr) => switch (param.type) {
  EnumRef() => '$expr.wire',
  PrimitiveRef(kind: Primitive.string) => expr,
  _ => "'\$$expr'",
};

void _operation(StringBuffer out, OperationDef op, ApiModel model) {
  final doc = <String>[
    if (op.summary != null) op.summary!.trim(),
    if (op.description != null && op.description!.trim().isNotEmpty) ...[
      '',
      ...op.description!.trimRight().split('\n').map((l) => l.trimRight()),
    ],
    '',
    '`${op.method} ${op.path}`',
    if (!op.authenticated) ...[
      '',
      'Kimlik doğrulaması gerektirmez (`security: []`).',
    ],
  ];
  for (final param in op.params) {
    if (param.doc.isEmpty) continue;
    doc
      ..add('')
      ..add('[${param.dartName}]: ${param.doc.first}')
      ..addAll(param.doc.skip(1));
  }
  _doc(out, doc, '  ');

  final response = op.response;
  final returnType = switch (response) {
    JsonResponse(:final type) => type.name,
    NoContentResponse() => 'void',
    TextResponse() => 'String',
  };
  final expect = switch (response) {
    JsonResponse() => 'ResponseKind.json',
    NoContentResponse() => 'ResponseKind.none',
    TextResponse() => 'ResponseKind.text',
  };

  // İmza: önce zorunlular (yol, zorunlu sorgu, zorunlu gövde), sonra
  // isteğe bağlılar; her grup sözleşmedeki sırayla.
  final signature = <String>[];
  final body = op.body;
  for (final param in op.params.where((p) => p.isRequired)) {
    signature.add('required ${param.type.dart} ${param.dartName}');
  }
  if (body != null && body.isRequired) {
    signature.add('required ${body.type.name} body');
  }
  for (final param in op.params.where((p) => !p.isRequired)) {
    signature.add('${param.type.dart}? ${param.dartName}');
  }
  if (body != null && !body.isRequired) {
    signature.add('${body.type.name}? body');
  }
  final params = signature.isEmpty ? '' : '{${signature.join(', ')},}';
  out.writeln('  Future<$returnType> ${op.operationId}($params) async {');

  final minProperties = body == null
      ? null
      : model.classes[body.type.name]!.minProperties;
  var bodyExpr = body == null
      ? null
      : (body.isRequired ? 'body.toJson()' : 'body?.toJson()');
  if (body != null && minProperties != null && minProperties > 0) {
    final tooFew = body.isRequired
        ? 'json.length < $minProperties'
        : 'json != null && json.length < $minProperties';
    final message = dartString(
      '${body.type.name}: en az $minProperties alan verilmeli',
    );
    out
      ..writeln('    final json = $bodyExpr;')
      ..writeln('    if ($tooFew) {')
      ..writeln('      throw ArgumentError($message);')
      ..writeln('    }');
    bodyExpr = 'json';
  }

  final args = <String>[
    'method: ${dartString(op.method)}',
    'pathTemplate: ${dartString(op.path)}',
  ];
  final pathParams = op.params.where((p) => p.location == ParamLocation.path);
  if (pathParams.isNotEmpty) {
    final entries = pathParams
        .map((p) => '${dartString(p.jsonName)}: ${_paramValue(p, p.dartName)}')
        .join(', ');
    args.add('pathParams: {$entries}');
  }
  final queryParams = op.params.where((p) => p.location == ParamLocation.query);
  if (queryParams.isNotEmpty) {
    final entries = queryParams
        .map((p) {
          final key = dartString(p.jsonName);
          if (p.isRequired) return '$key: ${_paramValue(p, p.dartName)}';
          return 'if (${p.dartName} != null) '
              '$key: ${_paramValue(p, p.dartName)}';
        })
        .join(', ');
    args.add('query: {$entries}');
  }
  if (bodyExpr != null) args.add('body: $bodyExpr');
  args
    ..add('expect: $expect')
    ..add('authenticated: ${op.authenticated}');

  final call = '_transport.send(${args.join(', ')},)';
  final id = dartString(op.operationId);
  switch (response) {
    case JsonResponse(:final type):
      out
        ..writeln('    final response = await $call;')
        ..writeln(
          '    return ${type.name}.fromJson(jsonObject(response, $id));',
        );
    case NoContentResponse():
      out.writeln('    await $call;');
    case TextResponse():
      out
        ..writeln('    final response = await $call;')
        ..writeln('    return textBody(response, $id);');
  }
  out.writeln('  }');
}

// --------------------------------------------------------------- transport

const String _transport =
    '''
$generatedHeader

/// Üretilen uç sınıflarının istek gönderdiği taşıma arayüzü (ADR-0005).
///
/// Gerçek uygulama `ApiClient`'tır: başlıkları (`Authorization`,
/// `X-Tayfam-Client`, `X-Tayfam-Client-Version`) o ekler, token yenilemeyi
/// ve `application/problem+json` yanıtlarını (`ApiProblem`) o yönetir.
library;

/// Başarılı yanıt gövdesinin beklenen biçimi.
enum ResponseKind {
  /// `application/json`; [ApiTransport.send] çözülmüş JSON döndürür.
  json,

  /// Gövde yok (`204`); [ApiTransport.send] `null` döndürür.
  none,

  /// Düz metin (örneğin `text/calendar`); [ApiTransport.send] `String`
  /// döndürür.
  text,
}

/// Uç sınıflarının tek bağımlılığı.
abstract interface class ApiTransport {
  /// İsteği gönderir ve başarılı yanıtın gövdesini [expect]'e göre döndürür.
  ///
  /// - [method]: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
  /// - [pathTemplate]: sözleşmedeki yol şablonu (`/v1/tayfas/{tayfa_id}`);
  ///   log'a yalnızca bu yazılır, gerçek kimlikler değil.
  /// - [pathParams]: şablondaki adlar → ham değerler; uygulama her değeri
  ///   yüzde kodlamasıyla (`Uri.encodeComponent`) yerleştirir.
  /// - [query]: yalnızca verilen sorgu parametreleri, dize olarak.
  /// - [body]: JSON'a çevrilecek gövde; `null` ise gövde gönderilmez.
  /// - [authenticated]: sözleşmedeki geçerli `security`'den gelir;
  ///   `false` (`security: []`) ise uygulama `Authorization` eklemez ve
  ///   token yenilemeyi denemez. Yoldan tahmin edilmez.
  ///
  /// Hata yanıtında tipli değer döndürmez, `ApiProblem` fırlatır.
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  });
}

/// Üretilen kod içindir: JSON yanıtının nesne olduğunu doğrular.
Map<String, Object?> jsonObject(Object? response, String operationId) {
  if (response is Map<String, Object?>) {
    return response;
  }
  throw FormatException('\$operationId: yanıt JSON nesnesi değil');
}

/// Üretilen kod içindir: metin yanıtının dize olduğunu doğrular.
String textBody(Object? response, String operationId) {
  if (response is String) {
    return response;
  }
  throw FormatException('\$operationId: yanıt metin değil');
}
''';
