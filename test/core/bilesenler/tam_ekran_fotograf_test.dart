import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tam_ekran_fotograf.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'bilesen_test_yardimcisi.dart';

/// Sınamada görsel: sıraya göre renkli kutu.
Widget _kutu(BuildContext _, int sira) =>
    ColoredBox(key: ValueKey('gorsel-$sira'), color: const Color(0xFF808080));

/// Görüntüleyiciyi bir düğmeyle [tamEkranFotografAc] üzerinden açar; en
/// dar hedef ekran (320 dp) ve 2× yazı.
Future<void> _ac(
  WidgetTester tester,
  WidgetBuilder builder, {
  ThemeMode mod = ThemeMode.light,
  bool hareketiAzalt = false,
}) async {
  tester.view
    ..physicalSize = const Size(960, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
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
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => tamEkranFotografAc(context, builder: builder),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

/// Albüm biçimi: sayaç, ⋯, alt bilgi ve Önceki / Sonraki.
TamEkranFotograf _galeri({List<int>? degisenler, int sayi = 3}) =>
    TamEkranFotograf(
      sayi: sayi,
      ilkSira: 1,
      kapatIpucu: 'Kapat',
      baslikOrtada: true,
      baslik: (_, sira) => Text('${sira + 1} / $sayi'),
      eylemler: (_, sira) => [
        IconButton(
          tooltip: 'İşlemler',
          icon: const Icon(Icons.more_horiz),
          onPressed: () {},
        ),
      ],
      etiket: (sira) => 'Fotoğraf ${sira + 1}',
      gorsel: _kutu,
      altBilgi: (_, sira) => Text('Açıklama ${sira + 1}'),
      oncekiSonraki: (onceki: 'Önceki fotoğraf', sonraki: 'Sonraki fotoğraf'),
      sayfaDegisti: degisenler?.add,
    );

void main() {
  for (final mod in temalar) {
    testWidgets('${mod.name}: her temada koyu yüzey; galeri, 2× yazı, '
        '320 dp', (tester) async {
      await _ac(tester, (_) => _galeri(), mod: mod);
      expect(tester.takeException(), isNull);
      final iskele = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(TamEkranFotograf),
          matching: find.byType(Scaffold),
        ),
      );
      expect(iskele.backgroundColor, TayfamColors.koyu.zemin);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Açıklama 2'), findsOneWidget);
      expect(find.byTooltip('İşlemler'), findsOneWidget);
      await erisilebilirlikDenetle(tester);
    });

    testWidgets('${mod.name}: tek fotoğraf (sohbet biçimi), 2× yazı', (
      tester,
    ) async {
      await _ac(
        tester,
        (_) => TamEkranFotograf(
          sayi: 1,
          etiket: (_) => 'Fotoğraf',
          gorsel: (c, i) => Center(child: _kutu(c, i)),
          baslik: (_, _) => const Text('Ayşe · 10:00'),
        ),
        mod: mod,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ayşe · 10:00'), findsOneWidget);
      // Tek fotoğraf kaydırılmaz; Önceki / Sonraki yok.
      expect(find.byType(PageView), findsNothing);
      expect(find.byTooltip('Önceki fotoğraf'), findsNothing);
      // ✕ platformun "Kapat"ı.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(TamEkranFotograf), findsNothing);
    });
  }

  testWidgets('yakınlaştırma en çok 4×; görsel ekran okuyucuya etiketle', (
    tester,
  ) async {
    await _ac(tester, (_) => _galeri());
    final yakinlik = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(yakinlik.maxScale, TayfamSizes.fotografEnCokYakinlik);
    expect(find.bySemanticsLabel('Fotoğraf 2'), findsOneWidget);
  });

  testWidgets('Önceki / Sonraki sırayı değiştirir ve bildirir', (tester) async {
    final degisenler = <int>[];
    await _ac(tester, (_) => _galeri(degisenler: degisenler));
    await tester.tap(find.byTooltip('Sonraki fotoğraf'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Açıklama 3'), findsOneWidget);
    // Sonda "Sonraki" kapalı.
    final sonraki = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(sonraki.onPressed, isNull);
    await tester.tap(find.byTooltip('Önceki fotoğraf'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    expect(degisenler, [2, 1]);
  });

  testWidgets('hareketi azalt: Önceki animasyonsuz geçer', (tester) async {
    await _ac(tester, (_) => _galeri(), hareketiAzalt: true);
    await tester.tap(find.byTooltip('Önceki fotoğraf'));
    // Tek kare: animasyonlu geçişte sayfa henüz değişmemiş olurdu.
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('fotoğraf yoksa yalnızca ✕ (ipucu verilen metin)', (
    tester,
  ) async {
    await _ac(tester, (_) => _galeri(sayi: 0));
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byTooltip('Kapat'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.byType(TamEkranFotograf), findsNothing);
  });
}
