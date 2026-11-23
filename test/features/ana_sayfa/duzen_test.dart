import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/features/ana_sayfa/ana_sayfa.dart';
import 'package:tayfam/features/ana_sayfa/application/duzen.dart';
import 'package:tayfam/features/ana_sayfa/presentation/ayar_formlari.dart';
import 'package:tayfam/features/ana_sayfa/presentation/metrik.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/katalog/sahte_katalog.dart';
import '../tayfa/sahteler.dart';

HomeWidget _bilesen(
  String anahtar, {
  bool acik = true,
  String tur = 'display',
  Map<String, Object?>? ayar,
}) => HomeWidget.fromJson(
  anaSayfaBileseniJson(anahtar, tur: tur, acik: acik, ayar: ayar),
);

DuzenTaslagi _taslak(List<String> anahtarlar) => DuzenTaslagi.sunucudan(
  HomeWidgetLayout(widgets: [for (final a in anahtarlar) _bilesen(a)]),
);

List<String> _sira(DuzenTaslagi t) => [for (final s in t.satirlar) s.anahtar];

void main() {
  group('düzen taslağı: sıralama', () {
    final t = _taslak(['upcoming', 'stats', 'goal', 'countdown']);

    test('sürükle-bırak: aşağı ve yukarı', () {
      expect(_sira(t.tasi(0, 2)), ['stats', 'goal', 'upcoming', 'countdown']);
      expect(_sira(t.tasi(3, 0)), ['countdown', 'upcoming', 'stats', 'goal']);
      expect(t.tasi(1, 1), same(t));
      // Sınır dışı hedef listenin ucuna sıkıştırılır.
      expect(_sira(t.tasi(0, 9)), ['stats', 'goal', 'countdown', 'upcoming']);
      expect(t.tasi(7, 0), same(t));
    });

    test('yukarı/aşağı düğmeleri bir adım taşır, uçta değişmez', () {
      expect(_sira(t.yukari(2)), ['upcoming', 'goal', 'stats', 'countdown']);
      expect(_sira(t.asagi(0)), ['stats', 'upcoming', 'goal', 'countdown']);
      expect(t.yukari(0), same(t));
      expect(t.asagi(3), same(t));
    });

    test('taslak değişmez; eşitlik sıraya bakar', () {
      final yeni = t.asagi(0);
      expect(_sira(t), ['upcoming', 'stats', 'goal', 'countdown']);
      expect(yeni == t, isFalse);
      expect(yeni.yukari(1), t);
    });

    test('sunucudaki tekrar eden anahtar bir kez alınır', () {
      expect(_sira(_taslak(['stats', 'goal', 'stats'])), ['stats', 'goal']);
    });
  });

  group('düzen taslağı: aç/kapa, ayar ve gönderim', () {
    test('bütün liste yeni sırasıyla, açık/kapalı ve ayarıyla gider', () {
      final t = DuzenTaslagi.sunucudan(
        HomeWidgetLayout(
          widgets: [
            _bilesen('upcoming', tur: 'section'),
            _bilesen(
              'stats',
              ayar: {
                'stats': {
                  'metric_keys': ['events'],
                  'period': 'this_year',
                },
              },
            ),
            _bilesen('goal', acik: false),
          ],
        ),
      );
      final yeni = t
          .acKapa(0, acik: false)
          .ayarla(
            2,
            const HomeWidgetConfig(
              goal: GoalWidgetConfig(metricKey: 'events', target: 20),
            ),
            ac: true,
          )
          .asagi(0);
      final girdiler = [for (final g in yeni.girdiler()) g.toJson()];
      expect(girdiler, [
        {
          'key': 'stats',
          'enabled': true,
          'config': {
            'stats': {
              'metric_keys': ['events'],
              'period': 'this_year',
            },
          },
        },
        {'key': 'upcoming', 'enabled': false},
        {
          'key': 'goal',
          'enabled': true,
          'config': {
            'goal': {'metric_key': 'events', 'target': 20.0},
          },
        },
      ]);
    });

    test('tanınmayan bileşenin okunamayan ayarı kaydetmeyi kapatır', () {
      final ayarsiz = DuzenTaslagi.sunucudan(
        HomeWidgetLayout(widgets: [_bilesen('garage', tur: 'module')]),
      );
      expect(ayarsiz.kaydedilebilir, isTrue);
      final ayarli = DuzenTaslagi.sunucudan(
        HomeWidgetLayout(
          widgets: [
            _bilesen(
              'daily',
              tur: 'module',
              ayar: {
                'daily': {'pool': 'x'},
              },
            ),
          ],
        ),
      );
      expect(ayarli.satirlar.single.korunamayanAyarVar, isTrue);
      expect(ayarli.kaydedilebilir, isFalse);
    });
  });

  group('ana sayfada gösterilecekler', () {
    const kayit = <AnaSayfaBileseni>[
      ...anaSayfaBolumleri,
      IstatistikKartiBileseni(),
      GeriSayimKartiBileseni(),
    ];

    test('sunucunun sırasıyla; tanınmayan ve tekrar atlanır', () {
      final sonuc = gosterilecekBilesenler(
        kayit,
        [
          _bilesen('countdown'),
          _bilesen('library', tur: 'module'),
          _bilesen('upcoming', tur: 'section'),
          _bilesen('stats'),
          _bilesen('countdown'),
        ],
        acikModuller: {'events'},
      );
      expect(
        [for (final (b, _) in sonuc) b.anahtar],
        ['countdown', 'upcoming', 'stats'],
      );
    });

    test('modülü görünür olmayan bölüm ve kapalı bileşen atlanır', () {
      final sonuc = gosterilecekBilesenler(
        kayit,
        [
          _bilesen('announcements', tur: 'section'),
          _bilesen('stats', acik: false),
          _bilesen('upcoming', tur: 'section'),
        ],
        acikModuller: {'events'},
      );
      expect([for (final (b, _) in sonuc) b.anahtar], ['upcoming']);
    });
  });

  group('metrik', () {
    final m = lookupAppLocalizations(const Locale('tr'));
    final katalog = testKatalogu();

    test('kaynak anahtardan çıkar', () {
      expect(metrikKaynagi('events', katalog), TayfaStatSource.common);
      expect(metrikKaynagi('hike.attended', katalog), TayfaStatSource.common);
      expect(metrikKaynagi('hike.distance', katalog), TayfaStatSource.measure);
      expect(
        metrikKaynagi('running.duration', katalog),
        TayfaStatSource.measure,
      );
      expect(
        metrikKaynagi('fishing.catches.count', katalog),
        TayfaStatSource.log,
      );
      expect(metrikKaynagi('a.b.c.d', katalog), TayfaStatSource.unknown);
    });

    test('ad ve değer istatistik metinlerinden', () {
      final g = anaSayfaMetrigi(
        m,
        anahtar: 'hike.distance',
        deger: 42.5,
        katalog: katalog,
        dil: 'tr',
      )!;
      expect(g.ad, m.istatistik_metrik_turlu('Doğa yürüyüşü', 'Mesafe'));
      expect(g.deger, m.katalog_birimli_deger('42,5', m.katalog_birim_km));
      expect(
        anaSayfaMetrigi(
          m,
          anahtar: 'olmayan_tur.distance',
          deger: 1,
          katalog: katalog,
          dil: 'tr',
        ),
        isNull,
      );
      expect(etkinlikSayisiYazilsin('events', katalog), isFalse);
      expect(etkinlikSayisiYazilsin('hike.distance', katalog), isTrue);
    });

    test('seçenekler: ortak metrikler, sonra tayfanınkiler; günlükte '
        'yalnızca günlük', () {
      final statlar = [
        TayfaStat.fromJson({
          'metric_key': 'hike.distance',
          'source': 'measure',
          'value': 4,
          'event_count': 1,
        }),
        TayfaStat.fromJson({
          'metric_key': 'fishing.catches.count',
          'source': 'log',
          'value': 4,
          'event_count': 1,
        }),
      ];
      final hepsi = metrikSecenekleri(
        m,
        statlar: statlar,
        katalog: katalog,
        dil: 'tr',
        secili: const ['olmayan_tur.distance'],
      );
      expect(
        [for (final s in hepsi) s.anahtar],
        [
          ...ortakMetrikler,
          'hike.distance',
          'fishing.catches.count',
          'olmayan_tur.distance',
        ],
      );
      expect(hepsi.last.ad, m.anasayfa_metrik_bilinmiyor);
      final gunluk = metrikSecenekleri(
        m,
        statlar: statlar,
        katalog: katalog,
        dil: 'tr',
        secili: const [],
        yalnizcaGunluk: true,
      );
      expect([for (final s in gunluk) s.anahtar], ['fishing.catches.count']);
    });

    test('hedef değeri Türkçe biçimle okunur, sınır dışı reddedilir', () {
      expect(hedefDegeriOku('1.250'), 1250);
      expect(hedefDegeriOku('12,5'), 12.5);
      expect(hedefDegeriOku(' 7 '), 7);
      expect(hedefDegeriOku('0'), isNull);
      expect(hedefDegeriOku('-3'), isNull);
      expect(hedefDegeriOku('abc'), isNull);
      expect(hedefDegeriOku('2000000000'), isNull);
    });
  });
}
