import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/etkinlik_turu_cipi.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  for (final vurgu in CipVurgusu.values) {
    ortakTestler(() {
      return EtkinlikTuruCipi(
        etiket: 'Doğa yürüyüşü',
        vurgu: vurgu,
        ikon: Icons.terrain_outlined,
      );
    });
  }

  for (final mod in temalar) {
    for (final vurgu in CipVurgusu.values) {
      testWidgets('${mod.name}: ${vurgu.name} zemin + ink', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(
          tester,
          EtkinlikTuruCipi(etiket: 'Kamp', vurgu: vurgu),
          mod: mod,
        );
        final kutu = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(EtkinlikTuruCipi),
            matching: find.byType(DecoratedBox),
          ),
        );
        final zemin = (kutu.decoration as BoxDecoration).color;
        expect(zemin, EtkinlikTuruCipi.zeminRengi(r, vurgu));
        expect(zemin, isNot(r.marka));
        // Vurgu renkleri metin rengi olmaz.
        expect(cizilenStil(tester, find.text('Kamp')).color, r.vurguUstu);
      });
    }
  }
}
