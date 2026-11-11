import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/adres_kilidi.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_alici.dart';

import '../sahte_e2e_istemcisi.dart';
import '../sahte_e2e_sunucu.dart';

const String ali = '5e6f7081-0000-4000-8000-0000000000a1';
const String ayse = '5e6f7081-0000-4000-8000-0000000000a2';
const String can = '5e6f7081-0000-4000-8000-0000000000a3';

const String _gonderYolu = '/v1/direct-messages';

List<SahteE2eIstegi> _gonderimler(SahteE2eSunucu s) => [
  for (final i in s.istekler)
    if (i.method == 'POST' && i.yol == _gonderYolu) i,
];

List<Map<String, Object?>> _zarflar(SahteE2eIstegi i) => [
  for (final z
      in (i.govde! as Map<String, Object?>)['envelopes']! as List<Object?>)
    z! as Map<String, Object?>,
];

void main() {
  group('dolgu', () {
    test('160 bayt bloklar; geri alınır', () {
      for (final n in [0, 1, 159, 160, 400]) {
        final veri = Uint8List.fromList(List.filled(n, 7));
        final dolgulu = dolguEkle(veri);
        expect(dolgulu.length % dolguBlogu, 0);
        expect(dolgulu.length, greaterThan(n));
        expect(dolguKaldir(dolgulu), veri);
      }
    });

    test('zarf içeriği: v1 metin; bozuk biçim null', () {
      expect(zarfIcerigiCoz(zarfIcerigiKodla('Selam 👋')), 'Selam 👋');
      expect(zarfIcerigiCoz(Uint8List.fromList([1, 2, 3])), isNull);
      final baska = dolguEkle(
        Uint8List.fromList(utf8.encode('{"v":2,"t":"metin","govde":"x"}')),
      );
      expect(zarfIcerigiCoz(baska), isNull);
    });
  });

  group('adres kilidi', () {
    test('aynı adres sırayla, farklı adres beklemeden', () async {
      final kilit = AdresKilidi();
      final olaylar = <String>[];
      final birinci = Completer<void>();
      final a1 = kilit.altinda('a', () async {
        olaylar.add('a1-basla');
        await birinci.future;
        olaylar.add('a1-bit');
      });
      final a2 = kilit.altinda('a', () async => olaylar.add('a2'));
      final b = kilit.altinda('b', () async => olaylar.add('b'));
      await b;
      expect(olaylar, ['a1-basla', 'b']);
      birinci.complete();
      await Future.wait([a1, a2]);
      expect(olaylar, ['a1-basla', 'b', 'a1-bit', 'a2']);
      expect(kilit.mesgulMu('a'), isFalse);
    });

    test('önceki işin hatası sonrakini durdurmaz', () async {
      final kilit = AdresKilidi();
      final hata = kilit.altinda<void>('a', () async => throw StateError(''));
      final sonraki = kilit.altinda('a', () async => 1);
      await expectLater(hata, throwsStateError);
      expect(await sonraki, 1);
    });
  });

  group('cihaz kaydı', () {
    test('kayıtsızsa anahtarlar önce depoya, sonra sunucuya', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      final bilgi = await a.hazirla();
      expect(bilgi.hazir, isTrue);
      expect(bilgi.cihazNo, 1);
      expect(s.istekler.map((i) => '${i.method} ${i.yol}'), [
        'GET /v1/me/e2e/device',
        'POST /v1/me/e2e/device',
        'GET /v1/me/e2e/device',
      ]);
      final cihaz = s.oturumCihazi(a.tasima.oturum)!;
      expect(cihaz.ec, hasLength(100));
      expect(cihaz.kyber, hasLength(30));
      expect(a.depo.onAnahtarKimlikleri, hasLength(100));
      expect(a.depo.kyberKimlikleri, hasLength(30));
      expect(a.depo.cihaz?.id, cihaz.id);
      expect(base64.encode(a.depo.kimlik!.acikAnahtar), cihaz.kimlik);
      // Kimlik sunucuya gitmeden önce depodaydı.
      expect(a.ham.islemler.first, 'temizle');
      expect(a.ham.islemler[1], 'yaz:${E2eDeposu.kimlikAnahtari}');
    });

    test('kayıtlıysa yalnızca durum okunur', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      await a.hazirla();
      s.istekler.clear();
      final bilgi = await a.hazirla();
      expect(bilgi.hazir, isTrue);
      expect(s.istekler.map((i) => i.method), ['GET']);
    });

    test('depoda anahtar yok ama sunucu kayıtlı: silinip yeniden', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      await a.hazirla();
      final eski = s.oturumCihazi(a.tasima.oturum)!.id;
      await a.depo.temizle();
      final bilgi = await a.hazirla();
      expect(bilgi.hazir, isTrue);
      expect(bilgi.cihazId, isNot(eski));
      expect(s.cihazlar.containsKey(eski), isFalse);
      expect(s.istekler.where((i) => i.method == 'DELETE'), hasLength(1));
      expect(a.depo.cihaz?.id, bilgi.cihazId);
    });

    test('cihaz sınırı: e2e-device-limit', () async {
      final s = SahteE2eSunucu();
      for (var i = 0; i < 5; i++) {
        await SahteE2eIstemcisi(s, ali, tohum: i + 10).hazirla();
      }
      final altinci = SahteE2eIstemcisi(s, ali, tohum: 99);
      await expectLater(
        altinci.hazirla(),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.e2eDeviceLimit,
          ),
        ),
      );
    });

    test('ön anahtarlar azalınca 100\'e tamamlanır', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      await a.hazirla();
      final cihaz = s.oturumCihazi(a.tasima.oturum)!;
      cihaz.ec.removeRange(0, 95);
      await a.yonetici.onAnahtarlarAzaldi();
      expect(cihaz.ec, hasLength(100));
      expect(cihaz.kyber, hasLength(30));
      final yukleme = s.istekler.lastWhere((i) => i.method == 'POST');
      final govde = yukleme.govde! as Map<String, Object?>;
      expect(govde['one_time_prekeys'], hasLength(95));
      expect(govde.containsKey('kyber_prekeys'), isFalse);
      expect(govde.containsKey('signed_prekey'), isFalse);
      // Yeni kimlikler eskilerle çakışmaz.
      expect(a.depo.onAnahtarKimlikleri, hasLength(195));
    });

    test('imzalı ön anahtar 7 günde yenilenir, eskisi 30 gün sonra '
        'silinir', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      await a.hazirla();
      final cihaz = s.oturumCihazi(a.tasima.oturum)!;
      expect(cihaz.imzali['key_id'], 1);

      a.simdi = a.simdi.add(const Duration(days: 8));
      await a.yonetici.onAnahtarlarAzaldi();
      expect(cihaz.imzali['key_id'], 2);
      expect(cihaz.sonCare['key_id'], isNot(1));
      expect(a.depo.imzali(1)?.emekli, isNotNull);
      expect(a.depo.sayac.etkinImzali, 2);

      a.simdi = a.simdi.add(const Duration(days: 31));
      await a.yonetici.onAnahtarlarAzaldi();
      expect(a.depo.imzali(1), isNull);
      expect(a.depo.sonCare(1), isNull);
      expect(a.depo.imzali(2), isNotNull);
      expect(a.depo.sayac.etkinImzali, 3);
    });

    test('kendi hesabına eklenen yeni cihaz: ilk bakışta taban', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      await a.hazirla();
      expect(await a.yonetici.yeniKendiCihazlari(ali), isEmpty);
      await SahteE2eIstemcisi(s, ali, tohum: 5).hazirla();
      final yeniler = await a.yonetici.yeniKendiCihazlari(ali);
      expect(yeniler, hasLength(1));
      expect(yeniler.single.type, E2EKeyEventType.deviceAdded);
      expect(await a.yonetici.yeniKendiCihazlari(ali), isEmpty);
    });
  });

  group('gönderim', () {
    late SahteE2eSunucu s;
    late SahteE2eIstemcisi a;
    late SahteE2eIstemcisi b;

    setUp(() async {
      s = SahteE2eSunucu();
      a = SahteE2eIstemcisi(s, ali);
      b = SahteE2eIstemcisi(s, ayse, tohum: 50);
      await a.hazirla();
      await b.hazirla();
    });

    test('ilk mesaj: paket çekilir, ön anahtar zarfı, REST', () async {
      final icerik = await a.gonder(ayse, 'Merhaba');
      expect(icerik.metin, 'Merhaba');
      expect(icerik.kaynak, CozulmusMesajKaynagi.gonderildi);
      final gonderim = _gonderimler(s).single;
      final zarflar = _zarflar(gonderim);
      expect(zarflar, hasLength(1));
      expect(zarflar.single['type'], 'prekey');
      expect(s.oturumCihazi(b.tasima.oturum)!.ec, hasLength(99));
      expect(
        (gonderim.govde! as Map<String, Object?>).containsKey('body'),
        isFalse,
      );
    });

    test('kendi diğer cihazına da zarf gider', () async {
      final a2 = SahteE2eIstemcisi(s, ali, tohum: 70);
      await a2.hazirla();
      await a.gonder(ayse, 'Merhaba');
      final zarflar = _zarflar(_gonderimler(s).single);
      expect(zarflar.map((z) => z['device_id']).toSet(), {
        s.oturumCihazi(b.tasima.oturum)!.id,
        s.oturumCihazi(a2.tasima.oturum)!.id,
      });
    });

    test('e2e-devices-changed: tazelenir, aynı client_request_id', () async {
      await a.gonder(ayse, 'Bir');
      final b2 = SahteE2eIstemcisi(s, ayse, tohum: 80);
      await b2.hazirla();
      s.istekler.clear();
      await a.gonder(
        ayse,
        'İki',
        istek: '9b000000-0000-4000-8000-000000000002',
      );
      final gonderimler = _gonderimler(s);
      expect(gonderimler, hasLength(2));
      for (final g in gonderimler) {
        expect(
          (g.govde! as Map<String, Object?>)['client_request_id'],
          '9b000000-0000-4000-8000-000000000002',
        );
      }
      expect(_zarflar(gonderimler.first), hasLength(1));
      expect(_zarflar(gonderimler.last), hasLength(2));
    });

    test('çıkarılan cihazın oturumu tazelemede silinir', () async {
      await a.gonder(ayse, 'Bir');
      final eski = s.oturumCihazi(b.tasima.oturum)!.id;
      expect(a.depo.oturum(eski), isNotNull);
      final b2 = SahteE2eIstemcisi(s, ayse, tohum: 80);
      await b2.hazirla();
      s.cihaziSil(eski);
      await a.gonder(ayse, 'İki');
      expect(a.depo.oturum(eski), isNull);
      expect(a.depo.karsiKimlik(eski), isNull);
      expect(_zarflar(_gonderimler(s).last), hasLength(1));
    });

    test('en çok 3 tekrar; sonra hata', () async {
      s.araya = (i) => i.yol == _gonderYolu
          ? const ApiProblem(type: ProblemType.e2eDevicesChanged, status: 409)
          : null;
      await expectLater(
        a.gonder(ayse, 'Merhaba'),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.e2eDevicesChanged,
          ),
        ),
      );
      expect(_gonderimler(s), hasLength(4));
    });

    test('alıcının cihazı yoksa e2e-recipient-unavailable', () async {
      await expectLater(
        a.gonder(can, 'Merhaba'),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.e2eRecipientUnavailable,
          ),
        ),
      );
      expect(_gonderimler(s), isEmpty);
    });

    test('kimlik anahtarı değişirse (TOFU) uyarı', () async {
      await a.gonder(ayse, 'Bir');
      final hedef = s.oturumCihazi(b.tasima.oturum)!;
      await a.depo.hamSil(E2eDeposu.oturumAnahtari(hedef.id));
      hedef.kimlik = base64.encode(
        Uint8List.fromList([5, ...List.filled(32, 9)]),
      );
      await a.gonder(ayse, 'İki');
      expect(a.guvenlikUyarilari, ['$ayse:kimlik:${hedef.id}']);
    });

    test('gönderilen mesaj E3 yayınına düşer', () async {
      final yayin = <CozulmusBirebirMesaj>[];
      final abonelik = a.yayin.akis.listen(yayin.add);
      await a.gonder(ayse, 'Merhaba');
      await pumpEventQueue();
      await abonelik.cancel();
      expect(yayin.single.metin, 'Merhaba');
    });
  });

  group('alım', () {
    late SahteE2eSunucu s;
    late SahteE2eIstemcisi a;
    late SahteE2eIstemcisi b;

    setUp(() async {
      s = SahteE2eSunucu();
      a = SahteE2eIstemcisi(s, ali);
      b = SahteE2eIstemcisi(s, ayse, tohum: 50);
      await a.hazirla();
      await b.hazirla();
    });

    test('çöz, durumu yaz, sonra onayla', () async {
      await a.gonder(ayse, 'Merhaba');
      b.ham.islemler.clear();
      await b.cek();
      expect(b.alinanlar.single.metin, 'Merhaba');
      expect(b.alinanlar.single.gonderenKullaniciId, ali);
      expect(b.bekleyenZarf, 0);
      final i = b.ham.islemler;
      final aCihazi = s.oturumCihazi(a.tasima.oturum)!.id;
      final oturum = i.indexOf('yaz:${E2eDeposu.oturumAnahtari(aCihazi)}');
      final gorulen = i.indexOf('yaz:${E2eDeposu.gorulenAnahtari}');
      expect(oturum, greaterThanOrEqualTo(0));
      expect(gorulen, greaterThan(oturum));
      expect(i.last, 'ack');
      // Tek kullanımlık ön anahtar silindi.
      expect(i.where((x) => x.startsWith('sil:e2e.onk.')), hasLength(1));
    });

    test('aynı zarf ikinci kez gelirse ayıklanır', () async {
      await a.gonder(ayse, 'Merhaba');
      final zarf = E2EEnvelope.fromJson(
        s.oturumCihazi(b.tasima.oturum)!.zarflar.single,
      );
      expect(await b.alici.zarfGeldi(zarf), ZarfSonucu.cozuldu);
      expect(await b.alici.zarfGeldi(zarf), ZarfSonucu.tekrar);
      expect(b.alinanlar, hasLength(1));
      expect(b.onaylar, hasLength(2));

      // Uygulama yeniden açıldı: depodaki görülenlerden ayıklanır.
      final yeni = SahteE2eIstemcisi(s, ayse, ham: b.ham);
      await yeni.depo.yukle();
      expect(await yeni.alici.isle(zarf), ZarfSonucu.tekrar);
    });

    test('çözülemeyen zarf onaylanır, konuşmaya satır düşer', () async {
      final zarf = E2EEnvelope(
        id: '2a000000-0000-4000-8000-0000000000ff',
        messageId: '4d000000-0000-4000-8000-0000000000ff',
        conversationId: '3c000000-0000-4000-8000-0000000000ff',
        senderUserId: ali,
        senderDeviceId: s.oturumCihazi(a.tasima.oturum)!.id,
        senderDeviceNumber: 1,
        type: E2EEnvelopeType.whisper,
        content: base64.encode([1, 2, 3]),
        createdAt: DateTime.utc(2026, 11, 11, 12),
      );
      expect(await b.alici.zarfGeldi(zarf), ZarfSonucu.cozulemedi);
      expect(b.onaylar.single, [zarf.id]);
      final (konusma, satir) = b.cozulemeyenler.single;
      expect(konusma, zarf.conversationId);
      expect(satir.tur, E2eSatirTuru.mesajCozulemedi);
      expect(b.alinanlar, isEmpty);
    });

    test('depoya yazılamazsa onaylanmaz', () async {
      await a.gonder(ayse, 'Merhaba');
      b.ham.hataVer = true;
      await b.cek();
      expect(b.onaylar, isEmpty);
      expect(b.bekleyenZarf, 1);
      expect(b.alinanlar, isEmpty);
    });
  });

  group('uçtan uca (iki sahte istemci)', () {
    test('karşılıklı yazışma; kendi diğer cihazına kopya', () async {
      final s = SahteE2eSunucu();
      final ali1 = SahteE2eIstemcisi(s, ali);
      final ali2 = SahteE2eIstemcisi(s, ali, tohum: 30);
      final ayse1 = SahteE2eIstemcisi(s, ayse, tohum: 60);
      await ali1.hazirla();
      await ali2.hazirla();
      await ayse1.hazirla();

      await ali1.gonder(ayse, 'Pazar konvoy var mı?');
      await ayse1.cek();
      await ali2.cek();
      expect(ayse1.alinanlar.single.metin, 'Pazar konvoy var mı?');
      expect(ali2.alinanlar.single.metin, 'Pazar konvoy var mı?');
      expect(ali2.alinanlar.single.gonderenKullaniciId, ali);

      await ayse1.gonder(ali, 'Var, 9\'da çıkıyoruz.');
      await ali1.cek();
      await ali2.cek();
      expect(ali1.alinanlar.single.metin, 'Var, 9\'da çıkıyoruz.');
      expect(ali2.alinanlar.last.metin, 'Var, 9\'da çıkıyoruz.');

      // Karşılık alındı: Ali'nin sonraki mesajı ön anahtarsız.
      await ali1.gonder(ayse, 'Tamam');
      final aysedeki = s.oturumCihazi(ayse1.tasima.oturum)!.zarflar.single;
      expect(aysedeki['type'], 'whisper');
      await ayse1.cek();
      expect(ayse1.alinanlar.map((m) => m.metin), [
        'Pazar konvoy var mı?',
        'Tamam',
      ]);
    });

    test('güvenlik kodu: ilk bakış taban, yeni cihaz satır', () async {
      final s = SahteE2eSunucu();
      final a = SahteE2eIstemcisi(s, ali);
      final b = SahteE2eIstemcisi(s, ayse, tohum: 60);
      await a.hazirla();
      await b.hazirla();
      expect(await b.guvenlik.denetle(ali), isEmpty);
      await SahteE2eIstemcisi(s, ali, tohum: 90).hazirla();
      final satirlar = await b.guvenlik.denetle(ali);
      expect(satirlar, hasLength(1));
      expect(satirlar.single.tur, E2eSatirTuru.guvenlikKoduDegisti);
      expect(await b.guvenlik.denetle(ali), isEmpty);
    });
  });
}
