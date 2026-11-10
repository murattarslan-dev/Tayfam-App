import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/tayfa/tayfa.dart';

import 'yardimcilar.dart';

void main() {
  testWidgets('uygulama Türkçe açılıyor; tayfası yokken karşılama', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    final context = tester.element(find.byType(KarsilamaEkrani));
    expect(Localizations.localeOf(context).languageCode, 'tr');
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    final beklenen = mod == ThemeMode.dark ? Brightness.dark : Brightness.light;

    testWidgets('${mod.name} temada 2× yazı ölçeğinde taşma yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      ikiKatYazi(tester);

      await uygulamayiAc(tester, themeMode: mod);

      final context = tester.element(find.byType(KarsilamaEkrani));
      expect(Theme.of(context).brightness, beklenen);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      // Taşma (RenderFlex overflow vb.) bir hata olarak raporlanır.
      expect(tester.takeException(), isNull);
    });
  }
}
