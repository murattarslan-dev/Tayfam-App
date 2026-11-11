import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/uploads_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/medya_tasima.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/medya/yukleyici.dart';

import '../../features/hesap/sahteler.dart';
import 'sahteler.dart';

const String _acYolu = 'POST /v1/uploads';
const String _tamamlaYolu = 'POST /v1/uploads/{upload_id}/complete';

HazirGoruntu _goruntu() => HazirGoruntu(
  tam: Uint8List.fromList(List.filled(20, 1)),
  onizleme: Uint8List.fromList(List.filled(10, 2)),
  tamOlcu: const JpegOlculeri(1600, 1200),
  onizlemeOlcu: const JpegOlculeri(400, 300),
);

final class _Ortam {
  _Ortam(
    Map<String, Object? Function()> yanitlar, {
    http.Response Function(http.Request istek)? depoYaniti,
  }) : api = SahteTasima(yanitlar) {
    yukleyici = MedyaYukleyici(
      uploads: UploadsApi(api),
      tasima: MedyaTasima(
        istemci: sahteDepo(depo, yanit: depoYaniti),
        gunluk: gunluk.add,
      ),
      bekle: (sure) async => beklemeler.add(sure),
    );
  }

  final SahteTasima api;
  final List<http.Request> depo = [];
  final List<String> gunluk = [];
  final List<Duration> beklemeler = [];
  late final MedyaYukleyici yukleyici;

  Future<String> yukle({
    UploadPurpose amac = UploadPurpose.avatar,
    String? tayfaId,
  }) => yukleyici.yukle(
    amac: amac,
    goruntu: _goruntu(),
    istekKimligi: 'b1b2c3d4-0000-4000-8000-000000000001',
    tayfaId: tayfaId,
  );

  List<Object?> acmaKimlikleri() => [
    for (final i in api.istekler)
      if (i.yol == '/v1/uploads')
        (i.govde! as Map<String, Object?>)['client_request_id'],
  ];
}

void main() {
  test(
    'aç → iki PUT → tamamla; token ve Tayfam başlıkları depoya gitmez',
    () async {
      final o = _Ortam({
        _acYolu: yuklemeAcildiJson,
        _tamamlaYolu: () => {'upload': yuklemeJson()},
      });

      expect(await o.yukle(), ornekUploadId);

      expect(o.depo, hasLength(2));
      for (final istek in o.depo) {
        expect(istek.method, 'PUT');
        expect(istek.url.host, 'ornekhesap.r2.cloudflarestorage.com');
        final adlar = istek.headers.keys.map((k) => k.toLowerCase()).toSet();
        expect(adlar, isNot(contains('authorization')));
        expect(adlar.where((a) => a.startsWith('x-tayfam')), isEmpty);
        expect(istek.headers['Content-Type'], 'image/jpeg');
        expect(istek.followRedirects, isFalse);
      }
      expect(o.depo[0].bodyBytes, _goruntu().onizleme);
      expect(o.depo[1].bodyBytes, _goruntu().tam);

      final ac = o.api.istekler.first.govde! as Map<String, Object?>;
      expect(ac['purpose'], 'avatar');
      expect(ac.containsKey('tayfa_id'), isFalse);
      expect(ac['variants'], [
        {'kind': 'preview', 'content_type': 'image/jpeg', 'size_bytes': 10},
        {'kind': 'full', 'content_type': 'image/jpeg', 'size_bytes': 20},
      ]);
      expect(o.api.istekler.last.govde, {'width': 1600, 'height': 1200});

      // Günlükte link ya da imza yok.
      for (final satir in o.gunluk) {
        expect(satir, isNot(contains('http')));
        expect(satir, isNot(contains('Signature')));
      }
    },
  );

  test('kapakta tayfa kimliği gönderilir', () async {
    final o = _Ortam({
      _acYolu: yuklemeAcildiJson,
      _tamamlaYolu: () => {'upload': yuklemeJson()},
    });
    await o.yukle(amac: UploadPurpose.cover, tayfaId: 'tayfa-1');
    final ac = o.api.istekler.first.govde! as Map<String, Object?>;
    expect(ac['purpose'], 'cover');
    expect(ac['tayfa_id'], 'tayfa-1');
  });

  test('upload-not-received: varyantlar yeniden PUT edilir', () async {
    var tamamlama = 0;
    final o = _Ortam({
      _acYolu: yuklemeAcildiJson,
      _tamamlaYolu: () => ++tamamlama == 1
          ? problem(ProblemType.uploadNotReceived, 409)
          : {'upload': yuklemeJson()},
    });
    expect(await o.yukle(), ornekUploadId);
    expect(o.depo, hasLength(4));
    expect(tamamlama, 2);
  });

  test('tamamlamada 503: beklenip tekrar denenir', () async {
    var tamamlama = 0;
    final o = _Ortam({
      _acYolu: yuklemeAcildiJson,
      _tamamlaYolu: () => ++tamamlama < 3
          ? problem(ProblemType.unavailable, 503)
          : {'upload': yuklemeJson()},
    });
    expect(await o.yukle(), ornekUploadId);
    expect(o.beklemeler, hasLength(2));
    expect(o.depo, hasLength(2));
  });

  test('tamamlamada 503 sürerse sınırlı denemeden sonra hata', () async {
    final o = _Ortam({
      _acYolu: yuklemeAcildiJson,
      _tamamlaYolu: () => problem(ProblemType.unavailable, 503),
    });
    await expectLater(o.yukle(), throwsA(isA<ApiProblem>()));
    expect(o.api.sayi('POST', '/v1/uploads/{upload_id}/complete'), 3);
  });

  test('medya kapalı (açılışta 503): tekrar denenmez', () async {
    final o = _Ortam({_acYolu: () => problem(ProblemType.unavailable, 503)});
    await expectLater(
      o.yukle(),
      throwsA(
        isA<ApiProblem>().having(
          (p) => p.type,
          'type',
          ProblemType.unavailable,
        ),
      ),
    );
    expect(o.api.sayi('POST', '/v1/uploads'), 1);
    expect(o.depo, isEmpty);
  });

  test(
    'süresi dolmuş link (403): aynı client_request_id ile yeni linkler',
    () async {
      var put = 0;
      final o = _Ortam(
        {
          _acYolu: yuklemeAcildiJson,
          _tamamlaYolu: () => {'upload': yuklemeJson()},
        },
        depoYaniti: (_) =>
            http.Response('', ++put == 1 ? 403 : 200, headers: {}),
      );
      expect(await o.yukle(), ornekUploadId);
      final kimlikler = o.acmaKimlikleri();
      expect(kimlikler, hasLength(2));
      expect(kimlikler.toSet(), hasLength(1));
    },
  );

  test('PUT bağlantı hatası tekrarlanır', () async {
    var put = 0;
    final o = _Ortam(
      {
        _acYolu: yuklemeAcildiJson,
        _tamamlaYolu: () => {'upload': yuklemeJson()},
      },
      depoYaniti: (istek) {
        if (++put == 1) throw http.ClientException('koptu');
        return http.Response('', 200, headers: {});
      },
    );
    expect(await o.yukle(), ornekUploadId);
    expect(o.beklemeler, hasLength(1));
  });

  test('reddedilen yükleme: neden döner, tekrar denenmez', () async {
    final o = _Ortam({
      _acYolu: yuklemeAcildiJson,
      _tamamlaYolu: () => {
        'upload': yuklemeJson(durum: 'rejected', neden: 'metadata_present'),
      },
    });
    await expectLater(
      o.yukle(),
      throwsA(
        isA<YuklemeReddedildi>().having(
          (h) => h.neden,
          'neden',
          UploadRejectReason.metadataPresent,
        ),
      ),
    );
    expect(o.api.sayi('POST', '/v1/uploads/{upload_id}/complete'), 1);
  });

  test('tekrar gönderimde hazır yükleme: PUT yapılmaz', () async {
    final o = _Ortam({_acYolu: () => yuklemeAcildiJson(durum: 'ready')});
    expect(await o.yukle(), ornekUploadId);
    expect(o.depo, isEmpty);
  });

  group('imzalı link doğrulaması', () {
    test('beklenmeyen alan adı reddedilir, istek gitmez', () async {
      final acildi = yuklemeAcildiJson();
      for (final h in acildi['targets']! as List<Object?>) {
        (h! as Map<String, Object?>)['url'] = 'https://api-dev.tayfam.app/x';
      }
      final o = _Ortam({_acYolu: () => acildi});
      await expectLater(o.yukle(), throwsA(isA<GecersizMedyaLinki>()));
      expect(o.depo, isEmpty);
    });

    test('Content-Length gövdeyle tutmazsa istek gitmez', () async {
      final o = _Ortam({_acYolu: () => yuklemeAcildiJson(onizlemeBoyutu: 11)});
      await expectLater(o.yukle(), throwsA(isA<GecersizMedyaLinki>()));
      expect(o.depo, isEmpty);
    });

    test('medyaLinkiGecerli', () {
      bool g(String s) => medyaLinkiGecerli(Uri.parse(s));
      expect(g('$ornekR2/a?X-Amz-Signature=x'), isTrue);
      expect(g('http://ornekhesap.r2.cloudflarestorage.com/a'), isFalse);
      expect(g('https://r2.cloudflarestorage.com.kotu.com/a'), isFalse);
      expect(g('https://.r2.cloudflarestorage.com/a'), isFalse);
      expect(g('https://u:p@ornekhesap.r2.cloudflarestorage.com/a'), isFalse);
      expect(g('$ornekR2/a#parca'), isFalse);
    });
  });
}
