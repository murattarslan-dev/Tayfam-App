import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tayfam_kart.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';

import 'bilesen_test_yardimcisi.dart';

const _icerik = Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [Text('Kaz Dağları yürüyüşü'), Text('Cumartesi, 07:30')],
);

Material _yuzey(WidgetTester tester) {
  final yuzey = find.descendant(
    of: find.byType(TayfamKart),
    matching: find.byType(Material),
  );
  return tester.widget<Material>(yuzey.first);
}

bool _golgeliMi(Widget w) {
  return w is DecoratedBox &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).boxShadow != null;
}

void main() {
  ortakTestler(() => const TayfamKart(child: _icerik));
  ortakTestler(() {
    return TayfamKart(oneCikan: true, onTap: () {}, child: _icerik);
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('card zemin, line kenar, 22 px köşe', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, const TayfamKart(child: _icerik), mod: mod);
        final yuzey = _yuzey(tester);
        expect(yuzey.color, r.kart);
        final sekil = yuzey.shape! as RoundedRectangleBorder;
        expect(sekil.borderRadius, TayfamRadii.kartKoseleri);
        expect(sekil.side.color, r.cizgi);
        expect(sekil.side.width, 1);
        final bosluk = tester.widget<Padding>(
          find.byWidgetPredicate((w) => w is Padding && w.child == _icerik),
        );
        expect(bosluk.padding, const EdgeInsets.all(20));
        // Gölge yalnızca öne çıkan kartta.
        expect(find.byWidgetPredicate(_golgeliMi), findsNothing);
      });

      testWidgets('öne çıkan kartta tek gölge', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(
          tester,
          const TayfamKart(oneCikan: true, child: _icerik),
          mod: mod,
        );
        final kutu = tester.widget<DecoratedBox>(
          find.byWidgetPredicate(_golgeliMi),
        );
        final golge = (kutu.decoration as BoxDecoration).boxShadow!;
        expect(golge, hasLength(1));
        expect(golge.single.offset, const Offset(0, 18));
        expect(golge.single.blurRadius, 40);
        expect(golge.single.spreadRadius, -24);
        expect(golge.single.color, r.golge);
      });

      testWidgets('dokunulabilir kart tek düğmedir', (tester) async {
        final kulp = tester.ensureSemantics();
        var sayac = 0;
        await bileseniAc(
          tester,
          TayfamKart(onTap: () => sayac++, child: _icerik),
          mod: mod,
        );
        await tester.tap(find.text('Kaz Dağları yürüyüşü'));
        expect(sayac, 1);
        expect(
          tester.getSemantics(find.byType(InkWell)),
          containsSemantics(isButton: true, hasTapAction: true),
        );
        dokunmaAlaniEnAz44(tester, find.byType(InkWell));
        kulp.dispose();
      });

      testWidgets('klavye odağında mango çerçeve', (tester) async {
        await odakCercevesiDenetle(
          tester,
          TayfamKart(onTap: () {}, child: _icerik),
          mod: mod,
        );
      });
    });
  }
}
