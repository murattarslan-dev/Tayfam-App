import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_bileseni.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  TakimBileseni(),
  KuraBileseni(),
];

const String _takim1 = '01970000-0000-7000-8000-000000000201';
const String _takim2 = '01970000-0000-7000-8000-000000000202';
const String _ucuncuId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';
const String _cekildi = '2026-11-20T11:05:00Z';

/// Çekilmiş katılımcı kurası: 3. yer boş (geri çekilen), beş yerde son
/// yer rakipsiz.
List<Map<String, Object?>> _yerler() => [
  kuraYeriJson(1, kisi: _ucuncuId),
  kuraYeriJson(2, kisi: katilimciId),
  kuraYeriJson(3),
  kuraYeriJson(4, kisi: organizatorId),
  kuraYeriJson(5, kisi: _ucuncuId),
];

/// Espor turnuvası (katalog fikstüründe takım kurma ve kura bileşeni var).
/// [kura] kuranın yanıtıdır; kendi kimliği [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti kura,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = katilimciId,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'esports', cevap: 'going'),
    'GET $kuraYolu': kura,
    'GET $takimYolu': (_) => takimlarJson(mod: 'manual'),
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
    find.descendant(of: find.byType(KuraBolumu), matching: bulucu);

Finder _pencerede(Finder bulucu) =>
    find.descendant(of: find.byType(AlertDialog), matching: bulucu);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe kura bileşenini kullanan tür var', () {
    final kuralar = turBilesenleri(
      testTuru('esports'),
    ).where((b) => b.kind == 'draw').toList();
    expect(kuralar, hasLength(1));
    expect(bilesenAnahtari(kuralar.single), 'draw');
    expect(
      turBilesenleri(testTuru('esports')).map((b) => b.kind),
      containsAll(<String>['teams', 'draw']),
    );
  });

  group('eşleşmeler', () {
    test('ardışık iki yer bir eşleşme; boş yer yerinde, sıra kaymaz', () {
      final kura = EventDraw.fromJson(
        kuraJson(yerler: _yerler().reversed.toList(), cekildi: _cekildi),
      );
      final eslesmeler = kuraEslesmeleri(kura);
      expect(eslesmeler.map((e) => e.no), [1, 2, 3]);
      expect(eslesmeler[0].ilk.userId, _ucuncuId);
      expect(eslesmeler[0].ikinci?.userId, katilimciId);
      expect(eslesmeler[1].ilk.position, 3);
      expect(kuraYeriBos(eslesmeler[1].ilk), isTrue);
      expect(eslesmeler[1].ikinci?.userId, organizatorId);
      expect(eslesmeler[2].ilk.position, 5);
      expect(eslesmeler[2].ikinci, isNull);
      expect(kuraEslesmeleri(EventDraw.fromJson(kuraJson())), isEmpty);
    });

    test('takım yerinde boş değil; kimliksiz yer boş', () {
      expect(
        kuraYeriBos(EventDrawEntry.fromJson(kuraYeriJson(1, takim: _takim1))),
        isFalse,
      );
      expect(kuraYeriBos(EventDrawEntry.fromJson(kuraYeriJson(2))), isTrue);
    });

    test('neyin sıralandığı yazılır', () {
      expect(
        kuraKonusu(m, EventDrawSubject.participants),
        m.bilesen_draw_konu_participants,
      );
      expect(kuraKonusu(m, EventDrawSubject.teams), m.bilesen_draw_konu_teams);
      expect(kuraKonusu(m, EventDrawSubject.unknown), isNull);
    });
  });

  group('kura bölümü', () {
    for (final tema in _temalar) {
      testWidgets('üye çekilmiş kurayı okur: eşleşmeler, bay, "Sen" '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          kura: (_) => kuraJson(yerler: _yerler(), cekildi: _cekildi),
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final son = _bolumde(find.text(m.bilesen_draw_eslesme(3)));
        await _gorunurYap(tester, son);
        expect(son, findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_draw_eslesme(1))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_draw_eslesme(2))), findsOneWidget);
        // Boş 3. yer ve rakipsiz 5. yer.
        expect(_bolumde(find.text(m.bilesen_draw_bay)), findsNWidgets(2));
        expect(_bolumde(find.text(m.bilesen_draw_sira(3))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_draw_sira(5))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_draw_sira(6))), findsNothing);
        expect(_bolumde(find.text(m.bilesen_draw_sen)), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_draw_konu_participants)),
          findsOneWidget,
        );
        expect(
          _bolumde(
            find.textContaining(m.bilesen_draw_cekildi('').trim()),
          ),
          findsOneWidget,
        );
        // Adlar profilden.
        expect(_bolumde(find.byType(KullaniciAdiMetni)), findsNWidgets(4));
        expect(_bolumde(find.text(m.bilesen_draw_cek)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_draw_yok)), findsNothing);
        expect(tasima.giden('GET', kuraYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'draw',
        });
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('yetkili onaydan sonra çeker; vazgeçerse istek gitmez '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          ben: organizatorId,
          kura: (_) => kuraJson(cekebilir: true),
          yanitlar: {
            'POST $kuraYolu': (_) =>
                kuraJson(yerler: _yerler().take(4).toList(), cekildi: _cekildi),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final bos = _bolumde(find.text(m.bilesen_draw_yok));
        await _gorunurYap(tester, bos);
        expect(bos, findsOneWidget);
        final cek = _bolumde(find.text(m.bilesen_draw_cek));
        expect(cek, findsOneWidget);

        // Onay geri alınamazlığı söyler; vazgeçince istek gitmez.
        await _dokun(tester, cek);
        expect(_pencerede(find.text(m.bilesen_draw_onay)), findsOneWidget);
        expect(
          _pencerede(find.text(m.bilesen_draw_onay_participants)),
          findsOneWidget,
        );
        await _dokun(tester, _pencerede(find.text(m.etkinlik_vazgec)));
        expect(tasima.giden('POST', kuraYolu), isEmpty);

        await _dokun(tester, cek);
        await _dokun(tester, _pencerede(find.text(m.bilesen_draw_cek)));
        final giden = tasima.giden('POST', kuraYolu);
        expect(giden, hasLength(1));
        expect(giden.single.yolParametreleri['component_key'], 'draw');
        expect(_bolumde(find.text(m.bilesen_draw_eslesme(2))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_draw_cek)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_draw_yok)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('takım kurasında takımların adı ya da numarası '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          kura: (_) => kuraJson(
            konu: 'teams',
            takimAnahtari: 'teams',
            yerler: [
              kuraYeriJson(1, takim: _takim2),
              kuraYeriJson(2, takim: _takim1),
            ],
            cekildi: _cekildi,
          ),
          yanitlar: {
            'GET $takimYolu': (_) => takimlarJson(
              mod: 'manual',
              takimlar: [
                takimJson(id: _takim1, sira: 1, uyeler: [katilimciId]),
                takimJson(
                  id: _takim2,
                  sira: 2,
                  ad: 'Kartallar',
                  uyeler: [_ucuncuId],
                ),
              ],
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final kartallar = _bolumde(find.text('Kartallar'));
        await _gorunurYap(tester, kartallar);
        expect(kartallar, findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_teams_takim_no(1))),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_draw_sen)), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_draw_konu_teams)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_draw_bay)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"hareketi azalt" açıkken geçiş yok', (tester) async {
      ekranBoyutu(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final tasima = _tasima(
        kura: (_) => kuraJson(yerler: _yerler(), cekildi: _cekildi),
      );
      await _detayiAc(tester, tasima);
      final gecis = _bolumde(find.byType(AnimatedSwitcher));
      await _gorunurYap(tester, gecis);
      expect(tester.widget<AnimatedSwitcher>(gecis).duration, Duration.zero);
    });

    testWidgets('az katılımcıda sunucunun hatası gösterilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        kura: (_) => kuraJson(cekebilir: true),
        yanitlar: {
          'POST $kuraYolu': (_) =>
              const ApiProblem(type: ProblemType.drawTooFew, status: 409),
        },
      );
      await _detayiAc(tester, tasima);
      final cek = _bolumde(find.text(m.bilesen_draw_cek));
      await _gorunurYap(tester, cek);
      await _dokun(tester, cek);
      await _dokun(tester, _pencerede(find.text(m.bilesen_draw_cek)));
      expect(tasima.giden('POST', kuraYolu), hasLength(1));
      expect(find.text(m.hata_draw_too_few), findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_draw_cek)), findsOneWidget);
    });

    testWidgets('başkası çektiyse hata gösterilir ve kura yeniden okunur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var okuma = 0;
      final tasima = _tasima(
        ben: organizatorId,
        kura: (_) {
          okuma++;
          return okuma == 1
              ? kuraJson(cekebilir: true)
              : kuraJson(yerler: _yerler(), cekildi: _cekildi);
        },
        yanitlar: {
          'POST $kuraYolu': (_) =>
              const ApiProblem(type: ProblemType.drawAlreadyMade, status: 409),
        },
      );
      await _detayiAc(tester, tasima);
      final cek = _bolumde(find.text(m.bilesen_draw_cek));
      await _gorunurYap(tester, cek);
      await _dokun(tester, cek);
      await _dokun(tester, _pencerede(find.text(m.bilesen_draw_cek)));
      expect(find.text(m.hata_draw_already_made), findsOneWidget);
      expect(tasima.giden('GET', kuraYolu), hasLength(2));
      expect(_bolumde(find.text(m.bilesen_draw_cek)), findsNothing);
      expect(_bolumde(find.text(m.bilesen_draw_eslesme(1))), findsOneWidget);
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        kura: (_) {
          if (okundu) return kuraJson(yerler: _yerler(), cekildi: _cekildi);
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(m.etkinlik_tekrar_dene));
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(_bolumde(find.text(m.bilesen_draw_eslesme(1))), findsOneWidget);
    });
  });
}
