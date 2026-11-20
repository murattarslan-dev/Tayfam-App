import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_ortak.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../core/realtime/sahte_soket.dart';
import '../../../core/zaman_sahteleri.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  TakimBileseni(),
  YazbozBileseni(),
];

const String _masa = '01970000-0000-7000-8000-000000000301';
const String _yer1 = '01970000-0000-7000-8000-000000000311';
const String _yer2 = '01970000-0000-7000-8000-000000000312';
const String _yer3 = '01970000-0000-7000-8000-000000000313';
const String _takim1 = '01970000-0000-7000-8000-000000000201';
const String _takim2 = '01970000-0000-7000-8000-000000000202';
const String _ucuncuId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';

const YazbozKimligi _kimlik = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
  anahtar: 'scoreboard',
);

List<Map<String, Object?>> _onAyarlar() => [
  yazbozOnAyariJson(
    'batak',
    'Batak',
    enAz: 3,
    enCok: 4,
    kurallar: {'side': 'player', 'rounds': 'round', 'winner': 'high'},
  ),
  yazbozOnAyariJson(
    'okey_101',
    '101 Okey',
    enAz: 2,
    enCok: 4,
    kurallar: {'side': 'player', 'rounds': 'round', 'winner': 'low'},
  ),
];

List<Map<String, Object?>> _ucYer() => [
  yazbozYeriJson(_yer1, 1, kisi: katilimciId),
  yazbozYeriJson(_yer2, 2, kisi: organizatorId),
  yazbozYeriJson(_yer3, 3, kisi: _ucuncuId),
];

Map<String, Object?> _sira(String yer, int sira, num toplam, [int el = 0]) => {
  'player_id': yer,
  'total': toplam,
  'rounds_won': el,
  'rank': sira,
};

Map<String, Object?> _el(int no, Map<String, int> puanlar) => {
  'number': no,
  'scores': [
    for (final MapEntry(key: yer, value: puan) in puanlar.entries)
      {'player_id': yer, 'points': puan},
  ],
};

/// Biten Batak masası: ilk iki yer berabere (iki kazanan), üçüncü geride.
Map<String, Object?> _bitenMasa({bool skorGirebilir = false}) =>
    yazbozMasasiJson(
      id: _masa,
      onAyar: 'batak',
      bitti: true,
      yerler: _ucYer(),
      eller: [
        _el(1, {_yer1: 70, _yer2: 50, _yer3: 30}),
        _el(2, {_yer1: 50, _yer2: 70, _yer3: 50}),
      ],
      siralama: [
        _sira(_yer1, 1, 120),
        _sira(_yer2, 1, 120),
        _sira(_yer3, 3, 80),
      ],
      kazananlar: [_yer1, _yer2],
      skorGirebilir: skorGirebilir,
    );

/// Masa oyunu gecesi (katalog fikstüründe masalı yazboz var). [yazboz]
/// yazbozun yanıtıdır; kendi kimliği [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti yazboz,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = katilimciId,
  String tur = 'board_game_night',
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(tur: tur, cevap: 'going'),
    'GET $yazbozYolu': yazboz,
    'GET $katilimcilarYolu': (_) =>
        katilimcilarJson([katilimciId, organizatorId, _ucuncuId]),
    ...yanitlar,
  });
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, bilesenler: _kayit),
  );
  yonlendiriciyiAl(tester).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
  await tester.pumpAndSettle();
}

Future<void> _gorunurYap(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(YazbozBolumu), matching: bulucu);

Finder _pencerede(Finder bulucu) =>
    find.descendant(of: find.byType(AlertDialog), matching: bulucu);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe yazbozu kullanan türler var', () {
    final masali = turBilesenleri(testTuru('board_game_night'))
        .where((b) => b.kind == 'scoreboard')
        .toList();
    expect(masali, hasLength(1));
    expect(bilesenAnahtari(masali.single), 'scoreboard');
    expect(
      turBilesenleri(testTuru('team_sport')).map((b) => b.kind),
      containsAll(<String>['teams', 'scoreboard']),
    );
  });

  group('yardımcılar', () {
    test('puan isteği: boş yer gitmez, hatalı değer işaretlenir', () {
      final sira = [_yer1, _yer2, _yer3];
      final iyi = yazbozPuanIstegi(sira, {_yer1: ' 120 ', _yer2: '-15'});
      expect(iyi.hatali, isEmpty);
      expect(iyi.istek?.scores.map((s) => (s.playerId, s.points)), [
        (_yer1, 120),
        (_yer2, -15),
      ]);
      final kotu = yazbozPuanIstegi(sira, {_yer1: '1000001', _yer2: '1-2'});
      expect(kotu.istek, isNull);
      expect(kotu.hatali, {_yer1, _yer2});
      final bos = yazbozPuanIstegi(sira, {_yer1: ''});
      expect(bos.istek, isNull);
      expect(bos.hatali, isEmpty);
    });

    test('sonuç isteği: seçilmeyen yer gitmez', () {
      final sonuc = yazbozSonucIstegi(
        [_yer1, _yer2],
        {_yer2: EventScoreEntryOutcome.win},
      );
      expect(sonuc.istek?.scores.single.playerId, _yer2);
      expect(sonuc.istek?.scores.single.outcome, EventScoreEntryOutcome.win);
      expect(yazbozSonucIstegi([_yer1], const {}).istek, isNull);
    });

    test('sıralama: sıra, sonra yer; kazanan yalnızca biten masada', () {
      final biten = EventScoreTable.fromJson(_bitenMasa());
      final satirlar = yazbozSiralamasi(biten);
      expect(satirlar.map((s) => s.yer?.id), [_yer1, _yer2, _yer3]);
      expect(satirlar.map((s) => s.kazanan), [true, true, false]);
      final acik = EventScoreTable.fromJson({
        ..._bitenMasa(),
        'status': 'open',
      });
      expect(yazbozSiralamasi(acik).where((s) => s.kazanan), isEmpty);
      expect(yazbozSonEl(biten)?.number, 2);
    });

    test('kurallar yazıyla özetlenir', () {
      const kural = EventScoreRules(
        rounds: EventScoreRulesRounds.single,
        winner: EventScoreRulesWinner.first,
        result: EventScoreRulesResult.wdl,
        target: 151,
        bestOf: 3,
      );
      expect(yazbozKuralOzeti(m, kural), [
        m.bilesen_scoreboard_kural_single,
        m.bilesen_scoreboard_kural_first,
        m.bilesen_scoreboard_kural_hedef('151'),
        m.bilesen_scoreboard_kural_bo(3),
        m.bilesen_scoreboard_kural_wdl,
      ]);
      expect(yazbozSayisi(m, 2.5), '2,5');
    });
  });

  group('yazboz bölümü', () {
    for (final tema in _temalar) {
      testWidgets('üye biten masayı okur: sıralama, iki kazanan, "Sen", '
          'eller (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          yazboz: (_) =>
              yazbozJson(masalar: [_bitenMasa()], onAyarlar: _onAyarlar()),
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final ucuncu = _bolumde(find.text(m.bilesen_scoreboard_puan('80')));
        await _gorunurYap(tester, ucuncu);
        expect(ucuncu, findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_puan('120'))),
          findsNWidgets(2),
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_scoreboard_kazanan)),
          findsNWidgets(2),
        );
        expect(_bolumde(find.text(m.bilesen_scoreboard_sen)), findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_scoreboard_durum_finished)),
          findsOneWidget,
        );
        expect(_bolumde(find.textContaining('Batak')), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_sira(1))),
          findsNWidgets(2),
        );
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_sira(3))),
          findsOneWidget,
        );
        // Satır ekran okuyucuda tek öğe: sıra, ad ve toplam birlikte.
        expect(
          find.bySemanticsLabel(RegExp(r'3\.[\s\S]*80 puan')),
          findsOneWidget,
        );
        // Üye masayı yönetmez, el girmez.
        expect(
          find.byTooltip(m.bilesen_scoreboard_islemler('Masa 1')),
          findsNothing,
        );
        expect(_bolumde(find.text(m.bilesen_scoreboard_el_gir)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_scoreboard_masa_ac)), findsNothing);

        await _dokun(
          tester,
          _bolumde(find.text(m.bilesen_scoreboard_elleri_goster(2))),
        );
        expect(_bolumde(find.text(m.bilesen_scoreboard_el(1))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_scoreboard_el(2))), findsOneWidget);
        expect(tasima.giden('GET', yazbozYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'scoreboard',
        });
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    for (final tema in _temalar) {
      testWidgets('hakem el girer; tablo yanıtla yenilenir '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final yerler = [
          yazbozYeriJson(_yer1, 1, kisi: katilimciId),
          yazbozYeriJson(_yer2, 2, kisi: organizatorId),
        ];
        final tasima = _tasima(
          yazboz: (_) => yazbozJson(
            onAyarlar: _onAyarlar(),
            masalar: [
              yazbozMasasiJson(
                id: _masa,
                onAyar: 'okey_101',
                yerler: yerler,
                siralama: [_sira(_yer1, 1, 0), _sira(_yer2, 1, 0)],
                skorGirebilir: true,
              ),
            ],
          ),
          yanitlar: {
            'POST $yazbozElleriYolu': (_) => yazbozJson(
              onAyarlar: _onAyarlar(),
              masalar: [
                yazbozMasasiJson(
                  id: _masa,
                  onAyar: 'okey_101',
                  yerler: yerler,
                  eller: [
                    _el(1, {_yer1: 45, _yer2: -101}),
                  ],
                  siralama: [_sira(_yer2, 1, -101), _sira(_yer1, 2, 45)],
                  skorGirebilir: true,
                ),
              ],
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final gir = _bolumde(find.text(m.bilesen_scoreboard_el_gir));
        await _gorunurYap(tester, gir);
        await _dokun(tester, gir);
        expect(find.byType(YazbozElFormu), findsOneWidget);
        expect(find.text(m.bilesen_scoreboard_el_baslik(1)), findsOneWidget);

        // Boş form gitmez.
        final kaydet = find.descendant(
          of: find.byType(YazbozElFormu),
          matching: find.text(m.etkinlik_kaydet),
        );
        await _dokun(tester, kaydet);
        expect(find.text(m.bilesen_scoreboard_puan_yok), findsOneWidget);
        expect(tasima.giden('POST', yazbozElleriYolu), isEmpty);

        await tester.enterText(
          find.byKey(const ValueKey('yazboz-puan-$_yer1')),
          '45',
        );
        await tester.enterText(
          find.byKey(const ValueKey('yazboz-puan-$_yer2')),
          '-101',
        );
        await tester.pumpAndSettle();
        await _dokun(tester, kaydet);
        final giden = tasima.giden('POST', yazbozElleriYolu).single;
        expect(giden.yolParametreleri['table_id'], _masa);
        expect(giden.govde, {
          'scores': [
            {'player_id': _yer1, 'points': 45},
            {'player_id': _yer2, 'points': -101},
          ],
        });
        expect(find.byType(YazbozElFormu), findsNothing);
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_puan('-101'))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_sira(2))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('organizatör ön ayarla masa açar; oyuncu sayısı denetlenir '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          ben: organizatorId,
          yazboz: (_) => yazbozJson(onAyarlar: _onAyarlar(), yonetebilir: true),
          yanitlar: {
            'POST $yazbozMasalariYolu': (_) => yazbozJson(
              onAyarlar: _onAyarlar(),
              yonetebilir: true,
              masalar: [
                yazbozMasasiJson(
                  id: _masa,
                  onAyar: 'okey_101',
                  yerler: [
                    yazbozYeriJson(_yer1, 1, kisi: katilimciId),
                    yazbozYeriJson(_yer2, 2, kisi: organizatorId),
                  ],
                  siralama: [_sira(_yer1, 1, 0), _sira(_yer2, 1, 0)],
                ),
              ],
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final bos = _bolumde(find.text(m.bilesen_scoreboard_yok));
        await _gorunurYap(tester, bos);
        expect(bos, findsOneWidget);
        await _dokun(tester, _bolumde(find.text(m.bilesen_scoreboard_masa_ac)));
        expect(find.byType(YazbozMasaFormu), findsOneWidget);
        Finder formda(Finder f) =>
            find.descendant(of: find.byType(YazbozMasaFormu), matching: f);

        await _dokun(
          tester,
          find.byKey(const ValueKey('yazboz-kisi-$katilimciId')),
        );
        await _dokun(
          tester,
          find.byKey(const ValueKey('yazboz-kisi-$organizatorId')),
        );
        expect(
          formda(find.text(m.bilesen_scoreboard_yer_no(2))),
          findsOneWidget,
        );

        // Batak üç-dört kişiyle oynanır: iki kişiyle istek gitmez.
        await _dokun(tester, formda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('POST', yazbozMasalariYolu), isEmpty);
        expect(
          formda(find.text(m.bilesen_scoreboard_yer_siniri(3, 4))),
          findsNWidgets(2),
        );

        await _dokun(tester, formda(find.text('101 Okey')));
        await _dokun(tester, formda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('POST', yazbozMasalariYolu).single.govde, {
          'label': m.bilesen_scoreboard_ad_varsayilan(1),
          'preset_key': 'okey_101',
          'players': [
            {'user_id': katilimciId},
            {'user_id': organizatorId},
          ],
        });
        expect(find.byType(YazbozMasaFormu), findsNothing);
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_durum_open)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('takım masası takım kurma bileşeninin takımlarıyla açılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      const kurallar = {
        'side': 'team',
        'rounds': 'single',
        'winner': 'high',
        'result': 'points',
      };
      final tasima = _tasima(
        ben: organizatorId,
        tur: 'team_sport',
        yazboz: (_) => yazbozJson(kurallar: kurallar, yonetebilir: true),
        yanitlar: {
          'GET $takimYolu': (_) => takimlarJson(
            mod: 'balanced',
            takimlar: [
              takimJson(id: _takim1, sira: 1, uyeler: [katilimciId]),
              takimJson(id: _takim2, sira: 2, ad: 'Kartallar'),
            ],
          ),
          'POST $yazbozMasalariYolu': (_) => yazbozJson(
            kurallar: kurallar,
            yonetebilir: true,
            masalar: [
              yazbozMasasiJson(
                id: _masa,
                kurallar: kurallar,
                takimAnahtari: 'teams',
                yerler: [
                  yazbozYeriJson(_yer1, 1, takim: _takim2),
                  yazbozYeriJson(_yer2, 2, takim: _takim1),
                ],
                siralama: [_sira(_yer1, 1, 0), _sira(_yer2, 1, 0)],
              ),
            ],
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final ac = _bolumde(find.text(m.bilesen_scoreboard_masa_ac));
      await _gorunurYap(tester, ac);
      await _dokun(tester, ac);
      await _dokun(tester, find.byKey(const ValueKey('yazboz-takim-$_takim2')));
      await _dokun(tester, find.byKey(const ValueKey('yazboz-takim-$_takim1')));
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(YazbozMasaFormu),
          matching: find.text(m.etkinlik_kaydet),
        ),
      );
      expect(tasima.giden('POST', yazbozMasalariYolu).single.govde, {
        'label': m.bilesen_scoreboard_ad_varsayilan(1),
        'teams_key': 'teams',
        'players': [
          {'team_id': _takim2},
          {'team_id': _takim1},
        ],
      });
      expect(_bolumde(find.text('Kartallar')), findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_teams_takim_no(1))), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('organizatör son eli siler ve masayı yeniden açar', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        yazboz: (_) => yazbozJson(
          masalar: [_bitenMasa()],
          onAyarlar: _onAyarlar(),
          yonetebilir: true,
        ),
        yanitlar: {
          'DELETE $yazbozEliYolu': (_) => yazbozJson(
            masalar: [_bitenMasa()],
            onAyarlar: _onAyarlar(),
            yonetebilir: true,
          ),
          'PATCH $yazbozMasasiYolu': (_) => yazbozJson(
            masalar: [
              {..._bitenMasa(), 'status': 'open', 'winner_ids': <String>[]},
            ],
            onAyarlar: _onAyarlar(),
            yonetebilir: true,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final menu = find.byTooltip(m.bilesen_scoreboard_islemler('Masa 1'));
      await _gorunurYap(tester, menu);
      await _dokun(tester, menu);
      // İlk elden sonra oyuncular değişmez.
      expect(find.text(m.bilesen_scoreboard_yerler), findsNothing);
      await _dokun(tester, find.text(m.bilesen_scoreboard_son_eli_sil).last);
      expect(
        _pencerede(find.text(m.bilesen_scoreboard_son_eli_sil_onay(2))),
        findsOneWidget,
      );
      await _dokun(tester, _pencerede(find.text(m.bilesen_scoreboard_sil)));
      final silinen = tasima.giden('DELETE', yazbozEliYolu).single;
      expect(silinen.yolParametreleri['round'], '2');
      expect(silinen.yolParametreleri['table_id'], _masa);

      await _dokun(tester, menu);
      await _dokun(tester, find.text(m.bilesen_scoreboard_yeniden_ac).last);
      expect(tasima.giden('PATCH', yazbozMasasiYolu).single.govde, {
        'status': 'open',
      });
      expect(
        _bolumde(find.text(m.bilesen_scoreboard_durum_open)),
        findsOneWidget,
      );
      expect(_bolumde(find.textContaining(m.bilesen_scoreboard_kazanan)), findsNothing);
    });

    testWidgets('organizatör masaya hakem atar', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        yazboz: (_) => yazbozJson(
          masalar: [_bitenMasa()],
          onAyarlar: _onAyarlar(),
          yonetebilir: true,
        ),
        yanitlar: {
          'POST $hakemlerYolu': (_) => {
            'id': '4b3a2918-0706-4f5e-8d4c-3b2a1908f7e9',
            'user_id': _ucuncuId,
            'component_key': 'scoreboard',
            'scope_id': _masa,
            'created_at': '2026-11-14T07:00:00Z',
          },
        },
      );
      await _detayiAc(tester, tasima);
      final menu = find.byTooltip(m.bilesen_scoreboard_islemler('Masa 1'));
      await _gorunurYap(tester, menu);
      await _dokun(tester, menu);
      await _dokun(tester, find.text(m.bilesen_scoreboard_hakemler).last);
      expect(find.byType(YazbozHakemFormu), findsOneWidget);
      expect(find.text(m.bilesen_scoreboard_hakem_yok), findsOneWidget);
      final okuma = tasima.giden('GET', hakemlerYolu).length;

      await _dokun(tester, find.byKey(const ValueKey('yazboz-hakem-secimi')));
      // Menüde katılımcılar; üçüncü kişiyi seç (adı profilden: "Mert").
      await _dokun(tester, find.text('Mert').last);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(YazbozHakemFormu),
          matching: find.text(m.bilesen_scoreboard_hakem_ata),
        ),
      );
      final giden = tasima.giden('POST', hakemlerYolu).single;
      expect(giden.govde, {
        'user_id': isA<String>(),
        'component_key': 'scoreboard',
        'scope_id': _masa,
      });
      expect(tasima.giden('GET', hakemlerYolu).length, greaterThan(okuma));
      expect(tester.takeException(), isNull);
    });

    testWidgets('etkinlik başlamadan bitirmede sunucunun hatası gösterilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        yazboz: (_) => yazbozJson(
          masalar: [
            yazbozMasasiJson(
              id: _masa,
              yerler: _ucYer(),
              siralama: [
                _sira(_yer1, 1, 0),
                _sira(_yer2, 1, 0),
                _sira(_yer3, 1, 0),
              ],
              skorGirebilir: true,
            ),
          ],
        ),
        yanitlar: {
          'POST $yazbozBitirYolu': (_) =>
              const ApiProblem(type: ProblemType.scoreNotStarted, status: 409),
        },
      );
      await _detayiAc(tester, tasima);
      final bitir = _bolumde(find.text(m.bilesen_scoreboard_bitir));
      await _gorunurYap(tester, bitir);
      await _dokun(tester, bitir);
      await _dokun(tester, _pencerede(find.text(m.bilesen_scoreboard_bitir)));
      expect(tasima.giden('POST', yazbozBitirYolu), hasLength(1));
      expect(find.text(m.hata_score_not_started), findsOneWidget);
      expect(tasima.giden('GET', yazbozYolu).length, greaterThan(1));
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        yazboz: (_) {
          if (okundu) return yazbozJson(masalar: [_bitenMasa()]);
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(m.etkinlik_tekrar_dene));
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(
        _bolumde(find.textContaining(m.bilesen_scoreboard_durum_finished)),
        findsOneWidget,
      );
    });
  });

  test('yazboz canlı değişince yeniden okunur', () async {
    final tasima = etkinlikTasimasi({
      'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'board_game_night'),
      'GET $yazbozYolu': (_) => yazbozJson(),
    });
    final zaman = SahteZamanlayici();
    final soketler = <SahteSoket>[];
    final realtime = RealtimeIstemcisi(
      adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
      baglayici: (adres, basliklar) {
        final s = SahteSoket(adres, basliklar);
        soketler.add(s);
        return s;
      },
      tokenAl: () async => 'token',
      reddedildi: (_) async => 'token',
      oturumuKapat: () async {},
      zamanlayici: zaman.kur,
      rastgele: Random(1),
      gunluk: (_) {},
    );
    final c = ProviderContainer(
      overrides: [
        etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
        realtimeIstemcisiProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(realtime.dispose);
    int okuma() => tasima.giden('GET', yazbozYolu).length;
    Future<void> bekle() async {
      await pumpEventQueue();
      await c.read(yazbozProvider(_kimlik).future);
    }

    void degisti(String anahtar) =>
        soketler.single.cerceve('event.component_changed', {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': anahtar,
        });

    const etkinlik = (tayfaId: ornekTayfaId, etkinlikId: ornekEtkinlikId);
    final detay = c.listen(etkinlikDetayProvider(etkinlik), (_, _) {});
    await c.read(etkinlikDetayProvider(etkinlik).future);
    final durum = c.listen(yazbozProvider(_kimlik), (_, _) {});
    await bekle();
    expect(okuma(), 1);

    realtime.baslat();
    await pumpEventQueue();
    await soketler.single.ac();
    await bekle();
    final once = okuma();

    // Biri el girdi: tablo yeniden okunur.
    degisti('scoreboard');
    await bekle();
    expect(okuma(), once + 1);

    // Başka bileşen yazbozu etkilemez.
    degisti('teams');
    await bekle();
    expect(okuma(), once + 1);

    durum.close();
    detay.close();
  });
}
