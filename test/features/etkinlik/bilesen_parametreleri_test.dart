import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_bolumleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';

import '../../core/katalog/sahte_katalog.dart';
import 'sahteler.dart';

CatalogComponent _bilesen(String anahtar) =>
    turBilesenleri(testTuru('ornek_bilesenler'))
        .firstWhere((b) => bilesenAnahtari(b) == anahtar);

CatalogEventType _tur(List<Map<String, Object?>> bilesenler) =>
    CatalogEventType.fromJson({
      ...testTuru('general').toJson(),
      'key': 'deneme',
      'definition': {'components': bilesenler},
    });

void main() {
  final tanim = testTuru('ornek_bilesenler');

  group('tanım', () {
    test('anahtar: key yoksa kind', () {
      expect(bilesenAnahtari(_bilesen('gear')), 'gear');
      expect(_bilesen('gear').kind, 'checklist');
      expect(bilesenAnahtari(_bilesen('teams')), 'teams');
    });

    test('geçersiz ya da tekrar eden anahtar atlanır', () {
      final tur = _tur([
        {'kind': 'route'},
        {'kind': 'route'},
        {'kind': 'Geçersiz'},
        {'kind': 'measure', 'key': 'a b'},
        {'kind': 'measure', 'key': 'distance'},
      ]);
      expect(turBilesenleri(tur).map(bilesenAnahtari), ['route', 'distance']);
      expect(turBilesenleri(null), isEmpty);
    });

    test('organizatöre bırakılan parametreler ada göre okunur', () {
      final takim = secimliParametreler(_bilesen('teams')).single;
      expect(takim.ad, 'mode');
      expect(takim.secenekler, ['random', 'balanced', 'manual']);
      expect(takim.varsayilan, 'balanced');
      expect(secimliParametreler(_bilesen('route')), isEmpty);

      final tur = _tur([
        {
          'kind': 'bracket',
          'params': {
            'format': {
              'organizer_choice': ['elimination', 'swiss'],
              'default': 'yok',
            },
            'best_of': {
              'organizer_choice': [1, 3, 5, 3, '', 2.5],
              'default': 3,
            },
            'bozuk': {'organizer_choice': 'liste-degil'},
            'bos': {'organizer_choice': <Object?>[]},
          },
        },
      ]);
      final secimli = secimliParametreler(turBilesenleri(tur).single);
      expect(secimli.map((p) => p.ad), ['best_of', 'format']);
      expect(secimli[0].secenekler, ['1', '3', '5']);
      expect(secimli[0].varsayilan, '3');
      // Varsayılan seçeneklerde yoksa ilk seçenek.
      expect(secimli[1].varsayilan, 'elimination');
    });

    test('parametreler güvenle okunur; seçimli parametre seçimiyle', () {
      const p = BilesenParametreleri(
        {
          'alarm': true,
          'return_grace_minutes': 30,
          'label': 'gear',
          'presets': ['batak', 7, 'tavla'],
          'saniye': [60, 'x', 300],
          'best_of': {
            'organizer_choice': [1, 3, 5],
            'default': 1,
          },
          'mode': {
            'organizer_choice': ['random', 'manual'],
            'default': 'random',
          },
        },
        {'best_of': '5', 'mode': 'tanimsiz'},
      );
      expect(p.mantik('alarm'), isTrue);
      expect(p.mantik('yok', varsayilan: true), isTrue);
      expect(p.mantik('label'), isFalse);
      expect(p.tamSayi('return_grace_minutes', enAz: 1, enCok: 1440), 30);
      expect(p.tamSayi('return_grace_minutes', enCok: 10), isNull);
      expect(p.tamSayi('label'), isNull);
      expect(p.metin('label'), 'gear');
      expect(p.metin('label', izinli: {'task'}), isNull);
      expect(p.metinler('presets'), ['batak', 'tavla']);
      expect(p.tamSayilar('saniye'), [60, 300]);
      expect(p.tamSayi('best_of'), 5);
      // Tanımda olmayan seçim varsayılana çekilir.
      expect(p.metin('mode'), 'random');
      expect(const BilesenParametreleri(null).metin('label'), isNull);
    });
  });

  group('seçimler', () {
    test('açık/kapalı: varsayılan tanımdan; optional olmayan hep açık', () {
      final yoklama = _bilesen('roll_call');
      expect(bilesenAcikMi(yoklama, const {}), isFalse);
      final acik = bilesenAcKapa(const {}, yoklama, acik: true);
      expect(bilesenAcikMi(yoklama, acik), isTrue);

      final rota = _bilesen('route');
      expect(bilesenAcikMi(rota, const {}), isTrue);
      expect(bilesenAcKapa(const {}, rota, acik: false), isEmpty);
    });

    test('seçim: yalnızca tanımdaki seçenek kabul edilir', () {
      final takim = _bilesen('teams');
      expect(gecerliSecimler(takim, const {}), {'mode': 'balanced'});
      final secili = bilesenSecimYap(const {}, takim, 'mode', 'manual');
      expect(gecerliSecimler(takim, secili), {'mode': 'manual'});
      expect(bilesenSecimYap(secili, takim, 'mode', 'yok'), same(secili));
      expect(bilesenSecimYap(secili, takim, 'team_count', '3'), same(secili));
    });

    test('oluşturma gövdesi: yalnızca dokunulanlar, tanımdaki sırayla', () {
      expect(bilesenSecimGovdesi(tanim, const {}), isNull);
      var secimler = bilesenSecimYap(
        const {},
        _bilesen('bracket'),
        'format',
        'league',
      );
      secimler = bilesenAcKapa(secimler, _bilesen('roll_call'), acik: true);
      final govde = bilesenSecimGovdesi(tanim, {
        ...secimler,
        // Türde olmayan bileşen ve tanımda olmayan seçim gönderilmez.
        'yok': const BilesenSecimi(acik: true),
        'teams': const BilesenSecimi(secimler: {'mode': 'uydurma'}),
      })!;
      expect(govde.map((g) => g.toJson()), [
        {'key': 'roll_call', 'enabled': true},
        {
          'key': 'bracket',
          'choices': [
            {'param': 'format', 'value': 'league'},
          ],
        },
      ]);
    });

    test('düzenleme: sunucudaki durumdan başlar, yalnızca fark gider', () {
      final durum = EventComponentList.fromJson(
        bilesenlerJson(
          bilesenler: [
            bilesenDurumuJson('roll_call', acik: false),
            bilesenDurumuJson(
              'teams',
              secimler: {
                'mode': ('manual', ['random', 'balanced', 'manual']),
              },
            ),
            bilesenDurumuJson(
              'bracket',
              secimler: {
                'format': ('uydurma', ['uydurma']),
              },
            ),
          ],
        ),
      );
      final ilk = durumdanSecimler(tanim, durum);
      expect(ilk['roll_call'], const BilesenSecimi(acik: false));
      expect(ilk['teams'], const BilesenSecimi(secimler: {'mode': 'manual'}));
      // Tanımda olmayan seçenek alınmaz.
      expect(ilk['bracket'], const BilesenSecimi());
      expect(bilesenSecimDegisiklikleri(tanim, ilk, ilk), isEmpty);

      var yeni = bilesenAcKapa(ilk, _bilesen('roll_call'), acik: true);
      yeni = bilesenSecimYap(yeni, _bilesen('teams'), 'mode', 'random');
      final fark = bilesenSecimDegisiklikleri(tanim, ilk, yeni);
      expect(
        [
          for (final (anahtar, istek) in fark) [anahtar, istek.toJson()],
        ],
        [
          [
            'roll_call',
            {'enabled': true},
          ],
          [
            'teams',
            {
              'choices': [
                {'param': 'mode', 'value': 'random'},
              ],
            },
          ],
        ],
      );
    });
  });

  group('çizim planı', () {
    const kayit = <EtkinlikBileseni>[
      TemelBilesen('meeting_point'),
      SahteBilesen('teams'),
    ];

    test('temel bileşen çizilmez; kayıtta olmayan bilinmeyendir', () {
      final plan = bilesenPlani(tanim, kayit);
      expect(
        plan.map((p) => bilesenAnahtari(p.tanim)),
        isNot(contains('meeting_point')),
      );
      expect(plan.first.bilesen, isNull);
      expect(bilesenAnahtari(plan.first.tanim), 'route');
      expect(
        plan.singleWhere((p) => p.bilesen != null).bilesen,
        same(kayit[1]),
      );
      expect(bilesenPlani(null, kayit), isEmpty);
      expect(etkinlikBileseniBul(kayit, 'gelecek_bilesen'), isNull);
    });

    test('bileşenin hali: durum yoksa tanımdaki varsayılan', () {
      expect(bilesenHali(_bilesen('roll_call'), null).acik, isFalse);
      final takim = bilesenHali(_bilesen('teams'), null);
      expect(takim.acik, isTrue);
      expect(takim.secimler, {'mode': 'balanced'});
      final durum = EventComponentList.fromJson(
        bilesenlerJson(
          bilesenler: [
            bilesenDurumuJson('roll_call', acik: true),
            bilesenDurumuJson(
              'teams',
              secimler: {
                'mode': ('uydurma', ['uydurma']),
              },
            ),
          ],
        ),
      );
      expect(bilesenHali(_bilesen('roll_call'), durum).acik, isTrue);
      expect(bilesenHali(_bilesen('teams'), durum).secimler, {
        'mode': 'balanced',
      });
    });
  });

  group('rol', () {
    final etkinlik = ornekEtkinlik();
    final takim = _bilesen('teams');
    EventComponentList durum({bool yonetebilir = false}) =>
        EventComponentList.fromJson(bilesenlerJson(yonetebilir: yonetebilir));
    List<EventReferee> hakemler(Map<String, Object?> ek) => [
      EventReferee.fromJson({
        'id': ikinciEtkinlikId,
        'user_id': katilimciId,
        'created_at': '2026-11-10T10:00:00Z',
        ...ek,
      }),
    ];

    BilesenRolu rol({
      EventComponentList? d,
      List<EventReferee> h = const [],
      String? ben = katilimciId,
      Event? e,
    }) => bilesenRolu(
      etkinlik: e ?? etkinlik,
      bilesen: takim,
      durum: d,
      hakemler: h,
      kullaniciId: ben,
    );

    test('yöneten organizatördür', () {
      expect(rol(d: durum(yonetebilir: true)), BilesenRolu.organizator);
    });

    test('hakem: etkinliğin tamamı ya da bu bileşen', () {
      expect(rol(d: durum(), h: hakemler({})), BilesenRolu.hakem);
      expect(rol(h: hakemler({'component_key': 'teams'})), BilesenRolu.hakem);
      expect(
        rol(h: hakemler({'component_key': 'bracket'})),
        isNot(BilesenRolu.hakem),
      );
      // Kimlik okunamadıysa kimse hakem sayılmaz.
      expect(rol(h: hakemler({}), ben: null), isNot(BilesenRolu.hakem));
    });

    test('"Geliyorum" diyen katılımcı, diğerleri üye', () {
      expect(rol(e: ornekEtkinlik(cevap: 'going')), BilesenRolu.katilimci);
      expect(rol(e: ornekEtkinlik(cevap: 'maybe')), BilesenRolu.uye);
      expect(rol(), BilesenRolu.uye);
    });
  });
}
