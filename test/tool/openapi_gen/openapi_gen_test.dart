import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/openapi_gen/openapi_gen.dart';

const SpecSource _source = SpecSource(
  repo: 'ornek/api',
  commit: '0123456789abcdef0123456789abcdef01234567',
  path: 'api/openapi/gateway.yaml',
);

/// Küçük bir örnek sözleşme. JSON, YAML'ın alt kümesi olduğu için
/// sözleşmeler Dart haritasıyla kurulur.
String _spec({
  Map<String, Object?> paths = const {},
  Map<String, Object?> schemas = const {},
  Map<String, Object?> parameters = const {},
  List<String> problems = const ['invalid-request', 'not-found'],
}) => jsonEncode({
  'openapi': '3.1.0',
  'info': {'title': 'Örnek', 'version': '0.1.0'},
  'paths': paths,
  'components': {
    'schemas': schemas,
    'parameters': parameters,
    'responses': {
      'Problem': {
        'description': 'Hata',
        'content': {
          'application/problem+json': {
            'schema': {r'$ref': '#/components/schemas/Problem'},
          },
        },
        'x-problem-types': problems,
      },
    },
  },
});

Map<String, Object?> _ref(String name) => {
  r'$ref': '#/components/schemas/$name',
};

Map<String, Object?> _json(Map<String, Object?> schema) => {
  'content': {
    'application/json': {'schema': schema},
  },
};

const Map<String, Object?> _problem = {
  r'$ref': '#/components/responses/Problem',
};

GenResult _generate(String spec) => generate(spec, source: _source);

String _models(String spec) => _generate(spec).files['models.dart']!;

void main() {
  group('tip eşlemesi', () {
    final schemas = {
      'Tag': {
        'type': 'object',
        'required': ['id'],
        'properties': {
          'id': {'type': 'string', 'format': 'uuid'},
        },
      },
      'Thing': {
        'type': 'object',
        'additionalProperties': false,
        'required': [
          'id',
          'created_at',
          'count',
          'ratio',
          'flag',
          'tags',
          'services',
          'link',
          'big',
        ],
        'properties': {
          'id': {'type': 'string', 'format': 'uuid'},
          'created_at': {'type': 'string', 'format': 'date-time'},
          'birth_date': {'type': 'string', 'format': 'date'},
          'count': {'type': 'integer'},
          'big': {'type': 'integer', 'format': 'int64'},
          'ratio': {'type': 'number'},
          'flag': {'type': 'boolean'},
          'link': {'type': 'string', 'format': 'uri'},
          'tags': {'type': 'array', 'items': _ref('Tag')},
          'names': {
            'type': 'array',
            'items': {'type': 'string'},
          },
          'services': {
            'type': 'object',
            'additionalProperties': {
              'type': 'string',
              'enum': ['ok', 'unavailable'],
            },
          },
          'inner': {
            'type': 'object',
            'properties': {
              'on': {'type': 'boolean'},
            },
          },
        },
      },
    };
    late final String models;
    setUpAll(() => models = _models(_spec(schemas: schemas)));

    test('ilkel tipler', () {
      expect(models, contains('final String id;'));
      expect(models, contains('final DateTime createdAt;'));
      expect(models, contains('final int count;'));
      expect(models, contains('final int big;'));
      expect(models, contains('final double ratio;'));
      expect(models, contains('final bool flag;'));
      expect(models, contains('final String link;'));
    });

    test('date String kalır, belgede biçimi yazar', () {
      expect(models, contains('final String? birthDate;'));
      expect(models, contains('`YYYY-AA-GG`'));
    });

    test('DateTime UTC yazılır ve okunur', () {
      expect(
        models,
        contains("'created_at': createdAt.toUtc().toIso8601String()"),
      );
      expect(models, contains("_readDateTime(json['created_at']"));
      expect(models, contains('!parsed.isUtc'));
    });

    test('dizi, harita ve satır içi tipler', () {
      expect(models, contains('final List<Tag> tags;'));
      expect(models, contains('final List<String>? names;'));
      expect(models, contains('final Map<String, ThingServicesValue> services;'));
      expect(models, contains('enum ThingServicesValue {'));
      expect(models, contains('final ThingInner? inner;'));
      expect(models, contains('final class ThingInner {'));
      // Ayrılmış kelime alan adı: `on` → `on_`, JSON adı korunur.
      expect(models, contains('final bool? on_;'));
      expect(models, contains("'on': value"));
    });

    test('modeller değişmez; == ve hashCode üretilir, toString üretilmez', () {
      expect(models, contains('const Thing({'));
      expect(models, contains('List<Tag>.unmodifiable('));
      expect(models, contains('bool operator ==(Object other)'));
      expect(models, contains('_deepEquals(tags, other.tags)'));
      expect(models, contains('int get hashCode'));
      expect(models, isNot(contains('String toString()')));
    });

    test('tipler ada göre sıralı', () {
      final order = [
        'final class Tag {',
        'final class Thing {',
        'final class ThingInner {',
        'enum ThingServicesValue {',
      ].map(models.indexOf).toList();
      expect(order.every((i) => i >= 0), isTrue);
      expect([...order]..sort(), order);
    });
  });

  group('isteğe bağlı alan', () {
    final spec = _spec(
      schemas: {
        'Note': {
          'type': 'object',
          'required': ['id'],
          'properties': {
            'id': {'type': 'string'},
            'text': {'type': 'string', 'maxLength': 500},
          },
        },
      },
    );

    test('T? olur, required değildir ve null yazılmaz', () {
      final models = _models(spec);
      expect(models, contains('final String? text;'));
      expect(models, contains('required this.id,'));
      expect(models, contains('    this.text,'));
      expect(models, contains("if (text case final value?) 'text': value"));
      expect(models, contains("switch (json['text']) { null => null"));
    });

    test('kısıtlar belge yorumuna yazılır', () {
      expect(_models(spec), contains('Kısıtlar: maxLength: 500.'));
    });
  });

  group('enum', () {
    final spec = _spec(
      schemas: {
        'RsvpStatus': {
          'type': 'string',
          'enum': ['going', 'not_going', 'switch'],
        },
        'Visibility': {
          'type': 'string',
          'enum': ['members', 'unknown'],
        },
      },
    );

    test('değerler camelCase, wire korunur, ayrılmış kelimeye _ eklenir', () {
      final models = _models(spec);
      expect(models, contains("going('going'),"));
      expect(models, contains("notGoing('not_going'),"));
      expect(models, contains("switch_('switch'),"));
    });

    test('her enum unknown düşüşü taşır; sözleşmede yoksa gönderilmez', () {
      final models = _models(spec);
      expect(models, contains('unknown(null);'));
      expect(models, contains("unknown('unknown');"));
      expect(models, contains('return unknown;'));
      expect(models, contains('throw StateError'));
    });

    test('string olmayan enum hata verir', () {
      final bad = _spec(
        schemas: {
          'Level': {
            'type': 'integer',
            'enum': [1, 2],
          },
        },
      );
      expect(() => _generate(bad), throwsA(isA<GenException>()));
    });
  });

  group('allOf', () {
    Map<String, Object?> holder(List<Object?> allOf) => {
      'Tag': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
        },
      },
      'Holder': {
        'type': 'object',
        'properties': {
          'primary': {'allOf': allOf, 'description': 'Açıklama.'},
        },
      },
    };

    test(r'tek elemanlı allOf doğrudan $ref tipidir', () {
      final models = _models(_spec(schemas: holder([_ref('Tag')])));
      expect(models, contains('final Tag? primary;'));
      expect(models, contains('/// Açıklama.'));
    });

    test('birden çok elemanlı allOf hata verir', () {
      final spec = _spec(schemas: holder([_ref('Tag'), _ref('Tag')]));
      expect(() => _generate(spec), throwsA(isA<GenException>()));
    });
  });

  group('desteklenmeyen yapı', () {
    for (final key in ['oneOf', 'anyOf']) {
      test('$key hata verir', () {
        final spec = _spec(
          schemas: {
            'Tag': {'type': 'object'},
            'Union': {
              'type': 'object',
              'properties': {
                'value': {
                  key: [_ref('Tag'), _ref('Tag')],
                },
              },
            },
          },
        );
        expect(
          () => _generate(spec),
          throwsA(
            isA<GenException>().having(
              (e) => e.message,
              'message',
              contains(key),
            ),
          ),
        );
      });
    }

    test('tip dizisi (nullable) hata verir', () {
      final spec = _spec(
        schemas: {
          'Thing': {
            'type': 'object',
            'properties': {
              'name': {
                'type': ['string', 'null'],
              },
            },
          },
        },
      );
      expect(() => _generate(spec), throwsA(isA<GenException>()));
    });

    test('bilinmeyen string biçimi hata verir', () {
      final spec = _spec(
        schemas: {
          'Thing': {
            'type': 'object',
            'properties': {
              'mail': {'type': 'string', 'format': 'email'},
            },
          },
        },
      );
      expect(() => _generate(spec), throwsA(isA<GenException>()));
    });

    test('x-problem-types yoksa hata verir', () {
      final spec = jsonDecode(_spec()) as Map<String, Object?>;
      final components = spec['components']! as Map<String, Object?>;
      components['responses'] = <String, Object?>{};
      expect(
        () => _generate(jsonEncode(spec)),
        throwsA(isA<GenException>()),
      );
    });
  });

  group('tanınmayan anahtar', () {
    test('hata değil uyarıdır', () {
      final result = _generate(
        _spec(
          schemas: {
            'Event': {
              'type': 'object',
              'properties': {
                'starts_at': {
                  'type': 'string',
                  'format': 'date-time',
                  'description': 'Gelecekte',
                  'en fazla iki yıl ileri.': null,
                },
              },
            },
          },
        ),
      );
      expect(result.warnings, hasLength(1));
      expect(
        result.warnings.single,
        allOf(contains('starts_at'), contains('en fazla iki yıl ileri.')),
      );
      expect(result.files['models.dart'], contains('final DateTime? startsAt;'));
    });
  });

  group('uçlar', () {
    final spec = _spec(
      parameters: {
        'ClientHeader': {
          'name': 'X-Tayfam-Client',
          'in': 'header',
          'required': true,
          'schema': {'type': 'string'},
        },
        'TayfaID': {
          'name': 'tayfa_id',
          'in': 'path',
          'required': true,
          'schema': {'type': 'string', 'format': 'uuid'},
        },
        'PageSize': {
          'name': 'page_size',
          'in': 'query',
          'schema': {'type': 'integer'},
        },
      },
      schemas: {
        'Tayfa': {
          'type': 'object',
          'required': ['id'],
          'properties': {
            'id': {'type': 'string'},
          },
        },
        'TayfaUpdateRequest': {
          'type': 'object',
          'additionalProperties': false,
          'minProperties': 1,
          'properties': {
            'name': {'type': 'string'},
            'description': {'type': 'string'},
          },
        },
        'EventList': {'type': 'object'},
        'MyReport': {'type': 'object'},
      },
      paths: {
        '/v1/tayfas/{tayfa_id}': {
          'parameters': [
            {r'$ref': '#/components/parameters/TayfaID'},
          ],
          'patch': {
            'operationId': 'updateTayfa',
            'summary': 'Tayfayı günceller',
            'parameters': [
              {r'$ref': '#/components/parameters/ClientHeader'},
            ],
            'requestBody': {
              'required': true,
              ..._json(_ref('TayfaUpdateRequest')),
            },
            'responses': {
              '200': {'description': 'Tayfa', ..._json(_ref('Tayfa'))},
              '400': _problem,
            },
          },
          'delete': {
            'operationId': 'deleteTayfa',
            'summary': 'Siler',
            'responses': {
              '204': {'description': 'Silindi'},
              '404': _problem,
            },
          },
        },
        '/v1/tayfas/{tayfa_id}/events': {
          'get': {
            'operationId': 'listEvents',
            'summary': 'Etkinlikler',
            'parameters': [
              {r'$ref': '#/components/parameters/TayfaID'},
              {r'$ref': '#/components/parameters/PageSize'},
              {
                'name': 'status',
                'in': 'query',
                'schema': {
                  'type': 'string',
                  'enum': ['open', 'closed'],
                },
              },
            ],
            'responses': {
              '200': {'description': 'Liste', ..._json(_ref('EventList'))},
            },
          },
        },
        '/v1/tayfas/{tayfa_id}/events/{event_id}/calendar': {
          'get': {
            'operationId': 'getEventCalendar',
            'summary': 'Takvim',
            'parameters': [
              {r'$ref': '#/components/parameters/TayfaID'},
              {
                'name': 'event_id',
                'in': 'path',
                'required': true,
                'schema': {'type': 'string', 'format': 'uuid'},
              },
            ],
            'responses': {
              '200': {
                'description': 'ics',
                'content': {
                  'text/calendar': {
                    'schema': {'type': 'string'},
                  },
                },
              },
            },
          },
        },
        '/v1/me/reports': {
          'post': {
            'operationId': 'reportMessage',
            'summary': 'Şikâyet',
            'responses': {
              '200': {'description': 'Eski', ..._json(_ref('MyReport'))},
              '201': {'description': 'Yeni', ..._json(_ref('MyReport'))},
            },
          },
        },
        '/v1/client-config': {
          'get': {
            'operationId': 'getClientConfig',
            'summary': 'Sürümler',
            'security': <Object?>[],
            'responses': {
              '200': {'description': 'Sürümler', ..._json(_ref('Tayfa'))},
            },
          },
        },
        '/v1/realtime': {
          'get': {
            'operationId': 'connectRealtime',
            'summary': 'WebSocket',
            'responses': {
              '101': {'description': 'Switching Protocols'},
            },
          },
        },
      },
    );
    late final GenResult result;
    setUpAll(() => result = _generate(spec));

    test('yol kaynağına göre gruplanır; WebSocket ucu üretilmez', () {
      expect(
        result.files.keys.where((p) => p.startsWith('apis/')),
        [
          'apis/client_config_api.dart',
          'apis/events_api.dart',
          'apis/me_api.dart',
          'apis/tayfas_api.dart',
        ],
      );
      expect(result.operationCount, 6);
      expect(result.skippedOperations.single, contains('connectRealtime'));
      expect(
        result.files['apis/client_config_api.dart'],
        contains('final class ClientConfigApi {'),
      );
      expect(
        result.files['apis/events_api.dart'],
        allOf(contains('listEvents('), contains('getEventCalendar(')),
      );
      expect(result.files['api.dart'], contains('apis/events_api.dart'));
    });

    test('başlık parametresi metoda girmez', () {
      final tayfas = result.files['apis/tayfas_api.dart']!;
      expect(tayfas, isNot(contains('X-Tayfam-Client')));
      expect(tayfas, isNot(contains('clientHeader')));
      expect(
        tayfas,
        contains(
          'Future<Tayfa> updateTayfa({required String tayfaId, '
          'required TayfaUpdateRequest body,})',
        ),
      );
    });

    test('PATCH yalnızca verilen alanları gönderir', () {
      final tayfas = result.files['apis/tayfas_api.dart']!;
      expect(tayfas, contains('final json = body.toJson();'));
      expect(tayfas, contains('if (json.length < 1) {'));
      expect(tayfas, contains('body: json'));
      expect(tayfas, contains("method: 'PATCH'"));
      final models = result.files['models.dart']!;
      expect(models, contains("if (name case final value?) 'name': value"));
      expect(
        models,
        contains("if (description case final value?) 'description': value"),
      );
    });

    test('204 void, text/calendar String döner', () {
      final tayfas = result.files['apis/tayfas_api.dart']!;
      expect(tayfas, contains('Future<void> deleteTayfa('));
      expect(tayfas, contains('expect: ResponseKind.none'));
      final events = result.files['apis/events_api.dart']!;
      expect(events, contains('Future<String> getEventCalendar('));
      expect(events, contains('expect: ResponseKind.text'));
      expect(events, contains("textBody(response, 'getEventCalendar')"));
    });

    test('sorgu parametreleri yalnızca verilince gönderilir', () {
      final events = result.files['apis/events_api.dart']!;
      expect(
        events,
        contains("if (pageSize != null) 'page_size': '\$pageSize'"),
      );
      expect(events, contains("if (status != null) 'status': status.wire"));
      expect(events, contains('ListEventsStatus? status'));
      expect(events, contains("pathParams: {'tayfa_id': tayfaId}"));
      expect(events, contains("pathTemplate: '/v1/tayfas/{tayfa_id}/events'"));
    });

    test('aynı şemalı 200 ve 201 tek modele döner', () {
      expect(
        result.files['apis/me_api.dart'],
        contains('Future<MyReport> reportMessage() async'),
      );
    });

    test('security: [] belgeye yazılır', () {
      expect(
        result.files['apis/client_config_api.dart'],
        contains('Kimlik doğrulaması gerektirmez'),
      );
    });

    test('farklı şemalı başarılı yanıtlar hata verir', () {
      final bad = _spec(
        schemas: {
          'A': {'type': 'object'},
          'B': {'type': 'object'},
        },
        paths: {
          '/v1/things': {
            'post': {
              'operationId': 'createThing',
              'responses': {
                '200': {'description': 'A', ..._json(_ref('A'))},
                '201': {'description': 'B', ..._json(_ref('B'))},
              },
            },
          },
        },
      );
      expect(() => _generate(bad), throwsA(isA<GenException>()));
    });
  });

  group('hata kodları', () {
    test('ProblemType kebab → camelCase, wire korunur, unknown eklenir', () {
      final problem = _generate(
        _spec(problems: ['invalid-request', 'check-in-too-far']),
      ).files['problem_type.dart']!;
      expect(problem, contains('enum ProblemType {'));
      expect(problem, contains("invalidRequest('invalid-request'),"));
      expect(problem, contains("checkInTooFar('check-in-too-far'),"));
      expect(problem, contains('unknown(null);'));
    });
  });

  group('çıktı', () {
    test('belirleyici: iki üretim aynı', () {
      final spec = _spec(
        schemas: {
          'B': {'type': 'object'},
          'A': {
            'type': 'string',
            'enum': ['x', 'y'],
          },
        },
      );
      expect(_generate(spec).files, _generate(spec).files);
    });

    test('dosya düzeni, başlık ve SOURCE', () {
      final files = _generate(_spec()).files;
      expect(files.keys, [
        'SOURCE',
        'api.dart',
        'models.dart',
        'problem_type.dart',
        'transport.dart',
      ]);
      for (final MapEntry(key: path, value: content) in files.entries) {
        if (path.endsWith('.dart')) {
          expect(content, startsWith(generatedHeader), reason: path);
        }
      }
      expect(
        files['SOURCE'],
        allOf(
          contains('repo: ornek/api\n'),
          contains('commit: 0123456789abcdef0123456789abcdef01234567\n'),
          contains('path: api/openapi/gateway.yaml\n'),
        ),
      );
      expect(files['transport.dart'], contains('abstract interface class'));
      expect(
        files['api.dart'],
        contains('show ApiTransport, ResponseKind;'),
      );
    });
  });
}
