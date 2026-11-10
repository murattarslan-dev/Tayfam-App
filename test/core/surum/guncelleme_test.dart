import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/client_config_api.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/surum/guncelleme.dart';

/// `GET /v1/client-config` sahtesi; gerçek ağ yok.
final class _SahteYapilandirma implements ApiTransport {
  _SahteYapilandirma(this.yanit);

  final Object? Function() yanit;
  int cagri = 0;

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
    cagri++;
    final deger = yanit();
    if (deger is Exception) throw deger;
    return deger;
  }
}

Map<String, Object?> _yapilandirma({
  Map<String, Object?> android = const {},
  Map<String, Object?> ios = const {},
}) => {
  'platforms': {'android': android, 'ios': ios},
};

Future<bool> _denetle(
  Object? Function() yanit, {
  String surum = '1.2.0',
  String istemciAdi = 'android',
}) {
  return ClientConfigSurumDenetleyici(
    api: ClientConfigApi(_SahteYapilandirma(yanit)),
    surum: surum,
    istemciAdi: istemciAdi,
  ).guncellemeGerekliMi();
}

void main() {
  group('ClientConfigSurumDenetleyici', () {
    test('en düşük sürümün altındaysa güncelleme gerekli', () async {
      final yanit = _yapilandirma(
        android: {'min_supported_version': '1.3.0', 'latest_version': '1.4.0'},
      );
      expect(await _denetle(() => yanit), isTrue);
      expect(await _denetle(() => yanit, surum: '1.3.0'), isFalse);
      expect(await _denetle(() => yanit, surum: '1.3.0-rc.1'), isTrue);
      expect(await _denetle(() => yanit, surum: '1.3.0+7'), isFalse);
      expect(await _denetle(() => yanit, surum: '2.0.0'), isFalse);
    });

    test('platformun kendi değeri kullanılıyor', () async {
      final yanit = _yapilandirma(
        android: {'min_supported_version': '1.0.0'},
        ios: {'min_supported_version': '9.0.0'},
      );
      expect(await _denetle(() => yanit), isFalse);
      expect(await _denetle(() => yanit, istemciAdi: 'ios'), isTrue);
      // web değeri yoksa zorlama yok.
      expect(await _denetle(() => yanit, istemciAdi: 'web'), isFalse);
    });

    test('değer yok, bozuk ya da uç yoksa engellenmez', () async {
      expect(await _denetle(_yapilandirma), isFalse);
      expect(
        await _denetle(
          () => _yapilandirma(android: {'min_supported_version': 'v9'}),
        ),
        isFalse,
      );
      expect(await _denetle(() => const ApiOffline()), isFalse);
      expect(await _denetle(() => const ApiTimeout()), isFalse);
      expect(await _denetle(() => <String, Object?>{}), isFalse);
    });

    test('uygulamanın sürümü bilinmiyorsa denetim yapılmıyor', () async {
      var cagri = 0;
      final sonuc = await _denetle(() {
        cagri++;
        return _yapilandirma(android: {'min_supported_version': '9.0.0'});
      }, surum: '');
      expect(sonuc, isFalse);
      expect(cagri, 0);
    });
  });

  group('guncellemeProvider', () {
    test('açılış denetimi güncelleme gerektirirse true olur', () async {
      final kap = ProviderContainer.test(
        overrides: [
          surumDenetleyiciProvider.overrideWithValue(_Sabit(true)),
          httpTasimaProvider.overrideWithValue(_tasima((_) async => _bos())),
        ],
      );
      expect(kap.read(guncellemeProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(kap.read(guncellemeProvider), isTrue);
    });

    test('herhangi bir istek client-outdated alınca true olur', () async {
      final govde = jsonEncode({'type': '${problemTypeOnEki}client-outdated'});
      final tasima = _tasima(
        (_) async => http.Response.bytes(
          utf8.encode(govde),
          426,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      final kap = ProviderContainer.test(
        overrides: [
          surumDenetleyiciProvider.overrideWithValue(_Sabit(false)),
          httpTasimaProvider.overrideWithValue(tasima),
        ],
      );
      expect(kap.read(guncellemeProvider), isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(kap.read(guncellemeProvider), isFalse);

      await expectLater(
        tasima.gonder(method: 'GET', pathTemplate: '/v1/status'),
        throwsA(isA<ApiProblem>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(kap.read(guncellemeProvider), isTrue);
    });
  });
}

final class _Sabit implements SurumDenetleyici {
  _Sabit(this.gerekli);

  final bool gerekli;

  @override
  Future<bool> guncellemeGerekliMi() async => gerekli;
}

http.Response _bos() => http.Response('', 204);

HttpTasima _tasima(Future<http.Response> Function(http.Request) sunucu) =>
    HttpTasima(
      istemci: MockClient(sunucu),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'android',
    );
