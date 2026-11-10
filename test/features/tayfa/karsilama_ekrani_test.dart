import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';

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
    expect(
      find.widgetWithText(FilledButton, arbMetni('karsilama_kodum_var')),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, arbMetni('karsilama_tayfa_olustur')),
      findsOneWidget,
    );
    for (final anahtar in _turAnahtarlari) {
      expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
    }
  });

  testWidgets('tür hapları birden çok renk kullanıyor', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(tester, const KarsilamaEkrani());

    final zeminler = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(TurVurgusu),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((kutu) => (kutu.decoration as BoxDecoration).color)
        .toSet();
    expect(zeminler.length, greaterThan(1));
  });

  testWidgets('"Tayfa kodum var" kodla katılma akışını açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    await tester.tap(find.text(arbMetni('karsilama_kodum_var')));
    await tester.pumpAndSettle();

    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/tayfa-katil',
    );
    expect(find.text(arbMetni('tayfa_kodla_katil')), findsOneWidget);
  });

  testWidgets('"Tayfa oluştur" oluşturma akışını açıyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    await tester.tap(find.text(arbMetni('karsilama_tayfa_olustur')));
    await tester.pumpAndSettle();

    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/tayfa-olustur',
    );
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    for (final genislik in [320.0, 360.0, 800.0]) {
      testWidgets(
        '${mod.name} temada ${genislik.toInt()} px, 2× yazıda taşma yok',
        (tester) async {
          ekranBoyutu(tester, genislik: genislik);
          ikiKatYazi(tester);
          await widgetAc(tester, const KarsilamaEkrani(), themeMode: mod);

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
