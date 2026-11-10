import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';

const String _tayfaId = '00000000-0000-4000-8000-0000000000aa';

http.Response _json(Object? govde, [int durum = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(govde)),
  durum,
  headers: {'content-type': 'application/json'},
);

http.Response _problem(
  String kod,
  int durum, {
  Map<String, String> basliklar = const {},
}) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'type': '$problemTypeOnEki$kod',
      'title': 'Sunucunun gizli başlığı',
      'status': durum,
      'detail': 'Sunucunun ayrıntısı',
    }),
  ),
  durum,
  headers: {'content-type': 'application/problem+json', ...basliklar},
);

final class _Kurulum {
  _Kurulum(
    Future<http.Response> Function(http.Request istek) sunucu, {
    Duration zamanAsimi = const Duration(seconds: 30),
  }) {
    tasima = HttpTasima(
      istemci: MockClient((istek) {
        istekler.add(istek);
        return sunucu(istek);
      }),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'android',
      zamanAsimi: zamanAsimi,
      gunluk: gunluk.add,
    );
  }

  final List<http.Request> istekler = [];
  final List<String> gunluk = [];
  late final HttpTasima tasima;
}

void main() {
  group('adres ve başlıklar', () {
    test('yol parametresi parça parça kodlanır, sorgu eklenir', () async {
      final k = _Kurulum((_) async => _json({'tamam': true}));
      final yanit = await k.tasima.gonder(
        method: 'GET',
        pathTemplate: '/v1/tayfas/{tayfa_id}/events',
        pathParams: {'tayfa_id': 'a/b c'},
        query: {'page_size': '20', 'page_token': 'x&y'},
      );

      expect(yanit, {'tamam': true});
      final istek = k.istekler.single;
      expect(istek.method, 'GET');
      expect(istek.url.scheme, 'https');
      expect(istek.url.host, 'api.ornek.test');
      expect(istek.url.path, '/v1/tayfas/a%2Fb%20c/events');
      expect(istek.url.queryParameters, {
        'page_size': '20',
        'page_token': 'x&y',
      });
      expect(istek.followRedirects, isFalse);
    });

    test('GET istemci başlığı ve token taşımaz', () async {
      final k = _Kurulum((_) async => _json({}));
      await k.tasima.gonder(method: 'GET', pathTemplate: '/v1/status');

      final basliklar = k.istekler.single.headers;
      expect(basliklar.containsKey('X-Tayfam-Client'), isFalse);
      expect(basliklar.containsKey('Authorization'), isFalse);
      expect(basliklar['Accept'], contains('application/problem+json'));
    });

    test(
      'durum değiştiren istek X-Tayfam-Client ve JSON gövde taşır',
      () async {
        final k = _Kurulum((_) async => http.Response('', 204));
        final yanit = await k.tasima.gonder(
          method: 'POST',
          pathTemplate: '/v1/tayfas',
          body: {'name': 'Örnek'},
          expect: ResponseKind.none,
          erisimTokeni: 'erisim-1',
        );

        expect(yanit, isNull);
        final istek = k.istekler.single;
        expect(istek.headers['X-Tayfam-Client'], 'android');
        expect(istek.headers['Authorization'], 'Bearer erisim-1');
        expect(istek.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(istek.body), {'name': 'Örnek'});
      },
    );

    test('metin yanıtı String döner', () async {
      final k = _Kurulum(
        (_) async => http.Response.bytes(utf8.encode('BEGIN:VCALENDAR'), 200),
      );
      final yanit = await k.tasima.gonder(
        method: 'GET',
        pathTemplate: '/v1/x',
        expect: ResponseKind.text,
      );
      expect(yanit, 'BEGIN:VCALENDAR');
    });

    for (final deger in ['', '.', '..']) {
      test('yolu değiştirebilecek parametre ("$deger") reddedilir', () async {
        final k = _Kurulum((_) async => _json({}));
        await expectLater(
          k.tasima.gonder(
            method: 'GET',
            pathTemplate: '/v1/tayfas/{tayfa_id}',
            pathParams: {'tayfa_id': deger},
          ),
          throwsArgumentError,
        );
        expect(k.istekler, isEmpty);
      });
    }

    test(
      'eksik ya da fazla yol parametresi reddedilir; mesajda değer yok',
      () async {
        final k = _Kurulum((_) async => _json({}));
        await expectLater(
          k.tasima.gonder(method: 'GET', pathTemplate: '/v1/tayfas/{tayfa_id}'),
          throwsArgumentError,
        );
        await expectLater(
          k.tasima.gonder(
            method: 'GET',
            pathTemplate: '/v1/status',
            pathParams: {'tayfa_id': _tayfaId},
          ),
          throwsA(
            isA<ArgumentError>().having(
              (e) => '${e.message}',
              'message',
              isNot(contains(_tayfaId)),
            ),
          ),
        );
        expect(k.istekler, isEmpty);
      },
    );

    test('taban adres yalnızca https olabilir', () {
      for (final adres in [
        'http://api.ornek.test',
        'https://kullanici@api.ornek.test',
        'https://api.ornek.test?a=1',
      ]) {
        expect(
          () => HttpTasima(
            istemci: MockClient((_) async => _json({})),
            tabanAdres: Uri.parse(adres),
            istemciAdi: 'android',
          ),
          throwsArgumentError,
          reason: adres,
        );
      }
    });

    test('istemci adı sözleşmedeki değerlerden biri olmalı', () {
      expect(
        () => HttpTasima(
          istemci: MockClient((_) async => _json({})),
          tabanAdres: Uri.parse('https://api.ornek.test'),
          istemciAdi: 'masaustu',
        ),
        throwsArgumentError,
      );
      expect(istemciAdi(web: true, platform: TargetPlatform.android), 'web');
      expect(istemciAdi(web: false, platform: TargetPlatform.iOS), 'ios');
      expect(
        istemciAdi(web: false, platform: TargetPlatform.android),
        'android',
      );
    });

    test('varsayılan taban adres dev ortamı ve https', () {
      expect(Uri.parse(apiTabanAdresi).scheme, 'https');
    });

    test('ApiTransport olarak kimlikli uç gönderilemez', () {
      final k = _Kurulum((_) async => _json({}));
      expect(
        () => k.tasima.send(
          method: 'GET',
          pathTemplate: '/v1/me/account',
          authenticated: true,
        ),
        throwsStateError,
      );
      expect(k.istekler, isEmpty);
    });
  });

  group('hatalar', () {
    test('problem+json → ApiProblem; title ve detail taşınmaz', () async {
      final k = _Kurulum(
        (_) async =>
            _problem('rate-limited', 429, basliklar: {'retry-after': '7'}),
      );
      final hata = await k.tasima
          .gonder(method: 'GET', pathTemplate: '/v1/status')
          .then<Object?>((_) => null, onError: (Object e) => e);

      expect(hata, isA<ApiProblem>());
      final problem = hata! as ApiProblem;
      expect(problem.type, ProblemType.rateLimited);
      expect(problem.status, 429);
      expect(problem.retryAfter, const Duration(seconds: 7));
      expect('$problem', isNot(contains('gizli')));
      expect('$problem', isNot(contains('ayrıntı')));
    });

    test('bilinmeyen kod ve problem olmayan hata genel türe düşer', () async {
      for (final yanit in [
        _problem('gelecekte-eklenecek-kod', 400),
        http.Response('<html>Bad Gateway</html>', 502),
        http.Response.bytes(
          utf8.encode(jsonEncode({'type': 'about:blank', 'status': 400})),
          400,
          headers: {'content-type': 'application/problem+json'},
        ),
        http.Response(
          '{bozuk',
          500,
          headers: {'content-type': 'application/problem+json'},
        ),
        http.Response('', 302, headers: {'location': 'http://baska.test'}),
      ]) {
        final k = _Kurulum((_) async => yanit);
        await expectLater(
          k.tasima.gonder(method: 'GET', pathTemplate: '/v1/status'),
          throwsA(
            isA<ApiProblem>()
                .having((p) => p.type, 'type', ProblemType.unknown)
                .having((p) => p.status, 'status', yanit.statusCode),
          ),
        );
      }
    });

    test('bağlantı hatası ApiOffline', () async {
      final k = _Kurulum((_) async => throw http.ClientException('kopuk'));
      await expectLater(
        k.tasima.gonder(method: 'GET', pathTemplate: '/v1/status'),
        throwsA(isA<ApiOffline>()),
      );
    });

    test('zaman aşımı ApiTimeout', () async {
      final k = _Kurulum(
        (_) => Completer<http.Response>().future,
        zamanAsimi: const Duration(milliseconds: 10),
      );
      await expectLater(
        k.tasima.gonder(method: 'GET', pathTemplate: '/v1/status'),
        throwsA(isA<ApiTimeout>()),
      );
    });

    test('problemTypeOku yalnızca beklenen ön eki kabul eder', () {
      expect(
        problemTypeOku('${problemTypeOnEki}refresh-conflict'),
        ProblemType.refreshConflict,
      );
      expect(
        problemTypeOku('https://baska.test/problems/refresh-conflict'),
        ProblemType.unknown,
      );
      expect(problemTypeOku(42), ProblemType.unknown);
      expect(problemTypeOku(null), ProblemType.unknown);
    });
  });

  group('günlük', () {
    test('yalnızca yöntem, yol şablonu, durum ve problem türü', () async {
      final k = _Kurulum((istek) async {
        if (istek.method == 'POST') return _problem('not-found', 404);
        return _json({'gizli': 'içerik'});
      });
      await k.tasima.gonder(
        method: 'GET',
        pathTemplate: '/v1/tayfas/{tayfa_id}',
        pathParams: {'tayfa_id': _tayfaId},
        query: {'page_token': 'sayfa-gizli'},
        erisimTokeni: 'erisim-gizli',
      );
      await expectLater(
        k.tasima.gonder(
          method: 'POST',
          pathTemplate: '/v1/tayfas/{tayfa_id}/events',
          pathParams: {'tayfa_id': _tayfaId},
          body: {'title': 'gövde-gizli'},
          erisimTokeni: 'erisim-gizli',
        ),
        throwsA(isA<ApiProblem>()),
      );

      expect(k.gunluk, [
        'GET /v1/tayfas/{tayfa_id} → 200',
        'POST /v1/tayfas/{tayfa_id}/events → 404 notFound',
      ]);
      for (final satir in k.gunluk) {
        expect(satir, isNot(contains(_tayfaId)));
        expect(satir, isNot(contains('gizli')));
        expect(satir, isNot(contains('ornek.test')));
      }
    });
  });

  group('istemci sürümü (ADR-0012 §1)', () {
    HttpTasima tasima(
      List<http.Request> istekler,
      String? surum, {
      int durum = 200,
    }) => HttpTasima(
      istemci: MockClient((istek) async {
        istekler.add(istek);
        return durum == 200
            ? _json({'ok': true})
            : _problem('client-outdated', durum);
      }),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'android',
      surumBasligi: surum,
    );

    test('sürüm başlığı GET dahil her istekte gönderiliyor', () async {
      final istekler = <http.Request>[];
      final t = tasima(istekler, 'android/0.1.0+1');
      await t.gonder(method: 'GET', pathTemplate: '/v1/status');
      await t.gonder(
        method: 'POST',
        pathTemplate: '/v1/auth/sign-out',
        expect: ResponseKind.none,
      );
      for (final istek in istekler) {
        expect(istek.headers['X-Tayfam-Client-Version'], 'android/0.1.0+1');
      }
    });

    test('sürüm verilmezse başlık yok', () async {
      final istekler = <http.Request>[];
      await tasima(
        istekler,
        null,
      ).gonder(method: 'GET', pathTemplate: '/v1/status');
      final basliklar = istekler.single.headers;
      expect(basliklar, isNot(contains('X-Tayfam-Client-Version')));
    });

    test('geçersiz sürüm başlığı reddediliyor', () {
      expect(() => tasima([], 'android/v1'), throwsArgumentError);
      expect(() => tasima([], 'masaustu/1.0.0'), throwsArgumentError);
    });

    test('client-outdated olay olarak bildiriliyor', () async {
      final t = tasima([], 'android/0.1.0', durum: 426);
      var olay = 0;
      final abonelik = t.eskiSurumOlaylari.listen((_) => olay++);
      addTearDown(abonelik.cancel);
      await expectLater(
        t.gonder(method: 'GET', pathTemplate: '/v1/status'),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.clientOutdated,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(olay, 1);
    });
  });
}
