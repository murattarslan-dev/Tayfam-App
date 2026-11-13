import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/yikici_eylem.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  ortakTestler(
    () => Wrap(
      children: [
        YikiciEylem(etiket: 'Banla', dolu: true, onPressed: () {}),
        YikiciEylem(etiket: 'Tayfayı sil', onPressed: () {}),
      ],
    ),
  );

  for (final mod in temalar) {
    testWidgets('${mod.name}: dolu düğme yıkıcı dolgu ve üstü renginde', (
      tester,
    ) async {
      final r = renklerOf(mod);
      await bileseniAc(
        tester,
        YikiciEylem(etiket: 'Banla', dolu: true, onPressed: () {}),
        mod: mod,
      );
      final dugme = tester.widget<FilledButton>(find.byType(FilledButton));
      final stil = dugme.style!;
      expect(stil.backgroundColor!.resolve(const {}), r.yikiciDolgu);
      expect(stil.foregroundColor!.resolve(const {}), r.yikiciDolguUstu);
      dokunmaAlaniEnAz44(tester, find.byType(FilledButton));
    });

    testWidgets('${mod.name}: çerçeveli düğme nar-metin kenar ve metin', (
      tester,
    ) async {
      final r = renklerOf(mod);
      await bileseniAc(
        tester,
        YikiciEylem(etiket: 'Tayfayı sil', onPressed: () {}),
        mod: mod,
      );
      final dugme = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final stil = dugme.style!;
      expect(stil.foregroundColor!.resolve(const {}), r.narMetin);
      expect(stil.side!.resolve(const {})!.color, r.narMetin);
    });

    testWidgets('${mod.name}: odak çerçevesi', (tester) async {
      await odakCercevesiDenetle(
        tester,
        YikiciEylem(etiket: 'Banla', dolu: true, onPressed: () {}),
        mod: mod,
      );
    });
  }
}
