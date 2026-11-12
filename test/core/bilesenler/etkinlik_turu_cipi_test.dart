import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/etkinlik_turu_cipi.dart';
import 'package:tayfam/core/bilesenler/marka_yuzeyi.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  for (final tur in EventType.values) {
    ortakTestler(() => EtkinlikTuruCipi(tur: tur));
  }

  group('büyük', () {
    for (final tur in EventType.values) {
      ortakTestler(() => EtkinlikTuruCipi(tur: tur, buyuk: true));
    }

    testWidgets('15 px etiket ve 18 px ikon', (tester) async {
      await bileseniAc(
        tester,
        const EtkinlikTuruCipi(tur: EventType.convoy, buyuk: true),
        mod: ThemeMode.light,
        yaziOlcegi: 1,
      );
      final girdi = etkinlikTuruGirdisi(EventType.convoy);
      final ad = arbMetni(girdi.adAnahtari);
      expect(cizilenStil(tester, find.text(ad)).fontSize, 15);
      expect(
        tester.widget<Icon>(find.byIcon(girdi.ikon)).size,
        TayfamSizes.ikonOrta,
      );
    });
  });

  for (final mod in temalar) {
    testWidgets('${mod.name}: mor marka yüzeyinde oyun brand-dark', (
      tester,
    ) async {
      await bileseniAc(
        tester,
        const MarkaYuzeyi(child: EtkinlikTuruCipi(tur: EventType.gaming)),
        mod: mod,
      );
      final kutu = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(EtkinlikTuruCipi),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (kutu.decoration as BoxDecoration).color,
        TayfamTurRenkleri.koyu.cift(TurRengi.oyun).dolgu,
      );
    });
  }

  for (final mod in temalar) {
    final renkler = mod == ThemeMode.dark
        ? TayfamTurRenkleri.koyu
        : TayfamTurRenkleri.acik;
    for (final tur in EventType.values) {
      testWidgets('${mod.name}: ${tur.name} kendi rengi, ikonu ve adı', (
        tester,
      ) async {
        await bileseniAc(tester, EtkinlikTuruCipi(tur: tur), mod: mod);
        final girdi = etkinlikTuruGirdisi(tur);
        final cift = renkler.cift(girdi.renk);

        final kutu = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(EtkinlikTuruCipi),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((kutu.decoration as BoxDecoration).color, cift.dolgu);
        final ad = arbMetni(girdi.adAnahtari);
        expect(cizilenStil(tester, find.text(ad)).color, cift.ustu);
        // Renk tek başına bilgi taşımaz: ikon ve ad her zaman var.
        final ikon = tester.widget<Icon>(find.byIcon(girdi.ikon));
        expect(ikon.color, cift.ustu);
      });
    }
  }

  testWidgets('tanınmayan tür genel görünüyor', (tester) async {
    await bileseniAc(
      tester,
      const EtkinlikTuruCipi(tur: EventType.unknown),
      mod: ThemeMode.light,
    );
    expect(find.text(arbMetni('etkinlik_turu_general')), findsOneWidget);
    expect(find.byIcon(Icons.event), findsOneWidget);
  });
}
