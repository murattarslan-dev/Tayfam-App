import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';

import 'bilesen_test_yardimcisi.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

Finder get _boyaci =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LogoBoyaci);

LogoBoyaci _cizilen(WidgetTester tester) {
  return tester.widget<CustomPaint>(_boyaci).painter! as LogoBoyaci;
}

void main() {
  group('Dalga zamanlaması (Design: Yükleniyor, A)', () {
    test('turun %20\'sinde %70 ölçek ve %45 saydamlık, %40\'ında normal', () {
      // Mango gecikmesiz: 1400 ms'nin %20'si 280 ms, %40'ı 560 ms.
      final tepe = yukleniyorBlokHali(LogoBlogu.mango, _ms(280));
      expect(tepe.olcek, moreOrLessEquals(TayfamSizes.yukleniyorEnKucukOlcek));
      expect(
        tepe.saydamlik,
        moreOrLessEquals(TayfamSizes.yukleniyorEnAzSaydamlik),
      );
      expect(yukleniyorBlokHali(LogoBlogu.mango, _ms(560)), BlokHali.normal);
      expect(yukleniyorBlokHali(LogoBlogu.mango, _ms(1000)), BlokHali.normal);
    });

    test('saat yönünde 175 ms arayla: mango → nar → turkuaz → L', () {
      const sira = {
        LogoBlogu.mango: 0,
        LogoBlogu.nar: 175,
        LogoBlogu.turkuaz: 350,
        LogoBlogu.l: 525,
      };
      for (final MapEntry(key: blok, value: gecikme) in sira.entries) {
        final tepe = yukleniyorBlokHali(blok, _ms(gecikme + 280));
        expect(
          tepe.olcek,
          moreOrLessEquals(TayfamSizes.yukleniyorEnKucukOlcek),
          reason: blok.name,
        );
        // Başlamadan önce durağan (CSS'te gecikme boyunca normal).
        if (gecikme > 0) {
          expect(
            yukleniyorBlokHali(blok, _ms(gecikme ~/ 2)),
            BlokHali.normal,
            reason: blok.name,
          );
        }
      }
    });

    test('1400 ms\'de bir tekrarlar', () {
      for (final blok in LogoBlogu.values) {
        for (final ms in [0, 100, 300, 700, 1200]) {
          expect(
            yukleniyorBlokHali(blok, _ms(ms + 1400)),
            yukleniyorBlokHali(blok, _ms(ms)),
            reason: '${blok.name} $ms',
          );
        }
      }
      expect(TayfamMotion.yukleniyorDongu, _ms(1400));
    });
  });

  group('boyutlar', () {
    for (final boyut in [
      TayfamSizes.yukleniyorDugme,
      TayfamSizes.yukleniyorSatir,
      TayfamSizes.yukleniyorTamEkran,
    ]) {
      group('$boyut px', () {
        ortakTestler(() => Center(child: TayfamYukleniyor(boyut: boyut)));

        testWidgets('kenar $boyut px', (tester) async {
          await bileseniAc(
            tester,
            Center(child: TayfamYukleniyor(boyut: boyut)),
            mod: ThemeMode.light,
          );
          expect(tester.getSize(_boyaci), Size.square(boyut));
        });
      });
    }
  });

  for (final mod in temalar) {
    testWidgets('${mod.name}: döner ve bloklar dalgalanır', (tester) async {
      await bileseniAc(tester, const TayfamYukleniyor(), mod: mod);

      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(_ms(280));
      final hal = _cizilen(tester).haller[LogoBlogu.mango]!;
      expect(hal.olcek, lessThan(1));
      // Açık temada L brand, koyu temada brand-dark.
      final l = mod == ThemeMode.dark
          ? TayfamLogoRenkleri.lKoyuZemin
          : TayfamLogoRenkleri.lAcikZemin;
      expect(_cizilen(tester).renkler.l, l);
    });
  }

  testWidgets('mor zeminde L #FAF8FF; tek renk istenirse tek renk', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const Column(
        children: [
          TayfamYukleniyor(zemin: TayfamLogoRenkleri.ikonZemini),
          TayfamYukleniyor(tekRenk: TayfamLogoRenkleri.lMorZemin),
        ],
      ),
      mod: ThemeMode.light,
    );

    final boyacilar = tester
        .widgetList<CustomPaint>(_boyaci)
        .map((w) => w.painter! as LogoBoyaci)
        .toList();
    expect(boyacilar[0].renkler.l, TayfamLogoRenkleri.lMorZemin);
    expect(
      boyacilar[1].renkler,
      LogoRenkleri.tek(TayfamLogoRenkleri.lMorZemin),
    );
  });

  testWidgets('ekran okuyucu etiketi: varsayılan "Yükleniyor" ya da verilen', (
    tester,
  ) async {
    final kulp = tester.ensureSemantics();
    await bileseniAc(
      tester,
      const Column(
        children: [
          TayfamYukleniyor(),
          TayfamYukleniyor(etiket: 'Kaydediliyor'),
        ],
      ),
      mod: ThemeMode.light,
    );

    expect(
      find.bySemanticsLabel(arbMetni('bilesen_yukleniyor')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Kaydediliyor'), findsOneWidget);
    kulp.dispose();
  });

  testWidgets('hareketi azalt: durağan logo, tam ekranda görünür etiket', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const Column(
        children: [
          TayfamYukleniyor(boyut: TayfamSizes.yukleniyorTamEkran),
          TayfamYukleniyor(),
        ],
      ),
      mod: ThemeMode.light,
      hareketiAzalt: true,
    );

    expect(tester.hasRunningAnimations, isFalse);
    for (final w in tester.widgetList<CustomPaint>(_boyaci)) {
      expect((w.painter! as LogoBoyaci).haller, isEmpty);
    }
    // Yalnızca tam ekran boyutunda metin görünür.
    expect(find.text(arbMetni('bilesen_yukleniyor')), findsOneWidget);
  });

  testWidgets('gecikmeli: 1 saniyeden önce görünmez ama okunur', (
    tester,
  ) async {
    final kulp = tester.ensureSemantics();
    await bileseniAc(
      tester,
      const Center(child: TayfamYukleniyor(gecikmeli: true)),
      mod: ThemeMode.light,
    );

    expect(_boyaci, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.bySemanticsLabel(arbMetni('bilesen_yukleniyor')),
      findsOneWidget,
    );
    // Yer tutulur: düzen animasyon gelince kaymaz.
    expect(
      tester.getSize(find.byType(TayfamYukleniyor)),
      const Size.square(TayfamSizes.yukleniyorSatir),
    );

    await tester.pump(TayfamMotion.yukleniyorGecikmesi);
    await tester.pump();

    expect(_boyaci, findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);
    kulp.dispose();
  });

  testWidgets('gecikme dolmadan kaldırılırsa zamanlayıcı kalmaz', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamYukleniyor(gecikmeli: true)),
      mod: ThemeMode.light,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(TayfamMotion.yukleniyorGecikmesi);
    expect(tester.takeException(), isNull);
  });
}
