import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/etiket.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  ortakTestler(() => const Etiket(metin: 'Doğa yürüyüşü'));

  for (final mod in temalar) {
    testWidgets('${mod.name}: tint zemin, 13 px 700 metin', (tester) async {
      final r = renklerOf(mod);
      await bileseniAc(tester, const Etiket(metin: 'Kamp'), mod: mod);

      final kutu = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Etiket),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((kutu.decoration as BoxDecoration).color, r.tintMarka);

      final stil = cizilenStil(tester, find.text('Kamp'));
      expect(stil.color, r.tintMarkaUstu);
      expect(stil.fontSize, 13);
      expect(stil.fontWeight, FontWeight.w700);
    });
  }
}
