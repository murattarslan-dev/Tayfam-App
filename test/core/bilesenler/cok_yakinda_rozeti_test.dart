import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/cok_yakinda_rozeti.dart';

import 'bilesen_test_yardimcisi.dart';

double _saydamlik(WidgetTester tester) {
  final gecis = tester.widget<FadeTransition>(
    find.descendant(
      of: find.byType(CokYakindaRozeti),
      matching: find.byType(FadeTransition),
    ),
  );
  return gecis.opacity.value;
}

void main() {
  ortakTestler(() => const CokYakindaRozeti());

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('metin çeviri dosyasından, honey', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, const CokYakindaRozeti(), mod: mod);
        final metin = find.text(arbMetni('bilesen_cok_yakinda'));
        expect(metin, findsOneWidget);
        expect(cizilenStil(tester, metin).color, r.tintMangoUstu);
      });

      testWidgets('nokta nabız atar', (tester) async {
        await bileseniAc(tester, const CokYakindaRozeti(), mod: mod);
        final ilk = _saydamlik(tester);
        await tester.pump(const Duration(milliseconds: 800));
        expect(_saydamlik(tester), isNot(closeTo(ilk, 0.01)));
      });

      testWidgets('hareketi azalt: nokta sabit', (tester) async {
        await bileseniAc(
          tester,
          const CokYakindaRozeti(),
          mod: mod,
          hareketiAzalt: true,
        );
        expect(_saydamlik(tester), 1);
        await tester.pump(const Duration(milliseconds: 800));
        expect(_saydamlik(tester), 1);
        expect(tester.hasRunningAnimations, isFalse);
      });
    });
  }
}
