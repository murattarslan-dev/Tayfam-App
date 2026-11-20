import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/metin/sure.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/istatistik/data/istatistik_deposu.dart';
import 'package:tayfam/features/istatistik/istatistik.dart';
import 'package:tayfam/features/istatistik/presentation/istatistik_metinleri.dart';
import 'package:tayfam/features/istatistik/presentation/tayfa_istatistik_ekrani.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/katalog/sahte_katalog.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

const String _tayfaId = '7b6a5c4d-3e2f-4a1b-8c0d-9e8f7a6b5c4d';
const String _uyeId = '00000000-0000-4000-8000-0000000000b1';
const String _istatistikYolu = '/v1/tayfas/{tayfa_id}/stats';

Map<String, Object?> _statJson(
  String anahtar,
  num deger, {
  String kaynak = 'common',
  int etkinlik = 4,
}) => {
  'metric_key': anahtar,
  'source': kaynak,
  'value': deger,
  'event_count': etkinlik,
};

TayfaStat _stat(
  String anahtar,
  num deger, {
  String kaynak = 'common',
  int etkinlik = 4,
}) => TayfaStat.fromJson(
  _statJson(anahtar, deger, kaynak: kaynak, etkinlik: etkinlik),
);

/// `TayfaStats` JSON'u: dolu toplamlar ve bir üyenin katkıları.
Map<String, Object?> _istatistiklerJson({int? yil, bool bos = false}) => {
  'year': ?yil,
  'years': [2026, 2025],
  'totals': bos
      ? const <Object?>[]
      : [
          _statJson('events', 12, etkinlik: 12),
          _statJson('attended', 87),
          _statJson('duration', 1530),
          _statJson('hike.distance', 42.5, kaynak: 'measure'),
          _statJson('fishing.catches.sum_weight', 3.2, kaynak: 'log'),
          _statJson('olmayan_tur.distance', 1, kaynak: 'measure'),
        ],
  'contributions': bos
      ? const <Object?>[]
      : [
          {
            'user_id': _uyeId,
            'metric_key': 'hike.distance',
            'value': 12.5,
            'event_count': 2,
          },
        ],
};

List<Override> _overridelar(SahteTayfaTasima tasima) => [
  istatistikDeposuProvider.overrideWithValue(IstatistikDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => const KullaniciAdi('Ayşe'),
  ),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];

Future<void> _ekraniAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  const TayfaIstatistikEkrani(tayfaId: _tayfaId),
  themeMode: themeMode,
  tayfa: tayfaOverridelari(),
  overrides: _overridelar(tasima),
);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));
  final katalog = testKatalogu();

  group('metrik metni', () {
    MetrikGorunumu? g(String anahtar, num deger, {String kaynak = 'common'}) =>
        metrikGorunumu(m, _stat(anahtar, deger, kaynak: kaynak), katalog, 'tr');

    test('ortak metrikler çeviriden, sayılar Türkçe biçimle', () {
      expect(g('events', 1250)?.ad, m.istatistik_metrik_events);
      expect(g('events', 1250)?.deger, '1.250');
      expect(g('attended', 87)?.ad, m.istatistik_metrik_attended);
      expect(g('participants', 30)?.ad, m.istatistik_metrik_participants);
    });

    test('süre dakikadır; sureMetni ile yazılır, okunuşu ayrı', () {
      final sure = g('duration', 90)!;
      expect(sure.ad, m.istatistik_metrik_duration);
      expect(sure.deger, sureMetni(m, 5400));
      expect(sure.deger, '1:30:00');
      expect(sure.okunus, sureOkunusu(m, 5400));
    });

    test('türün ortak metriği tür adıyla', () {
      expect(
        g('hike.attended', 5)?.ad,
        m.istatistik_metrik_turlu(
          'Doğa yürüyüşü',
          m.istatistik_metrik_attended,
        ),
      );
    });

    test('ölçüm: katalogdaki ad ve birim', () {
      final olcum = g('hike.distance', 12.5, kaynak: 'measure')!;
      expect(olcum.ad, m.istatistik_metrik_turlu('Doğa yürüyüşü', 'Mesafe'));
      expect(olcum.deger, m.katalog_birimli_deger('12,5', m.katalog_birim_km));
      // Türün ortak metriğiyle aynı adlı ölçümü kaynak ayırır.
      expect(
        g('running.duration', 45, kaynak: 'measure')?.ad,
        m.istatistik_metrik_turlu('Koşu', 'Süre'),
      );
    });

    test('günlük: kayıt sayısı, çeşit ve toplam', () {
      expect(
        g('fishing.catches.count', 7, kaynak: 'log')?.ad,
        m.istatistik_metrik_turlu(
          'Balıkçılık',
          m.istatistik_gunluk_kayit('Av günlüğü'),
        ),
      );
      expect(
        g('fishing.catches.distinct_species', 3, kaynak: 'log')?.ad,
        m.istatistik_metrik_turlu(
          'Balıkçılık',
          m.istatistik_gunluk_farkli('Av günlüğü', 'Tür'),
        ),
      );
      final toplam = g('fishing.catches.sum_weight', 3.2, kaynak: 'log')!;
      expect(
        toplam.ad,
        m.istatistik_metrik_turlu(
          'Balıkçılık',
          m.istatistik_gunluk_toplam('Av günlüğü', 'Ağırlık'),
        ),
      );
      expect(toplam.deger, m.katalog_birimli_deger('3,2', m.katalog_birim_kg));
    });

    test('tanınmayan metrik gösterilmez', () {
      for (final (anahtar, kaynak) in [
        ('bilinmeyen', 'common'),
        ('olmayan_tur.distance', 'measure'),
        ('hike.olmayan', 'measure'),
        ('hike.distance.fazla', 'measure'),
        ('fishing.catches.median_weight', 'log'),
        ('fishing.catches.sum_olmayan', 'log'),
        ('fishing.olmayan.count', 'log'),
        ('events', 'gelecek_kaynak'),
      ]) {
        expect(g(anahtar, 1, kaynak: kaynak), isNull, reason: anahtar);
      }
      expect(
        metrikGorunumu(
          m,
          _stat('hike.distance', 1, kaynak: 'measure'),
          null,
          'tr',
        ),
        isNull,
      );
    });

    test('events satırında etkinlik sayısı ayrıca yazılmaz', () {
      expect(etkinlikSayisiYazilir(_stat('events', 3)), isFalse);
      expect(etkinlikSayisiYazilir(_stat('hike.events', 3)), isFalse);
      expect(etkinlikSayisiYazilir(_stat('attended', 3)), isTrue);
    });
  });

  group('tayfa istatistikleri ekranı', () {
    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} tema, 2× yazı, 320 dp: taşmaz', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ekraniAc(
          tester,
          SahteTayfaTasima({
            'GET $_istatistikYolu': (_) => _istatistiklerJson(),
          }),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.istatistik_toplamlar), findsOneWidget);
        expect(find.text(m.istatistik_tum_zamanlar), findsOneWidget);
        expect(find.text('2026'), findsOneWidget);
        expect(find.text('2025'), findsOneWidget);
        expect(find.text(m.istatistik_metrik_events), findsOneWidget);
        expect(find.text(sureMetni(m, 91800)), findsOneWidget);
        // Katalogda olmayan tür satırı gösterilmez.
        expect(find.textContaining('olmayan_tur'), findsNothing);
        final katki = find.text(m.istatistik_katkilar);
        await tester.scrollUntilVisible(
          katki,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(katki, findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Ayşe'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('yıl seçilince o yılın istatistiği istenir', (tester) async {
      ekranBoyutu(tester);
      final tasima = SahteTayfaTasima({
        'GET $_istatistikYolu': (i) =>
            _istatistiklerJson(yil: int.tryParse(i.sorgu['year'] ?? '')),
      });
      await _ekraniAc(tester, tasima);
      expect(tasima.giden('GET', _istatistikYolu).single.sorgu, isEmpty);
      await tester.tap(find.text('2025'));
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', _istatistikYolu).last.sorgu, {'year': '2025'});
      final cip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '2025'),
      );
      expect(cip.selected, isTrue);
    });

    testWidgets('istatistik yoksa sakin not', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(
        tester,
        SahteTayfaTasima({
          'GET $_istatistikYolu': (_) => _istatistiklerJson(bos: true),
        }),
      );
      expect(find.text(m.istatistik_bos), findsOneWidget);
      expect(find.text(m.istatistik_katkilar), findsNothing);
    });
  });

  group('profil bölümü', () {
    Future<void> ac(WidgetTester tester, Widget bolum, {ThemeMode? mod}) =>
        widgetAc(
          tester,
          Scaffold(body: ListView(children: [bolum])),
          themeMode: mod ?? ThemeMode.light,
        );

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name}: istatistikler ve not, 2× yazı, 320 dp', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await ac(
          tester,
          IstatistikBolumu(
            statlar: [
              _stat('attended', 14),
              _stat('hike.distance', 42.5, kaynak: 'measure'),
            ],
            not: m.istatistik_profil_notu,
          ),
          mod: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.istatistik_baslik), findsOneWidget);
        expect(find.text('14'), findsOneWidget);
        expect(find.text(m.istatistik_profil_notu), findsOneWidget);
      });
    }

    testWidgets('ekran okuyucu satırı tek öğe, süreyi sözle okur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final anlam = tester.ensureSemantics();
      await ac(tester, IstatistikBolumu(statlar: [_stat('duration', 1530)]));
      final etiket = tester.getSemantics(find.byType(IstatistikSatiri)).label;
      expect(etiket, contains(m.istatistik_metrik_duration));
      expect(etiket, contains(sureOkunusu(m, 91800)));
      expect(etiket, isNot(contains(sureMetni(m, 91800))));
      expect(etiket, contains(m.istatistik_etkinlik_sayisi(4)));
      anlam.dispose();
    });

    testWidgets('boş liste: kendi profilinde sakin not, yoksa bölüm yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await ac(
        tester,
        IstatistikBolumu(
          statlar: const [],
          bosMetin: m.istatistik_profil_bos_kendi,
        ),
      );
      expect(find.text(m.istatistik_profil_bos_kendi), findsOneWidget);
      await ac(tester, const IstatistikBolumu(statlar: []));
      expect(find.text(m.istatistik_baslik), findsNothing);
    });
  });

  group('Keşfet vitrini', () {
    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name}: toplamlar ve rozetler, 2× yazı, 320 dp', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await widgetAc(
          tester,
          Scaffold(
            body: ListView(
              children: [
                VitrinIstatistikleri(
                  vitrin: TayfaShowcase.fromJson({
                    'stats': [
                      _statJson('events', 18, etkinlik: 18),
                      _statJson('hike.distance', 120, kaynak: 'measure'),
                    ],
                    'badges': [
                      {
                        'badge_key': 'ilk_adim',
                        'earned_at': '2026-11-01T10:00:00Z',
                      },
                    ],
                  }),
                ),
              ],
            ),
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(m.istatistik_vitrin_baslik), findsOneWidget);
        expect(find.text('18'), findsOneWidget);
        expect(find.text('İlk adım'), findsOneWidget);
      });
    }

    testWidgets('boş vitrin yer kaplamaz', (tester) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        Scaffold(
          body: VitrinIstatistikleri(
            vitrin: TayfaShowcase.fromJson({
              'stats': const <Object?>[],
              'badges': const <Object?>[],
            }),
          ),
        ),
      );
      expect(find.text(m.istatistik_vitrin_baslik), findsNothing);
    });
  });
}
