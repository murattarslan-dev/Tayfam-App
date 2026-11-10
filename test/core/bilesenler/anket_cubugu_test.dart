import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/anket_cubugu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'bilesen_test_yardimcisi.dart';

const _onde = AnketCubugu(
  secenek: '14–15 Haziran',
  oy: 9,
  toplamOy: 14,
  onde: true,
);
const _diger = AnketCubugu(secenek: '21–22 Haziran', oy: 5, toplamOy: 14);

FractionallySizedBox _dolgu(WidgetTester tester) {
  return tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
}

Color? _dolguRengi(WidgetTester tester) {
  final kutu = tester.widget<ColoredBox>(
    find.descendant(
      of: find.byType(FractionallySizedBox),
      matching: find.byType(ColoredBox),
    ),
  );
  return kutu.color;
}

void main() {
  ortakTestler(() => _onde);
  ortakTestler(() => _diger);

  test('oran: toplam sıfırsa 0, en fazla 1', () {
    expect(_onde.oran, closeTo(9 / 14, 1e-9));
    const bos = AnketCubugu(secenek: 'A', oy: 0, toplamOy: 0);
    expect(bos.oran, 0);
    const tasan = AnketCubugu(secenek: 'A', oy: 5, toplamOy: 3);
    expect(tasan.oran, 1);
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('önde olan brand, diğerleri nar', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, _onde, mod: mod);
        expect(_dolguRengi(tester), r.marka);
        await bileseniAc(tester, _diger, mod: mod);
        expect(_dolguRengi(tester), r.nar);
      });

      testWidgets('çubuk 10 px, dolum 150–250 ms', (tester) async {
        await bileseniAc(tester, _onde, mod: mod);
        final cubuk = tester.getSize(find.byType(FractionallySizedBox));
        expect(cubuk.height, 10);
        await tester.pump(const Duration(milliseconds: 250));
        expect(_dolgu(tester).widthFactor, closeTo(9 / 14, 1e-6));
      });

      testWidgets('hareketi azalt: dolum anında', (tester) async {
        await bileseniAc(tester, _onde, mod: mod, hareketiAzalt: true);
        await tester.pump();
        expect(_dolgu(tester).widthFactor, closeTo(9 / 14, 1e-6));
      });

      testWidgets('ekran okuyucu tek parça okur', (tester) async {
        final kulp = tester.ensureSemantics();
        await bileseniAc(tester, _onde, mod: mod);
        final metinler = AppLocalizations.of(
          tester.element(find.byType(AnketCubugu)),
        );
        final beklenen = metinler.bilesen_anket_secenek_anlam(
          '14–15 Haziran',
          9,
          64,
        );
        expect(beklenen, contains('14–15 Haziran'));
        expect(beklenen, contains('9'));
        expect(beklenen, contains('64'));
        expect(
          tester.getSemantics(find.byType(AnketCubugu)),
          containsSemantics(label: beklenen),
        );
        kulp.dispose();
      });
    });
  }
}
