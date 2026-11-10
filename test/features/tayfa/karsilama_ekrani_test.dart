import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _bekleyenId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

const _turAnahtarlari = [
  'karsilama_tur_konvoy',
  'karsilama_tur_kamp',
  'karsilama_tur_yuruyus',
  'karsilama_tur_balik',
  'karsilama_tur_oyun',
  'karsilama_tur_spor',
];

void main() {
  testWidgets('karşılama iki eylemi ve altı türü gösteriyor', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(tester, const KarsilamaEkrani());

    expect(find.text(arbMetni('karsilama_baslik')), findsOneWidget);
    // Eylemler ortak bileşenlerdir (ADR-0004 §3).
    expect(
      find.widgetWithText(BirincilEylem, arbMetni('karsilama_kodum_var')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(IkincilEylem, arbMetni('karsilama_tayfa_olustur')),
      findsOneWidget,
    );
    for (final anahtar in _turAnahtarlari) {
      expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
    }
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name}: tür hapları brand, nar ve mango', (tester) async {
      final r = mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;
      ekranBoyutu(tester);
      await widgetAc(tester, const KarsilamaEkrani(), themeMode: mod);

      final kutular = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(TurVurgusu),
          matching: find.byType(DecoratedBox),
        ),
      );
      final zeminler = {
        for (final kutu in kutular) (kutu.decoration as BoxDecoration).color,
      };
      expect(zeminler, {r.markaYuzey, r.nar, r.mango});
      for (final kutu in kutular) {
        expect(
          (kutu.decoration as BoxDecoration).borderRadius,
          TayfamRadii.hapKoseleri,
        );
      }
    });
  }

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name}: klavye odağında temanın odak rengi', (
      tester,
    ) async {
      final r = mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });
      ekranBoyutu(tester);
      await widgetAc(tester, const KarsilamaEkrani(), themeMode: mod);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final cerceve = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is OdakBoyaci,
      );
      expect(cerceve, findsOneWidget);
      final boya = tester.widget<CustomPaint>(cerceve);
      final boyaci = boya.foregroundPainter! as OdakBoyaci;
      // Açık temada brand, koyu temada mango (ADR-0004 Notlar).
      expect(boyaci.renk, r.odak);
      expect(boyaci.renk, mod == ThemeMode.dark ? r.mango : r.marka);
    });
  }

  testWidgets('"Tayfa kodum var" katılım sayfasını alttan açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    await tester.tap(find.text(arbMetni('karsilama_kodum_var')));
    await tester.pumpAndSettle();

    expect(find.byType(KodlaKatilmaSayfasi), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('"Tayfa oluştur" sihirbazı açıyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    await tester.tap(find.text(arbMetni('karsilama_tayfa_olustur')));
    await tester.pumpAndSettle();

    // Sihirbaz kabuğun üstüne itilen tam ekran bir sayfadır.
    expect(find.byType(OlusturmaEkrani), findsOneWidget);
    expect(
      find.widgetWithText(AppBar, arbMetni('tayfa_olustur')),
      findsOneWidget,
    );
  });

  testWidgets('bekleyen istek için bilgi kartı; yalnızca ad', (tester) async {
    ekranBoyutu(tester);
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => listeJson([
        bekleyenJson(_bekleyenId, ad: 'Kampçılar'),
      ]),
    });
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: tasima));

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.byType(BekleyenIstekKarti), findsOneWidget);
    expect(find.text(arbMetni('karsilama_bekleyen_baslik')), findsOneWidget);
    expect(find.textContaining('Kampçılar'), findsOneWidget);
    // Bekleyen tayfanın içeriği istenmez.
    expect(tasima.giden('GET', '/v1/tayfas/{tayfa_id}'), isEmpty);
  });

  testWidgets('liste alınamazsa hata ve "Tekrar dene"', (tester) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? const ApiOffline()
          : listeJson([bekleyenJson(_bekleyenId)]),
    });
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: tasima));

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.byType(HataSatiri), findsOneWidget);

    await tester.tap(find.text(arbMetni('tayfa_tekrar_dene')));
    await tester.pumpAndSettle();

    expect(find.byType(HataSatiri), findsNothing);
    expect(find.byType(BekleyenIstekKarti), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    for (final genislik in [320.0, 360.0, 800.0]) {
      testWidgets(
        '${mod.name} temada ${genislik.toInt()} px, 2× yazıda taşma yok',
        (tester) async {
          ekranBoyutu(tester, genislik: genislik);
          ikiKatYazi(tester);
          await widgetAc(
            tester,
            const KarsilamaEkrani(),
            themeMode: mod,
            overrides: [
              oturumDurumuProvider.overrideWith(
                () => SabitOturumDurumu(OturumDurumu.acik),
              ),
            ],
            tayfa: tayfaOverridelari(
              tasima: SahteTayfaTasima({
                'GET /v1/tayfas': (_) => listeJson([
                  bekleyenJson(_bekleyenId, ad: 'Kamp ve doğa yürüyüşü'),
                ]),
              }),
            ),
          );
          expect(find.byType(BekleyenIstekKarti), findsOneWidget);

          final context = tester.element(find.byType(KarsilamaEkrani));
          expect(
            Theme.of(context).brightness,
            mod == ThemeMode.dark ? Brightness.dark : Brightness.light,
          );
          expect(MediaQuery.textScalerOf(context).scale(10), 20);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
