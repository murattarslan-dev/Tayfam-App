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
const String _yer4 = '01970000-0000-7000-8000-000000000314';
const String _takim1 = '01970000-0000-7000-8000-000000000201';
const String _takim2 = '01970000-0000-7000-8000-000000000202';
const String _ucuncuId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';
const String _dorduncuId = '8a7f6e5d-4c3b-4a2f-9e1d-0c9b8a7f6e5d';

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

/// Eşli oyun kuralları (Tayfam-Api ADR-0044): 4 yer, el el, yüksek kazanır.
const Map<String, Object?> _esliKural = {
  'side': 'pair',
  'rounds': 'round',
  'winner': 'high',
  'result': 'points',
};

/// Bireysel ve eşli Batak (katalogdan adıyla gelir).
List<Map<String, Object?>> _esliOnAyarlar() => [
  yazbozOnAyariJson(
    'batak',
    'Batak',
    enAz: 3,
    enCok: 4,
    kurallar: {'side': 'player', 'rounds': 'round', 'winner': 'high'},
  ),
  yazbozOnAyariJson(
    'pair_batak',
    'Batak (eşli)',
    enAz: 4,
    enCok: 4,
    kurallar: _esliKural,
  ),
];

/// Eşli masanın yerleri seçim sırasıyla: Ayşe, Mert, Mehmet, Deniz; eş 1
/// Ayşe & Mehmet (koltuk 1 ve 3), eş 2 Mert & Deniz (koltuk 2 ve 4).
/// [esli] `false` ise sunucu `pair` alanını göndermez (eş koltuktan
/// türetilir).
List<Map<String, Object?>> _esliYerler({bool esli = true}) => [
  for (final (i, (yer, kisi)) in const [
    (_yer1, organizatorId),
    (_yer2, katilimciId),
    (_yer3, _ucuncuId),
    (_yer4, _dorduncuId),
  ].indexed)
    {...yazbozYeriJson(yer, i + 1, kisi: kisi), if (esli) 'pair': i % 2 + 1},
];

/// Organizatör "Ayşe", katılımcı "Mert", üçüncü "Mehmet", dördüncü "Deniz".
Map<String, Object?> _esliProfil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  final ad = switch (id) {
    organizatorId => 'Ayşe',
    katilimciId => 'Mert',
    _ucuncuId => 'Mehmet',
    _ => 'Deniz',
  };
  return profilJson(id, ad, ben: id == ben);
}

/// Biten eşli Batak: eş 1 (Ayşe & Mehmet) 150 ile kazandı, eş 2 (Mert &
/// Deniz) 90. Sunucu skoru ve sıralamayı yer başına, eşin iki koltuğunda
/// aynı değerle verir.
Map<String, Object?> _bitenEsliMasa({bool esli = true}) => yazbozMasasiJson(
  id: _masa,
  onAyar: 'pair_batak',
  kurallar: _esliKural,
  bitti: true,
  yerler: _esliYerler(esli: esli),
  eller: [
    _el(1, {_yer1: 80, _yer3: 80, _yer2: 40, _yer4: 40}),
    _el(2, {_yer1: 70, _yer3: 70, _yer2: 50, _yer4: 50}),
  ],
  siralama: [
    _sira(_yer1, 1, 150),
    _sira(_yer3, 1, 150),
    _sira(_yer2, 2, 90),
    _sira(_yer4, 2, 90),
  ],
  kazananlar: [_yer1, _yer3],
);

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

  group('eşli kip yardımcıları', () {
    test('eşler seçim sırasından: 1–3 ve 2–4', () {
      expect([1, 2, 3, 4].map(yazbozEsNo), [1, 2, 1, 2]);
      expect(yazbozEsKoltuklari(1), (1, 3));
      expect(yazbozEsKoltuklari(2), (2, 4));
      expect(yazbozEsliYer, 4);
      expect(yazbozEsliSayiUygun(0), isTrue);
      expect(yazbozEsliSayiUygun(4), isTrue);
      expect(yazbozEsliSayiUygun(3), isFalse);
      expect(yazbozEsliSayiUygun(5), isFalse);
      expect(
        yazbozEsli(const EventScoreRules(side: EventScoreRulesSide.pair)),
        isTrue,
      );
      expect(
        yazbozEsli(const EventScoreRules(side: EventScoreRulesSide.player)),
        isFalse,
      );
    });

    test('masanın eşleri: sunucunun pair alanından, yoksa koltuktan', () {
      for (final esli in [true, false]) {
        final masa = EventScoreTable.fromJson(_bitenEsliMasa(esli: esli));
        final esler = yazbozEsleri(masa);
        expect(esler.map((e) => e.es), [1, 2]);
        expect(esler.first.yerler.map((y) => y.id), [_yer1, _yer3]);
        expect(esler.last.yerler.map((y) => y.id), [_yer2, _yer4]);
        expect(esler.map(yazbozTemsilci), [_yer1, _yer2]);
      }
      // Seçim sırası değişirse eşler de değişir (yerin numarası esastır).
      final ters = EventScoreTable.fromJson(
        yazbozMasasiJson(
          id: _masa,
          kurallar: _esliKural,
          yerler: [
            yazbozYeriJson(_yer4, 1, kisi: _dorduncuId),
            yazbozYeriJson(_yer3, 2, kisi: _ucuncuId),
            yazbozYeriJson(_yer2, 3, kisi: katilimciId),
            yazbozYeriJson(_yer1, 4, kisi: organizatorId),
          ],
        ),
      );
      expect(yazbozEsleri(ters).first.yerler.map((y) => y.id), [_yer4, _yer2]);
    });

    test('eşin toplamı bir kez sayılır; sıra ve kazanan eş başına', () {
      final masa = EventScoreTable.fromJson(_bitenEsliMasa());
      final satirlar = yazbozEsSiralamasi(masa);
      expect(satirlar, hasLength(2));
      expect(satirlar.map((s) => s.es.es), [1, 2]);
      expect(satirlar.map((s) => s.sira.total), [150, 90]);
      expect(satirlar.map((s) => s.sira.rank), [1, 2]);
      expect(satirlar.map((s) => s.kazanan), [true, false]);
      // Açık masada kazanan yok.
      final acik = EventScoreTable.fromJson({
        ..._bitenEsliMasa(),
        'status': 'open',
      });
      expect(yazbozEsSiralamasi(acik).where((s) => s.kazanan), isEmpty);
    });

    test('bir elde eşin skoru herhangi bir koltuğundan okunur', () {
      final masa = EventScoreTable.fromJson(_bitenEsliMasa());
      final esler = yazbozEsleri(masa);
      final el = yazbozElleri(masa).first;
      expect(yazbozEsSkoru(el, esler.first)?.points, 80);
      expect(yazbozEsSkoru(el, esler.last)?.points, 40);
      // Yalnızca karşı koltukta skor varsa da bulunur.
      final tek = EventScoreRound.fromJson(_el(3, {_yer3: 25}));
      expect(yazbozEsSkoru(tek, esler.first)?.points, 25);
      expect(yazbozEsSkoru(tek, esler.last), isNull);
    });

    test('el isteği eş başına tek skor: eşin ilk koltuğuyla', () {
      final masa = EventScoreTable.fromJson(_bitenEsliMasa());
      final sira = yazbozEsleri(masa).map(yazbozTemsilci).toList();
      final istek = yazbozPuanIstegi(sira, {_yer1: '120', _yer2: '-30'});
      expect(istek.istek?.scores.map((s) => (s.playerId, s.points)), [
        (_yer1, 120),
        (_yer2, -30),
      ]);
    });

    test('eş adları ve kural özeti', () {
      expect(yazbozEsAdlariMetni(m, ['Ayşe', 'Mehmet']), 'Ayşe & Mehmet');
      expect(yazbozEsAdlariMetni(m, ['Ayşe']), 'Ayşe');
      expect(
        yazbozKuralOzeti(
          m,
          const EventScoreRules(side: EventScoreRulesSide.pair),
        ),
        [m.bilesen_scoreboard_kural_esli],
      );
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
      expect(
        _bolumde(find.textContaining(m.bilesen_scoreboard_kazanan)),
        findsNothing,
      );
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

    for (final tema in _temalar) {
      testWidgets('eşli masa: eşler birlikte, toplam bir kez, kazanan eş, '
          '"Sen" (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          yazboz: (_) => yazbozJson(
            masalar: [_bitenEsliMasa()],
            onAyarlar: _esliOnAyarlar(),
          ),
          yanitlar: {'GET $profilYolu': (i) => _esliProfil(i, katilimciId)},
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final ikinci = _bolumde(find.text('Mert & Deniz'));
        await _gorunurYap(tester, ikinci);
        expect(ikinci, findsOneWidget);
        expect(_bolumde(find.text('Ayşe & Mehmet')), findsOneWidget);
        // Toplam eş başına bir kez yazılır.
        expect(
          _bolumde(
            find.text(
              '${m.bilesen_scoreboard_es_no(1)} · '
              '${m.bilesen_scoreboard_puan('150')}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_scoreboard_puan('90'))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_scoreboard_kazanan)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_scoreboard_sen)), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_sira(1))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_scoreboard_sira(2))),
          findsOneWidget,
        );
        expect(_bolumde(find.textContaining('Batak (eşli)')), findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_scoreboard_kural_esli)),
          findsOneWidget,
        );
        // Satır ekran okuyucuda tek öğe: sıra, eşler ve toplam birlikte.
        expect(
          find.bySemanticsLabel(RegExp(r'1\.[\s\S]*Ayşe & Mehmet[\s\S]*150')),
          findsOneWidget,
        );

        await _dokun(
          tester,
          _bolumde(find.text(m.bilesen_scoreboard_elleri_goster(2))),
        );
        // Ellerde de eş başına tek skor.
        expect(_bolumde(find.text('Ayşe & Mehmet')), findsNWidgets(3));
        expect(_bolumde(find.text('80')), findsOneWidget);
        expect(_bolumde(find.text('40')), findsOneWidget);
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    for (final tema in _temalar) {
      testWidgets('eşli masa açılır: eşli ön ayar listede, koltuklar ve '
          'eşler açık, tam 4 kişi (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          ben: organizatorId,
          yazboz: (_) =>
              yazbozJson(onAyarlar: _esliOnAyarlar(), yonetebilir: true),
          yanitlar: {
            'GET $katilimcilarYolu': (_) => katilimcilarJson([
              organizatorId,
              katilimciId,
              _ucuncuId,
              _dorduncuId,
            ]),
            'GET $profilYolu': (i) => _esliProfil(i, organizatorId),
            'POST $yazbozMasalariYolu': (_) => yazbozJson(
              onAyarlar: _esliOnAyarlar(),
              yonetebilir: true,
              masalar: [
                yazbozMasasiJson(
                  id: _masa,
                  onAyar: 'pair_batak',
                  kurallar: _esliKural,
                  yerler: _esliYerler(),
                  siralama: [
                    _sira(_yer1, 1, 0),
                    _sira(_yer3, 1, 0),
                    _sira(_yer2, 1, 0),
                    _sira(_yer4, 1, 0),
                  ],
                ),
              ],
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);
        Finder formda(Finder f) =>
            find.descendant(of: find.byType(YazbozMasaFormu), matching: f);

        final ac = _bolumde(find.text(m.bilesen_scoreboard_masa_ac));
        await _gorunurYap(tester, ac);
        await _dokun(tester, ac);
        // Bireysel ve eşli ön ayar ikisi de seçilebilir.
        expect(formda(find.text('Batak')), findsOneWidget);
        final birinciEs = m.bilesen_scoreboard_es_koltuklari(1, 1, 3);
        expect(formda(find.text(birinciEs)), findsNothing);
        await _dokun(tester, formda(find.text('Batak (eşli)')));
        expect(formda(find.text(birinciEs)), findsOneWidget);
        expect(
          formda(find.text(m.bilesen_scoreboard_es_koltuklari(2, 2, 4))),
          findsOneWidget,
        );
        expect(
          formda(find.text(m.bilesen_scoreboard_esli_aciklama)),
          findsOneWidget,
        );

        for (final kisi in [organizatorId, katilimciId, _ucuncuId]) {
          await _dokun(tester, find.byKey(ValueKey('yazboz-kisi-$kisi')));
        }
        expect(
          formda(find.text(m.bilesen_scoreboard_koltuk_es(3, 1))),
          findsOneWidget,
        );
        // Üç kişiyle istek gitmez.
        await _dokun(tester, formda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('POST', yazbozMasalariYolu), isEmpty);
        expect(
          formda(find.text(m.bilesen_scoreboard_esli_sayi)),
          findsOneWidget,
        );

        await _dokun(
          tester,
          find.byKey(const ValueKey('yazboz-kisi-$_dorduncuId')),
        );
        expect(
          formda(find.text(m.bilesen_scoreboard_koltuk_es(4, 2))),
          findsOneWidget,
        );
        await _dokun(tester, formda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('POST', yazbozMasalariYolu).single.govde, {
          'label': m.bilesen_scoreboard_ad_varsayilan(1),
          'preset_key': 'pair_batak',
          'players': [
            {'user_id': organizatorId},
            {'user_id': katilimciId},
            {'user_id': _ucuncuId},
            {'user_id': _dorduncuId},
          ],
        });
        expect(find.byType(YazbozMasaFormu), findsNothing);
        expect(_bolumde(find.text('Ayşe & Mehmet')), findsOneWidget);
        expect(_bolumde(find.text('Mert & Deniz')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('eşli masada el eş başına tek kutuyla girilir '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        Map<String, Object?> masa({bool elli = false}) => yazbozMasasiJson(
          id: _masa,
          onAyar: 'pair_batak',
          kurallar: _esliKural,
          yerler: _esliYerler(),
          eller: [
            if (elli) _el(1, {_yer1: 120, _yer3: 120, _yer2: -30, _yer4: -30}),
          ],
          siralama: [
            _sira(_yer1, 1, elli ? 120 : 0),
            _sira(_yer3, 1, elli ? 120 : 0),
            _sira(_yer2, elli ? 2 : 1, elli ? -30 : 0),
            _sira(_yer4, elli ? 2 : 1, elli ? -30 : 0),
          ],
          skorGirebilir: true,
        );
        final tasima = _tasima(
          yazboz: (_) =>
              yazbozJson(onAyarlar: _esliOnAyarlar(), masalar: [masa()]),
          yanitlar: {
            'GET $profilYolu': (i) => _esliProfil(i, katilimciId),
            'POST $yazbozElleriYolu': (_) => yazbozJson(
              onAyarlar: _esliOnAyarlar(),
              masalar: [masa(elli: true)],
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final gir = _bolumde(find.text(m.bilesen_scoreboard_el_gir));
        await _gorunurYap(tester, gir);
        await _dokun(tester, gir);
        Finder formda(Finder f) =>
            find.descendant(of: find.byType(YazbozElFormu), matching: f);
        final birinciEs = m.bilesen_scoreboard_es_basligi(1, 'Ayşe & Mehmet');
        final ikinciEs = m.bilesen_scoreboard_es_basligi(2, 'Mert & Deniz');
        expect(formda(find.text(birinciEs)), findsOneWidget);
        expect(formda(find.text(ikinciEs)), findsOneWidget);
        expect(
          formda(find.text(m.bilesen_scoreboard_esli_puan_aciklama)),
          findsOneWidget,
        );
        expect(formda(find.byType(TextField)), findsNWidgets(2));
        expect(find.byKey(const ValueKey('yazboz-puan-$_yer3')), findsNothing);
        expect(find.byKey(const ValueKey('yazboz-puan-$_yer4')), findsNothing);

        await tester.enterText(
          find.byKey(const ValueKey('yazboz-puan-$_yer1')),
          '120',
        );
        await tester.enterText(
          find.byKey(const ValueKey('yazboz-puan-$_yer2')),
          '-30',
        );
        await tester.pumpAndSettle();
        await _dokun(tester, formda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('POST', yazbozElleriYolu).single.govde, {
          'scores': [
            {'player_id': _yer1, 'points': 120},
            {'player_id': _yer2, 'points': -30},
          ],
        });
        expect(find.byType(YazbozElFormu), findsNothing);
        expect(
          _bolumde(
            find.text(
              '${m.bilesen_scoreboard_es_no(1)} · '
              '${m.bilesen_scoreboard_puan('120')}',
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('eşli masada son el düzeltilirken eşin skoru dolu gelir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        yazboz: (_) => yazbozJson(
          masalar: [
            {..._bitenEsliMasa(), 'status': 'open', 'winner_ids': <String>[]},
          ],
          onAyarlar: _esliOnAyarlar(),
          yonetebilir: true,
        ),
        yanitlar: {'GET $profilYolu': (i) => _esliProfil(i, organizatorId)},
      );
      await _detayiAc(tester, tasima);
      final menu = find.byTooltip(m.bilesen_scoreboard_islemler('Masa 1'));
      await _gorunurYap(tester, menu);
      await _dokun(tester, menu);
      await _dokun(tester, find.text(m.bilesen_scoreboard_son_eli_duzelt).last);
      expect(find.byType(YazbozElFormu), findsOneWidget);
      final birinci = tester.widget<TextField>(
        find.byKey(const ValueKey('yazboz-puan-$_yer1')),
      );
      final ikinci = tester.widget<TextField>(
        find.byKey(const ValueKey('yazboz-puan-$_yer2')),
      );
      expect(birinci.controller?.text, '70');
      expect(ikinci.controller?.text, '50');
      expect(tester.takeException(), isNull);
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
