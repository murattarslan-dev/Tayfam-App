import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/features/tayfa/application/katilim_notifier.dart';
import 'package:tayfam/features/tayfa/application/olusturma_notifier.dart';
import 'package:tayfam/features/tayfa/application/tayfa_gorunumu.dart';
import 'package:tayfam/features/tayfa/application/tayfalarim_notifier.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _bekleyenId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';
const String _yeniId = '1f2e3d4c-5b6a-4978-8a6b-5c4d3e2f1a0b';

Future<void> _bekle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ApiProblem _problem(ProblemType tur, [int durum = 400]) =>
    ApiProblem(type: tur, status: durum);

final class _Kurulum {
  _Kurulum({
    Map<String, TayfaYaniti>? yanitlar,
    String? sonTayfa,
    OturumDurumu oturum = OturumDurumu.acik,
  }) : tasima = SahteTayfaTasima(yanitlar),
       depo = BellekSonTayfaDeposu(sonTayfa) {
    kap = ProviderContainer.test(
      overrides: [
        oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(oturum)),
        ...tayfaOverridelari(tasima: tasima, sonTayfa: depo),
      ],
    );
    // Kalıcı provider'lar; testte dinlenerek canlı tutulur.
    kap.listen(aktifTayfaIdProvider, (_, _) {});
    kap.listen(tayfalarimProvider, (_, _) {});
  }

  final SahteTayfaTasima tasima;
  final BellekSonTayfaDeposu depo;
  late final ProviderContainer kap;

  String? get aktif => kap.read(aktifTayfaIdProvider);
  List<MyTayfa>? get liste => kap.read(tayfalarimProvider).value;
}

void main() {
  group('tayfalarım', () {
    test('bütün sayfalar okunuyor; token opak geçiriliyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (i) => switch (i.sorgu['page_token']) {
            null => listeJson([etkinJson(ornekTayfaId)], sonraki: 'opak-1'),
            'opak-1' => listeJson([
              bekleyenJson(_bekleyenId),
            ], sonraki: 'opak-2'),
            _ => listeJson([etkinJson(ikinciTayfaId, ad: 'Kampçılar')]),
          },
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      final istekler = k.tasima.giden('GET', '/v1/tayfas');
      expect(istekler, hasLength(3));
      expect(istekler.map((i) => i.sorgu['page_token']), [
        null,
        'opak-1',
        'opak-2',
      ]);
      expect(istekler.first.sorgu['page_size'], '100');
      expect(k.liste!.map((t) => t.tayfaId), [
        ornekTayfaId,
        _bekleyenId,
        ikinciTayfaId,
      ]);
      expect(k.kap.read(etkinTayfaIdleriProvider), {
        ornekTayfaId,
        ikinciTayfaId,
      });
    });

    test('sunucu aynı token\'ı yinelerse okuma duruyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) =>
              listeJson([etkinJson(ornekTayfaId)], sonraki: 'hep-ayni'),
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      expect(k.tasima.giden('GET', '/v1/tayfas'), hasLength(2));
    });

    test('liste gelince ilk etkin tayfa aktif oluyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => listeJson([
            bekleyenJson(_bekleyenId),
            etkinJson(ikinciTayfaId),
            etkinJson(ornekTayfaId),
          ]),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      await _bekle();

      expect(k.aktif, ikinciTayfaId);
      expect(k.depo.kayit, ikinciTayfaId);
    });

    test('son kullanılan tayfa hâlâ etkinse o seçiliyor', () async {
      final k = _Kurulum(
        sonTayfa: ornekTayfaId,
        yanitlar: {
          'GET /v1/tayfas': (_) =>
              listeJson([etkinJson(ikinciTayfaId), etkinJson(ornekTayfaId)]),
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      expect(k.aktif, ornekTayfaId);
    });

    test('yalnızca bekleyen istek varsa aktif tayfa yok', () async {
      final k = _Kurulum(
        sonTayfa: ornekTayfaId,
        yanitlar: {
          'GET /v1/tayfas': (_) => listeJson([bekleyenJson(_bekleyenId)]),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      await _bekle();

      expect(k.aktif, isNull);
      expect(k.depo.kayit, isNull);
      expect(bekleyenTayfalar(k.liste!).single.tayfaId, _bekleyenId);
    });

    test('liste alınamazsa son tayfa kayıttan geliyor', () async {
      final k = _Kurulum(
        sonTayfa: ornekTayfaId,
        yanitlar: {'GET /v1/tayfas': (_) => const ApiOffline()},
      );
      await expectLater(
        k.kap.read(tayfalarimProvider.future),
        throwsA(anything),
      );
      await _bekle();

      expect(k.aktif, ornekTayfaId);
      expect(k.kap.read(etkinTayfaIdleriProvider), isNull);
    });

    test('oturum açık değilken istek yok, liste boş', () async {
      final k = _Kurulum(oturum: OturumDurumu.girisYok);
      expect(await k.kap.read(tayfalarimProvider.future), isEmpty);
      expect(k.tasima.istekler, isEmpty);
    });

    test('yenileme başarısızsa eldeki liste kalıyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => cagri++ == 0
              ? listeJson([etkinJson(ornekTayfaId)])
              : const ApiOffline(),
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      final sonuc = await k.kap.read(tayfalarimProvider.notifier).yenile();

      expect(sonuc, isFalse);
      expect(k.liste!.single.tayfaId, ornekTayfaId);
      expect(k.kap.read(tayfalarimProvider).hasError, isFalse);
    });

    test('yenilemede çıkarılan aktif tayfa yerine ilk etkin geliyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => cagri++ == 0
              ? listeJson([etkinJson(ornekTayfaId), etkinJson(ikinciTayfaId)])
              : listeJson([etkinJson(ikinciTayfaId)]),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      expect(k.aktif, ornekTayfaId);

      await k.kap.read(tayfalarimProvider.notifier).yenile();

      expect(k.aktif, ikinciTayfaId);
    });

    test('bekleyen istek geri çekiliyor ve listeden düşüyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => cagri++ == 0
              ? listeJson([bekleyenJson(_bekleyenId)])
              : listeJson(const []),
          'DELETE /v1/tayfas/{tayfa_id}/membership': (_) => null,
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      final hata = await k.kap
          .read(tayfalarimProvider.notifier)
          .geriCek(_bekleyenId);
      await _bekle();

      expect(hata, isNull);
      final silme = k.tasima.giden(
        'DELETE',
        '/v1/tayfas/{tayfa_id}/membership',
      );
      expect(silme.single.yolParametreleri['tayfa_id'], _bekleyenId);
      expect(k.liste, isEmpty);
    });

    test('geri çekme hatası döndürülüyor, liste değişmiyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => listeJson([bekleyenJson(_bekleyenId)]),
          'DELETE /v1/tayfas/{tayfa_id}/membership': (_) => const ApiOffline(),
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      final hata = await k.kap
          .read(tayfalarimProvider.notifier)
          .geriCek(_bekleyenId);

      expect(hata, isA<ApiOffline>());
      expect(k.liste!.single.tayfaId, _bekleyenId);
    });

    test('tayfa adı listeden geliyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) =>
              listeJson([etkinJson(ornekTayfaId, ad: 'Klasikçiler')]),
        },
      );
      await k.kap.read(tayfalarimProvider.future);

      expect(k.kap.read(tayfaAdiProvider(ornekTayfaId)), 'Klasikçiler');
      expect(k.kap.read(tayfaAdiProvider(ikinciTayfaId)), isNull);
    });
  });

  group('kodla katılım', () {
    test('kod boşsa istek yok, alan hatası', () async {
      final k = _Kurulum();
      final sub = k.kap.listen(katilimProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(katilimProvider.notifier).katil('   ');

      expect(k.kap.read(katilimProvider).kodHatali, isTrue);
      expect(k.tasima.giden('POST', '/v1/tayfa-joins'), isEmpty);
    });

    test('kod kırpılıyor; harfler dönüştürülmüyor', () {
      expect(katilimKoduDuzenle('  k7m2q9xa \n'), 'k7m2q9xa');
      expect(katilimKoduDuzenle('A' * 32), 'A' * 32);
      expect(katilimKoduDuzenle('A' * 33), isNull);
      expect(katilimKoduDuzenle(''), isNull);
    });

    test('açık tayfa: üyelik etkin, tayfa aktif oluyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => cagri++ == 0
              ? listeJson([etkinJson(ornekTayfaId)])
              : listeJson([etkinJson(ikinciTayfaId), etkinJson(ornekTayfaId)]),
          'POST /v1/tayfa-joins': (_) => uyelikJson(ikinciTayfaId),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(katilimProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(katilimProvider.notifier).katil(' $sahteKod ');

      final istek = k.tasima.giden('POST', '/v1/tayfa-joins').single;
      expect(istek.govde, {'code': sahteKod});
      final durum = k.kap.read(katilimProvider);
      expect(durum.sonuc, KatilimSonucu.etkin);
      expect(durum.tayfaId, ikinciTayfaId);
      expect(k.aktif, ikinciTayfaId);
      expect(k.kap.read(etkinTayfaIdleriProvider), contains(ikinciTayfaId));
    });

    test('onaylı tayfa: istek bekliyor, aktif tayfa değişmiyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) => cagri++ == 0
              ? listeJson([etkinJson(ornekTayfaId)])
              : listeJson([bekleyenJson(_bekleyenId), etkinJson(ornekTayfaId)]),
          'POST /v1/tayfa-joins': (_) =>
              uyelikJson(_bekleyenId, durum: 'pending'),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(katilimProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(katilimProvider.notifier).katil(sahteKod);

      expect(k.kap.read(katilimProvider).sonuc, KatilimSonucu.bekliyor);
      expect(k.aktif, ornekTayfaId);
      expect(bekleyenTayfalar(k.liste!).single.tayfaId, _bekleyenId);
    });

    test('liste yenilenemezse sunucunun cevabı yine listeye giriyor', () async {
      var cagri = 0;
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) =>
              cagri++ == 0 ? listeJson(const []) : const ApiOffline(),
          'POST /v1/tayfa-joins': (_) => uyelikJson(ornekTayfaId),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(katilimProvider, (_, _) {});
      addTearDown(sub.close);

      await k.kap.read(katilimProvider.notifier).katil(sahteKod);

      expect(k.aktif, ornekTayfaId);
      expect(k.kap.read(etkinTayfaIdleriProvider), {ornekTayfaId});
    });

    for (final tur in [
      ProblemType.invalidJoinCode,
      ProblemType.rateLimited,
      ProblemType.alreadyPending,
    ]) {
      test('${tur.name}: hata durumda, sonuç yok', () async {
        final k = _Kurulum(
          yanitlar: {'POST /v1/tayfa-joins': (_) => _problem(tur)},
        );
        await k.kap.read(tayfalarimProvider.future);
        final sub = k.kap.listen(katilimProvider, (_, _) {});
        addTearDown(sub.close);

        await k.kap.read(katilimProvider.notifier).katil(sahteKod);

        final durum = k.kap.read(katilimProvider);
        expect((durum.hata! as ApiProblem).type, tur);
        expect(durum.sonuc, isNull);
        expect(durum.gonderiliyor, isFalse);
      });
    }

    test('gönderim sürerken ikinci çağrı yok sayılıyor', () async {
      final k = _Kurulum(
        yanitlar: {'POST /v1/tayfa-joins': (_) => uyelikJson(ornekTayfaId)},
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(katilimProvider, (_, _) {});
      addTearDown(sub.close);
      final bekle = k.tasima.bekle = Completer<void>();

      final ilk = k.kap.read(katilimProvider.notifier).katil(sahteKod);
      await _bekle();
      expect(k.kap.read(katilimProvider).gonderiliyor, isTrue);
      await k.kap.read(katilimProvider.notifier).katil(sahteKod);
      k.tasima.bekle = null;
      bekle.complete();
      await ilk;

      expect(k.tasima.giden('POST', '/v1/tayfa-joins'), hasLength(1));
    });
  });

  group('oluşturma sihirbazı', () {
    Future<_Kurulum> kur(Map<String, TayfaYaniti> yanitlar) async {
      final k = _Kurulum(yanitlar: yanitlar);
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(olusturmaProvider, (_, _) {});
      addTearDown(sub.close);
      return k;
    }

    test('ad geçersizken ileri gidilmiyor', () async {
      final k = await kur({});
      final n = k.kap.read(olusturmaProvider.notifier);

      n.adAyarla('  ab  ');
      n.ileri();
      expect(k.kap.read(olusturmaProvider).adim, 0);
      expect(k.kap.read(olusturmaProvider).adHatali, isTrue);

      n.adAyarla('a' * 51);
      n.ileri();
      expect(k.kap.read(olusturmaProvider).adim, 0);

      n.adAyarla('  Klasikçiler  ');
      expect(k.kap.read(olusturmaProvider).adHatali, isFalse);
      n.ileri();
      expect(k.kap.read(olusturmaProvider).adim, 1);
    });

    test('geri ve ileride girilenler korunuyor', () async {
      final k = await kur({});
      final n = k.kap.read(olusturmaProvider.notifier);

      n.adAyarla('Klasikçiler');
      n.ileri();
      n.ilgiDegistir(EventType.hike);
      n.ilgiDegistir(EventType.convoy);
      n.ileri();
      n.katilimAyarla(JoinPolicy.open);
      n.aciklamaAyarla('Hafta sonu turları');
      expect(n.geri(), isTrue);
      expect(n.geri(), isTrue);
      expect(n.geri(), isFalse);

      final durum = k.kap.read(olusturmaProvider);
      expect(durum.adim, 0);
      expect(durum.ad, 'Klasikçiler');
      // Sözleşmenin tür sırasıyla.
      expect(durum.ilgiler, [EventType.convoy, EventType.hike]);
      expect(durum.katilim, JoinPolicy.open);
      expect(durum.aciklama, 'Hafta sonu turları');

      n.ilgiDegistir(EventType.convoy);
      expect(k.kap.read(olusturmaProvider).ilgiler, [EventType.hike]);
    });

    test('girilen bir şey var mı (vazgeç onayı)', () async {
      final k = await kur({});
      final n = k.kap.read(olusturmaProvider.notifier);
      expect(k.kap.read(olusturmaProvider).girdiVar, isFalse);

      n.adAyarla('   ');
      expect(k.kap.read(olusturmaProvider).girdiVar, isFalse);
      n.adAyarla('K');
      expect(k.kap.read(olusturmaProvider).girdiVar, isTrue);
      n.adAyarla('');
      n.ilgiDegistir(EventType.camp);
      expect(k.kap.read(olusturmaProvider).girdiVar, isTrue);
      n.ilgiDegistir(EventType.camp);
      n.katilimAyarla(JoinPolicy.open);
      expect(k.kap.read(olusturmaProvider).girdiVar, isTrue);
      n.katilimAyarla(JoinPolicy.approval);
      n.aciklamaAyarla('Kamp');
      expect(k.kap.read(olusturmaProvider).girdiVar, isTrue);
      n.aciklamaAyarla('');
      expect(k.kap.read(olusturmaProvider).girdiVar, isFalse);
    });

    test('varsayılan onaylı; boş açıklama ve ilgi gönderilmiyor', () async {
      final k = await kur({
        'POST /v1/tayfas': (_) => tayfaJson(id: _yeniId, kod: sahteKod),
      });
      final n = k.kap.read(olusturmaProvider.notifier);
      n.adAyarla('  Klasikçiler ');
      n.ileri();
      n.ileri();

      await n.gonder();

      final govde = k.tasima.giden('POST', '/v1/tayfas').single.govde;
      expect(govde, {
        'name': 'Klasikçiler',
        'join_policy': 'approval',
        'client_request_id': sahteIstekKimligi,
      });
    });

    test('hata sonrası tekrar gönderim aynı client_request_id ile', () async {
      var cagri = 0;
      final k = await kur({
        'POST /v1/tayfas': (_) => cagri++ == 0
            ? _problem(ProblemType.tayfaCreateLimit, 429)
            : tayfaJson(id: _yeniId, kod: sahteKod),
      });
      final n = k.kap.read(olusturmaProvider.notifier);
      n.adAyarla('Klasikçiler');
      n.ileri();
      n.ilgiDegistir(EventType.camp);
      n.ileri();
      n.aciklamaAyarla(' Kamp tayfası ');

      await n.gonder();
      final hata = k.kap.read(olusturmaProvider).hata;
      expect((hata! as ApiProblem).type, ProblemType.tayfaCreateLimit);
      expect(k.kap.read(olusturmaProvider).olusturulan, isNull);

      await n.gonder();

      final istekler = k.tasima.giden('POST', '/v1/tayfas');
      expect(istekler, hasLength(2));
      for (final istek in istekler) {
        final govde = istek.govde! as Map<String, Object?>;
        expect(govde['client_request_id'], sahteIstekKimligi);
        expect(govde['interests'], ['camp']);
        expect(govde['description'], 'Kamp tayfası');
      }
      expect(k.kap.read(olusturmaProvider).olusturulan, _yeniId);
    });

    test('her sihirbaz açılışı yeni bir istek kimliği üretiyor', () {
      var sayac = 0;
      final kap = ProviderContainer.test(
        overrides: [
          istekKimligiUreticisiProvider.overrideWithValue(
            () => 'kimlik-${sayac++}',
          ),
        ],
      );
      var sub = kap.listen(olusturmaProvider, (_, _) {});
      expect(kap.read(olusturmaProvider).istekKimligi, 'kimlik-0');
      // Durum güncellemesi kimliği değiştirmez.
      kap.read(olusturmaProvider.notifier).adAyarla('Klasikçiler');
      expect(kap.read(olusturmaProvider).istekKimligi, 'kimlik-0');
      sub.close();
      kap.invalidate(olusturmaProvider);

      sub = kap.listen(olusturmaProvider, (_, _) {});
      addTearDown(sub.close);
      expect(kap.read(olusturmaProvider).istekKimligi, 'kimlik-1');
    });

    test('başarıda tayfa listede, aktif ve davet kısayolu açık', () async {
      final k = await kur({
        'POST /v1/tayfas': (_) => tayfaJson(id: _yeniId, kod: sahteKod),
      });
      k.tasima.yanitlar['GET /v1/tayfas'] = (_) =>
          listeJson([etkinJson(_yeniId, rol: 'admin', kod: sahteKod)]);
      final n = k.kap.read(olusturmaProvider.notifier);
      n.adAyarla('Klasikçiler');
      n.ileri();
      n.ileri();

      await n.gonder();
      await _bekle();

      expect(k.kap.read(olusturmaProvider).olusturulan, _yeniId);
      // "Tayfa kuruldu" ekranı oluşturma yanıtıyla çizilir.
      final kurulan = k.kap.read(olusturmaProvider).kurulan;
      expect(kurulan?.id, _yeniId);
      expect(kurulan?.joinCode, sahteKod);
      expect(k.aktif, _yeniId);
      expect(k.depo.kayit, _yeniId);
      expect(k.kap.read(etkinTayfaIdleriProvider), {_yeniId});
      expect(k.kap.read(davetKisayoluProvider), _yeniId);
    });
  });

  group('tayfa durumu (ADR-0014 §6)', () {
    Tayfa tayfa({String durum = 'active', String? askida, String? silinme}) =>
        Tayfa.fromJson(
          tayfaJson(
            id: ornekTayfaId,
            durum: durum,
            askida: askida,
            silinme: silinme,
          ),
        );

    test('olağan durumda şerit yok', () {
      expect(tayfaDurumu(tayfa()), isNull);
    });

    test('uyarı ve arşiv', () {
      expect(
        tayfaDurumu(tayfa(durum: 'warned')),
        const TayfaDurumu(TayfaDurumTuru.uyari),
      );
      expect(
        tayfaDurumu(tayfa(durum: 'archived')),
        const TayfaDurumu(TayfaDurumTuru.arsiv),
      );
    });

    test('silinme zamanı arşivden önce gelir', () {
      expect(
        tayfaDurumu(tayfa(durum: 'archived', silinme: '2026-12-01T09:00:00Z')),
        TayfaDurumu(
          TayfaDurumTuru.silinecek,
          zaman: DateTime.utc(2026, 12, 1, 9),
        ),
      );
    });

    test('askı her şeyden önce gelir', () {
      expect(
        tayfaDurumu(
          tayfa(
            durum: 'warned',
            askida: '2026-11-01T09:00:00Z',
            silinme: '2026-12-01T09:00:00Z',
          ),
        ),
        const TayfaDurumu(TayfaDurumTuru.askida),
      );
    });
  });

  group('tayfa görünümü', () {
    test('ana sayfa açılınca tayfa tazeleniyor; özet görünümden', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas': (_) =>
              listeJson([etkinJson(ornekTayfaId, ad: 'Eski ad')]),
          'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(
            ornekTayfaId,
            ad: 'Yeni ad',
            uyeSayisi: 142,
            rol: 'admin',
            kod: sahteKod,
          ),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(tayfaOzetiProvider(ornekTayfaId), (_, _) {});
      addTearDown(sub.close);
      expect(k.kap.read(tayfaOzetiProvider(ornekTayfaId)).ad, 'Eski ad');

      await k.kap.read(tayfaGorunumuProvider(ornekTayfaId).future);

      final ozet = k.kap.read(tayfaOzetiProvider(ornekTayfaId));
      expect(ozet.ad, 'Yeni ad');
      expect(ozet.tayfa!.memberCount, 142);
      expect(ozet.katilimKodu, sahteKod);
      final istek = k.tasima.giden('GET', '/v1/tayfas/{tayfa_id}').single;
      expect(istek.yolParametreleri['tayfa_id'], ornekTayfaId);
    });

    test('kod yalnızca sunucu döndürdüyse var', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas/{tayfa_id}': (_) => gorunumJson(ornekTayfaId),
        },
      );
      final sub = k.kap.listen(tayfaOzetiProvider(ornekTayfaId), (_, _) {});
      addTearDown(sub.close);
      await k.kap.read(tayfaGorunumuProvider(ornekTayfaId).future);

      expect(k.kap.read(tayfaOzetiProvider(ornekTayfaId)).katilimKodu, isNull);
    });

    test('tayfa-not-found gelince liste yenileniyor', () async {
      final k = _Kurulum(
        yanitlar: {
          'GET /v1/tayfas/{tayfa_id}': (_) =>
              _problem(ProblemType.tayfaNotFound, 404),
        },
      );
      await k.kap.read(tayfalarimProvider.future);
      final sub = k.kap.listen(tayfaGorunumuProvider(ornekTayfaId), (_, _) {});
      addTearDown(sub.close);
      await _bekle();

      expect(k.tasima.giden('GET', '/v1/tayfas'), hasLength(2));
    });
  });
}
