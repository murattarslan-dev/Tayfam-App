import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/ikincil_eylem.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';

import 'bilesen_test_yardimcisi.dart';

Material _yuzey(WidgetTester tester) {
  final yuzey = find.descendant(
    of: find.byType(FilledButton),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(yuzey.first);
}

void main() {
  ortakTestler(() {
    return IkincilEylem(
      etiket: 'Buradayım',
      ikon: Icons.place_outlined,
      onPressed: () {},
    );
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('nar zemin + ink metin, 12 px köşe', (tester) async {
        final r = renklerOf(mod);
        var sayac = 0;
        await bileseniAc(
          tester,
          IkincilEylem(etiket: 'Buradayım', onPressed: () => sayac++),
          mod: mod,
        );
        final yuzey = _yuzey(tester);
        expect(yuzey.color, r.nar);
        expect(
          yuzey.shape,
          const RoundedRectangleBorder(borderRadius: TayfamRadii.dugmeKoseleri),
        );
        // Nar zemin üzerinde beyaz kullanılmaz.
        final stil = cizilenStil(tester, find.text('Buradayım'));
        expect(stil.color, r.vurguUstu);

        await tester.tap(find.text('Buradayım'));
        expect(sayac, 1);
        dokunmaAlaniEnAz44(tester, find.byType(FilledButton));
      });

      testWidgets('devre dışıyken bildirir', (tester) async {
        final kulp = tester.ensureSemantics();
        await bileseniAc(
          tester,
          const IkincilEylem(etiket: 'Buradayım', onPressed: null),
          mod: mod,
        );
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          isSemantics(isButton: true, isEnabled: false),
        );
        kulp.dispose();
      });

      testWidgets('klavye odağında temanın odak çerçevesi', (tester) async {
        await odakCercevesiDenetle(
          tester,
          IkincilEylem(etiket: 'Buradayım', onPressed: () {}),
          mod: mod,
        );
      });
    });
  }
}
