import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/features/rozet/presentation/rozet_bolumu.dart';
import 'package:tayfam/features/rozet/presentation/rozet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/katalog/sahte_katalog.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

EarnedBadge _rozet(String anahtar, {int? yil}) => EarnedBadge.fromJson({
  'badge_key': anahtar,
  'year': ?yil,
  'earned_at': '2026-11-01T10:00:00Z',
});

CatalogBadgeRule _kural(Map<String, Object?> json) =>
    CatalogBadgeRule.fromJson(json);

Future<void> _bolumuAc(
  WidgetTester tester,
  Widget bolum, {
  ThemeMode themeMode = ThemeMode.light,
  Override? katalog,
  bool dur = true,
}) => widgetAc(
  tester,
  Scaffold(
    body: ListView(children: [bolum]),
  ),
  themeMode: themeMode,
  tayfa: tayfaOverridelari(katalog: katalog),
  dur: dur,
);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));
  final katalog = testKatalogu();

  test('katalog rozetleri: emekliler dahil, biçimsiz anahtar atlanır', () {
    expect(katalog.rozetler.map((b) => b.key), contains('eski_rozet'));
    expect(katalog.rozet('eski_rozet')?.status, CatalogStatus.retired);
    expect(katalog.rozet('yok'), isNull);
    final json = testKataloguJson();
    final rozetler = (json['badges']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final bozuk = Katalog(
      Catalog.fromJson({
        ...json,
        'badges': [
          {...rozetler.first, 'key': 'Bozuk Anahtar'},
          rozetler.first,
          {
            ...rozetler.first,
            'labels': {'tr': 'İkinci kopya'},
          },
        ],
      }),
    );
    expect(bozuk.rozetler, hasLength(1));
    expect(bozuk.rozet('ilk_adim')?.labels['tr'], 'İlk adım');
  });

  group('kazanma kuralı metni', () {
    String? metin(Map<String, Object?> kural) =>
        rozetKuralMetni(m, _kural(kural), katalog, 'tr');

    test('ilk katılım: türsüz ve türde', () {
      expect(metin({'kind': 'first'}), m.rozet_kural_ilk);
      expect(
        metin({'kind': 'first', 'event_type': 'chess'}),
        m.rozet_kural_ilk_tur('Satranç'),
      );
    });

    test('şampiyonluk: türsüz ve türde', () {
      expect(metin({'kind': 'champion'}), m.rozet_kural_sampiyon);
      expect(
        metin({'kind': 'champion', 'event_type': 'chess'}),
        m.rozet_kural_sampiyon_tur('Satranç'),
      );
    });

    test('eşik: ortak metrik, toplamda ve yıllık', () {
      expect(
        metin({'kind': 'threshold', 'metric': 'attended', 'value': 50}),
        m.rozet_kural_esik_toplam(m.rozet_metrik_katilim, '50'),
      );
      expect(
        metin({
          'kind': 'threshold',
          'metric': 'events',
          'value': 12,
          'period': 'year',
        }),
        m.rozet_kural_esik_yillik(m.rozet_metrik_etkinlik, '12'),
      );
      expect(
        metin({
          'kind': 'threshold',
          'metric': 'participants',
          'value': 100,
          'period': 'all_time',
        }),
        m.rozet_kural_esik_toplam(m.rozet_metrik_katilimci, '100'),
      );
    });

    test('eşik: süre dakikadır, tam saat saat olarak yazılır', () {
      expect(
        metin({'kind': 'threshold', 'metric': 'duration', 'value': 600}),
        m.rozet_kural_esik_toplam(
          m.rozet_metrik_sure,
          m.katalog_birimli_deger('10', m.katalog_birim_hour),
        ),
      );
      expect(
        metin({'kind': 'threshold', 'metric': 'duration', 'value': 90}),
        m.rozet_kural_esik_toplam(
          m.rozet_metrik_sure,
          m.katalog_birimli_deger('90', m.katalog_birim_minute),
        ),
      );
    });

    test('eşik: türün ölçümü katalogdaki adı ve birimiyle', () {
      expect(
        metin({'kind': 'threshold', 'metric': 'hike.distance', 'value': 12.5}),
        m.rozet_kural_esik_toplam(
          m.rozet_metrik_turlu('Doğa yürüyüşü', 'Mesafe'),
          m.katalog_birimli_deger('12,5', m.katalog_birim_km),
        ),
      );
      expect(
        metin({'kind': 'threshold', 'metric': 'hike.attended', 'value': 5}),
        m.rozet_kural_esik_toplam(
          m.rozet_metrik_turlu('Doğa yürüyüşü', m.rozet_metrik_katilim),
          '5',
        ),
      );
    });

    test('açıklanamayan kural açıklamasız kalır', () {
      for (final kural in <Map<String, Object?>>[
        {'kind': 'streak'},
        {'kind': 'first', 'event_type': 'olmayan_tur'},
        {'kind': 'champion', 'event_type': 'olmayan_tur'},
        {'kind': 'threshold', 'metric': 'bilinmeyen', 'value': 1},
        {'kind': 'threshold', 'metric': 'olmayan_tur.distance', 'value': 1},
        {'kind': 'threshold', 'metric': 'hike.olmayan', 'value': 1},
        {'kind': 'threshold', 'metric': 'hike.distance.fazla', 'value': 1},
        {'kind': 'threshold', 'metric': 'events'},
        {'kind': 'threshold', 'metric': 'events', 'value': -1},
        {
          'kind': 'threshold',
          'metric': 'events',
          'value': 1,
          'period': 'decade',
        },
      ]) {
        expect(metin(kural), isNull, reason: '$kural');
      }
      // Katalog gelmeden türe bağlı metrik açıklanamaz.
      expect(
        rozetKuralMetni(
          m,
          _kural({'kind': 'threshold', 'metric': 'hike.distance', 'value': 1}),
          null,
          'tr',
        ),
        isNull,
      );
    });
  });

  group('rozet görünümü', () {
    test('katalogdaki rozet: ad, ikon, yıl ve kural', () {
      final g = rozetGorunumu(
        m,
        _rozet('yilin_tayfasi', yil: 2026),
        katalog,
        'tr',
      );
      expect(g.ad, 'Yılın tayfası');
      expect(g.ikon, Icons.workspace_premium);
      expect(g.yil, 2026);
      expect(g.kural, m.rozet_kural_esik_yillik(m.rozet_metrik_etkinlik, '12'));
      expect(rozetAdMetni(m, g), m.rozet_ad_yil('Yılın tayfası', '2026'));
      expect(rozetOkunusu(m, g), 'Yılın tayfası, 2026');
    });

    test('emekli rozet de adıyla gösterilir', () {
      final g = rozetGorunumu(m, _rozet('eski_rozet'), katalog, 'tr');
      expect(g.ad, 'Eski rozet');
      expect(rozetOkunusu(m, g), 'Eski rozet');
    });

    test('tanınmayan ikon ve kural: genel ikon, açıklama yok', () {
      final g = rozetGorunumu(m, _rozet('gelecek_kural'), katalog, 'tr');
      expect(g.ad, 'Gelecek kural');
      expect(g.ikon, rozetGenelIkonu);
      expect(g.kural, isNull);
    });

    test('katalogda olmayan rozet: anahtar ve genel ikon', () {
      final g = rozetGorunumu(m, _rozet('yeni_rozet'), katalog, 'tr');
      expect(g.ad, 'yeni_rozet');
      expect(g.ikon, rozetGenelIkonu);
      expect(g.kural, isNull);
      // Katalog gelmediyse de aynı.
      expect(rozetGorunumu(m, _rozet('yeni_rozet'), null, 'tr').ad, 'yeni_rozet');
    });

    test('biçimsiz anahtar ve yıl gösterilmez', () {
      final g = rozetGorunumu(m, _rozet('Bozuk Anahtar', yil: -3), null, 'tr');
      expect(g.ad, m.rozet_genel_ad);
      expect(g.yil, isNull);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} tema, 2× yazı, 320 dp', () {
      testWidgets('rozetler ad, yıl ve kuralla; taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        await _bolumuAc(
          tester,
          RozetBolumu(
            rozetler: [
              _rozet('ilk_adim'),
              _rozet('yilin_tayfasi', yil: 2026),
              _rozet('yeni_rozet'),
            ],
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.rozet_baslik), findsOneWidget);
        expect(find.text('İlk adım'), findsOneWidget);
        expect(find.text(m.rozet_kural_ilk), findsOneWidget);
        expect(find.text(m.rozet_ad_yil('Yılın tayfası', '2026')), findsOneWidget);
        expect(find.text('yeni_rozet'), findsOneWidget);
        // Ekran okuyucu "ad, yıl" ve ardından kuralı okur.
        expect(
          find.bySemanticsLabel(RegExp('^Yılın tayfası, 2026')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(RegExp('^yeni_rozet')), findsOneWidget);
        anlam.dispose();
      });

      testWidgets('boşken not; not yoksa bölüm çizilmez', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _bolumuAc(
          tester,
          RozetBolumu(
            rozetler: const [],
            bosMetin: m.rozet_bos_kendi,
            not: m.rozet_gorunurluk_notu,
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.rozet_baslik), findsOneWidget);
        expect(find.text(m.rozet_bos_kendi), findsOneWidget);
        expect(find.text(m.rozet_gorunurluk_notu), findsOneWidget);
      });
    });
  }

  testWidgets('rozet yoksa ve boş notu verilmediyse bölüm yok', (tester) async {
    ekranBoyutu(tester);
    await _bolumuAc(tester, const RozetBolumu(rozetler: []));
    expect(find.text(m.rozet_baslik), findsNothing);
  });

  testWidgets('katalog gelene kadar rozetler çizilmez', (tester) async {
    ekranBoyutu(tester);
    await _bolumuAc(
      tester,
      RozetBolumu(rozetler: [_rozet('ilk_adim')]),
      katalog: katalogDurumuOverride(const AsyncLoading<Katalog?>()),
      dur: false,
    );
    await tester.pump();
    expect(find.text(m.rozet_baslik), findsOneWidget);
    expect(find.text('İlk adım'), findsNothing);
  });
}
