import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/anket/application/anket_formu_notifier.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/application/anket_listesi_notifier.dart';
import 'package:tayfam/features/anket/application/anket_notifier.dart';
import 'package:tayfam/features/anket/application/oy_verenler_notifier.dart';
import 'package:tayfam/features/anket/presentation/anket_modulu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Poll _anket(
  String id, {
  bool gizli = false,
  bool coklu = false,
  bool kapali = false,
  int oyVeren = 0,
  List<int> oylar = const [0, 0, 0],
  List<String> kendi = const [],
  String? kapanis,
}) => Poll.fromJson(
  anketJson(
    id,
    gizli: gizli,
    coklu: coklu,
    kapali: kapali,
    oyVeren: oyVeren,
    oylar: oylar,
    kendi: kendi,
    kapanis: kapanis,
  ),
);

final class _Kurulum {
  _Kurulum([Map<String, TayfaYaniti>? yanitlar])
    : tasima = anketTasimasi(yanitlar) {
    kap = ProviderContainer.test(overrides: anketOverridelari(tasima));
  }

  final SahteTayfaTasima tasima;
  late final ProviderContainer kap;

  static const AnketAnahtari anahtar = (
    tayfaId: ornekTayfaId,
    anketId: anketId1,
  );

  Future<Poll> anket() async {
    final saglayici = anketProvider(anahtar);
    kap.listen(saglayici, (_, _) {});
    return kap.read(saglayici.future);
  }

  OylamaNotifier oylama() {
    final saglayici = oylamaProvider(anahtar);
    kap.listen(saglayici, (_, _) {});
    return kap.read(saglayici.notifier);
  }
}

void main() {
  group('gizlilik kuralları (kesin kural 7)', () {
    test('açık ankette sayılar her zaman görünür', () {
      expect(secenekSayilariGorunur(_anket(anketId1)), isTrue);
      expect(
        secenekSayilariGorunur(_anket(anketId1, oyVeren: 1, oylar: [1, 0, 0])),
        isTrue,
      );
    });

    test('gizli ankette eşiğin altında sayılar gizli', () {
      for (final oyVeren in [0, 1, 2, 3, 4]) {
        final anket = _anket(
          anketId1,
          gizli: true,
          oyVeren: oyVeren,
          oylar: [oyVeren, 0, 0],
        );
        expect(secenekSayilariGorunur(anket), isFalse, reason: '$oyVeren oy');
        expect(ondekiSecenekler(anket), isEmpty, reason: '$oyVeren oy');
      }
    });

    test('gizli ankette eşikte ve üstünde sayılar görünür', () {
      expect(anketSonucEsigi, 5);
      for (final oyVeren in [5, 6, 40]) {
        final anket = _anket(
          anketId1,
          gizli: true,
          oyVeren: oyVeren,
          oylar: [oyVeren, 0, 0],
        );
        expect(secenekSayilariGorunur(anket), isTrue);
        expect(ondekiSecenekler(anket), {secenekA});
      }
    });

    test('oy verenler yalnızca açık ankette görünür', () {
      expect(oyVerenlerGorunur(_anket(anketId1)), isTrue);
      expect(
        oyVerenlerGorunur(
          _anket(anketId1, gizli: true, oyVeren: 50, oylar: [50, 0, 0]),
        ),
        isFalse,
      );
    });

    test('önde olanlar: eşitlikte hepsi, oy yoksa hiçbiri', () {
      expect(
        ondekiSecenekler(_anket(anketId1, oyVeren: 4, oylar: [2, 2, 0])),
        {secenekA, secenekB},
      );
      expect(ondekiSecenekler(_anket(anketId1)), isEmpty);
    });
  });

  group('oy verenler (gizli ankette istek yok)', () {
    test('gizli ankette uç çağrılmıyor, hata dönüyor', () async {
      final k = _Kurulum({'GET $oyVerenlerYolu': yanit({'voters': []})});
      final anket = _anket(
        anketId1,
        gizli: true,
        oyVeren: 9,
        oylar: [9, 0, 0],
      );
      final saglayici = oyVerenlerProvider((
        tayfaId: ornekTayfaId,
        anket: anket,
        secenekId: secenekA,
      ));
      k.kap.listen(saglayici, (_, _) {});
      await expectLater(
        k.kap.read(saglayici.future),
        throwsA(isA<GizliAnketOyVerenleri>()),
      );
      expect(k.tasima.giden('GET', oyVerenlerYolu), isEmpty);
    });

    test('açık ankette oy verenler okunuyor', () async {
      final k = _Kurulum({
        'GET $oyVerenlerYolu': yanit({
          'voters': [
            {'user_id': digerId, 'voted_at': '2026-11-10T11:00:00Z'},
          ],
        }),
      });
      final anket = _anket(anketId1, oyVeren: 1, oylar: [1, 0, 0]);
      final saglayici = oyVerenlerProvider((
        tayfaId: ornekTayfaId,
        anket: anket,
        secenekId: secenekA,
      ));
      k.kap.listen(saglayici, (_, _) {});
      final liste = await k.kap.read(saglayici.future);
      expect(liste.ogeler.single.userId, digerId);
      final istek = k.tasima.giden('GET', oyVerenlerYolu).single;
      expect(istek.yolParametreleri['option_id'], secenekA);
      expect(istek.yolParametreleri['poll_id'], anketId1);
    });
  });

  group('kapanma ve ana sayfa', () {
    test('kapanma zamanı geçen anket kapalı sayılıyor', () {
      expect(anketKapali(_anket(anketId1), anketSimdi), isFalse);
      expect(anketKapali(_anket(anketId1, kapali: true), anketSimdi), isTrue);
      expect(
        anketKapali(
          _anket(anketId1, kapanis: '2026-11-11T11:00:00Z'),
          anketSimdi,
        ),
        isTrue,
      );
      expect(
        anketKapali(
          _anket(anketId1, kapanis: '2026-11-12T11:00:00Z'),
          anketSimdi,
        ),
        isFalse,
      );
    });

    test('ana sayfada yalnızca açık anketler, en çok üç', () {
      final anketler = [
        _anket(anketId1, kapali: true),
        for (var i = 0; i < 5; i++)
          _anket('3c4d5e6f-0000-4000-8000-00000000001$i'),
      ];
      final gosterilen = anaSayfaAnketleri(anketler, anketSimdi);
      expect(gosterilen, hasLength(anaSayfaAnketSayisi));
      expect(gosterilen.map((a) => a.id), isNot(contains(anketId1)));
    });

    test('etkinlik süzgeci adresten doğrulanıyor', () {
      expect(
        anketEtkinlikSuzgeci(
          Uri.parse('/t/$ornekTayfaId/anketler?etkinlik=$anketEtkinlikId'),
        ),
        anketEtkinlikId,
      );
      expect(
        anketEtkinlikSuzgeci(Uri(queryParameters: {'etkinlik': '../x'})),
        isNull,
      );
      expect(anketEtkinlikSuzgeci(Uri()), isNull);
    });

    test('etkinlik listesi event_id ile okunuyor', () async {
      final k = _Kurulum();
      final saglayici = anketListesiProvider((
        tayfaId: ornekTayfaId,
        etkinlikId: anketEtkinlikId,
      ));
      k.kap.listen(saglayici, (_, _) {});
      await k.kap.read(saglayici.future);
      final istek = k.tasima.giden('GET', anketlerYolu).single;
      expect(istek.sorgu['event_id'], anketEtkinlikId);
    });
  });

  group('oy verme', () {
    test('tek seçimlide seçim tek, çoklu seçimde tersine çevriliyor', () {
      final k = _Kurulum();
      final oylama = k.oylama();
      final tek = _anket(anketId1);
      oylama
        ..sec(tek, secenekA)
        ..sec(tek, secenekB);
      expect(k.kap.read(oylamaProvider(_Kurulum.anahtar)).secim, {secenekB});

      oylama.vazgec();
      final coklu = _anket(anketId1, coklu: true);
      oylama
        ..sec(coklu, secenekA)
        ..sec(coklu, secenekB)
        ..sec(coklu, secenekA);
      expect(k.kap.read(oylamaProvider(_Kurulum.anahtar)).secim, {secenekB});
    });

    test('seçim geçerliliği', () {
      final tek = _anket(anketId1);
      expect(secimGecerli(tek, {}), isFalse);
      expect(secimGecerli(tek, {secenekA}), isTrue);
      expect(secimGecerli(tek, {secenekA, secenekB}), isFalse);
      expect(secimGecerli(tek, {'yabanci'}), isFalse);
      final coklu = _anket(anketId1, coklu: true);
      expect(secimGecerli(coklu, {secenekA, secenekB}), isTrue);
    });

    test('oy gönderiliyor ve sonuç listeye yansıyor', () async {
      final k = _Kurulum({
        'GET $anketlerYolu': yanit(anketListesiJson([anketJson(anketId1)])),
        'PUT $oyYolu': yanit(
          anketJson(anketId1, oyVeren: 1, oylar: [0, 1, 0], kendi: [secenekB]),
        ),
      });
      final liste = anketListesiProvider((
        tayfaId: ornekTayfaId,
        etkinlikId: null,
      ));
      k.kap.listen(liste, (_, _) {});
      await k.kap.read(liste.future);
      final anket = await k.anket();
      expect(k.tasima.giden('GET', anketYolu), isEmpty);

      final oylama = k.oylama()..sec(anket, secenekB);
      final hata = await oylama.gonder(anket);

      expect(hata, isNull);
      expect(k.tasima.giden('PUT', oyYolu).single.govde, {
        'option_ids': [secenekB],
      });
      final guncel = k.kap.read(liste).requireValue.ogeler.single;
      expect(guncel.ownOptionIds, [secenekB]);
      expect(k.kap.read(oylamaProvider(_Kurulum.anahtar)).secim, isEmpty);
    });

    test('susturulmuş üyede hata dönüyor, seçim korunuyor', () async {
      final k = _Kurulum({
        'GET $anketYolu': yanit(anketJson(anketId1)),
        'PUT $oyYolu': yanit(
          const ApiProblem(type: ProblemType.muted, status: 403),
        ),
      });
      final anket = await k.anket();
      final oylama = k.oylama()..sec(anket, secenekA);
      final hata = await oylama.gonder(anket);
      expect(hata, isA<ApiProblem>());
      expect(k.kap.read(oylamaProvider(_Kurulum.anahtar)).secim, {secenekA});
    });

    test('oy değiştirme mevcut oyla başlıyor; geri çekme DELETE', () async {
      final k = _Kurulum({
        'GET $anketYolu': yanit(
          anketJson(anketId1, oyVeren: 1, oylar: [1, 0, 0], kendi: [secenekA]),
        ),
        'DELETE $oyYolu': yanit(anketJson(anketId1)),
      });
      final anket = await k.anket();
      final oylama = k.oylama()..degistir(anket);
      final durum = k.kap.read(oylamaProvider(_Kurulum.anahtar));
      expect(durum.secim, {secenekA});
      expect(secimGosterilir(anket, durum, anketSimdi), isTrue);

      oylama.vazgec();
      expect(await oylama.geriCek(), isNull);
      expect(k.tasima.giden('DELETE', oyYolu), hasLength(1));
      final guncel = k.kap.read(anketProvider(_Kurulum.anahtar)).requireValue;
      expect(guncel.ownOptionIds, isEmpty);
    });

    test('kapalı ankette seçim gösterilmiyor', () {
      final anket = _anket(anketId1, kapali: true);
      expect(
        secimGosterilir(anket, const OylamaDurumu(), anketSimdi),
        isFalse,
      );
    });
  });

  group('anket formu', () {
    const AnketFormuAnahtari anahtar = (
      tayfaId: ornekTayfaId,
      etkinlikId: anketEtkinlikId,
    );

    test('alan kuralları', () {
      expect(anketSorusuGecerli(''), isFalse);
      expect(anketSorusuGecerli('  Nereye?  '), isTrue);
      expect(anketSorusuGecerli('a\nb'), isFalse);
      expect(anketSorusuGecerli('x' * 201), isFalse);
      expect(anketSecenegiGecerli('x' * 100), isTrue);
      expect(anketSecenegiGecerli('x' * 101), isFalse);
      expect(secenekHatalari(['Moda', ' Moda ', '']), {
        1: SecenekHatasi.tekrar,
        2: SecenekHatasi.gecersiz,
      });
      expect(
        anketKapanisiGecerli(
          anketSimdi.add(const Duration(days: 1)),
          anketSimdi,
        ),
        isTrue,
      );
      expect(anketKapanisiGecerli(anketSimdi, anketSimdi), isFalse);
      expect(
        anketKapanisiGecerli(
          anketSimdi.add(const Duration(days: 366)),
          anketSimdi,
        ),
        isFalse,
      );
    });

    test('seçenek sayısı 2–10 arasında kalıyor', () {
      final k = _Kurulum();
      final saglayici = anketFormuProvider(anahtar);
      k.kap.listen(saglayici, (_, _) {});
      final form = k.kap.read(saglayici.notifier)..secenekKaldir(0);
      expect(k.kap.read(saglayici).secenekler, hasLength(2));
      for (var i = 0; i < 12; i++) {
        form.secenekEkle();
      }
      expect(k.kap.read(saglayici).secenekler, hasLength(anketSecenekEnCok));
    });

    test('geçersiz formda istek gitmiyor', () async {
      final k = _Kurulum();
      final saglayici = anketFormuProvider(anahtar);
      k.kap.listen(saglayici, (_, _) {});
      final form = k.kap.read(saglayici.notifier)
        ..soruAyarla('Nereye?')
        ..secenekAyarla(0, 'Moda');
      await form.gonder();
      expect(k.kap.read(saglayici).denendi, isTrue);
      expect(k.tasima.giden('POST', anketlerYolu), isEmpty);
    });

    test('gönderim gövdesi ve listeye ekleme', () async {
      final k = _Kurulum({
        'POST $anketlerYolu': yanit(
          anketJson(anketId2, gizli: true, etkinlik: anketEtkinlikId),
        ),
      });
      final liste = anketListesiProvider((
        tayfaId: ornekTayfaId,
        etkinlikId: anketEtkinlikId,
      ));
      k.kap.listen(liste, (_, _) {});
      await k.kap.read(liste.future);
      final saglayici = anketFormuProvider(anahtar);
      k.kap.listen(saglayici, (_, _) {});
      final kapanis = DateTime.utc(2026, 11, 20, 18);
      final form = k.kap.read(saglayici.notifier)
        ..soruAyarla('  Nereye?  ')
        ..secenekAyarla(0, ' Moda ')
        ..secenekAyarla(1, 'Şile')
        ..gizliAyarla(gizli: true)
        ..cokluAyarla(coklu: true)
        ..kapanisAyarla(kapanis);
      await form.gonder();

      final govde = k.tasima.giden('POST', anketlerYolu).single.govde;
      expect(govde, {
        'question': 'Nereye?',
        'options': ['Moda', 'Şile'],
        'anonymous': true,
        'multiple_choice': true,
        'closes_at': PollCreateRequest(
          question: '',
          options: const [],
          closesAt: kapanis,
        ).toJson()['closes_at'],
        'event_id': anketEtkinlikId,
      });
      expect(k.kap.read(saglayici).tamamlanan?.id, anketId2);
      expect(k.kap.read(liste).requireValue.ogeler.first.id, anketId2);
    });

    test('bağlantı yoksa girilenler korunuyor', () async {
      final k = _Kurulum({'POST $anketlerYolu': yanit(const ApiOffline())});
      final saglayici = anketFormuProvider(anahtar);
      k.kap.listen(saglayici, (_, _) {});
      final form = k.kap.read(saglayici.notifier)
        ..soruAyarla('Nereye?')
        ..secenekAyarla(0, 'Moda')
        ..secenekAyarla(1, 'Şile');
      await form.gonder();
      final durum = k.kap.read(saglayici);
      expect(durum.hata, isA<ApiOffline>());
      expect(durum.soru, 'Nereye?');
      expect(durum.tamamlanan, isNull);
    });
  });

  test('liste sayfalı okunuyor', () async {
    final k = _Kurulum({
      'GET $anketlerYolu': (i) => switch (i.sorgu['page_token']) {
        null => anketListesiJson([anketJson(anketId1)], sonraki: 'opak-1'),
        _ => anketListesiJson([anketJson(anketId2)]),
      },
    });
    final saglayici = anketListesiProvider((
      tayfaId: ornekTayfaId,
      etkinlikId: null,
    ));
    k.kap.listen(saglayici, (_, _) {});
    await k.kap.read(saglayici.future);
    await k.kap.read(saglayici.notifier).dahaFazla();
    final SayfaliListe<Poll> liste = k.kap.read(saglayici).requireValue;
    expect(liste.ogeler.map((a) => a.id), [anketId1, anketId2]);
    expect(liste.dahaVar, isFalse);
  });
}
