import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/marka_yuzeyi.dart';
import 'package:tayfam/core/bilesenler/tayfam_monogram.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

import 'bilesen_test_yardimcisi.dart';

Finder get _boyaci => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is MonogramBoyaci,
);

MonogramBoyaci _cizilen(WidgetTester tester) {
  return tester.widget<CustomPaint>(_boyaci).painter! as MonogramBoyaci;
}

Finder get _yazi => find.text(arbMetni('bilesen_logo_yazisi'));

/// Mor marka yüzeyinde, zemini `markaYuzey` verilmiş yazılı logo.
Widget _markaYuzeyinde() {
  return MarkaYuzeyi(
    child: Builder(
      builder: (context) =>
          TayfamMonogram.yazili(zemin: context.renkler.markaYuzey),
    ),
  );
}

void main() {
  group('yazılı', () {
    ortakTestler(() => const TayfamMonogram.yazili());
  });

  group('yalnız monogram', () {
    ortakTestler(() => const TayfamMonogram());
  });

  group('marka yüzeyinde', () {
    ortakTestler(_markaYuzeyinde);
  });

  group('gövde rengi zemine göre', () {
    test('açık zeminlerde brand', () {
      const r = TayfamColors.acik;
      for (final zemin in [r.zemin, r.kart, r.tintMarka, r.tintMango]) {
        expect(monogramGovdeRengi(r, zemin), r.markaYuzey);
      }
      // Brand iki temada da #5B2BE0'dır (Notion: Marka).
      expect(r.markaYuzey, TayfamColors.koyu.markaYuzey);
    });

    test('koyu zeminlerde turkuaz', () {
      const r = TayfamColors.koyu;
      for (final zemin in [r.zemin, r.kart, r.gelenBalon]) {
        expect(monogramGovdeRengi(r, zemin), r.teal);
      }
    });

    test('mor marka yüzeyinde iki temada da turkuaz', () {
      for (final r in [TayfamColors.acik, TayfamColors.koyu]) {
        expect(monogramGovdeRengi(r, r.markaYuzey), r.teal);
      }
    });

    test('yazı rengi: açık zeminde ana metin, koyu zeminde beyaz', () {
      const acik = TayfamColors.acik;
      const koyu = TayfamColors.koyu;
      expect(logoYaziRengi(acik, acik.zemin), acik.metin);
      expect(logoYaziRengi(acik, acik.markaYuzey), acik.markaYuzeyUstu);
      expect(logoYaziRengi(koyu, koyu.zemin), koyu.metin);
      expect(logoYaziRengi(koyu, koyu.markaYuzey), koyu.markaYuzeyUstu);
    });
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('sayfa zemininde gövde temaya göre', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, const TayfamMonogram.yazili(), mod: mod);

        final boyaci = _cizilen(tester);
        final govde = mod == ThemeMode.light ? r.markaYuzey : r.teal;
        expect(boyaci.govde, govde);
        expect(boyaci.cizgi, r.mango);
        expect(boyaci.nokta, r.nar);
        expect(cizilenStil(tester, _yazi).color, r.metin);
      });

      testWidgets('mor marka yüzeyinde gövde turkuaz, yazı beyaz', (
        tester,
      ) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, _markaYuzeyinde(), mod: mod);

        expect(_cizilen(tester).govde, r.teal);
        expect(cizilenStil(tester, _yazi).color, r.markaYuzeyUstu);
      });
    });
  }

  testWidgets('yazı ile monogram arası simge genişliğinin %30\'u', (
    tester,
  ) async {
    // Dar alanda logo orantılı küçülür; bu boyut 320 dp'ye sığar.
    const boyut = 32.0;
    await bileseniAc(
      tester,
      const Center(child: TayfamMonogram.yazili(boyut: boyut)),
      mod: ThemeMode.light,
    );

    final simge = tester.getRect(_boyaci);
    final yazi = tester.getRect(_yazi);
    expect(simge.size, const Size.square(boyut));
    final bosluk = boyut * TayfamSizes.logoYaziBoslukOrani;
    expect(yazi.left - simge.right, moreOrLessEquals(bosluk));
  });

  testWidgets('dar alanda bütün logo orantılı küçülür, taşmaz', (tester) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamMonogram.yazili()),
      mod: ThemeMode.light,
    );

    final simge = tester.getRect(_boyaci);
    final yazi = tester.getRect(_yazi);
    expect(simge.width, simge.height);
    expect(simge.width, lessThanOrEqualTo(TayfamSizes.logoBuyuk));
    final oran = (yazi.left - simge.right) / simge.width;
    expect(oran, moreOrLessEquals(TayfamSizes.logoYaziBoslukOrani));
    expect(tester.takeException(), isNull);
  });

  testWidgets('yazı sistem yazı ölçeğiyle büyümez (logo oranı korunur)', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamMonogram.yazili()),
      mod: ThemeMode.light,
    );

    final stil = cizilenStil(tester, _yazi);
    expect(
      stil.fontSize,
      moreOrLessEquals(TayfamSizes.logoBuyuk * TayfamSizes.logoYaziOrani),
    );
    expect(tester.widget<Text>(_yazi).textScaler, TextScaler.noScaling);
  });

  testWidgets('24 px altında yazısız', (tester) async {
    await bileseniAc(
      tester,
      const Center(
        child: TayfamMonogram.yazili(boyut: TayfamSizes.logoEnKucuk),
      ),
      mod: ThemeMode.light,
    );

    expect(_yazi, findsNothing);
    expect(tester.getSize(_boyaci), const Size.square(TayfamSizes.logoEnKucuk));
  });

  testWidgets('24 px ve üstünde yazılı', (tester) async {
    await bileseniAc(
      tester,
      const Center(
        child: TayfamMonogram.yazili(boyut: TayfamSizes.logoYaziEsigi),
      ),
      mod: ThemeMode.light,
    );

    expect(_yazi, findsOneWidget);
  });

  test('16 px\'ten küçük boyut kabul edilmez', () {
    TayfamMonogram olustur(double boyut) => TayfamMonogram(boyut: boyut);
    expect(() => olustur(TayfamSizes.logoEnKucuk - 1), throwsAssertionError);
    expect(olustur(TayfamSizes.logoEnKucuk).boyut, TayfamSizes.logoEnKucuk);
  });

  testWidgets('ekran okuyucu tek bir "Tayfam" görseli okur', (tester) async {
    final kulp = tester.ensureSemantics();
    await bileseniAc(
      tester,
      const TayfamMonogram.yazili(baslik: true),
      mod: ThemeMode.light,
    );

    final dugum = tester.getSemantics(find.byType(TayfamMonogram));
    expect(
      dugum,
      containsSemantics(
        label: arbMetni('bilesen_logo_etiketi'),
        isImage: true,
        isHeader: true,
      ),
    );
    kulp.dispose();
  });

  test('renk değişince yeniden çizilir', () {
    const r = TayfamColors.acik;
    final a = MonogramBoyaci(govde: r.markaYuzey, cizgi: r.mango, nokta: r.nar);
    final b = MonogramBoyaci(govde: r.teal, cizgi: r.mango, nokta: r.nar);
    final c = MonogramBoyaci(govde: r.markaYuzey, cizgi: r.mango, nokta: r.nar);
    expect(b.shouldRepaint(a), isTrue);
    expect(c.shouldRepaint(a), isFalse);
  });
}
