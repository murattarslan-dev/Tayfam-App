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
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_bileseni.dart';
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
  KuraBileseni(),
  AgacBileseni(),
  TemelBilesen('scoreboard'),
];

const String _ucuncuId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';
const String _mac1 = '01970000-0000-7000-8000-000000000301';
const String _mac2 = '01970000-0000-7000-8000-000000000302';
const String _mac3 = '01970000-0000-7000-8000-000000000303';

const AgacKimligi _kimlik = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
  anahtar: 'bracket',
  kura: 'draw',
);

/// Kuradaki üç yer: 1 Ayşe (organizatör), 2 Mert (katılımcı), 3 üçüncü.
List<Map<String, Object?>> _yerler() => [
  kuraYeriJson(1, kisi: organizatorId),
  kuraYeriJson(2, kisi: katilimciId),
  kuraYeriJson(3, kisi: _ucuncuId),
];

/// Başlamış eleme ağacı, 1. tur: 1–2 maçı ([birinci]) ve 3'ün bayı.
Map<String, Object?> _elemeAgaci({
  required Map<String, Object?> birinci,
  bool yonetebilir = false,
}) => agacJson(
  basladi: true,
  cekildi: true,
  turlar: 2,
  mevcutTur: 1,
  yerler: _yerler(),
  maclar: [
    birinci,
    agacMaciJson(
      id: _mac2,
      sira: 2,
      a: 3,
      sonuclandi: true,
      bay: true,
      kazanan: 3,
    ),
  ],
  yonetebilir: yonetebilir,
);

/// 1–2 maçı: Ayşe 21–18 kazandı.
Map<String, Object?> _bitenMac() => agacMaciJson(
  id: _mac1,
  a: 1,
  b: 2,
  oyunlar: [agacOyunuJson(1, a: 21, b: 18)],
  sonuclandi: true,
  kazanan: 1,
  aToplam: 21,
  bToplam: 18,
  aOyun: 1,
);

/// Satranç (katalog fikstüründe kura, eşleşme ağacı ve yazboz var).
/// [agac] ağacın yanıtıdır; kendi kimliği [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti agac,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = katilimciId,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'chess', cevap: 'going'),
    'GET $agacYolu': agac,
    'GET $kuraYolu': (_) => kuraJson(yerler: _yerler(), cekildi: _cekildi),
    ...yanitlar,
  });
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

const String _cekildi = '2026-11-20T11:05:00Z';

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
    find.descendant(of: find.byType(AgacBolumu), matching: bulucu);

Finder _pencerede(Finder bulucu) =>
    find.descendant(of: find.byType(AlertDialog), matching: bulucu);

Finder _etiket(String metin) =>
    find.bySemanticsLabel(RegExp('^${RegExp.escape(metin)}'));

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe eşleşme ağacını kullanan tür var', () {
    final bilesenler = turBilesenleri(testTuru('chess'));
    final agaclar = bilesenler.where((b) => b.kind == 'bracket').toList();
    expect(agaclar, hasLength(1));
    expect(bilesenAnahtari(agaclar.single), 'bracket');
    expect(
      bilesenler.map((b) => b.kind),
      containsAll(<String>['draw', 'bracket', 'scoreboard']),
    );
    final secimler = secimliParametreler(agaclar.single);
    expect(secimler.map((p) => p.ad), ['best_of', 'format']);
    expect(secimler.first.secenekler, ['1', '3', '5']);
    expect(secimler.last.varsayilan, 'swiss');
  });

  group('yardımcılar', () {
    test('maçlar tura ve sıraya göre gruplanır', () {
      final agac = EventBracket.fromJson(
        agacJson(
          basladi: true,
          maclar: [
            agacMaciJson(id: _mac3, tur: 2, a: 1),
            agacMaciJson(id: _mac2, sira: 2, a: 3, b: 4, sonuclandi: true),
            agacMaciJson(id: _mac1, a: 1, b: 2),
          ],
        ),
      );
      final turlar = agacTurlari(agac);
      expect(turlar.map((t) => t.no), [1, 2]);
      expect(turlar.first.maclar.map((m) => m.id), [_mac1, _mac2]);
      expect(agacBitenMaclar(turlar.first), 1);
    });

    test('sonraki tur yalnızca tur sonuçlanınca, ligde hiç', () {
      EventBracket agac({
        String bicim = 'elimination',
        bool sonuclandi = true,
        bool yonetebilir = true,
        int mevcut = 1,
      }) => EventBracket.fromJson(
        agacJson(
          basladi: true,
          bicim: bicim,
          turlar: 3,
          mevcutTur: mevcut,
          maclar: [
            agacMaciJson(id: _mac1, tur: mevcut, a: 1, sonuclandi: sonuclandi),
          ],
          yonetebilir: yonetebilir,
        ),
      );
      expect(agacSonrakiTurEslenebilir(agac()), isTrue);
      expect(agacSonrakiTurEslenebilir(agac(bicim: 'swiss')), isTrue);
      expect(agacSonrakiTurEslenebilir(agac(sonuclandi: false)), isFalse);
      expect(agacSonrakiTurEslenebilir(agac(yonetebilir: false)), isFalse);
      expect(agacSonrakiTurEslenebilir(agac(bicim: 'league')), isFalse);
      expect(agacSonrakiTurEslenebilir(agac(mevcut: 3)), isFalse);
    });

    test('puan isteği iki tarafı birlikte ister ve sınırı denetler', () {
      final dogru = agacPuanIstegi(' 21 ', '−18');
      expect(dogru.istek?.toJson(), {'a_points': 21, 'b_points': -18});
      final bos = agacPuanIstegi('', ' ');
      expect(bos.istek, isNull);
      expect(bos.hatali, isEmpty);
      expect(agacPuanIstegi('21', '').hatali, {'b'});
      expect(agacPuanIstegi('2000000', 'x').hatali, {'a', 'b'});
    });

    test('oyun skoru A–B; sonuç modunda 1–0, ½–½', () {
      expect(
        agacOyunMetni(
          m,
          EventBracketGame.fromJson(agacOyunuJson(1, a: 21, b: 18)),
        ),
        m.bilesen_bracket_oyun_skoru('21', '18'),
      );
      expect(
        agacOyunMetni(
          m,
          EventBracketGame.fromJson(agacOyunuJson(2, sonuc: 'draw')),
        ),
        m.bilesen_bracket_oyun_skoru('½', '½'),
      );
      expect(agacBicimAdi(m, EventBracketFormat.unknown), isNull);
      expect(agacBoAdi(m, 1), m.bilesen_bracket_bo_tek);
      expect(agacBoAdi(m, 3), m.bilesen_bracket_bo(3));
    });
  });

  group('eşleşme ağacı bölümü', () {
    for (final tema in _temalar) {
      testWidgets('üye tur tur okur: kazanan yazıyla, bay, "Sen", maç tek '
          'cümle (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(agac: (_) => _elemeAgaci(birinci: _bitenMac()));
        await _detayiAc(tester, tasima, themeMode: tema);

        final bay = _bolumde(find.text(m.bilesen_bracket_bay_gecer));
        await _gorunurYap(tester, bay);
        expect(bay, findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_bracket_tur_toplam(1, 2))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_bracket_tur_durumu(1, 2))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_bracket_format_elimination)),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_bracket_kazanan)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_bracket_sen)), findsOneWidget);
        expect(
          _bolumde(
            find.text(
              m.bilesen_bracket_oyunlar(m.bilesen_bracket_oyun_skoru('21', '18')),
            ),
          ),
          findsOneWidget,
        );
        // Ekran okuyucu: tur, taraflar, skor, kazanan.
        expect(
          _etiket(
            '${m.bilesen_bracket_ozet(1, 1)}, '
            '${m.bilesen_bracket_ozet_taraflar('Ayşe', '21', 'Mert', '18')}, '
            '${m.bilesen_bracket_ozet_kazanan('Ayşe')}',
          ),
          findsOneWidget,
        );
        expect(
          _etiket(
            '${m.bilesen_bracket_ozet(1, 2)}, Mert, '
            '${m.bilesen_bracket_ozet_bay('Mert')}',
          ),
          findsOneWidget,
        );
        // Üye yönetmez, oyun girmez.
        expect(_bolumde(find.text(m.bilesen_bracket_oyun_gir)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_bracket_sifirla)), findsNothing);
        expect(
          _bolumde(find.text(m.bilesen_bracket_sonraki_tur)),
          findsNothing,
        );
        expect(find.byTooltip(m.bilesen_bracket_islemler(1, 1)), findsNothing);
        expect(tasima.giden('GET', agacYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'bracket',
        });
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('kura çekilmeden başlamaz; çekilince onayla başlatılır '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var cekildi = false;
        final tasima = _tasima(
          ben: organizatorId,
          agac: (_) => agacJson(
            cekildi: cekildi,
            yerler: cekildi ? _yerler() : const [],
            turlar: 2,
            yonetebilir: true,
          ),
          yanitlar: {
            'POST $agacYolu': (_) =>
                _elemeAgaci(birinci: agacMaciJson(id: _mac1, a: 1, b: 2)),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final bekliyor = _bolumde(find.text(m.bilesen_bracket_kura_bekleniyor));
        await _gorunurYap(tester, bekliyor);
        expect(bekliyor, findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_bracket_baslat)), findsNothing);

        // Kura çekildi (canlı yenileme yerine yeniden okuma).
        cekildi = true;
        final c = ProviderScope.containerOf(
          tester.element(find.byType(AgacBolumu)),
        );
        await c.read(agacProvider(_kimlik).notifier).yenile();
        await tester.pumpAndSettle();
        expect(
          _bolumde(find.text(m.bilesen_bracket_baslamadi(3))),
          findsOneWidget,
        );
        final baslat = _bolumde(find.text(m.bilesen_bracket_baslat));
        expect(baslat, findsOneWidget);

        // Onay kuralın sabitlendiğini söyler; vazgeçince istek gitmez.
        await _dokun(tester, baslat);
        expect(
          _pencerede(find.text(m.bilesen_bracket_baslat_aciklama)),
          findsOneWidget,
        );
        await _dokun(tester, _pencerede(find.text(m.etkinlik_vazgec)));
        expect(tasima.giden('POST', agacYolu), isEmpty);

        await _dokun(tester, baslat);
        await _dokun(tester, _pencerede(find.text(m.bilesen_bracket_baslat)));
        expect(tasima.giden('POST', agacYolu), hasLength(1));
        expect(
          _bolumde(find.text(m.bilesen_bracket_tur_toplam(1, 2))),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_bracket_baslat)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('türde kura yoksa bunu söyler', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(agac: (_) => agacJson(kura: null));
      await _detayiAc(tester, tasima);
      final yok = _bolumde(find.text(m.bilesen_bracket_kura_yok));
      await _gorunurYap(tester, yok);
      expect(yok, findsOneWidget);
    });

    for (final tema in _temalar) {
      testWidgets('organizatör puanla oyun girer; boşsa istek gitmez '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          ben: organizatorId,
          agac: (_) => _elemeAgaci(
            birinci: agacMaciJson(id: _mac1, a: 1, b: 2, girebilir: true),
            yonetebilir: true,
          ),
          yanitlar: {
            'POST $agacOyunlariYolu': (_) =>
                _elemeAgaci(birinci: _bitenMac(), yonetebilir: true),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final gir = _bolumde(find.text(m.bilesen_bracket_oyun_gir));
        await _gorunurYap(tester, gir);
        await _dokun(tester, gir);
        expect(find.text(m.bilesen_bracket_oyun_baslik(1)), findsOneWidget);
        expect(find.text(m.bilesen_bracket_puan_alani('Ayşe')), findsOneWidget);
        expect(find.text(m.bilesen_bracket_puan_alani('Mert')), findsOneWidget);
        expect(find.text(m.bilesen_bracket_ek_oyun(9)), findsOneWidget);

        await _dokun(tester, find.text(m.etkinlik_kaydet));
        expect(find.text(m.bilesen_bracket_puan_yok), findsOneWidget);
        expect(tasima.giden('POST', agacOyunlariYolu), isEmpty);

        await tester.enterText(find.byKey(const ValueKey('agac-puan-a')), '21');
        await tester.enterText(find.byKey(const ValueKey('agac-puan-b')), '18');
        await _dokun(tester, find.text(m.etkinlik_kaydet));
        final giden = tasima.giden('POST', agacOyunlariYolu).single;
        expect(giden.yolParametreleri['match_id'], _mac1);
        expect(giden.yolParametreleri['component_key'], 'bracket');
        expect(giden.govde, {'a_points': 21, 'b_points': 18});
        expect(find.text(m.bilesen_bracket_oyun_baslik(1)), findsNothing);
        expect(
          _bolumde(find.textContaining(m.bilesen_bracket_kazanan)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_bracket_oyun_gir)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sonuç kuralında tek seçimle oyun girilir', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      final tasima = _tasima(
        ben: organizatorId,
        agac: (_) => agacJson(
          basladi: true,
          cekildi: true,
          bicim: 'swiss',
          sonuc: 'wdl',
          turlar: 2,
          mevcutTur: 1,
          yerler: _yerler().take(2).toList(),
          maclar: [agacMaciJson(id: _mac1, a: 1, b: 2, girebilir: true)],
        ),
        yanitlar: {'POST $agacOyunlariYolu': (_) => agacJson(basladi: true)},
      );
      await _detayiAc(tester, tasima);
      final gir = _bolumde(find.text(m.bilesen_bracket_oyun_gir));
      await _gorunurYap(tester, gir);
      await _dokun(tester, gir);
      expect(find.text(m.bilesen_bracket_kazandi('Ayşe')), findsOneWidget);
      expect(find.text(m.bilesen_bracket_kazandi('Mert')), findsOneWidget);
      expect(find.text(m.bilesen_bracket_ek_oyun(9)), findsNothing);
      await _dokun(tester, find.text(m.etkinlik_kaydet));
      expect(find.text(m.bilesen_bracket_sonuc_yok), findsOneWidget);
      await _dokun(tester, find.text(m.bilesen_bracket_berabere));
      await _dokun(tester, find.text(m.etkinlik_kaydet));
      expect(tasima.giden('POST', agacOyunlariYolu).single.govde, {
        'a_outcome': 'draw',
      });
    });

    testWidgets('tur sonuçlanınca sonraki tur eşlenir; ağaç onayla '
        'sıfırlanır, kura kalır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        agac: (_) => _elemeAgaci(birinci: _bitenMac(), yonetebilir: true),
        yanitlar: {
          'POST $agacTurlariYolu': (_) => agacJson(
            basladi: true,
            cekildi: true,
            turlar: 2,
            mevcutTur: 2,
            yerler: _yerler(),
            maclar: [
              _bitenMac(),
              agacMaciJson(
                id: _mac2,
                sira: 2,
                a: 3,
                sonuclandi: true,
                bay: true,
                kazanan: 3,
              ),
              agacMaciJson(id: _mac3, tur: 2, a: 1, b: 3),
            ],
            yonetebilir: true,
          ),
          'DELETE $agacYolu': (_) => agacJson(
            cekildi: true,
            yerler: _yerler(),
            turlar: 2,
            yonetebilir: true,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final sonraki = _bolumde(find.text(m.bilesen_bracket_sonraki_tur));
      await _gorunurYap(tester, sonraki);
      await _dokun(tester, sonraki);
      expect(tasima.giden('POST', agacTurlariYolu), hasLength(1));
      expect(
        _bolumde(find.text(m.bilesen_bracket_tur_toplam(2, 2))),
        findsOneWidget,
      );
      expect(_bolumde(find.text(m.bilesen_bracket_sonraki_tur)), findsNothing);
      // Sonuçlanmış 1. tur kapanır; açılabilir.
      expect(
        _bolumde(find.text(m.bilesen_bracket_turu_goster(1))),
        findsOneWidget,
      );
      expect(_bolumde(find.text(m.bilesen_bracket_bay_gecer)), findsNothing);
      await _dokun(
        tester,
        _bolumde(find.text(m.bilesen_bracket_turu_goster(1))),
      );
      expect(_bolumde(find.text(m.bilesen_bracket_bay_gecer)), findsOneWidget);

      final sifirla = _bolumde(find.text(m.bilesen_bracket_sifirla));
      await _dokun(tester, sifirla);
      expect(
        _pencerede(find.text(m.bilesen_bracket_sifirla_aciklama)),
        findsOneWidget,
      );
      await _dokun(tester, _pencerede(find.text(m.bilesen_bracket_sifirla)));
      expect(tasima.giden('DELETE', agacYolu), hasLength(1));
      expect(
        _bolumde(find.text(m.bilesen_bracket_baslamadi(3))),
        findsOneWidget,
      );
      expect(_bolumde(find.text(m.bilesen_bracket_baslat)), findsOneWidget);
    });

    for (final tema in _temalar) {
      testWidgets('biten İsviçre ağacı: şampiyon, sıralama, Buchholz '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          agac: (_) => agacJson(
            basladi: true,
            cekildi: true,
            bicim: 'swiss',
            sonuc: 'wdl',
            turlar: 1,
            mevcutTur: 1,
            yerler: _yerler().take(2).toList(),
            maclar: [
              agacMaciJson(
                id: _mac1,
                a: 1,
                b: 2,
                oyunlar: [agacOyunuJson(1, sonuc: 'win')],
                sonuclandi: true,
                kazanan: 1,
                aToplam: 1,
              ),
            ],
            siralama: [
              agacSirasiJson(2, sira: 2, oynadi: 1, maglubiyet: 1, buchholz: 1),
              agacSirasiJson(1, sira: 1, puan: 1, oynadi: 1, galibiyet: 1),
            ],
            bitti: true,
            kazananlar: [1],
          ),
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final sampiyon = _bolumde(
          find.text(m.bilesen_bracket_sampiyon('Ayşe')),
        );
        await _gorunurYap(tester, sampiyon);
        expect(sampiyon, findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_bracket_siralama)), findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_bracket_sampiyon_etiketi)),
          findsNWidgets(2),
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_bracket_buchholz('1'))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_bracket_gbm(1, 0, 0))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_bracket_tur_durumu(1, 1))),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sonraki tur eşlendiyse hata gösterilir ve ağaç yeniden '
        'okunur', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        agac: (_) => _elemeAgaci(birinci: _bitenMac(), yonetebilir: true),
        yanitlar: {
          'DELETE $agacOyunuYolu': (_) => const ApiProblem(
            type: ProblemType.bracketRoundClosed,
            status: 409,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final menu = find.byTooltip(m.bilesen_bracket_islemler(1, 1));
      await _gorunurYap(tester, menu);
      await _dokun(tester, menu);
      await _dokun(tester, find.text(m.bilesen_bracket_son_oyunu_sil));
      expect(
        _pencerede(find.text(m.bilesen_bracket_son_oyunu_sil_onay(1))),
        findsOneWidget,
      );
      final once = tasima.giden('GET', agacYolu).length;
      await _dokun(tester, _pencerede(find.text(m.bilesen_bracket_sil)));
      final silinen = tasima.giden('DELETE', agacOyunuYolu).single;
      expect(silinen.yolParametreleri['match_id'], _mac1);
      expect(silinen.yolParametreleri['game'], '1');
      expect(find.text(m.hata_bracket_round_closed), findsOneWidget);
      expect(tasima.giden('GET', agacYolu), hasLength(once + 1));
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        agac: (_) {
          if (okundu) return _elemeAgaci(birinci: _bitenMac());
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(m.etkinlik_tekrar_dene));
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(
        _bolumde(find.text(m.bilesen_bracket_tur_toplam(1, 2))),
        findsOneWidget,
      );
    });
  });

  test('ağaç da kurası da canlı değişince yeniden okunur', () async {
    final tasima = etkinlikTasimasi({
      'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'chess'),
      'GET $agacYolu': (_) => agacJson(),
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
    int okuma() => tasima.giden('GET', agacYolu).length;
    Future<void> bekle() async {
      await pumpEventQueue();
      await c.read(agacProvider(_kimlik).future);
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
    final durum = c.listen(agacProvider(_kimlik), (_, _) {});
    await bekle();
    expect(okuma(), 1);

    realtime.baslat();
    await pumpEventQueue();
    await soketler.single.ac();
    await bekle();
    final once = okuma();

    // Biri oyun girdi: ağaç yeniden okunur.
    degisti('bracket');
    await bekle();
    expect(okuma(), once + 1);

    // Kura çekildi: ağaç (tohumları) yeniden okunur.
    degisti('draw');
    await bekle();
    expect(okuma(), once + 2);

    // Başka bileşen ağacı etkilemez.
    degisti('scoreboard');
    await bekle();
    expect(okuma(), once + 2);

    durum.close();
    detay.close();
  });
}
