import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/moduller/ana_sayfa_bileseni.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/ana_sayfa/ana_sayfa.dart';
import 'package:tayfam/features/ana_sayfa/data/ana_sayfa_deposu.dart';
import 'package:tayfam/features/ana_sayfa/presentation/duzen_ekrani.dart';
import 'package:tayfam/features/istatistik/data/istatistik_deposu.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/ek_girisler.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/ayarlar_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import '../tayfa_yonetim/sahteler.dart';

const String _veriYolu = '/v1/tayfas/{tayfa_id}/home-widgets/{widget_key}/data';
const String _duzenYolu = '/v1/tayfas/{tayfa_id}/home-widgets';
const String _istatistikYolu = '/v1/tayfas/{tayfa_id}/stats';
const String _etkinlikId = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e99';

/// Testlerin sabit saati: geri sayım (31 Aralık) 41 gün sonra.
final DateTime _simdi = DateTime.utc(2026, 11, 20, 9);

const List<AnaSayfaBileseni> _kayit = [
  ...anaSayfaBolumleri,
  IstatistikKartiBileseni(),
  HedefKartiBileseni(),
  GeriSayimKartiBileseni(),
  SampiyonlarKartiBileseni(),
  GunlukOzetiKartiBileseni(),
];

/// Gösterim bileşenlerinin verisi (`HomeWidgetData`).
Object? _veri(TayfaIstegi istek) {
  final anahtar = istek.yolParametreleri['widget_key']!;
  return switch (anahtar) {
    'stats' => {
      'key': 'stats',
      'stats': {
        'period': 'this_year',
        'year': 2026,
        'values': [
          {'metric_key': 'events', 'value': 12, 'event_count': 12},
          {'metric_key': 'attended', 'value': 87, 'event_count': 9},
        ],
      },
    },
    'goal' => {
      'key': 'goal',
      'goal': {
        'metric_key': 'hike.distance',
        'target': 100,
        'year': 2026,
        'value': 42.5,
        'event_count': 3,
        'reached': false,
      },
    },
    'countdown' => {
      'key': 'countdown',
      'countdown': {'title': 'Yılbaşı kampı', 'at': '2026-12-31T18:00:00Z'},
    },
    'champions' => {
      'key': 'champions',
      'champions': {
        'period': 'this_year',
        'champions': [
          {
            'event_id': _etkinlikId,
            'event_title': 'Cuma buluşması',
            'event_type': 'car_meet',
            'component_key': 'kutlama',
            'winners': [
              {
                'team_id': '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e98',
                'team_position': 2,
              },
              {
                'guest_id': '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e97',
                'guest_nickname': 'Kaptan',
              },
            ],
          },
        ],
      },
    },
    'log_summary' => {
      'key': 'log_summary',
      'log_summary': {
        'metric_key': 'fishing.catches.count',
        'period': 'all_time',
        'value': 7,
        'event_count': 2,
      },
    },
    _ => const ApiProblem(type: ProblemType.homeWidgetNotFound, status: 404),
  };
}

List<Map<String, Object?>> _gosterimler(List<String> anahtarlar) => [
  for (final (sira, a) in anahtarlar.indexed)
    anaSayfaBileseniJson(a, sira: sira),
];

SahteTayfaTasima _anaSayfaTasimasi(
  List<String> anahtarlar, {
  TayfaYaniti veri = _veri,
}) => SahteTayfaTasima({
  'GET /v1/tayfas/{tayfa_id}': yanit(
    gorunumJson(ornekTayfaId, bilesenler: _gosterimler(anahtarlar)),
  ),
  'GET $_veriYolu': veri,
});

List<Override> _overridelar(SahteTayfaTasima tasima) => [
  anaSayfaDeposuProvider.overrideWithValue(AnaSayfaDeposu(tasima)),
  istatistikDeposuProvider.overrideWithValue(IstatistikDeposu(tasima)),
  anaSayfaBilesenKaydiProvider.overrideWithValue(_kayit),
  simdiProvider.overrideWithValue(() => _simdi),
];

Future<void> _anaSayfayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  const TayfaAnaSayfa(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: tayfaOverridelari(tasima: tasima),
  overrides: _overridelar(tasima),
);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  group('ana sayfa gösterim kartları', () {
    const hepsi = ['stats', 'goal', 'countdown', 'champions', 'log_summary'];

    testWidgets('beş kart sunucunun verisiyle çiziliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 3000);
      await _anaSayfayiAc(tester, _anaSayfaTasimasi(hepsi));

      // İstatistik: ortak metrikler, dönem.
      expect(find.text(m.istatistik_metrik_attended), findsOneWidget);
      expect(find.text('87'), findsOneWidget);
      expect(find.text(m.anasayfa_donem_yil(2026)), findsWidgets);
      // Hedef: "değer / hedef", ulaşılmadı.
      expect(
        find.text(
          m.anasayfa_goal_ilerleme(
            m.katalog_birimli_deger('42,5', m.katalog_birim_km),
            m.katalog_birimli_deger('100', m.katalog_birim_km),
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(m.anasayfa_goal_yuzde(42)), findsOneWidget);
      expect(find.text(m.anasayfa_goal_ulasildi), findsNothing);
      // Geri sayım: başlık ve takvim günü.
      expect(find.text('Yılbaşı kampı'), findsOneWidget);
      expect(find.text(m.goreli_gun_sonra(41)), findsOneWidget);
      // Şampiyonlar: adsız takım, misafir, etkinlik ve tür.
      expect(find.text(m.anasayfa_takim_no(2)), findsOneWidget);
      expect(find.text('Kaptan'), findsOneWidget);
      expect(
        find.text(
          m.anasayfa_champions_etkinlik('Cuma buluşması', 'Araç buluşması'),
        ),
        findsOneWidget,
      );
      // Günlük özeti: tüm zamanlar.
      expect(find.text(m.anasayfa_donem_tum_zamanlar), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('kartlar sunucunun sırasıyla; sıra değişince değişiyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 3000);
      final geriSayim = find.text('Yılbaşı kampı');
      final sampiyon = find.text('Kaptan');

      await _anaSayfayiAc(
        tester,
        _anaSayfaTasimasi(['countdown', 'champions']),
      );
      expect(
        tester.getTopLeft(geriSayim).dy,
        lessThan(tester.getTopLeft(sampiyon).dy),
      );

      await _anaSayfayiAc(
        tester,
        _anaSayfaTasimasi(['champions', 'countdown']),
      );
      expect(
        tester.getTopLeft(sampiyon).dy,
        lessThan(tester.getTopLeft(geriSayim).dy),
      );
    });

    testWidgets('tanınmayan bileşen atlanıyor, istek atılmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 3000);
      final tasima = _anaSayfaTasimasi(['garage', 'countdown']);
      await _anaSayfayiAc(tester, tasima);

      expect(find.text('Yılbaşı kampı'), findsOneWidget);
      expect(
        [for (final i in tasima.giden('GET', _veriYolu)) i.yolParametreleri],
        [
          {'tayfa_id': ornekTayfaId, 'widget_key': 'countdown'},
        ],
      );
      expect(find.text(arbMetni('tayfa_ana_sayfa_bos')), findsNothing);
    });

    testWidgets('home-widget-not-found: kart yer kaplamıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 3000);
      await _anaSayfayiAc(
        tester,
        _anaSayfaTasimasi(
          ['countdown', 'stats'],
          veri: (i) => i.yolParametreleri['widget_key'] == 'countdown'
              ? const ApiProblem(
                  type: ProblemType.homeWidgetNotFound,
                  status: 404,
                )
              : _veri(i),
        ),
      );

      expect(find.text(m.anasayfa_countdown_ad), findsNothing);
      expect(find.text(m.istatistik_metrik_attended), findsOneWidget);
    });

    testWidgets('başka hata: hata satırı ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester, yukseklik: 3000);
      var deneme = 0;
      await _anaSayfayiAc(
        tester,
        _anaSayfaTasimasi(
          ['countdown'],
          veri: (i) => deneme++ == 0
              ? const ApiProblem(type: ProblemType.unknown, status: 503)
              : _veri(i),
        ),
      );
      expect(find.byType(HataSatiri), findsOneWidget);

      await tester.tap(find.text(m.tayfa_ana_tekrar_dene));
      await tester.pumpAndSettle();
      expect(find.text('Yılbaşı kampı'), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 6000);
        ikiKatYazi(tester);
        await _anaSayfayiAc(tester, _anaSayfaTasimasi(hepsi), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(find.text('Kaptan'), findsOneWidget);
      });
    }
  });

  group('ana sayfa düzeni ekranı', () {
    Map<String, Object?> duzenJson() => {
      'widgets': [
        anaSayfaBileseniJson('upcoming', tur: 'section', modul: 'events'),
        anaSayfaBileseniJson(
          'stats',
          sira: 1,
          ayar: {
            'stats': {
              'metric_keys': ['events'],
              'period': 'this_year',
            },
          },
        ),
        anaSayfaBileseniJson('goal', acik: false, sira: 2),
        anaSayfaBileseniJson('garage', tur: 'module', acik: false, sira: 3),
      ],
    };

    SahteTayfaTasima duzenTasimasi({String rol = 'admin'}) => SahteTayfaTasima({
      'GET /v1/tayfas/{tayfa_id}': yanit(gorunumJson(ornekTayfaId, rol: rol)),
      'GET $_duzenYolu': yanit(duzenJson()),
      'PUT $_duzenYolu': yanit(duzenJson()),
      'GET $_istatistikYolu': yanit({
        'years': [2026],
        'totals': const <Object?>[],
        'contributions': const <Object?>[],
      }),
    });

    Future<void> duzeniAc(
      WidgetTester tester,
      SahteTayfaTasima tasima, {
      ThemeMode themeMode = ThemeMode.light,
    }) => widgetAc(
      tester,
      const AnaSayfaDuzenEkrani(tayfaId: ornekTayfaId),
      themeMode: themeMode,
      tayfa: tayfaOverridelari(tasima: tasima),
      overrides: _overridelar(tasima),
    );

    List<Object?> gonderilenler(SahteTayfaTasima tasima) {
      final govde = tasima.giden('PUT', _duzenYolu).single.govde;
      return (govde! as Map<String, Object?>)['widgets']! as List<Object?>;
    }

    List<Object?> anahtarlar(List<Object?> liste) => [
      for (final w in liste) (w! as Map<String, Object?>)['key'],
    ];

    Finder satirdaki(String ad, Finder hedef) => find.descendant(
      of: find.ancestor(of: find.text(ad), matching: find.byType(TayfamKart)),
      matching: hedef,
    );

    testWidgets('bütün bileşenler; tanınmayan "Uygulamayı güncelle"', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await duzeniAc(tester, duzenTasimasi());

      expect(find.text(m.anasayfa_bolum_upcoming), findsOneWidget);
      expect(find.text(m.anasayfa_stats_ad), findsOneWidget);
      expect(find.text(m.anasayfa_goal_ad), findsOneWidget);
      expect(find.text(m.anasayfa_bilinmeyen_ad), findsOneWidget);
      expect(find.textContaining(m.anasayfa_guncelle_etiketi), findsOneWidget);
      // Tanınmayan satırda aç/kapa ve taşıma yok.
      expect(
        satirdaki(m.anasayfa_bilinmeyen_ad, find.byType(Switch)),
        findsNothing,
      );
      expect(
        find.byTooltip(m.anasayfa_yukari(m.anasayfa_bilinmeyen_ad)),
        findsNothing,
      );
      // Ayarsız açılamayan bileşen bunu söylüyor.
      expect(
        find.text(m.anasayfa_ayar_gerekli(m.anasayfa_goal_aciklama)),
        findsOneWidget,
      );
      // Değişiklik yokken "Kaydet" kapalı.
      final kaydet = tester.widget<TextButton>(
        find.widgetWithText(TextButton, m.anasayfa_ayar_kaydet),
      );
      expect(kaydet.onPressed, isNull);
    });

    testWidgets('aşağı/yukarı taşı ve kapat; Kaydet bütün listeyi gönderir', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = duzenTasimasi();
      await duzeniAc(tester, tasima);

      await tester.tap(
        find.byTooltip(m.anasayfa_asagi(m.anasayfa_bolum_upcoming)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(m.anasayfa_yukari(m.anasayfa_goal_ad)));
      await tester.pumpAndSettle();
      await tester.tap(satirdaki(m.anasayfa_stats_ad, find.byType(Switch)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.anasayfa_ayar_kaydet));
      await tester.pumpAndSettle();

      final liste = gonderilenler(tasima);
      expect(anahtarlar(liste), ['stats', 'goal', 'upcoming', 'garage']);
      expect(liste.first, {
        'key': 'stats',
        'enabled': false,
        'config': {
          'stats': {
            'metric_keys': ['events'],
            'period': 'this_year',
          },
        },
      });
      expect(liste.last, {'key': 'garage', 'enabled': false});
      expect(find.text(m.anasayfa_kaydedildi), findsOneWidget);
    });

    testWidgets('sürükle-bırak sırayı değiştiriyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = duzenTasimasi();
      await duzeniAc(tester, tasima);

      final tutamac = find.bySemanticsLabel(
        m.anasayfa_surukle(m.anasayfa_bolum_upcoming),
      );
      final hedef = tester.getCenter(
        satirdaki(m.anasayfa_goal_ad, find.byType(Switch)),
      );
      final baslangic = tester.getCenter(tutamac);
      final hareket = await tester.startGesture(baslangic);
      await tester.pump();
      for (var adim = 1; adim <= 10; adim++) {
        await hareket.moveTo(
          Offset(
            baslangic.dx,
            baslangic.dy + (hedef.dy + 40 - baslangic.dy) * adim / 10,
          ),
        );
        await tester.pump();
      }
      await hareket.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text(m.anasayfa_ayar_kaydet));
      await tester.pumpAndSettle();
      expect(anahtarlar(gonderilenler(tasima)), [
        'stats',
        'goal',
        'upcoming',
        'garage',
      ]);
    });

    testWidgets('ayar isteyen bileşen açılırken önce ayarı soruluyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = duzenTasimasi();
      await duzeniAc(tester, tasima);

      await tester.tap(satirdaki(m.anasayfa_goal_ad, find.byType(Switch)));
      await tester.pumpAndSettle();
      // Ayar sayfası: hedef ve metrik seçilmeden Kaydet kapalı.
      expect(find.text(m.anasayfa_goal_hedef_alani), findsOneWidget);
      await tester.enterText(find.byType(TextField), '250');
      await tester.tap(find.text(m.istatistik_metrik_events));
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.anasayfa_ayar_kaydet));
      await tester.pumpAndSettle();

      // Düzen ekranına dönüldü; bileşen açık ve ayarlı.
      expect(find.text(m.anasayfa_goal_aciklama), findsOneWidget);
      await tester.tap(find.text(m.anasayfa_ayar_kaydet));
      await tester.pumpAndSettle();
      expect(gonderilenler(tasima)[2], {
        'key': 'goal',
        'enabled': true,
        'config': {
          'goal': {'metric_key': 'events', 'target': 250.0},
        },
      });
    });

    testWidgets('ayar sayfasından vazgeçince bileşen kapalı kalıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await duzeniAc(tester, duzenTasimasi());

      await tester.tap(satirdaki(m.anasayfa_goal_ad, find.byType(Switch)));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text(m.anasayfa_goal_hedef_alani)))
          .pop();
      await tester.pumpAndSettle();

      final anahtar = tester.widget<Switch>(
        satirdaki(m.anasayfa_goal_ad, find.byType(Switch)),
      );
      expect(anahtar.value, isFalse);
    });

    testWidgets('kaydetme hatası gösteriliyor, taslak kalıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = duzenTasimasi();
      tasima.yanitlar['PUT $_duzenYolu'] = (_) =>
          const ApiProblem(type: ProblemType.permissionDenied, status: 403);
      await duzeniAc(tester, tasima);

      await tester.tap(
        find.byTooltip(m.anasayfa_asagi(m.anasayfa_bolum_upcoming)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(m.anasayfa_ayar_kaydet));
      await tester.pumpAndSettle();

      expect(find.text(m.hata_permission_denied), findsOneWidget);
      final kaydet = tester.widget<TextButton>(
        find.widgetWithText(TextButton, m.anasayfa_ayar_kaydet),
      );
      expect(kaydet.onPressed, isNotNull);
    });

    testWidgets('yönetici olmayan değiştiremiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await duzeniAc(tester, duzenTasimasi(rol: 'moderator'));

      expect(find.text(m.anasayfa_duzen_yalnizca_yonetici), findsOneWidget);
      expect(find.text(m.anasayfa_ayar_kaydet), findsNothing);
      expect(
        find.byTooltip(m.anasayfa_asagi(m.anasayfa_bolum_upcoming)),
        findsNothing,
      );
      for (final s in tester.widgetList<Switch>(find.byType(Switch))) {
        expect(s.onChanged, isNull);
      }
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 4000);
        ikiKatYazi(tester);
        await duzeniAc(tester, duzenTasimasi(), themeMode: mod);

        expect(tester.takeException(), isNull);
        expect(
          find.textContaining(m.anasayfa_guncelle_etiketi),
          findsOneWidget,
        );
      });
    }
  });

  group('tayfa ayarlarındaki giriş', () {
    const giris = YonetimEkGirisi(
      ikon: anaSayfaGirisIkonu,
      etiket: anaSayfaGirisEtiketi,
      adres: anaSayfaDuzeniAdresi,
      yalnizcaYonetici: true,
    );

    for (final (rol, gorunur) in [('admin', true), ('moderator', false)]) {
      testWidgets('$rol: ${gorunur ? 'görünüyor' : 'görünmüyor'}', (
        tester,
      ) async {
        ekranBoyutu(tester, yukseklik: 2000);
        await widgetAc(
          tester,
          const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
          tayfa: yonetimOverridelari(yonetimTasimasi(rol: rol)),
          overrides: [
            yonetimEkGirisleriProvider.overrideWithValue(const [giris]),
          ],
        );

        expect(
          find.text(m.anasayfa_duzen_baslik),
          gorunur ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
