import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/birincil_eylem.dart';

import 'bilesen_test_yardimcisi.dart';

Color _zemin(WidgetTester tester) {
  final yuzey = find.descendant(
    of: find.byType(FilledButton),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(yuzey.first).color!;
}

void main() {
  ortakTestler(() {
    return BirincilEylem(
      etiket: 'Etkinliğe katılıyorum',
      ikon: Icons.check,
      onPressed: () {},
    );
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('dokununca eylemi çalıştırır', (tester) async {
        var sayac = 0;
        await bileseniAc(
          tester,
          BirincilEylem(etiket: 'Katıl', onPressed: () => sayac++),
          mod: mod,
        );
        await tester.tap(find.text('Katıl'));
        expect(sayac, 1);
        dokunmaAlaniEnAz44(tester, find.byType(FilledButton));
      });

      testWidgets('temaya göre renk', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(
          tester,
          BirincilEylem(etiket: 'Katıl', onPressed: () {}),
          mod: mod,
        );
        // Açık zeminde brand, koyu zeminde mango.
        final beklenen = mod == ThemeMode.dark ? r.mango : r.marka;
        expect(_zemin(tester), beklenen);
        expect(r.birincilEylem, beklenen);
      });

      testWidgets('marka yüzeyinde mango + ink', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(
          tester,
          BirincilEylem(
            etiket: 'Katıl',
            onPressed: () {},
            markaYuzeyinde: true,
          ),
          mod: mod,
        );
        expect(_zemin(tester), r.mango);
        expect(cizilenStil(tester, find.text('Katıl')).color, r.vurguUstu);
      });

      testWidgets('devre dışıyken bildirir', (tester) async {
        final kulp = tester.ensureSemantics();
        await bileseniAc(
          tester,
          const BirincilEylem(etiket: 'Katıl', onPressed: null),
          mod: mod,
        );
        expect(
          tester.getSemantics(find.byType(FilledButton)),
          isSemantics(isButton: true, isEnabled: false),
        );
        expect(_zemin(tester), renklerOf(mod).pasif);
        kulp.dispose();
      });

      testWidgets('klavye odağında temanın odak çerçevesi', (tester) async {
        await odakCercevesiDenetle(
          tester,
          BirincilEylem(etiket: 'Katıl', onPressed: () {}),
          mod: mod,
        );
      });
    });
  }
}
