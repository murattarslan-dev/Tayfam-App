// Sözleşmenin üreticideki ara gösterimi (ADR-0005).

/// Bir alanın, parametrenin ya da yanıtın tipi.
sealed class TypeRef {
  const TypeRef();

  /// Dart'taki tip adı.
  String get dart;
}

/// JSON'un ilkel tipleri ve `date-time`.
enum Primitive {
  string('String'),
  integer('int'),
  number('double'),
  boolean('bool'),
  dateTime('DateTime');

  const Primitive(this.dart);

  final String dart;
}

final class PrimitiveRef extends TypeRef {
  const PrimitiveRef(this.kind);

  final Primitive kind;

  @override
  String get dart => kind.dart;
}

final class EnumRef extends TypeRef {
  const EnumRef(this.name);

  final String name;

  @override
  String get dart => name;
}

final class ClassRef extends TypeRef {
  const ClassRef(this.name);

  final String name;

  @override
  String get dart => name;
}

final class ListRef extends TypeRef {
  const ListRef(this.item);

  final TypeRef item;

  @override
  String get dart => 'List<${item.dart}>';
}

final class MapRef extends TypeRef {
  const MapRef(this.value);

  final TypeRef value;

  @override
  String get dart => 'Map<String, ${value.dart}>';
}

/// Bir string enum'u. [wires] sözleşmedeki sırayla JSON değerleridir.
final class EnumDef {
  const EnumDef({required this.name, required this.wires, required this.doc});

  final String name;
  final List<String> wires;
  final List<String> doc;
}

final class FieldDef {
  const FieldDef({
    required this.jsonName,
    required this.dartName,
    required this.type,
    required this.isRequired,
    required this.doc,
  });

  final String jsonName;
  final String dartName;
  final TypeRef type;
  final bool isRequired;
  final List<String> doc;
}

final class ClassDef {
  const ClassDef({
    required this.name,
    required this.fields,
    required this.doc,
    required this.minProperties,
  });

  final String name;
  final List<FieldDef> fields;
  final List<String> doc;

  /// Şemadaki `minProperties`; yoksa `null`.
  final int? minProperties;
}

enum ParamLocation { path, query }

final class ParamDef {
  const ParamDef({
    required this.jsonName,
    required this.dartName,
    required this.location,
    required this.type,
    required this.isRequired,
    required this.doc,
  });

  final String jsonName;
  final String dartName;
  final ParamLocation location;
  final TypeRef type;
  final bool isRequired;
  final List<String> doc;
}

final class BodyDef {
  const BodyDef({required this.type, required this.isRequired});

  final ClassRef type;
  final bool isRequired;
}

/// Başarılı yanıtın biçimi.
sealed class ResponseShape {
  const ResponseShape();
}

/// `application/json` gövdesi; her zaman bir model.
final class JsonResponse extends ResponseShape {
  const JsonResponse(this.type);

  final ClassRef type;

  @override
  bool operator ==(Object other) =>
      other is JsonResponse && other.type.name == type.name;

  @override
  int get hashCode => type.name.hashCode;
}

/// Gövdesiz yanıt (`204`).
final class NoContentResponse extends ResponseShape {
  const NoContentResponse();

  @override
  bool operator ==(Object other) => other is NoContentResponse;

  @override
  int get hashCode => 0;
}

/// Düz metin gövde (örneğin `text/calendar`).
final class TextResponse extends ResponseShape {
  const TextResponse(this.contentType);

  final String contentType;

  @override
  bool operator ==(Object other) =>
      other is TextResponse && other.contentType == contentType;

  @override
  int get hashCode => contentType.hashCode;
}

final class OperationDef {
  const OperationDef({
    required this.operationId,
    required this.method,
    required this.path,
    required this.group,
    required this.summary,
    required this.description,
    required this.params,
    required this.body,
    required this.response,
    required this.authenticated,
  });

  final String operationId;

  /// Büyük harfle: `GET`, `POST` …
  final String method;
  final String path;

  /// Yol kaynağı: `/v1/<x>/…` ve `/v1/tayfas/{tayfa_id}/<x>/…` → `<x>`.
  final String group;
  final String? summary;
  final String? description;
  final List<ParamDef> params;
  final BodyDef? body;
  final ResponseShape response;

  /// Sözleşmedeki geçerli `security` (işleminki, yoksa kökteki) boş
  /// değil: istek erişim token'ıyla gider. `security: []` olan uçlarda
  /// `false`; `ApiClient` bu uçlarda token eklemez ve yenileme denemez.
  final bool authenticated;
}

/// Sözleşmenin üretilecek tamamı.
final class ApiModel {
  const ApiModel({
    required this.enums,
    required this.classes,
    required this.operations,
    required this.problemTypes,
    required this.skippedOperations,
    required this.warnings,
  });

  final Map<String, EnumDef> enums;
  final Map<String, ClassDef> classes;
  final List<OperationDef> operations;
  final List<String> problemTypes;

  /// Bilerek üretilmeyen işlemler (`101` yanıtlı WebSocket ucu).
  final List<String> skippedOperations;
  final List<String> warnings;
}
