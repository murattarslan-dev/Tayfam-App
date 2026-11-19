import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/etkinlik_turu_cipi.dart';
import 'package:tayfam/core/bilesenler/marka_yuzeyi.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/core/katalog/tanitim_turleri.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

import '../katalog/sahte_katalog.dart';
import 'bilesen_test_yardimcisi.dart';

/// Test kataloğundaki türler: anahtar, ad, ikon ve renk anahtarı.
const _turler = [
  ('convoy', 'Konvoy', Icons.directions_car, TurRengi.konvoy),
  ('camp', 'Kamp', Icons.cabin, TurRengi.kamp),
  ('hike', 'Doğa yürüyüşü', Icons.hiking, TurRengi.yuruyus),
  ('fishing', 'Balıkçılık', Icons.phishing, TurRengi.balik),
  ('gaming', 'Video oyunu', Icons.sports_esports, TurRengi.oyun),
  ('sports', 'Spor (diğer)', Icons.sports, TurRengi.spor),
  ('general', 'Genel', Icons.event, TurRengi.genel),
];

void main() {
  for (final (anahtar, _, _, _) in _turler) {
    ortakTestler(
      () => EtkinlikTuruCipi(tur: anahtar),
      overrides: () => [katalogOverride()],
    );
  }

  group('büyük', () {
    for (final tur in TanitimTuru.values) {
      ortakTestler(() => TanitimTurCipi(tur: tur, buyuk: true));
    }

    testWidgets('15 px etiket ve 18 px ikon', (tester) async {
      await bileseniAc(
        tester,
        const TanitimTurCipi(tur: TanitimTuru.konvoy, buyuk: true),
        mod: ThemeMode.light,
        yaziOlcegi: 1,
      );
      final ad = arbMetni('etkinlik_turu_convoy');
      expect(cizilenStil(tester, find.text(ad)).fontSize, 15);
      expect(
        tester.widget<Icon>(find.byIcon(TanitimTuru.konvoy.ikon)).size,
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
        const MarkaYuzeyi(child: EtkinlikTuruCipi(tur: 'gaming')),
        mod: mod,
        overrides: [katalogOverride()],
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
    for (final (anahtar, ad, ikon, renk) in _turler) {
      testWidgets('${mod.name}: $anahtar katalogdaki adı, ikonu ve rengi', (
        tester,
      ) async {
        await bileseniAc(
          tester,
          EtkinlikTuruCipi(tur: anahtar),
          mod: mod,
          overrides: [katalogOverride()],
        );
        final cift = renkler.cift(renk);

        final kutu = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(EtkinlikTuruCipi),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect((kutu.decoration as BoxDecoration).color, cift.dolgu);
        expect(cizilenStil(tester, find.text(ad)).color, cift.ustu);
        // Renk tek başına bilgi taşımaz: ikon ve ad her zaman var.
        expect(tester.widget<Icon>(find.byIcon(ikon)).color, cift.ustu);
      });
    }
  }

  testWidgets('katalog gelmeden "Etkinlik" ve genel ikon; istek atılmaz', (
    tester,
  ) async {
    late final SabitKatalogNotifier katalog;
    await bileseniAc(
      tester,
      const EtkinlikTuruCipi(tur: 'convoy', surum: 3),
      mod: ThemeMode.light,
      overrides: [
        katalogProvider.overrideWith(
          () => katalog = SabitKatalogNotifier(const AsyncData(null)),
        ),
      ],
    );
    expect(find.text(arbMetni('katalog_tur_bilinmiyor')), findsOneWidget);
    expect(find.byIcon(Icons.event), findsOneWidget);
    await tester.pump();
    expect(katalog.bilinmeyenler, isEmpty);
    expect(katalog.yenileme, 0);
  });

  testWidgets('katalogda olmayan tür genel görünür; katalog bir kez sorulur', (
    tester,
  ) async {
    late final SabitKatalogNotifier katalog;
    await bileseniAc(
      tester,
      const EtkinlikTuruCipi(tur: 'yepyeni_tur'),
      mod: ThemeMode.light,
      overrides: [
        katalogProvider.overrideWith(
          () => katalog = SabitKatalogNotifier(AsyncData(testKatalogu())),
        ),
      ],
    );
    await tester.pump();
    expect(find.text(arbMetni('katalog_tur_bilinmiyor')), findsOneWidget);
    expect(find.byIcon(Icons.event), findsOneWidget);
    expect(katalog.bilinmeyenler, contains('yepyeni_tur'));
  });

  testWidgets('ikonu tanınmayan tür ilgi alanının ikonunu alır', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      // `ornek_alanlar`: ikon `bilinmeyen_ikon`, ilgi alanı `general`.
      const EtkinlikTuruCipi(tur: 'ornek_alanlar'),
      mod: ThemeMode.light,
      overrides: [katalogOverride()],
    );
    expect(find.text('Örnek alanlar'), findsOneWidget);
    expect(find.byIcon(Icons.event), findsOneWidget);
  });

  group('ilgi alanı çipi', () {
    ortakTestler(
      () => const IlgiAlaniCipi(anahtar: 'automotive'),
      overrides: () => [katalogOverride()],
    );

    testWidgets('ad ve ikon katalogdan; katalogda yoksa çizilmez', (
      tester,
    ) async {
      await bileseniAc(
        tester,
        const Column(
          children: [
            IlgiAlaniCipi(anahtar: 'nature'),
            IlgiAlaniCipi(anahtar: 'bilinmeyen_alan'),
          ],
        ),
        mod: ThemeMode.light,
        overrides: [katalogOverride()],
      );
      expect(find.text('Doğa'), findsOneWidget);
      expect(find.byIcon(Icons.forest), findsOneWidget);
      expect(find.byType(TurCipi), findsOneWidget);
    });

    testWidgets('katalog gelmeden çizilmez', (tester) async {
      await bileseniAc(
        tester,
        const IlgiAlaniCipi(anahtar: 'nature'),
        mod: ThemeMode.light,
        overrides: [
          katalogDurumuOverride(const AsyncData<Katalog?>(null)),
        ],
      );
      expect(find.byType(TurCipi), findsNothing);
    });
  });
}
