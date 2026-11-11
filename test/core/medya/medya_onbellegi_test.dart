import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';

import 'sahteler.dart';

const String _a = '11111111-1111-4111-8111-111111111111';
const String _b = '22222222-2222-4222-8222-222222222222';
const String _c = '33333333-3333-4333-8333-333333333333';

final class _Ortam {
  _Ortam({
    List<MediaUrls> Function(List<String> idler)? yanit,
    http.Response Function(http.Request istek)? depoYaniti,
  }) {
    onbellek = MedyaOnbellegi(
      isteyici: (idler) async {
        istekler.add(idler);
        return (yanit ?? _hepsi)(idler);
      },
      tasima: MedyaTasima(istemci: sahteDepo(depo, yanit: depoYaniti)),
      saat: () => simdi,
    );
  }

  final List<List<String>> istekler = [];
  final List<http.Request> depo = [];
  DateTime simdi = DateTime.utc(2026, 11, 11, 20);
  late final MedyaOnbellegi onbellek;

  static List<MediaUrls> _hepsi(List<String> idler) => [
    for (final id in idler) MediaUrls.fromJson(medyaLinkiJson(id)),
  ];
}

void main() {
  test('aynı turda istenen linkler tek istekte birleşir', () async {
    final o = _Ortam();
    final sonuclar = await Future.wait([
      o.onbellek.link(_a),
      o.onbellek.link(_b),
      o.onbellek.link(_a),
    ]);
    expect(o.istekler, [
      [_a, _b],
    ]);
    expect(sonuclar.every((l) => l != null), isTrue);
    expect(sonuclar[0]!.toString(), isNot(contains('http')));
  });

  test("link expires_at'tan bir dakika öncesine kadar önbellekte", () async {
    final o = _Ortam(
      yanit: (idler) => [
        MediaUrls.fromJson(
          medyaLinkiJson(idler.single, sonGecerlilik: '2026-11-11T20:30:00Z'),
        ),
      ],
    );
    await o.onbellek.link(_a);
    o.simdi = DateTime.utc(2026, 11, 11, 20, 28);
    await o.onbellek.link(_a);
    expect(o.istekler, hasLength(1));
    o.simdi = DateTime.utc(2026, 11, 11, 20, 29, 1);
    await o.onbellek.link(_a);
    expect(o.istekler, hasLength(2));
  });

  test('link en geç bir saat tutulur', () async {
    final o = _Ortam(
      yanit: (idler) => [
        MediaUrls.fromJson(
          medyaLinkiJson(idler.single, sonGecerlilik: '2026-11-12T20:00:00Z'),
        ),
      ],
    );
    await o.onbellek.link(_a);
    o.simdi = o.simdi.add(const Duration(minutes: 59));
    await o.onbellek.link(_a);
    expect(o.istekler, hasLength(1));
    o.simdi = o.simdi.add(const Duration(minutes: 2));
    await o.onbellek.link(_a);
    expect(o.istekler, hasLength(2));
  });

  test('görülemeyen ve geçersiz linkli dosya null; kısa süre sorulmaz', () async {
    final o = _Ortam(
      yanit: (idler) => [
        MediaUrls.fromJson(
          medyaLinkiJson(_b, alan: 'https://kotu.example.com'),
        ),
      ],
    );
    expect(await o.onbellek.link(_a), isNull);
    expect(await o.onbellek.link(_b), isNull);
    expect(await o.onbellek.link(_a), isNull);
    expect(o.istekler, hasLength(2));
    o.simdi = o.simdi.add(const Duration(minutes: 6));
    await o.onbellek.link(_a);
    expect(o.istekler, hasLength(3));
  });

  test('ağ hatası önbelleğe alınmaz', () async {
    var ilk = true;
    final o = _Ortam(
      yanit: (idler) {
        if (ilk) {
          ilk = false;
          throw const FormatException('sahte');
        }
        return _Ortam._hepsi(idler);
      },
    );
    await expectLater(o.onbellek.link(_a), throwsA(isA<FormatException>()));
    expect(await o.onbellek.link(_a), isNotNull);
  });

  test('baytlar bellekte tutulur, aynı varyant yeniden indirilmez', () async {
    final o = _Ortam();
    final ilk = await o.onbellek.bayt(_a, MedyaVaryanti.onizleme);
    final ikinci = await o.onbellek.bayt(_a, MedyaVaryanti.onizleme);
    expect(ilk, isNotNull);
    expect(identical(ilk, ikinci), isTrue);
    expect(o.depo, hasLength(1));
    expect(o.depo.single.url.path, endsWith('/preview'));
    expect(o.depo.single.headers.keys, isNot(contains('Authorization')));
    await o.onbellek.bayt(_a, MedyaVaryanti.tam);
    expect(o.depo.last.url.path, endsWith('/full'));
  });

  test('süresi dolmuş link (403): link bir kez yenilenir', () async {
    var n = 0;
    final o = _Ortam(
      depoYaniti: (_) => ++n == 1
          ? http.Response('', 403, headers: {})
          : http.Response.bytes(Uint8List(3), 200, headers: {}),
    );
    expect(await o.onbellek.bayt(_c, MedyaVaryanti.tam), hasLength(3));
    expect(o.istekler, hasLength(2));
  });

  test('bellek sınırı: en eski kullanılan atılır', () async {
    final buyuk = Uint8List(MedyaOnbellegi.baytEnCok ~/ 2 + 1);
    final o = _Ortam();
    o.onbellek
      ..yerelEkle(_a, MedyaVaryanti.tam, buyuk)
      ..yerelEkle(_b, MedyaVaryanti.tam, buyuk);
    expect(o.onbellek.toplamBayt, buyuk.length);
    // _a atıldı: yeniden indirilir.
    await o.onbellek.bayt(_a, MedyaVaryanti.tam);
    expect(o.depo, hasLength(1));
  });

  test('kapatınca her şey boşalır', () async {
    final o = _Ortam();
    await o.onbellek.bayt(_a, MedyaVaryanti.onizleme);
    o.onbellek.kapat();
    expect(o.onbellek.toplamBayt, 0);
  });
}
