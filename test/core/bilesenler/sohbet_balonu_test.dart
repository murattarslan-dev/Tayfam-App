import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/sohbet_balonu.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';

import 'bilesen_test_yardimcisi.dart';

const _metin = 'Cumartesi termosu ben getiriyorum.';

final _balonBulucu = find.descendant(
  of: find.byType(SohbetBalonu),
  matching: find.byType(DecoratedBox),
);

BoxDecoration _balon(WidgetTester tester) {
  final kutu = tester.widget<DecoratedBox>(_balonBulucu);
  return kutu.decoration as BoxDecoration;
}

/// Balonun ekran okuyucu etiketi: önce "kim yazdı", sonra mesaj.
void _etiketDenetle(WidgetTester tester, String kim) {
  final etiket = tester.getSemantics(_balonBulucu).label;
  expect(etiket, startsWith(kim));
  expect(etiket, contains(_metin));
}

void main() {
  ortakTestler(() => const SohbetBalonu(metin: _metin, giden: true));
  ortakTestler(() {
    return const SohbetBalonu(metin: _metin, giden: false, gonderen: 'Ayşe');
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('giden: sağda, brand + beyaz', (tester) async {
        final r = renklerOf(mod);
        final kulp = tester.ensureSemantics();
        await bileseniAc(
          tester,
          const SohbetBalonu(metin: _metin, giden: true),
          mod: mod,
        );
        final balon = _balon(tester);
        expect(balon.color, r.markaYuzey);
        expect(
          balon.borderRadius,
          const BorderRadiusDirectional.only(
            topStart: Radius.circular(TayfamRadii.balon),
            topEnd: Radius.circular(TayfamRadii.balon),
            bottomStart: Radius.circular(TayfamRadii.balon),
            bottomEnd: Radius.circular(TayfamRadii.balonKuyruk),
          ),
        );
        expect(cizilenStil(tester, find.text(_metin)).color, r.markaYuzeyUstu);

        final ekran = tester.getRect(find.byType(ListView));
        final kutu = tester.getRect(_balonBulucu);
        // Sağa yaslı ve genişliğin en fazla %78'i.
        expect(kutu.right, closeTo(ekran.right - 16, 0.5));
        expect(kutu.width, lessThanOrEqualTo((ekran.width - 32) * .78 + .5));

        _etiketDenetle(tester, arbMetni('bilesen_sohbet_giden'));
        kulp.dispose();
      });

      testWidgets('gelen: solda, tint + metin', (tester) async {
        final r = renklerOf(mod);
        final kulp = tester.ensureSemantics();
        await bileseniAc(
          tester,
          const SohbetBalonu(metin: _metin, giden: false, gonderen: 'Ayşe'),
          mod: mod,
        );
        final balon = _balon(tester);
        expect(balon.color, r.gelenBalon);
        expect(
          (balon.borderRadius! as BorderRadiusDirectional).bottomStart,
          const Radius.circular(TayfamRadii.balonKuyruk),
        );
        expect(cizilenStil(tester, find.text(_metin)).color, r.gelenBalonUstu);

        final ekran = tester.getRect(find.byType(ListView));
        final kutu = tester.getRect(_balonBulucu);
        expect(kutu.left, closeTo(ekran.left + 16, 0.5));

        final kim = arbMetni('bilesen_sohbet_gelen');
        _etiketDenetle(tester, kim.replaceAll('{gonderen}', 'Ayşe'));
        kulp.dispose();
      });

      testWidgets('gönderen adı yoksa genel etiket', (tester) async {
        final kulp = tester.ensureSemantics();
        await bileseniAc(
          tester,
          const SohbetBalonu(metin: _metin, giden: false),
          mod: mod,
        );
        _etiketDenetle(tester, arbMetni('bilesen_sohbet_gelen_adsiz'));
        kulp.dispose();
      });
    });
  }
}
