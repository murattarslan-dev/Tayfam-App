import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/faydali_sayaci.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  ortakTestler(() => const FaydaliSayaci(sayi: 12));
  ortakTestler(() => FaydaliSayaci(sayi: 4, isaretli: true, onPressed: () {}));

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('tint-mango zemin + honey metin', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, const FaydaliSayaci(sayi: 12), mod: mod);
        expect(find.text('12'), findsOneWidget);
        final etiket = find.text(arbMetni('bilesen_faydali'));
        expect(etiket, findsOneWidget);
        expect(cizilenStil(tester, etiket).color, r.tintMangoUstu);
        expect(cizilenStil(tester, find.text('12')).color, r.tintMangoUstu);
        final kutu = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(FaydaliSayaci),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((kutu.decoration as BoxDecoration).color, r.tintMango);
        // Dokunulamayan sayaç düğme değildir.
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('dokunulabilir sayaç aç/kapa düğmesi', (tester) async {
        final kulp = tester.ensureSemantics();
        var sayac = 0;
        await bileseniAc(
          tester,
          FaydaliSayaci(sayi: 4, isaretli: true, onPressed: () => sayac++),
          mod: mod,
        );
        await tester.tap(find.byType(FaydaliSayaci));
        expect(sayac, 1);
        dokunmaAlaniEnAz44(tester, find.byType(InkWell));

        final metinler = AppLocalizations.of(
          tester.element(find.byType(FaydaliSayaci)),
        );
        expect(
          tester.getSemantics(find.byType(InkWell)),
          isSemantics(
            label: metinler.bilesen_faydali_anlam(4),
            isButton: true,
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true,
          ),
        );
        // İşaretli durum yalnızca renkle değil ikonla da görünür.
        expect(find.byIcon(Icons.thumb_up_alt), findsOneWidget);
        kulp.dispose();
      });

      testWidgets('klavye odağında mango çerçeve', (tester) async {
        await odakCercevesiDenetle(
          tester,
          FaydaliSayaci(sayi: 4, onPressed: () {}),
          mod: mod,
        );
      });
    });
  }
}
