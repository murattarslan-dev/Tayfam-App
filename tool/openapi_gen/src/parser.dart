// gateway.yaml'ı okur ve ara gösterime çevirir (ADR-0005).
//
// Yalnızca sözleşmenin kullandığı OpenAPI 3.1 yapılarını destekler.
// Desteklenmeyen bir yapıda GenException fırlatır; şemadaki tanınmayan
// anahtarları uyarı olarak raporlar.

import 'package:yaml/yaml.dart';

import 'errors.dart';
import 'model.dart';
import 'names.dart';

const String _schemaRefPrefix = '#/components/schemas/';
const String _parameterRefPrefix = '#/components/parameters/';
const String _responseRefPrefix = '#/components/responses/';

const List<String> _methods = ['get', 'put', 'post', 'delete', 'patch'];

/// Şemada tipi belirleyen anahtarlar.
const Set<String> _structuralKeys = {
  r'$ref',
  'type',
  'format',
  'properties',
  'required',
  'additionalProperties',
  'items',
  'enum',
  'allOf',
};

/// Yalnızca belgeye yansıyan anahtarlar.
const Set<String> _annotationKeys = {
  'description',
  'title',
  'default',
  'examples',
  'example',
  'deprecated',
  'minLength',
  'maxLength',
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'minItems',
  'maxItems',
  'uniqueItems',
  'minProperties',
  'maxProperties',
  'pattern',
};

/// Tipi değiştiren ama desteklenmeyen anahtarlar: görülürse hata.
const Set<String> _unsupportedKeys = {
  'oneOf',
  'anyOf',
  'not',
  'discriminator',
  'const',
  'nullable',
  'readOnly',
  'writeOnly',
  'if',
  'then',
  'else',
  'prefixItems',
  'patternProperties',
  'propertyNames',
  'dependentSchemas',
  'dependentRequired',
  'unevaluatedProperties',
  'unevaluatedItems',
  'contains',
  r'$defs',
  r'$dynamicRef',
  'contentMediaType',
  'contentEncoding',
};

/// Belgeye yazılan kısıtlar, bu sırayla.
const List<String> _constraintKeys = [
  'minLength',
  'maxLength',
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'minItems',
  'maxItems',
  'uniqueItems',
  'minProperties',
  'maxProperties',
  'pattern',
];

/// [yaml] metnini okur. Desteklenmeyen yapıda [GenException] fırlatır.
ApiModel parseSpec(String yaml) {
  final Object? doc;
  try {
    doc = _plain(loadYaml(yaml));
  } on YamlException catch (e) {
    throw GenException('YAML okunamadı: ${e.message}');
  }
  return _Parser(_asMap(doc, '(kök)')).parse();
}

/// YamlMap/YamlList'i sıradan Dart koleksiyonlarına çevirir; anahtarlar
/// dizeye çevrilir (`200` → `"200"`), sıra korunur.
Object? _plain(Object? node) {
  if (node is Map<Object?, Object?>) {
    return <String, Object?>{
      for (final entry in node.entries) '${entry.key}': _plain(entry.value),
    };
  }
  if (node is List<Object?>) {
    return <Object?>[for (final item in node) _plain(item)];
  }
  return node;
}

Map<String, Object?> _asMap(Object? value, String at) {
  if (value is Map<String, Object?>) return value;
  throw GenException('$at: nesne bekleniyordu');
}

List<Object?> _asList(Object? value, String at) {
  if (value is List<Object?>) return value;
  throw GenException('$at: dizi bekleniyordu');
}

String _asString(Object? value, String at) {
  if (value is String) return value;
  throw GenException('$at: dize bekleniyordu');
}

final class _Parser {
  _Parser(this.root);

  final Map<String, Object?> root;
  final List<String> warnings = [];
  final Map<String, EnumDef> enums = {};
  final Map<String, ClassDef> classes = {};
  final Set<String> _typeNames = {};
  late final Map<String, Object?> _schemas;
  late final Map<String, Object?> _parameters;
  late final Map<String, Object?> _responses;

  ApiModel parse() {
    final version = root['openapi'];
    if (version is! String || !version.startsWith('3.1.')) {
      throw GenException('yalnızca OpenAPI 3.1 desteklenir (openapi: $version)');
    }
    final components = _asMap(root['components'], 'components');
    _schemas = _asMap(components['schemas'], 'components.schemas');
    _parameters = components['parameters'] == null
        ? const {}
        : _asMap(components['parameters'], 'components.parameters');
    _responses = components['responses'] == null
        ? const {}
        : _asMap(components['responses'], 'components.responses');

    for (final name in _schemas.keys) {
      _reserveTypeName(name, 'components.schemas.$name');
    }
    for (final entry in _schemas.entries) {
      _topLevelSchema(entry.key, entry.value);
    }

    final operations = <OperationDef>[];
    final skipped = <String>[];
    final operationIds = <String>{};
    final paths = _asMap(root['paths'], 'paths');
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final item = _asMap(pathEntry.value, 'paths.$path');
      final common = item['parameters'] == null
          ? const <Object?>[]
          : _asList(item['parameters'], 'paths.$path.parameters');
      for (final entry in item.entries) {
        final at = 'paths.$path.${entry.key}';
        if (entry.key == 'parameters' ||
            entry.key == 'summary' ||
            entry.key == 'description') {
          continue;
        }
        if (!_methods.contains(entry.key)) {
          throw GenException('$at: desteklenmeyen yol anahtarı');
        }
        final op = _asMap(entry.value, at);
        final id = _asString(op['operationId'], '$at.operationId');
        if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(id)) {
          throw GenException('$at: operationId camelCase olmalı: $id');
        }
        if (!operationIds.add(id)) {
          throw GenException('$at: operationId tekrar ediyor: $id');
        }
        if (_isWebSocket(op, at)) {
          skipped.add('${entry.key.toUpperCase()} $path ($id)');
          continue;
        }
        operations.add(_operation(path, entry.key, op, common, at));
      }
    }

    return ApiModel(
      enums: enums,
      classes: classes,
      operations: operations,
      problemTypes: _problemTypes(),
      skippedOperations: skipped,
      warnings: warnings,
    );
  }

  // ---------------------------------------------------------------- şemalar

  void _reserveTypeName(String name, String at) {
    if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(name)) {
      throw GenException('$at: tip adı PascalCase olmalı: $name');
    }
    if (reservedTypeNames.contains(name)) {
      throw GenException('$at: "$name" adı ayrılmış');
    }
    if (!_typeNames.add(name)) {
      throw GenException('$at: "$name" tip adı çakışıyor');
    }
  }

  void _topLevelSchema(String name, Object? raw) {
    final at = 'components.schemas.$name';
    final schema = _asMap(raw, at);
    _checkKeys(schema, at);
    if (schema.containsKey('enum')) {
      enums[name] = _enumDef(name, schema, at);
      return;
    }
    if (schema['type'] == 'object' &&
        schema['additionalProperties'] is! Map<String, Object?>) {
      classes[name] = _classDef(name, schema, at);
      return;
    }
    throw GenException(
      '$at: üst düzey şema yalnızca nesne ya da string enum olabilir',
    );
  }

  /// Şemadaki anahtarları denetler: desteklenmeyen yapı hata, tanınmayan
  /// anahtar uyarıdır.
  void _checkKeys(Map<String, Object?> schema, String at) {
    for (final key in schema.keys) {
      if (_unsupportedKeys.contains(key)) {
        throw GenException('$at: "$key" desteklenmiyor');
      }
      if (_structuralKeys.contains(key) ||
          _annotationKeys.contains(key) ||
          key.startsWith('x-')) {
        continue;
      }
      warnings.add('$at: tanınmayan anahtar "$key" yok sayıldı');
    }
  }

  EnumDef _enumDef(String name, Map<String, Object?> schema, String at) {
    if (schema['type'] != 'string') {
      throw GenException('$at: yalnızca string enum desteklenir');
    }
    final values = _asList(schema['enum'], '$at.enum');
    if (values.isEmpty) throw GenException('$at: enum boş');
    final wires = <String>[];
    final memberNames = <String>{'unknown'};
    for (final value in values) {
      final wire = _asString(value, '$at.enum');
      if (wires.contains(wire)) {
        throw GenException('$at: enum değeri tekrar ediyor: $wire');
      }
      wires.add(wire);
      if (wire == 'unknown') continue;
      if (!memberNames.add(enumDegerAdi(wire))) {
        throw GenException('$at: enum değeri adı çakışıyor: $wire');
      }
    }
    return EnumDef(name: name, wires: wires, doc: _docLines(schema));
  }

  ClassDef _classDef(String name, Map<String, Object?> schema, String at) {
    final properties = schema['properties'] == null
        ? const <String, Object?>{}
        : _asMap(schema['properties'], '$at.properties');
    final requiredList = schema['required'] == null
        ? const <Object?>[]
        : _asList(schema['required'], '$at.required');
    final requiredNames = <String>{};
    for (final value in requiredList) {
      final field = _asString(value, '$at.required');
      if (!properties.containsKey(field)) {
        throw GenException('$at: required alanı tanımlı değil: $field');
      }
      requiredNames.add(field);
    }
    final fields = <FieldDef>[];
    final dartNames = <String>{};
    for (final entry in properties.entries) {
      final fieldAt = '$at.properties.${entry.key}';
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(entry.key)) {
        throw GenException('$fieldAt: alan adı desteklenmiyor');
      }
      final dartName = alanAdi(entry.key);
      if (!dartNames.add(dartName)) {
        throw GenException('$fieldAt: Dart alan adı çakışıyor: $dartName');
      }
      final fieldSchema = _asMap(entry.value, fieldAt);
      fields.add(
        FieldDef(
          jsonName: entry.key,
          dartName: dartName,
          type: _type(fieldSchema, fieldAt, '$name${pascalCase(entry.key)}'),
          isRequired: requiredNames.contains(entry.key),
          doc: _docLines(fieldSchema),
        ),
      );
    }
    final minProperties = schema['minProperties'];
    if (minProperties != null && minProperties is! int) {
      throw GenException('$at.minProperties: tamsayı bekleniyordu');
    }
    return ClassDef(
      name: name,
      fields: fields,
      doc: _docLines(schema),
      minProperties: minProperties as int?,
    );
  }

  /// Bir alanın ya da parametrenin şemasından tipi çıkarır. Satır içi enum
  /// ve nesneler [nameHint] adıyla üretilir.
  TypeRef _type(Map<String, Object?> schema, String at, String nameHint) {
    _checkKeys(schema, at);
    if (schema.containsKey(r'$ref')) {
      _onlyAnnotationsBesides(schema, r'$ref', at);
      return _schemaRef(schema[r'$ref'], at);
    }
    if (schema.containsKey('allOf')) {
      final all = _asList(schema['allOf'], '$at.allOf');
      if (all.length != 1) {
        throw GenException('$at: yalnızca tek elemanlı allOf desteklenir');
      }
      _onlyAnnotationsBesides(schema, 'allOf', at);
      final inner = _asMap(all.single, '$at.allOf[0]');
      if (inner.length != 1 || !inner.containsKey(r'$ref')) {
        throw GenException('$at.allOf[0]: yalnızca \$ref desteklenir');
      }
      return _schemaRef(inner[r'$ref'], '$at.allOf[0]');
    }
    final type = schema['type'];
    if (type is! String) {
      throw GenException('$at: type eksik ya da dizi (desteklenmiyor)');
    }
    final format = schema['format'];
    switch (type) {
      case 'string':
        if (schema.containsKey('enum')) {
          if (format != null) {
            throw GenException('$at: biçimli enum desteklenmiyor');
          }
          _reserveTypeName(nameHint, at);
          enums[nameHint] = _enumDef(nameHint, schema, at);
          return EnumRef(nameHint);
        }
        switch (format) {
          case null || 'uuid' || 'uri' || 'date':
            return const PrimitiveRef(Primitive.string);
          case 'date-time':
            return const PrimitiveRef(Primitive.dateTime);
          default:
            throw GenException('$at: desteklenmeyen string biçimi: $format');
        }
      case 'integer':
        _noEnum(schema, at);
        if (format != null && format != 'int32' && format != 'int64') {
          throw GenException('$at: desteklenmeyen integer biçimi: $format');
        }
        return const PrimitiveRef(Primitive.integer);
      case 'number':
        _noEnum(schema, at);
        if (format != null && format != 'float' && format != 'double') {
          throw GenException('$at: desteklenmeyen number biçimi: $format');
        }
        return const PrimitiveRef(Primitive.number);
      case 'boolean':
        _noEnum(schema, at);
        return const PrimitiveRef(Primitive.boolean);
      case 'array':
        _noEnum(schema, at);
        final items = _asMap(schema['items'], '$at.items');
        return ListRef(_type(items, '$at.items', '${nameHint}Item'));
      case 'object':
        _noEnum(schema, at);
        final additional = schema['additionalProperties'];
        if (additional is Map<String, Object?>) {
          if (schema.containsKey('properties')) {
            throw GenException(
              '$at: properties ile additionalProperties şeması birlikte '
              'desteklenmiyor',
            );
          }
          final valueAt = '$at.additionalProperties';
          return MapRef(_type(additional, valueAt, '${nameHint}Value'));
        }
        _reserveTypeName(nameHint, at);
        classes[nameHint] = _classDef(nameHint, schema, at);
        return ClassRef(nameHint);
      default:
        throw GenException('$at: desteklenmeyen tip: $type');
    }
  }

  void _noEnum(Map<String, Object?> schema, String at) {
    if (schema.containsKey('enum')) {
      throw GenException('$at: yalnızca string enum desteklenir');
    }
  }

  void _onlyAnnotationsBesides(
    Map<String, Object?> schema,
    String key,
    String at,
  ) {
    for (final other in schema.keys) {
      if (other == key || !_structuralKeys.contains(other)) continue;
      throw GenException('$at: "$key" yanında "$other" desteklenmiyor');
    }
  }

  TypeRef _schemaRef(Object? ref, String at) {
    final value = _asString(ref, '$at.\$ref');
    if (!value.startsWith(_schemaRefPrefix)) {
      throw GenException('$at: yalnızca yerel şema referansı desteklenir');
    }
    final name = value.substring(_schemaRefPrefix.length);
    final schema = _schemas[name];
    if (schema == null) {
      throw GenException('$at: tanımsız şema: $name');
    }
    if (_asMap(schema, 'components.schemas.$name').containsKey('enum')) {
      return EnumRef(name);
    }
    return ClassRef(name);
  }

  // ------------------------------------------------------------- işlemler

  bool _isWebSocket(Map<String, Object?> op, String at) {
    final responses = _asMap(op['responses'], '$at.responses');
    return responses.containsKey('101');
  }

  OperationDef _operation(
    String path,
    String method,
    Map<String, Object?> op,
    List<Object?> common,
    String at,
  ) {
    const knownKeys = {
      'operationId',
      'summary',
      'description',
      'parameters',
      'requestBody',
      'responses',
      'security',
      'tags',
      'deprecated',
    };
    for (final key in op.keys) {
      if (knownKeys.contains(key) || key.startsWith('x-')) continue;
      throw GenException('$at: desteklenmeyen işlem anahtarı "$key"');
    }
    final id = op['operationId']! as String;

    final params = _params(
      [
        ...common,
        if (op['parameters'] != null)
          ..._asList(op['parameters'], '$at.parameters'),
      ],
      id,
      at,
    );
    final placeholders = RegExp(r'\{([^}]+)\}')
        .allMatches(path)
        .map((m) => m[1]!)
        .toSet();
    final pathParams = params
        .where((p) => p.location == ParamLocation.path)
        .map((p) => p.jsonName)
        .toSet();
    if (placeholders.length != pathParams.length ||
        !placeholders.containsAll(pathParams)) {
      throw GenException('$at: yol parametreleri yoldaki adlarla uyuşmuyor');
    }

    final body = op['requestBody'] == null
        ? null
        : _body(_asMap(op['requestBody'], '$at.requestBody'), at);
    final names = params.map((p) => p.dartName).toSet();
    if (names.length != params.length ||
        (body != null && names.contains('body'))) {
      throw GenException('$at: parametre adları çakışıyor');
    }

    final security = op['security'];
    return OperationDef(
      operationId: id,
      method: method.toUpperCase(),
      path: path,
      group: _group(path, at),
      summary: op['summary'] as String?,
      description: op['description'] as String?,
      params: params,
      body: body,
      response: _response(_asMap(op['responses'], '$at.responses'), at),
      noAuth: security is List<Object?> && security.isEmpty,
    );
  }

  /// `/v1/<x>/…` → `<x>`; `/v1/tayfas/{tayfa_id}/<x>/…` → `<x>`.
  String _group(String path, String at) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && RegExp(r'^v[0-9]+$').hasMatch(segments[0])) {
      segments.removeAt(0);
    }
    if (segments.isEmpty) throw GenException('$at: yoldan grup çıkmıyor');
    var group = segments[0];
    if (group == 'tayfas' &&
        segments.length >= 3 &&
        segments[1].startsWith('{')) {
      group = segments[2];
    }
    if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(group)) {
      throw GenException('$at: desteklenmeyen grup adı: $group');
    }
    return group;
  }

  List<ParamDef> _params(List<Object?> raw, String operationId, String at) {
    // Aynı ad ve konumdaki işlem parametresi yol parametresini ezer.
    final byKey = <String, Map<String, Object?>>{};
    for (final (index, item) in raw.indexed) {
      final param = _resolve(item, _parameterRefPrefix, _parameters, at);
      final name = _asString(param['name'], '$at.parameters[$index].name');
      final location = _asString(param['in'], '$at.parameters[$index].in');
      byKey['$location:$name'] = param;
    }
    final result = <ParamDef>[];
    for (final param in byKey.values) {
      final name = param['name']! as String;
      final location = param['in']! as String;
      final paramAt = '$at.parameters.$name';
      const knownKeys = {
        'name',
        'in',
        'required',
        'description',
        'schema',
        'deprecated',
        'example',
        'examples',
      };
      for (final key in param.keys) {
        if (knownKeys.contains(key) || key.startsWith('x-')) continue;
        throw GenException('$paramAt: desteklenmeyen parametre anahtarı "$key"');
      }
      if (location == 'header') {
        // Başlıkları ApiClient ekler (ADR-0005); metoda girmez.
        continue;
      }
      final ParamLocation where;
      switch (location) {
        case 'path':
          where = ParamLocation.path;
        case 'query':
          where = ParamLocation.query;
        default:
          throw GenException('$paramAt: desteklenmeyen konum: $location');
      }
      final isRequired = param['required'] == true;
      if (where == ParamLocation.path && !isRequired) {
        throw GenException('$paramAt: yol parametresi zorunlu olmalı');
      }
      final schema = _asMap(param['schema'], '$paramAt.schema');
      final type = _type(
        schema,
        '$paramAt.schema',
        '${pascalCase(operationId)}${pascalCase(name)}',
      );
      final supported =
          type is EnumRef ||
          (type is PrimitiveRef &&
              (type.kind == Primitive.string ||
                  type.kind == Primitive.integer ||
                  type.kind == Primitive.boolean));
      if (!supported) {
        throw GenException('$paramAt: desteklenmeyen parametre tipi');
      }
      result.add(
        ParamDef(
          jsonName: name,
          dartName: alanAdi(name),
          location: where,
          type: type,
          isRequired: isRequired,
          doc: _docLines({
            ...schema,
            if (param['description'] != null)
              'description': param['description'],
          }),
        ),
      );
    }
    return result;
  }

  BodyDef _body(Map<String, Object?> requestBody, String at) {
    final bodyAt = '$at.requestBody';
    for (final key in requestBody.keys) {
      if (key == 'content' || key == 'required' || key == 'description') {
        continue;
      }
      throw GenException('$bodyAt: desteklenmeyen anahtar "$key"');
    }
    final content = _asMap(requestBody['content'], '$bodyAt.content');
    if (content.length != 1 || !content.containsKey('application/json')) {
      throw GenException('$bodyAt: yalnızca application/json gövde desteklenir');
    }
    final media = _asMap(content['application/json'], '$bodyAt.content');
    final schema = _asMap(media['schema'], '$bodyAt.content.schema');
    final type = schema.containsKey(r'$ref')
        ? _type(schema, '$bodyAt.content.schema', 'Unused')
        : null;
    if (type is! ClassRef) {
      throw GenException('$bodyAt: gövde bir nesne şemasına \$ref olmalı');
    }
    return BodyDef(type: type, isRequired: requestBody['required'] == true);
  }

  ResponseShape _response(Map<String, Object?> responses, String at) {
    final shapes = <ResponseShape>{};
    for (final entry in responses.entries) {
      final code = entry.key;
      final responseAt = '$at.responses.$code';
      if (code == 'default' ||
          code.startsWith('4') ||
          code.startsWith('5')) {
        // Hata yanıtları tipli dönmez; taşıma katmanı ApiProblem fırlatır.
        continue;
      }
      if (!RegExp(r'^2[0-9][0-9]$').hasMatch(code)) {
        throw GenException('$responseAt: desteklenmeyen durum kodu');
      }
      final response = _resolve(
        entry.value,
        _responseRefPrefix,
        _responses,
        responseAt,
      );
      for (final key in response.keys) {
        if (key == 'description' || key == 'content' || key == 'headers') {
          continue;
        }
        throw GenException('$responseAt: desteklenmeyen anahtar "$key"');
      }
      final content = response['content'] == null
          ? const <String, Object?>{}
          : _asMap(response['content'], '$responseAt.content');
      if (content.isEmpty) {
        shapes.add(const NoContentResponse());
        continue;
      }
      if (content.length != 1) {
        throw GenException('$responseAt: birden çok içerik türü desteklenmiyor');
      }
      final contentType = content.keys.single;
      final media = _asMap(content[contentType], '$responseAt.content');
      final schema = _asMap(media['schema'], '$responseAt.content.schema');
      if (contentType == 'application/json') {
        final type = schema.containsKey(r'$ref')
            ? _type(schema, '$responseAt.content.schema', 'Unused')
            : null;
        if (type is! ClassRef) {
          throw GenException(
            '$responseAt: JSON yanıtı bir nesne şemasına \$ref olmalı',
          );
        }
        shapes.add(JsonResponse(type));
      } else if (contentType.startsWith('text/')) {
        if (schema['type'] != 'string' || schema.length != 1) {
          throw GenException('$responseAt: metin yanıtı string olmalı');
        }
        shapes.add(TextResponse(contentType));
      } else {
        throw GenException(
          '$responseAt: desteklenmeyen içerik türü: $contentType',
        );
      }
    }
    if (shapes.length != 1) {
      throw GenException(
        '$at: tam olarak bir başarılı yanıt biçimi olmalı (${shapes.length})',
      );
    }
    return shapes.single;
  }

  Map<String, Object?> _resolve(
    Object? raw,
    String prefix,
    Map<String, Object?> components,
    String at,
  ) {
    final map = _asMap(raw, at);
    final ref = map[r'$ref'];
    if (ref == null) return map;
    final value = _asString(ref, at);
    if (!value.startsWith(prefix) || map.length != 1) {
      throw GenException('$at: desteklenmeyen referans: $value');
    }
    final name = value.substring(prefix.length);
    final target = components[name];
    if (target == null) throw GenException('$at: tanımsız referans: $value');
    return _asMap(target, value);
  }

  // ---------------------------------------------------------- hata kodları

  List<String> _problemTypes() {
    const at = 'components.responses.Problem.x-problem-types';
    final problem = _responses['Problem'];
    if (problem == null) {
      throw GenException('components.responses.Problem tanımlı değil');
    }
    final raw = _asMap(problem, 'components.responses.Problem');
    final list = _asList(raw['x-problem-types'], at);
    if (list.isEmpty) throw GenException('$at: boş');
    final codes = <String>[];
    final memberNames = <String>{'unknown'};
    for (final item in list) {
      final code = _asString(item, at);
      if (!RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(code)) {
        throw GenException('$at: desteklenmeyen kod: $code');
      }
      if (codes.contains(code)) {
        throw GenException('$at: kod tekrar ediyor: $code');
      }
      codes.add(code);
      if (code != 'unknown' && !memberNames.add(enumDegerAdi(code))) {
        throw GenException('$at: kod adı çakışıyor: $code');
      }
    }
    return codes;
  }

  // ----------------------------------------------------------------- belge

  /// Şemanın açıklaması ve kısıtları; belge yorumu satırları.
  List<String> _docLines(Map<String, Object?> schema) {
    final lines = <String>[];
    final description = schema['description'];
    if (description is String && description.trim().isNotEmpty) {
      lines.addAll(description.trimRight().split('\n').map((l) => l.trimRight()));
    }
    final constraints = <String>[
      for (final key in _constraintKeys)
        if (schema[key] != null) '$key: ${_docValue(schema[key])}',
    ];
    if (schema['format'] == 'date') {
      constraints.add('biçim: `YYYY-AA-GG` (saat dilimsiz tarih)');
    }
    if (schema['default'] != null) {
      constraints.add('varsayılan (sunucu): ${_docValue(schema['default'])}');
    }
    if (constraints.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Kısıtlar: ${constraints.join('; ')}.');
    }
    return lines;
  }

  String _docValue(Object? value) =>
      value is String ? '`$value`' : '$value';
}
