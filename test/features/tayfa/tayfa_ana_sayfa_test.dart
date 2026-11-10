import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
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

  testWidgets('üst bölüm mor (primary) zemin, onPrimary metin', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const TayfaAnaSayfa(tayfaId: ornekTayfaId),
      overrides: [tayfaAdiProvider.overrideWith((ref, id) => 'Klasikçiler')],
    );

    final context = tester.element(find.byType(TayfaUstBolumu));
    final renkler = Theme.of(context).colorScheme;
    final zemin = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(TayfaUstBolumu),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(zemin.color, renkler.primary);

    final ad = tester.widget<RichText>(
      find.descendant(
        of: find.text('Klasikçiler'),
        matching: find.byType(RichText),
      ),
    );
    expect(ad.text.style?.color, renkler.onPrimary);
  });

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
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/tayfa-katil',
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

    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/tayfa-olustur',
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
