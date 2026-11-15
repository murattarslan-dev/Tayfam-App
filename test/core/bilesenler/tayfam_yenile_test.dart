import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/bilesenler/tayfam_yenile.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'bilesen_test_yardimcisi.dart';

/// Yenileme sayacı; [tut] verilirse iş o tamamlanana kadar sürer.
final class _Yenileme {
  int sayi = 0;
  Completer<void>? tut;

  Future<void> call() {
    sayi++;
    return tut?.future ?? Future<void>.value();
  }
}

Future<void> _ac(
  WidgetTester tester,
  _Yenileme yenileme, {
  ThemeMode mod = ThemeMode.light,
  double yaziOlcegi = 1,
  bool hareketiAzalt = false,
  Color? zemin,
}) async {
  tester.view
    ..physicalSize = const Size(960, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = yaziOlcegi;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (hareketiAzalt) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr', 'TR'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: TayfamTheme.acik(),
      darkTheme: TayfamTheme.koyu(),
      themeMode: mod,
      home: Scaffold(
        appBar: AppBar(title: const Text('Başlık')),
        body: TayfamYenile(
          onRefresh: yenileme.call,
          zemin: zemin,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(key: ValueKey(i), height: 60, child: Text('Satır $i')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Listeyi parmakla [mesafe] kadar aşağı çeker; bırakmaz.
Future<TestGesture> _cek(WidgetTester tester, double mesafe) async {
  final g = await tester.startGesture(tester.getCenter(find.byType(ListView)));
  const adim = 10.0;
  for (var d = 0.0; d < mesafe; d += adim) {
    await g.moveBy(const Offset(0, adim));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return g;
}

double _ilkSatirUstu(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey(0))).dy;

double _listeUstu(WidgetTester tester) =>
    tester.getTopLeft(find.byType(TayfamYenile)).dy;

void main() {
  group('blokların sırası', () {
    test('mango → nar → turkuaz → L, ilerlemeyi dörde bölerek', () {
      expect(yenileBlokIlerlemesi(LogoBlogu.mango, .125), closeTo(.5, 1e-9));
      expect(yenileBlokIlerlemesi(LogoBlogu.nar, .125), 0);
      expect(yenileBlokIlerlemesi(LogoBlogu.mango, .5), 1);
      expect(yenileBlokIlerlemesi(LogoBlogu.nar, .5), 1);
      expect(yenileBlokIlerlemesi(LogoBlogu.turkuaz, .5), 0);
      expect(yenileBlokIlerlemesi(LogoBlogu.l, .875), closeTo(.5, 1e-9));
      for (final blok in LogoBlogu.values) {
        expect(yenileBlokIlerlemesi(blok, 1), 1, reason: blok.name);
        expect(yenileBlokIlerlemesi(blok, 2), 1, reason: blok.name);
      }
    });

    test('hareketi azalt: ara hal yok', () {
      expect(yenileBlokIlerlemesi(LogoBlogu.mango, .125, adimli: true), 0);
      expect(yenileBlokIlerlemesi(LogoBlogu.mango, .25, adimli: true), 1);
    });
  });

  testWidgets('eşik altında bırakınca onRefresh çağrılmıyor', (tester) async {
    final yenileme = _Yenileme();
    await _ac(tester, yenileme);
    final g = await _cek(tester, 60);
    expect(find.text(arbMetni('bilesen_yenile_cek')), findsOneWidget);
    expect(find.text(arbMetni('bilesen_yenile_birak')), findsNothing);
    await g.up();
    await tester.pumpAndSettle();

    expect(yenileme.sayi, 0);
    expect(_ilkSatirUstu(tester), _listeUstu(tester));
    expect(find.byType(TayfamYukleniyor), findsNothing);
  });

  testWidgets('eşik üstünde bir kez yeniliyor, bitince içerik yerinde', (
    tester,
  ) async {
    final titresim = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (cagri) async {
        if (cagri.method == 'HapticFeedback.vibrate') {
          titresim.add(cagri.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final yenileme = _Yenileme()..tut = Completer<void>();
    await _ac(tester, yenileme);
    final ust = _listeUstu(tester);

    final g = await _cek(tester, 300);
    expect(
      _ilkSatirUstu(tester) - ust,
      greaterThanOrEqualTo(TayfamSizes.yenileEsigi),
    );
    expect(find.text(arbMetni('bilesen_yenile_birak')), findsOneWidget);
    expect(titresim, ['HapticFeedbackType.lightImpact']);
    await g.up();

    // Geri sekme biter, boşluk 72 dp'de durur; Dalga oynar.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(yenileme.sayi, 1);
    expect(_ilkSatirUstu(tester) - ust, closeTo(TayfamSizes.yenileBoslugu, 1));
    expect(find.byType(TayfamYukleniyor), findsOneWidget);
    expect(find.text(arbMetni('bilesen_yenile_birak')), findsNothing);

    yenileme.tut!.complete();
    await tester.pumpAndSettle();
    expect(yenileme.sayi, 1);
    expect(_ilkSatirUstu(tester), ust);
    expect(find.byType(TayfamYukleniyor), findsNothing);
  });

  testWidgets('hareketi azalt: statik logo ve "Yükleniyor"', (tester) async {
    final yenileme = _Yenileme()..tut = Completer<void>();
    await _ac(tester, yenileme, hareketiAzalt: true);
    final g = await _cek(tester, 60);
    final boyaci =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CekmeLogosuBoyaci,
                  ),
                )
                .painter!
            as CekmeLogosuBoyaci;
    expect(boyaci.adimli, isTrue);
    await g.up();
    await tester.pumpAndSettle();

    final g2 = await _cek(tester, 300);
    await g2.up();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(yenileme.sayi, 1);
    expect(find.text(arbMetni('bilesen_yukleniyor')), findsOneWidget);
    // Dalga durur: logo hep aynı çizilir.
    final logo = find.descendant(
      of: find.byType(TayfamYukleniyor),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is LogoBoyaci,
      ),
    );
    LogoBoyaci cizilen() =>
        tester.widget<CustomPaint>(logo).painter! as LogoBoyaci;
    expect(cizilen().haller, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(cizilen().haller, isEmpty);

    yenileme.tut!.complete();
    await tester.pump();
    await tester.pump();
    // Dönüş anında.
    expect(_ilkSatirUstu(tester), _listeUstu(tester));
    await tester.pumpAndSettle();
  });

  testWidgets('mor zemin: boşluk mor, L beyaz', (tester) async {
    final mor = TayfamColors.acik.markaYuzey;
    final yenileme = _Yenileme()..tut = Completer<void>();
    await _ac(tester, yenileme, zemin: mor);
    final g = await _cek(tester, 300);
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == mor),
      findsOneWidget,
    );
    final cekme =
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is CekmeLogosuBoyaci,
                  ),
                )
                .painter!
            as CekmeLogosuBoyaci;
    expect(cekme.renkler.l, TayfamLogoRenkleri.lMorZemin);
    await g.up();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.widget<TayfamYukleniyor>(find.byType(TayfamYukleniyor)).zemin,
      mor,
    );
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == mor),
      findsOneWidget,
    );
    yenileme.tut!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('ekran okuyucu: "Yenile" eylemi, "Yükleniyor" bir kez', (
    tester,
  ) async {
    final kulp = tester.ensureSemantics();
    final yenileme = _Yenileme()..tut = Completer<void>();
    await _ac(tester, yenileme);

    tester.semantics.customAction(
      find.semantics.byAction(SemanticsAction.customAction),
      CustomSemanticsAction(label: arbMetni('bilesen_yenile')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(yenileme.sayi, 1);
    expect(
      _ilkSatirUstu(tester) - _listeUstu(tester),
      closeTo(TayfamSizes.yenileBoslugu, 1),
    );
    final canli = find.semantics.byPredicate(
      (n) =>
          n.label == arbMetni('bilesen_yukleniyor') &&
          n.getSemanticsData().flagsCollection.isLiveRegion,
    );
    expect(canli, findsOne);

    // Yenilenirken ikinci istek yok sayılır.
    tester.semantics.customAction(
      find.semantics.byAction(SemanticsAction.customAction),
      CustomSemanticsAction(label: arbMetni('bilesen_yenile')),
    );
    await tester.pump();
    expect(yenileme.sayi, 1);

    yenileme.tut!.complete();
    await tester.pumpAndSettle();
    expect(_ilkSatirUstu(tester), _listeUstu(tester));
    kulp.dispose();
  });

  for (final mod in temalar) {
    for (final hareketiAzalt in [false, true]) {
      testWidgets(
        '${mod.name}${hareketiAzalt ? ', hareketi azalt' : ''}: 2× yazı, '
        '320 dp; çekerken, eşikte ve yenilenirken taşma yok',
        (tester) async {
          final yenileme = _Yenileme()..tut = Completer<void>();
          await _ac(
            tester,
            yenileme,
            mod: mod,
            yaziOlcegi: 2,
            hareketiAzalt: hareketiAzalt,
          );
          expect(tester.getSize(find.byType(TayfamYenile)).width, 320);
          final g = await _cek(tester, 60);
          expect(tester.takeException(), isNull);
          await g.moveBy(const Offset(0, 300));
          await tester.pump();
          expect(find.text(arbMetni('bilesen_yenile_birak')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await g.up();
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(tester.takeException(), isNull);
          yenileme.tut!.complete();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
