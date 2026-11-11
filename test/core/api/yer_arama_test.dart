import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/yer_arama.dart';

List<Map<String, Object?>> _yanit() => [
  {
    'lat': '40.6012',
    'lon': '31.2834',
    'display_name': 'Abant Gölü, Bolu, Türkiye',
    'address': {'province': 'Bolu', 'town': 'Merkez'},
  },
  {'lat': 'x', 'lon': '31', 'display_name': 'Bozuk'},
  {'lat': '95', 'lon': '31', 'display_name': 'Sınır dışı'},
  {'lat': '41.0', 'lon': '29.0', 'display_name': '  '},
];

void main() {
  test('istek: adres, sorgu ve uygulamayı tanıtan User-Agent', () async {
    final istekler = <http.Request>[];
    final arayici = NominatimArayici(
      istemci: MockClient((istek) async {
        istekler.add(istek);
        return http.Response.bytes(utf8.encode(jsonEncode(_yanit())), 200);
      }),
    );

    final sonuclar = await arayici.ara('  Abant Gölü ');

    final istek = istekler.single;
    expect(istek.method, 'GET');
    expect(istek.url.scheme, 'https');
    expect(istek.url.host, 'nominatim.openstreetmap.org');
    expect(istek.url.path, '/search');
    expect(istek.url.queryParameters, {
      'q': 'Abant Gölü',
      'format': 'jsonv2',
      'accept-language': 'tr',
      'countrycodes': 'tr',
      'addressdetails': '1',
      'limit': '10',
    });
    expect(istek.headers['User-Agent'], NominatimArayici.kullaniciAjani);
    expect(istek.headers['User-Agent'], startsWith('Tayfam/'));
    expect(istek.headers['User-Agent'], contains('https://tayfam.app'));
    expect(istek.headers.containsKey('Authorization'), isFalse);

    expect(sonuclar, const [
      YerSonucu(
        ad: 'Abant Gölü, Bolu, Türkiye',
        enlem: 40.6012,
        boylam: 31.2834,
        il: 'Bolu',
        ilce: 'Merkez',
      ),
    ]);
  });

  test('boş metin için istek gitmez', () async {
    var cagri = 0;
    final arayici = NominatimArayici(
      istemci: MockClient((_) async {
        cagri++;
        return http.Response('[]', 200);
      }),
    );
    expect(await arayici.ara('   '), isEmpty);
    expect(cagri, 0);
  });

  test('saniyede en çok bir istek: ikinci arama beklenir', () async {
    var simdi = DateTime.utc(2026, 11, 11, 9);
    final beklemeler = <Duration>[];
    final arayici = NominatimArayici(
      istemci: MockClient((_) async => http.Response('[]', 200)),
      saat: () => simdi,
      bekle: (sure) async {
        beklemeler.add(sure);
        simdi = simdi.add(sure);
      },
    );

    await arayici.ara('bir');
    simdi = simdi.add(const Duration(milliseconds: 300));
    await arayici.ara('iki');
    simdi = simdi.add(const Duration(seconds: 2));
    await arayici.ara('üç');

    expect(beklemeler, [const Duration(milliseconds: 700)]);
  });

  test('ağ hatası, hatalı durum kodu ve bozuk yanıt YerAramaHatasi', () async {
    for (final yanit in [
      () => throw http.ClientException('yok'),
      () => http.Response('[]', 503),
      () => http.Response('{"hata": 1}', 200),
      () => http.Response('<html>', 200),
    ]) {
      final arayici = NominatimArayici(
        istemci: MockClient((_) async => yanit()),
      );
      await expectLater(arayici.ara('Abant'), throwsA(isA<YerAramaHatasi>()));
    }
  });

  test('sonuçlar en çok on tane; ad ve adres parçaları kısaltılır', () {
    final uzun = 'a' * 400;
    final govde = utf8.encode(
      jsonEncode([
        for (var i = 0; i < 15; i++)
          {
            'lat': '$i',
            'lon': '$i',
            'display_name': uzun,
            'address': {'state': 'b' * 80},
          },
      ]),
    );
    final sonuclar = yerSonuclariniOku(govde);
    expect(sonuclar, hasLength(NominatimArayici.enCokSonuc));
    expect(sonuclar.first.ad.length, 300);
    expect(sonuclar.first.il?.length, 50);
    expect(sonuclar.first.ilce, isNull);
  });
}
