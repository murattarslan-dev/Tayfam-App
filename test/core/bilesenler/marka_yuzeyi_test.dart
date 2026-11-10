import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/birincil_eylem.dart';
import 'package:tayfam/core/bilesenler/marka_yuzeyi.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

import 'bilesen_test_yardimcisi.dart';

Widget _yuzey() {
  return MarkaYuzeyi(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Klasikçiler'),
        BirincilEylem(
          etiket: 'Etkinlik oluştur',
          markaYuzeyinde: true,
          onPressed: () {},
        ),
      ],
    ),
  );
}

void main() {
  ortakTestler(_yuzey);

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('brand zemin, beyaz metin, açık durum çubuğu', (
        tester,
      ) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, _yuzey(), mod: mod);

        final zemin = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(MarkaYuzeyi),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(zemin.color, r.markaYuzey);
        expect(
          cizilenStil(tester, find.text('Klasikçiler')).color,
          r.markaYuzeyUstu,
        );
        final bolge = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: find.byType(MarkaYuzeyi),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
        expect(bolge.value, SystemUiOverlayStyle.light);
      });

      testWidgets('altında odak rengi mango, dışarısı değişmez', (
        tester,
      ) async {
        final r = renklerOf(mod);
        late Color icerde;
        late Color disarda;
        await bileseniAc(
          tester,
          Builder(
            builder: (context) {
              disarda = context.renkler.odak;
              return MarkaYuzeyi(
                child: Builder(
                  builder: (context) {
                    icerde = context.renkler.odak;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
          mod: mod,
        );
        expect(icerde, r.markaYuzeyOdak);
        expect(icerde, r.mango);
        expect(disarda, r.odak);
      });

      testWidgets('klavye odağında mango çerçeve (iki temada)', (tester) async {
        await odakCercevesiDenetle(
          tester,
          _yuzey(),
          mod: mod,
          beklenenRenk: renklerOf(mod).mango,
        );
      });
    });
  }
}
