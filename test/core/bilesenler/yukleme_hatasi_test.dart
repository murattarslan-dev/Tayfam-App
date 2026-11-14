import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/yukleme_hatasi.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  group('YuklemeHatasi', () {
    ortakTestler(
      () => YuklemeHatasi(hata: const ApiOffline(), onTekrarDene: () {}),
    );

    testWidgets('bağlantı yok: başlık, ortak metin ve "Tekrar dene"', (
      tester,
    ) async {
      var deneme = 0;
      await bileseniAc(
        tester,
        YuklemeHatasi(hata: const ApiOffline(), onTekrarDene: () => deneme++),
        mod: ThemeMode.light,
      );
      expect(find.text(arbMetni('yukleme_hatasi_baslik')), findsOneWidget);
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      final dugme = find.text(arbMetni('yukleme_hatasi_tekrar_dene'));
      await tester.ensureVisible(dugme);
      await tester.pump();
      await tester.tap(dugme);
      expect(deneme, 1);
    });

    testWidgets('bilinmeyen hata genel metne düşer; sunucu metni yok', (
      tester,
    ) async {
      await bileseniAc(
        tester,
        YuklemeHatasi(hata: StateError('iç ayrıntı'), onTekrarDene: () {}),
        mod: ThemeMode.dark,
      );
      expect(find.text(arbMetni('hata_genel')), findsOneWidget);
      expect(find.textContaining('iç ayrıntı'), findsNothing);
    });

    testWidgets('problem type eşlemesi', (tester) async {
      await bileseniAc(
        tester,
        YuklemeHatasi(
          hata: const ApiProblem(type: ProblemType.moduleDisabled, status: 403),
          onTekrarDene: () {},
        ),
        mod: ThemeMode.light,
      );
      expect(find.text(arbMetni('hata_module_disabled')), findsOneWidget);
    });
  });

  group('yenilemeHatasiBildir', () {
    Future<void> ac(WidgetTester tester, Object hata, VoidCallback dene) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr', 'TR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: TayfamTheme.acik(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    yenilemeHatasiBildir(context, hata, tekrarDene: dene),
                child: const Text('dolu liste'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('dolu liste'));
      await tester.pumpAndSettle();
    }

    testWidgets('içerik yerinde, alttan bildirim ve "Tekrar dene"', (
      tester,
    ) async {
      var deneme = 0;
      await ac(tester, const ApiOffline(), () => deneme++);
      expect(find.text('dolu liste'), findsOneWidget);
      expect(
        find.text(arbMetni('yenileme_hatasi_baglanti_yok')),
        findsOneWidget,
      );
      await tester.tap(find.text(arbMetni('yukleme_hatasi_tekrar_dene')));
      expect(deneme, 1);
    });

    testWidgets('diğer hatalarda ortak metin eklenir', (tester) async {
      await ac(tester, const ApiTimeout(), () {});
      expect(
        find.text(
          arbMetni('yenileme_hatasi')
              .replaceFirst('{neden}', arbMetni('hata_zaman_asimi')),
        ),
        findsOneWidget,
      );
    });
  });
}
