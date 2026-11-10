import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/api.dart';

const String _tayfaId = '00000000-0000-4000-8000-000000000001';
const String _userId = '00000000-0000-4000-8000-000000000002';
const String _eventId = '00000000-0000-4000-8000-000000000003';

Map<String, Object?> _tayfaJson() => {
  'id': _tayfaId,
  'name': 'Örnek tayfa',
  'description': 'Açıklama',
  'interests': ['convoy', 'camp'],
  'join_policy': 'approval',
  'modules': {'announcements': true, 'events': true, 'qa': false},
  'status': 'active',
  'member_count': 12,
  'members_can_create_events': false,
  'created_at': '2026-11-10T09:00:00Z',
  'updated_at': '2026-11-10T12:30:00+03:00',
};

/// Gönderilen istekleri kaydeden, hazır yanıt dönen sahte taşıma.
final class _SahteTasima implements ApiTransport {
  _SahteTasima([this.yanit]);

  final Object? yanit;
  final List<_Istek> istekler = [];

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) async {
    istekler.add(
      _Istek(
        method,
        pathTemplate,
        pathParams,
        query,
        body,
        expect,
        authenticated,
      ),
    );
    return yanit;
  }
}

final class _Istek {
  _Istek(
    this.method,
    this.pathTemplate,
    this.pathParams,
    this.query,
    this.body,
    this.expect,
    this.authenticated,
  );

  final String method;
  final String pathTemplate;
  final Map<String, String> pathParams;
  final Map<String, String> query;
  final Object? body;
  final ResponseKind expect;
  final bool authenticated;
}

void main() {
  group('modeller', () {
    test('fromJson → toJson → fromJson aynı modeli verir', () {
      final tayfa = Tayfa.fromJson(_tayfaJson());
      expect(Tayfa.fromJson(tayfa.toJson()), tayfa);
      expect(Tayfa.fromJson(tayfa.toJson()).hashCode, tayfa.hashCode);
    });

    test('alanlar tiplerine çevrilir; zamanlar UTC', () {
      final tayfa = Tayfa.fromJson(_tayfaJson());
      expect(tayfa.interests, [EventType.convoy, EventType.camp]);
      expect(tayfa.joinPolicy, JoinPolicy.approval);
      expect(tayfa.status, TayfaStatus.active);
      expect(tayfa.modules.qa, isFalse);
      expect(tayfa.modules.polls, isNull);
      expect(tayfa.createdAt, DateTime.utc(2026, 11, 10, 9));
      expect(tayfa.updatedAt, DateTime.utc(2026, 11, 10, 9, 30));
      expect(tayfa.updatedAt.isUtc, isTrue);
      expect(tayfa.toJson()['created_at'], '2026-11-10T09:00:00.000Z');
    });

    test('isteğe bağlı alan yoksa null olur ve yazılmaz', () {
      final tayfa = Tayfa.fromJson(_tayfaJson());
      expect(tayfa.joinCode, isNull);
      expect(tayfa.suspendedAt, isNull);
      final json = tayfa.toJson();
      expect(json.containsKey('join_code'), isFalse);
      expect(json.containsKey('suspended_at'), isFalse);
      expect(json['modules'], {
        'announcements': true,
        'events': true,
        'qa': false,
      });
    });

    test(
      'tanınmayan alan yok sayılır, tanınmayan enum değeri unknown olur',
      () {
        final tayfa = Tayfa.fromJson({
          ..._tayfaJson(),
          'gelecekte_eklenecek_alan': 1,
          'interests': ['convoy', 'yelken'],
          'status': 'gelecek_durum',
        });
        expect(tayfa.interests, [EventType.convoy, EventType.unknown]);
        expect(tayfa.status, TayfaStatus.unknown);
        // Sözleşmede olmayan unknown sunucuya gönderilemez.
        expect(tayfa.toJson, throwsStateError);
      },
    );

    test('koleksiyonlar değiştirilemez', () {
      final tayfa = Tayfa.fromJson(_tayfaJson());
      expect(() => tayfa.interests.add(EventType.hike), throwsUnsupportedError);
    });

    test('eksik zorunlu alan FormatException; mesajda değer yok', () {
      final json = _tayfaJson()..remove('name');
      expect(
        () => Tayfa.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Tayfa.name'), isNot(contains('Açıklama'))),
          ),
        ),
      );
    });

    test('saat dilimsiz zaman reddedilir', () {
      final json = {..._tayfaJson(), 'created_at': '2026-11-10T09:00:00'};
      expect(() => Tayfa.fromJson(json), throwsFormatException);
    });

    test('ProblemType wire değerinden okunur; bilinmeyen kod unknown', () {
      expect(
        ProblemType.fromWire('refresh-conflict'),
        ProblemType.refreshConflict,
      );
      expect(ProblemType.fromWire('yeni-bir-kod'), ProblemType.unknown);
      expect(ProblemType.invalidRequest.wire, 'invalid-request');
    });
  });

  group('uç sınıfları', () {
    test(
      'PATCH yalnızca verilen alanları doğru yol ve yöntemle gönderir',
      () async {
        final tasima = _SahteTasima(_tayfaJson());
        final tayfa = await TayfasApi(tasima).updateTayfa(
          tayfaId: _tayfaId,
          body: const TayfaUpdateRequest(name: 'Yeni ad'),
        );

        final istek = tasima.istekler.single;
        expect(istek.method, 'PATCH');
        expect(istek.pathTemplate, '/v1/tayfas/{tayfa_id}');
        expect(istek.pathParams, {'tayfa_id': _tayfaId});
        expect(istek.query, isEmpty);
        expect(istek.body, {'name': 'Yeni ad'});
        expect(istek.expect, ResponseKind.json);
        expect(istek.authenticated, isTrue);
        expect(tayfa, Tayfa.fromJson(_tayfaJson()));
      },
    );

    test('boş PATCH gövdesi gönderilmeden reddedilir', () async {
      final tasima = _SahteTasima(_tayfaJson());
      await expectLater(
        TayfasApi(tasima)
            .updateTayfa(tayfaId: _tayfaId, body: const TayfaUpdateRequest()),
        throwsArgumentError,
      );
      expect(tasima.istekler, isEmpty);
    });

    test(
      'sorgu parametreleri yalnızca verilince ve wire değeriyle gider',
      () async {
        final tasima = _SahteTasima({'members': <Object?>[]});
        final liste = await MembersApi(tasima).listMembers(
          tayfaId: _tayfaId,
          status: ListMembersStatus.banned,
          pageSize: 20,
        );

        final istek = tasima.istekler.single;
        expect(istek.method, 'GET');
        expect(istek.pathTemplate, '/v1/tayfas/{tayfa_id}/members');
        expect(istek.query, {'status': 'banned', 'page_size': '20'});
        expect(istek.body, isNull);
        expect(liste.members, isEmpty);
        expect(liste.nextPageToken, isNull);
      },
    );

    test('204 yanıtlı uç gövde beklemez', () async {
      final tasima = _SahteTasima();
      await MembersApi(tasima).removeMember(tayfaId: _tayfaId, userId: _userId);

      final istek = tasima.istekler.single;
      expect(istek.method, 'DELETE');
      expect(istek.pathTemplate, '/v1/tayfas/{tayfa_id}/members/{user_id}');
      expect(istek.pathParams, {'tayfa_id': _tayfaId, 'user_id': _userId});
      expect(istek.expect, ResponseKind.none);
    });

    test('text/calendar yanıtı String döner', () async {
      final tasima = _SahteTasima('BEGIN:VCALENDAR');
      final takvim = await EventsApi(tasima)
          .exportEventCalendar(tayfaId: _tayfaId, eventId: _eventId);

      expect(takvim, 'BEGIN:VCALENDAR');
      expect(tasima.istekler.single.expect, ResponseKind.text);
    });

    test('security: [] uçları kimliksiz, diğerleri kimlikli gider', () async {
      final tasima = _SahteTasima();
      await AuthApi(tasima).signOut();
      await expectLater(
        AuthApi(tasima)
            .refresh(body: const RefreshRequest(refreshToken: 'ornek')),
        throwsFormatException,
      );

      expect(tasima.istekler.map((i) => i.pathTemplate), [
        '/v1/auth/sign-out',
        '/v1/auth/refresh',
      ]);
      expect(tasima.istekler.map((i) => i.authenticated), [true, false]);
    });

    test('nesne olmayan JSON yanıtı FormatException', () async {
      final tasima = _SahteTasima(<Object?>[]);
      await expectLater(
        TayfasApi(tasima).getTayfa(tayfaId: _tayfaId),
        throwsFormatException,
      );
    });
  });
}
