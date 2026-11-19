import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/sozluk_girisi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_ekranlari.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _kucukId = '3d4e5f6a-7b8c-4d9e-8f0a-2b3c4d5e6f7a';
const String _levrekId = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';

/// "levrek" (kopya) ve "Levrek"; birleştirilenlerde "levrek" → "Levrek".
SahteTayfaTasima _tasima({bool birlestirebilir = true}) =>
    etkinlikTasimasi({
      'GET $sozlukYolu': (i) => sozlukJson(
        birlestirebilir: birlestirebilir,
        degerler: i.sorgu['merged'] == 'true'
            ? [
                sozlukDegeriJson(
                  _kucukId,
                  'levrek',
                  hedefId: _levrekId,
                  hedef: 'Levrek',
                ),
              ]
            : [
                sozlukDegeriJson(_kucukId, 'levrek'),
                sozlukDegeriJson(_levrekId, 'Levrek'),
              ],
      ),
      'POST $sozlukBirlestirmeYolu': (_) => sozlukDegeriJson(
        _kucukId,
        'levrek',
        hedefId: _levrekId,
        hedef: 'Levrek',
      ),
      'DELETE $sozlukBirlestirmeYolu': (_) => null,
    });

Future<void> _sozluguAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  String adAlani = 'fish_species',
}) => widgetAc(
  tester,
  SozlukEkrani(tayfaId: ornekTayfaId, adAlani: adAlani),
  themeMode: themeMode,
  tayfa: etkinlikOverridelari(tasima: tasima),
);

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _dugme(String anahtar) =>
    find.widgetWithText(TextButton, arbMetni(anahtar));

void main() {
  test('katalog fikstüründe sözlük kullanan günlük alanları', () {
    final adAlanlari = sozlukAdAlanlari(testKatalogu());
    expect(
      adAlanlari.map((a) => a.adAlani),
      unorderedEquals(['fish_species', 'species']),
    );
    final balik = adAlanlari.singleWhere((a) => a.adAlani == 'fish_species');
    expect(balik.alan.key, 'species');
    expect(balik.turler.map((t) => t.key), ['fishing']);
    // Tür alanındaki (`fields`) sözlük günlük değildir; listelenmez.
    expect(adAlanlari.map((a) => a.adAlani), isNot(contains('ornek')));
  });

  group('sözlükler ekranı', () {
    for (final tema in _temalar) {
      testWidgets('ad alanları türleriyle (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await widgetAc(
          tester,
          const SozluklerEkrani(tayfaId: ornekTayfaId),
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: _tasima()),
        );
        expect(find.text(arbMetni('bilesen_vocab_baslik')), findsOneWidget);
        expect(find.text('Tür'), findsNWidgets(2));
        expect(find.text('Balıkçılık'), findsOneWidget);
        expect(find.text('Örnek bileşenler'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sözlük ekranı', () {
    for (final tema in _temalar) {
      testWidgets('birleştirme: hedef seçimi ve onay '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima();
        await _sozluguAc(tester, tasima, themeMode: tema);

        // Başlık alanın katalogdaki adı.
        expect(find.text('Tür'), findsOneWidget);
        expect(tasima.giden('GET', sozlukYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'namespace': 'fish_species',
        });
        expect(find.text('levrek'), findsOneWidget);
        expect(find.text('Levrek'), findsOneWidget);
        expect(_dugme('bilesen_vocab_birlestir'), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        await _dokun(tester, _dugme('bilesen_vocab_birlestir').first);
        final sayfa = find.byType(BottomSheet);
        expect(sayfa, findsOneWidget);
        // Kaynak hedef listesinde yok.
        expect(
          find.descendant(of: sayfa, matching: find.text('levrek')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await _dokun(
          tester,
          find.descendant(of: sayfa, matching: find.text('Levrek')),
        );
        expect(find.byType(BottomSheet), findsNothing);

        // Onay istatistiğin yeniden hesaplanacağını söyler.
        final pencere = find.byType(AlertDialog);
        expect(pencere, findsOneWidget);
        expect(
          find.descendant(
            of: pencere,
            matching: find.textContaining('“levrek”'),
          ),
          findsOneWidget,
        );
        expect(tasima.giden('POST', sozlukBirlestirmeYolu), isEmpty);
        await _dokun(
          tester,
          find.descendant(
            of: pencere,
            matching: find.text(arbMetni('bilesen_vocab_birlestir')),
          ),
        );
        final istek = tasima.giden('POST', sozlukBirlestirmeYolu).single;
        expect(istek.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'namespace': 'fish_species',
          'vocabulary_id': _kucukId,
        });
        expect(istek.govde, {'target_id': _levrekId});
        expect(
          find.text(arbMetni('bilesen_vocab_birlestirildi')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('birleştirilenler: hedefle gösterim ve geri alma '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima();
        await _sozluguAc(tester, tasima, themeMode: tema);

        await _dokun(tester, find.text(arbMetni('bilesen_vocab_birlesenler')));
        expect(
          tasima.giden('GET', sozlukYolu).last.sorgu,
          {'merged': 'true'},
        );
        expect(find.text('levrek'), findsOneWidget);
        expect(find.text('“Levrek” olarak görünüyor'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await _dokun(tester, _dugme('bilesen_vocab_geri_al'));
        final pencere = find.byType(AlertDialog);
        expect(pencere, findsOneWidget);
        await _dokun(
          tester,
          find.descendant(
            of: pencere,
            matching: find.text(arbMetni('bilesen_vocab_geri_al')),
          ),
        );
        expect(
          tasima.giden('DELETE', sozlukBirlestirmeYolu).single.yolParametreleri,
          {
            'tayfa_id': ornekTayfaId,
            'namespace': 'fish_species',
            'vocabulary_id': _kucukId,
          },
        );
        expect(
          find.text(arbMetni('bilesen_vocab_geri_alindi')),
          findsOneWidget,
        );
      });
    }

    testWidgets('arama 300 ms sonra `q` ile', (tester) async {
      final tasima = _tasima();
      await _sozluguAc(tester, tasima);
      await tester.enterText(find.byType(TextField), '  lev ');
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tasima.giden('GET', sozlukYolu).where((i) => i.sorgu.isNotEmpty),
        isEmpty,
      );
      await tester.pump(sozlukAramaGecikmesi);
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', sozlukYolu).last.sorgu, {'q': 'lev'});
    });

    testWidgets('yetkisi olmayana bilgi; düğme yok', (tester) async {
      await _sozluguAc(tester, _tasima(birlestirebilir: false));
      expect(find.text('Levrek'), findsOneWidget);
      expect(find.text(arbMetni('bilesen_vocab_yetki_yok')), findsOneWidget);
      expect(_dugme('bilesen_vocab_birlestir'), findsNothing);
    });

    testWidgets('sunucu hatası gösterilir', (tester) async {
      final tasima = _tasima();
      tasima.yanitlar['POST $sozlukBirlestirmeYolu'] = (_) =>
          const ApiProblem(type: ProblemType.vocabularyMerged, status: 409);
      await _sozluguAc(tester, tasima);
      await _dokun(tester, _dugme('bilesen_vocab_birlestir').first);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Levrek'),
        ),
      );
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('bilesen_vocab_birlestir')),
        ),
      );
      expect(find.text(arbMetni('hata_vocabulary_merged')), findsOneWidget);
    });

    testWidgets('adresteki ad alanı geçersizse istek yok', (tester) async {
      final tasima = _tasima();
      await _sozluguAc(tester, tasima, adAlani: 'Kötü-ad');
      expect(find.text(arbMetni('bilesen_vocab_gecersiz')), findsOneWidget);
      expect(tasima.giden('GET', sozlukYolu), isEmpty);
    });
  });
}
