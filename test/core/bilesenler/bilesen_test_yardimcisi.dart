import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/odak_cercevesi.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Çeviri kaynağındaki (lib/l10n/app_tr.arb) bir anahtarın metni.
String arbMetni(String anahtar) {
  final kaynak = File('lib/l10n/app_tr.arb').readAsStringSync();
  final arb = jsonDecode(kaynak) as Map<String, Object?>;
  return arb[anahtar] as String;
}

/// Bileşen testlerinin denendiği iki tema.
const List<ThemeMode> temalar = [ThemeMode.light, ThemeMode.dark];

/// Temanın renk token'ları.
TayfamColors renklerOf(ThemeMode mod) {
  return mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;
}

/// Bileşeni en dar hedef ekranda (320×640 dp, ADR-0004), 2× yazı ölçeğinde
/// ve verilen temada açar. Taşma bir hata olarak raporlanır; çağıran
/// `tester.takeException()` ile denetler.
Future<void> bileseniAc(
  WidgetTester tester,
  Widget bilesen, {
  required ThemeMode mod,
  double yaziOlcegi = 2,
  bool hareketiAzalt = false,
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
        body: ListView(padding: const EdgeInsets.all(16), children: [bilesen]),
      ),
    ),
  );
  // Tekrarlayan animasyon (nabız) olabileceği için pumpAndSettle yok.
  await tester.pump();
}

/// Ekrandaki her dokunma hedefinin en az 48×48 (Android) ve etiketli
/// olduğunu, metnin kontrast eşiğini geçtiğini denetler.
Future<void> erisilebilirlikDenetle(WidgetTester tester) async {
  final kulp = tester.ensureSemantics();
  await tester.pump();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  kulp.dispose();
}

/// Bulunan öğenin dokunma alanı en az 44×44 mü (Standartlar; Material 48).
void dokunmaAlaniEnAz44(WidgetTester tester, Finder bulucu) {
  final boyut = tester.getSize(bulucu);
  expect(boyut.width, greaterThanOrEqualTo(44));
  expect(boyut.height, greaterThanOrEqualTo(44));
}

/// Her iki temada, 320 dp genişlikte ve 2× yazı ölçeğinde taşma olmadığını
/// ve dokunma/etiket/kontrast kurallarını denetleyen testleri kaydeder.
void ortakTestler(Widget Function() kur) {
  for (final mod in temalar) {
    testWidgets('${mod.name}: 2× yazı ölçeğinde taşma yok', (tester) async {
      await bileseniAc(tester, kur(), mod: mod);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${mod.name}: erişilebilirlik kuralları', (tester) async {
      await bileseniAc(tester, kur(), mod: mod);
      await erisilebilirlikDenetle(tester);
    });
  }
}

/// Klavyeyle (Tab) ilk odaklanabilir öğeye geçer ve 3 px mango odak
/// çerçevesinin çizildiğini denetler.
Future<void> odakCercevesiDenetle(
  WidgetTester tester,
  Widget bilesen, {
  required ThemeMode mod,
}) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });
  await bileseniAc(tester, bilesen, mod: mod);
  expect(find.byWidgetPredicate(_odakCercevesiMi), findsNothing);

  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();

  final cerceve = find.byWidgetPredicate(_odakCercevesiMi);
  expect(cerceve, findsOneWidget);
  final boya = tester.widget<CustomPaint>(cerceve);
  final boyaci = boya.foregroundPainter! as OdakBoyaci;
  expect(boyaci.renk, renklerOf(mod).mango);
  expect(boyaci.kalinlik, 3);
}

bool _odakCercevesiMi(Widget w) {
  return w is CustomPaint && w.foregroundPainter is OdakBoyaci;
}

/// Ekranda çizilen metnin etkin stili (DefaultTextStyle ile birleşmiş).
TextStyle cizilenStil(WidgetTester tester, Finder metin) {
  return tester.renderObject<RenderParagraph>(metin).text.style!;
}
