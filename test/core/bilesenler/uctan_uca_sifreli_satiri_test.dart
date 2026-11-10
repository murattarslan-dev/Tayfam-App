import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/uctan_uca_sifreli_satiri.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  ortakTestler(() => const UctanUcaSifreliSatiri());

  for (final mod in temalar) {
    testWidgets('${mod.name}: kilit + ink-muted metin', (tester) async {
      final r = renklerOf(mod);
      final kulp = tester.ensureSemantics();
      await bileseniAc(tester, const UctanUcaSifreliSatiri(), mod: mod);

      final metin = find.text(arbMetni('bilesen_uctan_uca_sifreli'));
      expect(metin, findsOneWidget);
      expect(cizilenStil(tester, metin).color, r.metinIkincil);

      final kilit = tester.widget<Icon>(find.byType(Icon));
      expect(kilit.color, r.metinIkincil);
      // Kilit süstür; ekran okuyucu yalnızca metni okur.
      expect(
        find.descendant(
          of: find.byType(ExcludeSemantics),
          matching: find.byType(Icon),
        ),
        findsOneWidget,
      );
      kulp.dispose();
    });
  }
}
