import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/app.dart';

/// Çeviri kaynağındaki (lib/l10n/app_tr.arb) bir anahtarın metni. Test,
/// ekrandaki metnin koda gömülü değil bu dosyadan geldiğini doğrular.
String arbMetni(String anahtar) {
  final kaynak = File('lib/l10n/app_tr.arb').readAsStringSync();
  final arb = jsonDecode(kaynak) as Map<String, Object?>;
  return arb[anahtar] as String;
}

/// Küçük bir telefon ekranı (360×640 dp) kurar ve test sonunda geri alır.
void telefonEkrani(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1080, 1920)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> uygulamayiAc(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(child: TayfamApp(themeMode: themeMode)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('uygulama açılıyor ve karşılama metni çeviri dosyasından geliyor',
      (tester) async {
    telefonEkrani(tester);
    await uygulamayiAc(tester);

    expect(find.text(arbMetni('karsilama_metni')), findsOneWidget);

    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context).languageCode, 'tr');
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    final beklenen =
        mod == ThemeMode.dark ? Brightness.dark : Brightness.light;

    testWidgets('${mod.name} temada 2× yazı ölçeğinde taşma yok',
        (tester) async {
      telefonEkrani(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await uygulamayiAc(tester, themeMode: mod);

      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, beklenen);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(find.text(arbMetni('karsilama_metni')), findsOneWidget);
      // Taşma (RenderFlex overflow vb.) bir hata olarak raporlanır.
      expect(tester.takeException(), isNull);
    });
  }
}
