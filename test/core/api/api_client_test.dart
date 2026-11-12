import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/api.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';

const String _kullaniciId = '00000000-0000-4000-8000-0000000000bb';

http.Response _json(Object? govde, [int durum = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(govde)),
  durum,
  headers: {'content-type': 'application/json'},
);

http.Response _problem(String kod, int durum) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'type': '$problemTypeOnEki$kod',
      'title': 'Başlık',
      'status': durum,
    }),
  ),
  durum,
  headers: {'content-type': 'application/problem+json'},
);

Map<String, Object?> _oturumJson(int n, {Duration omur = _omur}) => {
  'user_id': '00000000-0000-4000-8000-000000000001',
  'session_id': '00000000-0000-4000-8000-000000000002',
  'access_token': 'erisim-$n',
  'access_expires_at': DateTime.now().toUtc().add(omur).toIso8601String(),
  'refresh_token': 'yenileme-$n',
  'refresh_expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(days: 90))
      .toIso8601String(),
  'registration_pending': false,
};

const Duration _omur = Duration(minutes: 15);

/// Sözleşmedeki davranışı taklit eden sahte gateway. Yalnızca geçerli
/// erişim token'ını kabul eder; yenileme token'ı her kullanımda değişir.
final class _SahteGateway {
  int _surum = 1;
  int yenilemeSayisi = 0;
  final List<http.Request> istekler = [];

  /// Bir sonraki yenileme yanıtını geciktirmek için.
  Completer<void>? yenilemeKapisi;

  /// Doluysa yenileme bu problemle reddedilir.
  String? yenilemeHatasi;

  /// Doluysa kimlikli her istek bu problemle reddedilir.
  bool herZaman401 = false;

  /// Engelleme uçlarının kaç kez daha `integrity-required` döneceği.
  int butunlukReddi = 0;

  String get gecerliErisim => 'erisim-$_surum';

  Future<http.Response> isle(http.Request istek) async {
    istekler.add(istek);
    final yol = istek.url.path;
    if (yol == '/v1/status') {
      return _json({
        'status': 'ok',
        'version': '1',
        'services': {'identity': 'ok'},
        'checked_at': '2026-11-10T09:00:00Z',
      });
    }
    if (yol == '/v1/auth/refresh') {
      yenilemeSayisi++;
      final kapi = yenilemeKapisi;
      if (kapi != null) await kapi.future;
      final hata = yenilemeHatasi;
      if (hata != null) {
        return _problem(hata, hata == 'invalid-refresh' ? 401 : 409);
      }
      final govde = jsonDecode(istek.body) as Map<String, Object?>;
      if (govde['refresh_token'] != 'yenileme-$_surum') {
        return _problem('invalid-refresh', 401);
      }
      _surum++;
      return _json(_oturumJson(_surum));
    }
    if (yol == '/v1/client-config') {
      return _problem('unauthenticated', 401);
    }
    if (herZaman401 ||
        istek.headers['Authorization'] != 'Bearer $gecerliErisim') {
      return _problem('unauthenticated', 401);
    }
    if (yol == '/v1/auth/sign-out') return http.Response('', 204);
    if (yol.startsWith('/v1/me/blocks')) {
      if (butunlukReddi > 0) {
        butunlukReddi--;
        return _problem('integrity-required', 403);
      }
      if (istek.method == 'GET') return _json({'users': <Object?>[]});
      return http.Response('', 204);
    }
    return _problem('not-found', 404);
  }

  List<http.Request> yenilemeIstekleri() =>
      istekler.where((i) => i.url.path == '/v1/auth/refresh').toList();
}

final class _Kurulum {
  _Kurulum() {
    tasima = HttpTasima(
      istemci: MockClient(sunucu.isle),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'ios',
      gunluk: gunluk.add,
    );
    final auth = AuthApi(tasima);
    final status = StatusApi(tasima);
    oturum = SessionStore(
      depo: depo,
      yenileyici: (token, {butunlukTokeni}) => auth.refresh(
        body: RefreshRequest(
          refreshToken: token,
          integrityToken: butunlukTokeni,
        ),
      ),
      yoklayici: () async {
        await status.getStatus();
      },
      kanit: (_) async => 'kanit',
      bekle: (_) async {},
      gunluk: gunluk.add,
    );
    oturum.olaylar.listen(olaylar.add);
    addTearDown(oturum.dispose);
    istemci = ApiClient(tasima: tasima, oturum: oturum);
  }

  final _SahteGateway sunucu = _SahteGateway();
  final BellekTokenDeposu depo = BellekTokenDeposu();
  final List<String> gunluk = [];
  final List<OturumOlayi> olaylar = [];
  late final HttpTasima tasima;
  late final SessionStore oturum;
  late final ApiClient istemci;

  Future<void> girisYap({Duration omur = _omur}) =>
      oturum.oturumAc(Session.fromJson(_oturumJson(1, omur: omur)));
}

void main() {
  test('eşzamanlı 5 istek tek yenileme yapar', () async {
    final k = _Kurulum();
    await k.girisYap(omur: Duration.zero);
    k.sunucu.yenilemeKapisi = Completer<void>();

    final istekler = Future.wait([
      for (var i = 0; i < 5; i++) MeApi(k.istemci).blockUser(userId: '$i'),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    k.sunucu.yenilemeKapisi!.complete();
    await istekler;

    expect(k.sunucu.yenilemeSayisi, 1);
    final engelleme = k.sunucu.istekler.where(
      (i) => i.url.path.startsWith('/v1/me/blocks'),
    );
    expect(engelleme, hasLength(5));
    for (final istek in engelleme) {
      expect(istek.headers['Authorization'], 'Bearer erisim-2');
      expect(istek.headers['X-Tayfam-Client'], 'ios');
    }
  });

  test('integrity-required: kanıtla yenilenip bir kez tekrarlanır', () async {
    final k = _Kurulum();
    await k.girisYap();
    k.sunucu.butunlukReddi = 1;

    await MeApi(k.istemci).blockUser(userId: '1');

    final yenileme = k.sunucu.yenilemeIstekleri().single;
    final govde = jsonDecode(yenileme.body) as Map<String, Object?>;
    expect(govde['integrity_token'], 'kanit');
    final engelleme = k.sunucu.istekler
        .where((i) => i.url.path.startsWith('/v1/me/blocks'))
        .toList();
    expect(engelleme, hasLength(2));
    expect(engelleme.last.headers['Authorization'], 'Bearer erisim-2');
  });

  test('integrity-required: ikinci ret hataya döner, döngü yok', () async {
    final k = _Kurulum();
    await k.girisYap();
    k.sunucu.butunlukReddi = 99;

    for (var i = 0; i < 2; i++) {
      await expectLater(
        MeApi(k.istemci).blockUser(userId: '1'),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.integrityRequired,
          ),
        ),
      );
    }
    expect(k.sunucu.yenilemeSayisi, 1);
    expect(await k.oturum.durum(), isA<OturumAcik>());
  });

  test('401 alan istek yenilenip bir kez tekrarlanır', () async {
    final k = _Kurulum();
    await k.girisYap();
    // Sunucu tarafında erişim token'ı geçersizleşti (ör. anahtar
    // değişimi); yenileme token'ı hâlâ geçerli.
    var ilk = true;
    final orijinal = k.sunucu.isle;
    final istemci = ApiClient(
      tasima: HttpTasima(
        istemci: MockClient((istek) {
          if (ilk && istek.url.path.startsWith('/v1/me/blocks')) {
            ilk = false;
            k.sunucu.istekler.add(istek);
            return Future.value(_problem('unauthenticated', 401));
          }
          return orijinal(istek);
        }),
        tabanAdres: Uri.parse('https://api.ornek.test'),
        istemciAdi: 'android',
        gunluk: k.gunluk.add,
      ),
      oturum: k.oturum,
    );

    await MeApi(istemci).blockUser(userId: _kullaniciId);

    expect(k.sunucu.yenilemeSayisi, 1);
    final engelleme = k.sunucu.istekler
        .where((i) => i.url.path.startsWith('/v1/me/blocks'))
        .map((i) => i.headers['Authorization'])
        .toList();
    expect(engelleme, ['Bearer erisim-1', 'Bearer erisim-2']);
    expect(k.olaylar.whereType<OturumKapali>(), isEmpty);
  });

  test('ikinci unauthenticated oturumu kapatır', () async {
    final k = _Kurulum();
    await k.girisYap();
    k.sunucu.herZaman401 = true;

    await expectLater(
      MeApi(k.istemci).blockUser(userId: _kullaniciId),
      throwsA(
        isA<ApiProblem>().having(
          (p) => p.type,
          'type',
          ProblemType.unauthenticated,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(k.sunucu.yenilemeSayisi, 1);
    expect(await k.depo.oku(), isNull);
    expect(k.olaylar.last, const OturumKapali(OturumKapanisNedeni.yetkisiz));
  });

  test('invalid-refresh oturumu kapatır, istek OturumYok ile biter', () async {
    final k = _Kurulum();
    await k.girisYap(omur: Duration.zero);
    k.sunucu.yenilemeHatasi = 'invalid-refresh';

    await expectLater(
      MeApi(k.istemci).blockUser(userId: _kullaniciId),
      throwsA(isA<OturumYok>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await k.depo.oku(), isNull);
    expect(
      k.olaylar.last,
      const OturumKapali(OturumKapanisNedeni.yenilemeReddedildi),
    );
    expect(
      k.sunucu.istekler.where((i) => i.url.path.startsWith('/v1/me/')),
      isEmpty,
    );
  });

  test('refresh-conflict oturumu kapatmaz', () async {
    final k = _Kurulum();
    await k.girisYap(omur: Duration.zero);
    k.sunucu.yenilemeHatasi = 'refresh-conflict';
    // Başka bir süreç aynı anda yeniledi ve depoya yazdı.
    final baska = KayitliOturum(
      erisimTokeni: 'erisim-1',
      erisimBitis: DateTime.now().toUtc().add(_omur),
      yenilemeTokeni: 'yenileme-baska',
      yenilemeBitis: DateTime.now().toUtc().add(const Duration(days: 1)),
      kayitBekliyor: false,
      onayGerekli: false,
    );
    k.sunucu.yenilemeKapisi = Completer<void>();
    final istek = MeApi(k.istemci).blockUser(userId: _kullaniciId);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await k.depo.yaz(baska.kodla());
    k.sunucu.yenilemeKapisi!.complete();

    await istek;
    expect(k.olaylar.whereType<OturumKapali>(), isEmpty);
    expect(k.sunucu.yenilemeSayisi, 1);
  });

  test('security: [] uçları token taşımaz ve 401\'de yenilemez', () async {
    final k = _Kurulum();
    await k.girisYap();

    await StatusApi(k.istemci).getStatus();
    await expectLater(
      ClientConfigApi(k.istemci).getClientConfig(),
      throwsA(isA<ApiProblem>()),
    );

    expect(k.sunucu.yenilemeSayisi, 0);
    for (final istek in k.sunucu.istekler) {
      expect(istek.headers.containsKey('Authorization'), isFalse);
    }
    expect(k.olaylar.whereType<OturumKapali>(), isEmpty);
  });

  test('yenileme isteği Authorization taşımaz, gövdede token gider', () async {
    final k = _Kurulum();
    await k.girisYap(omur: Duration.zero);
    await MeApi(k.istemci).blockUser(userId: _kullaniciId);

    final yenileme = k.sunucu.yenilemeIstekleri().single;
    expect(yenileme.headers.containsKey('Authorization'), isFalse);
    expect(yenileme.headers['X-Tayfam-Client'], 'ios');
    expect(jsonDecode(yenileme.body), {'refresh_token': 'yenileme-1'});
  });

  test('oturum yokken kimlikli istek gönderilmez', () async {
    final k = _Kurulum();
    await expectLater(
      MeApi(k.istemci).blockUser(userId: _kullaniciId),
      throwsA(isA<OturumYok>()),
    );
    expect(k.sunucu.istekler, isEmpty);
  });

  test('çıkış: sunucu hata verse de yerel token\'lar silinir', () async {
    final k = _Kurulum();
    await k.girisYap();
    k.sunucu.herZaman401 = true;
    k.sunucu.yenilemeHatasi = 'invalid-refresh';

    await k.istemci.cikisYap();
    await Future<void>.delayed(Duration.zero);

    expect(await k.depo.oku(), isNull);
    expect(k.olaylar.last, isA<OturumKapali>());
    await expectLater(k.oturum.erisimTokeni(), throwsA(isA<OturumYok>()));
  });

  test('çıkış isteği gönderilir', () async {
    final k = _Kurulum();
    await k.girisYap();
    await k.istemci.cikisYap();
    await Future<void>.delayed(Duration.zero);

    final cikis = k.sunucu.istekler.singleWhere(
      (i) => i.url.path == '/v1/auth/sign-out',
    );
    expect(cikis.headers['Authorization'], 'Bearer erisim-1');
    expect(await k.depo.oku(), isNull);
    expect(k.olaylar.last, const OturumKapali(OturumKapanisNedeni.cikis));
  });

  test('günlükte token, gövde ve gerçek kimlik yok', () async {
    final k = _Kurulum();
    await k.girisYap(omur: Duration.zero);
    await MeApi(k.istemci).blockUser(userId: _kullaniciId);
    k.sunucu.herZaman401 = true;
    await expectLater(
      MeApi(k.istemci).blockUser(userId: _kullaniciId),
      throwsA(isA<ApiProblem>()),
    );

    expect(k.gunluk, contains('PUT /v1/me/blocks/{user_id} → 204'));
    expect(k.gunluk, contains('POST /v1/auth/refresh → 200'));
    for (final satir in k.gunluk) {
      expect(satir, isNot(contains('erisim-')));
      expect(satir, isNot(contains('yenileme-')));
      expect(satir, isNot(contains(_kullaniciId)));
      expect(satir, isNot(contains('ornek.test')));
    }
  });

  test('provider\'lar tek http istemcisiyle kurulur', () async {
    final sunucu = _SahteGateway();
    final depo = BellekTokenDeposu();
    final kap = ProviderContainer(
      overrides: [
        httpClientProvider.overrideWithValue(MockClient(sunucu.isle)),
        tokenDeposuProvider.overrideWithValue(depo),
      ],
    );
    addTearDown(kap.dispose);

    final oturum = kap.read(sessionStoreProvider);
    await oturum.oturumAc(Session.fromJson(_oturumJson(1)));
    await MeApi(kap.read(apiClientProvider)).blockUser(userId: _kullaniciId);

    expect(identical(kap.read(sessionStoreProvider), oturum), isTrue);
    final istek = sunucu.istekler.single;
    expect(istek.url.host, Uri.parse(apiTabanAdresi).host);
    expect(istek.headers['Authorization'], 'Bearer erisim-1');
    expect(await depo.oku(), isNotNull);
  });
}
