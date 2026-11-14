import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/baglanti/baglanti_bandi.dart';
import 'package:tayfam/core/baglanti/baglanti_durumu.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../bilesenler/bilesen_test_yardimcisi.dart';

final class _SahteBant extends BaglantiYokNotifier {
  @override
  bool build() => false;

  void ayarla(bool deger) => state = deger;
}

final class _SahteBaglaniyor extends SohbetBaglaniyorNotifier {
  @override
  bool build() => false;

  void ayarla(bool deger) => state = deger;
}

/// İçerik: kaydırma durumu korunuyor mu diye sayaçlı bir durum.
class _Icerik extends StatefulWidget {
  const _Icerik();

  @override
  State<_Icerik> createState() => _IcerikState();
}

class _IcerikState extends State<_Icerik> {
  int sayac = 0;

  @override
  Widget build(BuildContext context) => Text('içerik $sayac');
}

Future<ProviderContainer> _ac(
  WidgetTester tester, {
  ThemeMode mod = ThemeMode.light,
  bool hareketiAzalt = false,
}) async {
  tester.view
    ..physicalSize = const Size(960, 1920)
    ..devicePixelRatio = 3
    ..padding = const FakeViewPadding(top: 72);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (hareketiAzalt) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final kap = ProviderContainer(
    overrides: [
      baglantiYokProvider.overrideWith(_SahteBant.new),
      sohbetBaglaniyorProvider.overrideWith(_SahteBaglaniyor.new),
    ],
  );
  addTearDown(kap.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: kap,
      child: MaterialApp(
        locale: const Locale('tr', 'TR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: TayfamTheme.acik(),
        darkTheme: TayfamTheme.koyu(),
        themeMode: mod,
        home: const Scaffold(
          body: BaglantiBandi(
            child: Column(
              children: [
                _Icerik(),
                BaglaniyorSatiri(child: Text('alt satır')),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return kap;
}

void main() {
  final bant = find.text(arbMetni('baglanti_yok_bandi'));
  final baglaniyor = find.text(arbMetni('baglanti_baglaniyor'));

  testWidgets('bağlantı hatasıyla görünür, içerik aşağı kayar; başarılı '
      'istekte kaybolur, içerik korunur', (tester) async {
    final kap = await _ac(tester);
    final bantNotifier = kap.read(baglantiYokProvider.notifier) as _SahteBant;
    expect(bant, findsNothing);
    final ilkUst = tester.getTopLeft(find.byType(_Icerik)).dy;
    tester.state<_IcerikState>(find.byType(_Icerik)).sayac = 7;

    bantNotifier.ayarla(true);
    await tester.pump();
    expect(bant, findsOneWidget);
    // Bant durum çubuğunun altında, içerik bandın altında.
    // 72 fiziksel piksel = 24 dp durum çubuğu.
    expect(tester.getTopLeft(bant).dy, greaterThanOrEqualTo(24));
    expect(
      tester.getTopLeft(find.byType(_Icerik)).dy,
      greaterThan(tester.getBottomLeft(bant).dy - 1),
    );
    expect(tester.getTopLeft(find.byType(_Icerik)).dy, greaterThan(ilkUst));

    bantNotifier.ayarla(false);
    await tester.pump();
    expect(bant, findsNothing);
    expect(tester.getTopLeft(find.byType(_Icerik)).dy, ilkUst);
    // Gezinme yığınları yeniden kurulmadı.
    expect(tester.state<_IcerikState>(find.byType(_Icerik)).sayac, 7);
  });

  testWidgets('ekran okuyucu bandı bir kez durum olarak okur', (tester) async {
    final kulp = tester.ensureSemantics();
    final kap = await _ac(tester);
    (kap.read(baglantiYokProvider.notifier) as _SahteBant).ayarla(true);
    await tester.pump();
    expect(
      find.semantics.byPredicate(
        (n) =>
            n.label == arbMetni('baglanti_yok_bandi') &&
            n.getSemanticsData().flagsCollection.isLiveRegion,
      ),
      findsOne,
    );
    kulp.dispose();
  });

  testWidgets('"Bağlanıyor…" alt satırın yerini alır ve geri döner', (
    tester,
  ) async {
    final kap = await _ac(tester);
    final n = kap.read(sohbetBaglaniyorProvider.notifier) as _SahteBaglaniyor;
    expect(find.text('alt satır'), findsOneWidget);
    expect(baglaniyor, findsNothing);
    n.ayarla(true);
    await tester.pump();
    expect(baglaniyor, findsOneWidget);
    expect(find.text('alt satır'), findsNothing);
    n.ayarla(false);
    await tester.pump();
    expect(baglaniyor, findsNothing);
    expect(find.text('alt satır'), findsOneWidget);
  });

  testWidgets('hareketi azalt: "Bağlanıyor…" ikonu dönmez', (tester) async {
    final kap = await _ac(tester, hareketiAzalt: true);
    (kap.read(sohbetBaglaniyorProvider.notifier) as _SahteBaglaniyor).ayarla(
      true,
    );
    await tester.pump();
    final donus = tester.widget<RotationTransition>(
      find.descendant(
        of: find.byType(BaglaniyorSatiri),
        matching: find.byType(RotationTransition),
      ),
    );
    final once = donus.turns.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(donus.turns.value, once);
  });

  for (final mod in temalar) {
    testWidgets('${mod.name}: 2× yazı, 320 dp; bant ve "Bağlanıyor…" '
        'taşmıyor', (tester) async {
      final kap = await _ac(tester, mod: mod);
      (kap.read(baglantiYokProvider.notifier) as _SahteBant).ayarla(true);
      (kap.read(sohbetBaglaniyorProvider.notifier) as _SahteBaglaniyor).ayarla(
        true,
      );
      await tester.pump();
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(bant, findsOneWidget);
      expect(baglaniyor, findsOneWidget);
      expect(tester.takeException(), isNull);
      // Bant metni zeminle yeterli kontrastta.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
