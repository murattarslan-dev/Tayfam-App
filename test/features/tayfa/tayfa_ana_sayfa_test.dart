import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';

final Finder _tayfaAdiDugmesi = find.descendant(
  of: find.byType(TayfaUstBolumu),
  matching: find.byType(TextButton),
);

void main() {
  testWidgets('ad bilinmiyorken genel başlık gösteriliyor', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(tester, const TayfaAnaSayfa(tayfaId: ornekTayfaId));

    expect(find.text(arbMetni('tayfa_adi_bilinmiyor')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_ana_sayfa_bos')), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    final r = mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;

    testWidgets('${mod.name}: üst bölüm brand zemin, beyaz ad', (tester) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const TayfaAnaSayfa(tayfaId: ornekTayfaId),
        themeMode: mod,
        overrides: [tayfaAdiProvider.overrideWith((ref, id) => 'Klasikçiler')],
      );

      // Mor yüzey ortak bileşenle çizilir; iki temada da brand (§2a).
      expect(
        find.descendant(
          of: find.byType(TayfaUstBolumu),
          matching: find.byType(MarkaYuzeyi),
        ),
        findsOneWidget,
      );
      final zemin = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(TayfaUstBolumu),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(zemin.color, r.markaYuzey);

      final ad = tester.widget<RichText>(
        find.descendant(
          of: find.text('Klasikçiler'),
          matching: find.byType(RichText),
        ),
      );
      expect(ad.text.style?.color, r.markaYuzeyUstu);
    });

    testWidgets('${mod.name}: tayfa adında mango odak çerçevesi', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const TayfaAnaSayfa(tayfaId: ornekTayfaId),
        themeMode: mod,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final cerceve = find.descendant(
        of: find.byType(TayfaUstBolumu),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is OdakBoyaci,
        ),
      );
      expect(cerceve, findsOneWidget);
      final boya = tester.widget<CustomPaint>(cerceve);
      final boyaci = boya.foregroundPainter! as OdakBoyaci;
      // Mor yüzeyde iki temada da mango (ADR-0004 Notlar, 2026-11-10).
      expect(boyaci.renk, r.mango);
      expect(boyaci.kalinlik, 3);
    });

    testWidgets('${mod.name}: panel mor yüzeyin odak rengini almıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const TayfaAnaSayfa(tayfaId: ornekTayfaId),
        themeMode: mod,
      );

      await tester.tap(_tayfaAdiDugmesi);
      await tester.pumpAndSettle();

      final panel = tester.element(find.byType(TayfaDegistirmePaneli));
      expect(panel.renkler.odak, r.odak);
    });
  }

  testWidgets('tayfa adına dokununca değiştirme paneli açılıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await widgetAc(tester, const TayfaAnaSayfa(tayfaId: ornekTayfaId));

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();

    expect(find.byType(TayfaDegistirmePaneli), findsOneWidget);
    expect(find.text(arbMetni('tayfa_tayfalarim')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_tayfalarim_bos')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_kodla_katil')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_olustur')), findsOneWidget);
  });

  testWidgets('paneldeki "Kodla katıl" paneli kapatıp akışı açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('tayfa_kodla_katil')));
    await tester.pumpAndSettle();

    expect(find.byType(TayfaDegistirmePaneli), findsNothing);
    // Akış kabuğun üstüne itilen tam ekran bir sayfadır.
    expect(
      find.widgetWithText(AppBar, arbMetni('tayfa_kodla_katil')),
      findsOneWidget,
    );

    // Geri dönünce tayfanın ana sayfası yerinde.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
  });

  testWidgets('paneldeki "Tayfa oluştur" oluşturma akışını açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('tayfa_olustur')));
    await tester.pumpAndSettle();

    // Akış kabuğun üstüne itilen tam ekran bir sayfadır.
    expect(
      find.widgetWithText(AppBar, arbMetni('tayfa_olustur')),
      findsOneWidget,
    );
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda sayfa ve panel taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await widgetAc(
        tester,
        const TayfaAnaSayfa(tayfaId: ornekTayfaId),
        themeMode: mod,
        overrides: [
          tayfaAdiProvider.overrideWith(
            (ref, id) => 'Çok uzun adlı bir klasik otomobil tayfası',
          ),
        ],
      );
      expect(tester.takeException(), isNull);

      await tester.tap(_tayfaAdiDugmesi);
      await tester.pumpAndSettle();
      expect(find.byType(TayfaDegistirmePaneli), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
