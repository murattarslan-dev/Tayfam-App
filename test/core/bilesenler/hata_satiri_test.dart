import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';

import 'bilesen_test_yardimcisi.dart';

const ApiProblem _problem = ApiProblem(
  type: ProblemType.tayfaNotFound,
  status: 404,
);

void main() {
  ortakTestler(() => const HataSatiri.hatadan(_problem));

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('hatanın metni ortak eşlemeden', (tester) async {
        await bileseniAc(tester, const HataSatiri.hatadan(_problem), mod: mod);
        final metin = find.text(arbMetni('hata_tayfa_not_found'));
        expect(metin, findsOneWidget);
        expect(cizilenStil(tester, metin).color, renklerOf(mod).metin);
      });

      testWidgets('bilinmeyen hata genel metinle', (tester) async {
        await bileseniAc(
          tester,
          const HataSatiri.hatadan(FormatException('ayrıntı')),
          mod: mod,
        );
        expect(find.text(arbMetni('hata_genel')), findsOneWidget);
        expect(find.textContaining('ayrıntı'), findsNothing);
      });

      testWidgets('hazır metin ve renk', (tester) async {
        final metin = arbMetni('hata_baglanti_yok');
        await bileseniAc(
          tester,
          HataSatiri(metin: metin, renk: renklerOf(mod).markaYuzeyUstu),
          mod: mod,
        );
        final bulunan = find.text(metin);
        expect(bulunan, findsOneWidget);
        expect(
          cizilenStil(tester, bulunan).color,
          renklerOf(mod).markaYuzeyUstu,
        );
      });

      testWidgets('ekran okuyucu için canlı bölge', (tester) async {
        await bileseniAc(
          tester,
          const HataSatiri.hatadan(ApiOffline()),
          mod: mod,
        );
        final bulucu = find.descendant(
          of: find.byType(HataSatiri),
          matching: find.byType(Semantics),
        );
        final semantik = tester.widget<Semantics>(bulucu.first);
        expect(semantik.properties.liveRegion, isTrue);
      });

      testWidgets('bildirim (snackbar) ortak eşlemeden', (tester) async {
        late BuildContext baglam;
        await bileseniAc(
          tester,
          Builder(
            builder: (context) {
              baglam = context;
              return const SizedBox.shrink();
            },
          ),
          mod: mod,
        );

        hataBildir(baglam, const ApiTimeout());
        await tester.pump();
        expect(find.text(arbMetni('hata_zaman_asimi')), findsOneWidget);

        // Önceki bildirim kapanır, yenisi gelir.
        hataBildir(baglam, _problem);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text(arbMetni('hata_tayfa_not_found')), findsOneWidget);
        expect(find.text(arbMetni('hata_zaman_asimi')), findsNothing);
      });
    });
  }
}
