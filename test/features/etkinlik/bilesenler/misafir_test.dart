import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/agac/agac_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kura/kura_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/misafir/misafir_ortak.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/yazboz/yazboz_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _masa = '01970000-0000-7000-8000-000000000301';
const String _yer1 = '01970000-0000-7000-8000-000000000311';
const String _yer2 = '01970000-0000-7000-8000-000000000312';
const String _yer3 = '01970000-0000-7000-8000-000000000313';
const String _deniz = '01970000-0000-7000-8000-000000000401';
const String _adsiz = '01970000-0000-7000-8000-000000000402';
const String _ece = '01970000-0000-7000-8000-000000000403';
const String _mac = '01970000-0000-7000-8000-000000000501';

Map<String, Object?> _sira(String yer, int sira) => {
  'player_id': yer,
  'total': 0,
  'rounds_won': 0,
  'rank': sira,
};

/// Bir etkinlik detayı: [tur] türü, [yanitlar] bileşen yanıtları; kendi
/// kimliği [ben].
SahteTayfaTasima _tasima({
  required String tur,
  required Map<String, TayfaYaniti> yanitlar,
  String ben = katilimciId,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(tur: tur, cevap: 'going'),
    'GET $katilimcilarYolu': (_) =>
        katilimcilarJson([katilimciId, organizatorId]),
    ...yanitlar,
  });
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  List<EtkinlikBileseni> kayit, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, bilesenler: kayit),
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

Finder _icinde(Type tur, Finder bulucu) =>
    find.descendant(of: find.byType(tur), matching: bulucu);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  group('yardımcılar', () {
    test('katalog fikstüründe misafir alan yazboz kullanan türler var', () {
      expect(misafirBileseni(testTuru('board_game_night')), 'scoreboard');
      expect(misafirBileseni(testTuru('chess')), 'scoreboard');
      // Takım masası olan yazboz misafir almaz.
      expect(misafirBileseni(testTuru('team_sport')), isNull);
    });

    test('takma ad: boşluk atılır, 1–24 karakter', () {
      expect(misafirAdiTemiz('  Deniz '), 'Deniz');
      expect(misafirAdiTemiz('   '), isNull);
      expect(misafirAdiTemiz('a' * 24), 'a' * 24);
      expect(misafirAdiTemiz('a' * 25), isNull);
    });
  });

  group('yazboz', () {
    const kayit = <EtkinlikBileseni>[YazbozBileseni()];

    for (final tema in _temalar) {
      testWidgets('misafir "Misafir" etiketiyle, adsız misafir adsız görünür '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          tur: 'board_game_night',
          yanitlar: {
            'GET $yazbozYolu': (_) => yazbozJson(
              masalar: [
                yazbozMasasiJson(
                  id: _masa,
                  yerler: [
                    yazbozYeriJson(_yer1, 1, kisi: katilimciId),
                    yazbozYeriJson(_yer2, 2, misafir: _deniz),
                    yazbozYeriJson(_yer3, 3, misafir: _adsiz),
                  ],
                  siralama: [
                    _sira(_yer1, 1),
                    _sira(_yer2, 1),
                    _sira(_yer3, 1),
                  ],
                ),
              ],
            ),
            'GET $misafirlerYolu': (_) => misafirlerJson(
              misafirler: [misafirJson(_deniz, ad: 'Deniz'), misafirJson(_adsiz)],
            ),
          },
        );
        await _detayiAc(tester, tasima, kayit, themeMode: tema);

        final deniz = _icinde(YazbozBolumu, find.text('Deniz'));
        await _gorunurYap(tester, deniz);
        expect(deniz, findsOneWidget);
        expect(
          _icinde(YazbozBolumu, find.textContaining(m.bilesen_guest_etiket)),
          findsWidgets,
        );
        expect(
          _icinde(YazbozBolumu, find.text(m.bilesen_guest_adsiz)),
          findsOneWidget,
        );
        expect(tasima.giden('GET', misafirlerYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'scoreboard',
        });
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('organizatör misafir ekler ve masaya oturtur '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          tur: 'board_game_night',
          ben: organizatorId,
          yanitlar: {
            'GET $yazbozYolu': (_) => yazbozJson(yonetebilir: true),
            'GET $misafirlerYolu': (_) => misafirlerJson(
              misafirler: [misafirJson(_deniz, ad: 'Deniz')],
              ekleyebilir: true,
              silebilir: true,
            ),
            'POST $misafirlerYolu': (_) => misafirlerJson(
              misafirler: [
                misafirJson(_deniz, ad: 'Deniz'),
                misafirJson(_ece, ad: 'Ece'),
              ],
              ekleyebilir: true,
              silebilir: true,
            ),
            'POST $yazbozMasalariYolu': (_) => yazbozJson(yonetebilir: true),
          },
        );
        await _detayiAc(tester, tasima, kayit, themeMode: tema);

        final masaAc = _icinde(
          YazbozBolumu,
          find.text(m.bilesen_scoreboard_masa_ac),
        );
        await _gorunurYap(tester, masaAc);
        await _dokun(tester, masaAc);
        expect(find.byType(YazbozMasaFormu), findsOneWidget);
        expect(
          _icinde(YazbozMasaFormu, find.text(m.bilesen_guest_sayi(1, 30))),
          findsOneWidget,
        );

        await _dokun(tester, find.byKey(const ValueKey('yazboz-misafir-ekle')));
        expect(find.byType(MisafirFormu), findsOneWidget);
        final alan = find.byKey(const ValueKey('misafir-takma-ad'));
        final ekle = _icinde(
          MisafirFormu,
          find.text(m.bilesen_guest_ekle_onay),
        );

        // Boş takma adla istek gitmez.
        await tester.enterText(alan, '   ');
        await _dokun(tester, ekle);
        expect(tasima.giden('POST', misafirlerYolu), isEmpty);
        expect(
          _icinde(MisafirFormu, find.text(m.bilesen_guest_ad_hatali)),
          findsOneWidget,
        );

        await tester.enterText(alan, ' Ece ');
        await _dokun(tester, ekle);
        expect(tasima.giden('POST', misafirlerYolu).single.govde, {
          'nickname': 'Ece',
        });
        expect(find.byType(MisafirFormu), findsNothing);
        // Eklenen misafir seçime girer.
        expect(
          _icinde(YazbozMasaFormu, find.text(m.bilesen_scoreboard_yer_no(1))),
          findsOneWidget,
        );

        await _dokun(tester, find.byKey(const ValueKey('yazboz-misafir-$_deniz')));
        await _dokun(
          tester,
          _icinde(YazbozMasaFormu, find.text(m.etkinlik_kaydet)),
        );
        final govde =
            tasima.giden('POST', yazbozMasalariYolu).single.govde
                as Map<String, Object?>;
        expect(govde['players'], [
          {'guest_id': _ece},
          {'guest_id': _deniz},
        ]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('yöneticinin silmesi; yeri olan misafirde sunucunun hatası', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var silindi = false;
      final tasima = _tasima(
        tur: 'board_game_night',
        ben: organizatorId,
        yanitlar: {
          'GET $yazbozYolu': (_) => yazbozJson(yonetebilir: true),
          'GET $misafirlerYolu': (_) => misafirlerJson(
            misafirler: [
              misafirJson(_deniz, ad: 'Deniz'),
              if (!silindi) misafirJson(_ece, ad: 'Ece'),
            ],
            ekleyebilir: true,
            silebilir: true,
          ),
          'DELETE $misafirYolu': (i) {
            if (i.yolParametreleri['guest_id'] == _deniz) {
              return const ApiProblem(
                type: ProblemType.guestPlayerInUse,
                status: 409,
              );
            }
            silindi = true;
            return misafirlerJson(
              misafirler: [misafirJson(_deniz, ad: 'Deniz')],
              ekleyebilir: true,
              silebilir: true,
            );
          },
        },
      );
      await _detayiAc(tester, tasima, kayit);

      final masaAc = _icinde(
        YazbozBolumu,
        find.text(m.bilesen_scoreboard_masa_ac),
      );
      await _gorunurYap(tester, masaAc);
      await _dokun(tester, masaAc);

      await _dokun(
        tester,
        find.byKey(const ValueKey('yazboz-misafir-sil-$_ece')),
      );
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(m.bilesen_guest_sil),
        ),
      );
      expect(
        tasima.giden('DELETE', misafirYolu).single.yolParametreleri['guest_id'],
        _ece,
      );
      expect(find.byKey(const ValueKey('yazboz-misafir-$_ece')), findsNothing);

      await _dokun(
        tester,
        find.byKey(const ValueKey('yazboz-misafir-sil-$_deniz')),
      );
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(m.bilesen_guest_sil),
        ),
      );
      expect(find.text(m.hata_guest_player_in_use), findsOneWidget);
      expect(
        find.byKey(const ValueKey('yazboz-misafir-$_deniz')),
        findsOneWidget,
      );
    });
  });

  group('kura ve eşleşme ağacı', () {
    for (final tema in _temalar) {
      testWidgets('kurada misafir "Misafir" etiketiyle, yeri boş sayılmaz '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          tur: 'chess',
          yanitlar: {
            'GET $kuraYolu': (_) => kuraJson(
              yerler: [
                kuraYeriJson(1, kisi: katilimciId),
                kuraYeriJson(2, misafir: _deniz),
              ],
              cekildi: '2026-11-20T11:05:00Z',
            ),
            'GET $misafirlerYolu': (_) => misafirlerJson(
              misafirler: [misafirJson(_deniz, ad: 'Deniz')],
            ),
          },
        );
        await _detayiAc(
          tester,
          tasima,
          const [
            KuraBileseni(),
            TemelBilesen('bracket'),
            TemelBilesen('scoreboard'),
          ],
          themeMode: tema,
        );

        final deniz = _icinde(KuraBolumu, find.text('Deniz'));
        await _gorunurYap(tester, deniz);
        expect(deniz, findsOneWidget);
        expect(
          _icinde(KuraBolumu, find.textContaining(m.bilesen_guest_etiket)),
          findsOneWidget,
        );
        expect(_icinde(KuraBolumu, find.text(m.bilesen_draw_bay)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('ağaçta misafirin adı "(misafir)" ile '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          tur: 'chess',
          yanitlar: {
            'GET $agacYolu': (_) => agacJson(
              basladi: true,
              cekildi: true,
              turlar: 1,
              mevcutTur: 1,
              yerler: [
                kuraYeriJson(1, kisi: katilimciId),
                kuraYeriJson(2, misafir: _deniz),
              ],
              maclar: [
                agacMaciJson(
                  id: _mac,
                  a: 1,
                  b: 2,
                  sonuclandi: true,
                  kazanan: 2,
                ),
              ],
              bitti: true,
              kazananlar: [2],
            ),
            'GET $kuraYolu': (_) => kuraJson(
              yerler: [
                kuraYeriJson(1, kisi: katilimciId),
                kuraYeriJson(2, misafir: _deniz),
              ],
              cekildi: '2026-11-20T11:05:00Z',
            ),
            'GET $misafirlerYolu': (_) => misafirlerJson(
              misafirler: [misafirJson(_deniz, ad: 'Deniz')],
            ),
          },
        );
        await _detayiAc(
          tester,
          tasima,
          const [
            AgacBileseni(),
            TemelBilesen('draw'),
            TemelBilesen('scoreboard'),
          ],
          themeMode: tema,
        );

        final ad = _icinde(
          AgacBolumu,
          find.textContaining(m.bilesen_guest_ad_metni('Deniz')),
        );
        await _gorunurYap(tester, ad.first);
        expect(ad, findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
