import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/acilis_logosu.dart';
import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

import 'bilesen_test_yardimcisi.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

/// Açılış zemininde, ekran yüksekliğinde açılış logosu.
Widget _acilis() {
  return SizedBox(
    height: 600,
    child: Builder(
      builder: (context) => ColoredBox(
        color: context.renkler.acilisZemini,
        child: AcilisLogosu(zemin: context.renkler.acilisZemini),
      ),
    ),
  );
}

LogoBoyaci _boyaci(WidgetTester tester) {
  final boya = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LogoBoyaci),
  );
  return boya.painter! as LogoBoyaci;
}

double _yaziSaydamligi(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.ancestor(
          of: find.byType(LogoYazisi),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}

void main() {
  group('zamanlama (Design: Splash animasyonu)', () {
    test('başta bütün bloklar görünmez ve küçük', () {
      for (final blok in LogoBlogu.values) {
        final hal = acilisBlokHali(blok, Duration.zero);
        expect(hal.saydamlik, 0, reason: blok.name);
        expect(hal.olcek, acilisBaslangiclari[blok]!.olcek, reason: blok.name);
        expect(hal.kayma, acilisBaslangiclari[blok]!.kayma, reason: blok.name);
      }
    });

    test('sıra: L 0, mango 80, nar 140, turkuaz 200 ms; her blok 420 ms', () {
      const gecikmeler = {
        LogoBlogu.l: 0,
        LogoBlogu.mango: 80,
        LogoBlogu.nar: 140,
        LogoBlogu.turkuaz: 200,
      };
      for (final MapEntry(key: blok, value: gecikme) in gecikmeler.entries) {
        // Gecikme bitene kadar başlangıç halinde.
        expect(
          acilisBlokHali(blok, _ms(gecikme)).saydamlik,
          0,
          reason: blok.name,
        );
        // Ortada görünür olmaya başlamış.
        expect(
          acilisBlokHali(blok, _ms(gecikme + 100)).saydamlik,
          greaterThan(0),
          reason: blok.name,
        );
        // 420 ms sonra yerinde.
        expect(
          acilisBlokHali(blok, _ms(gecikme + 420)),
          BlokHali.normal,
          reason: blok.name,
        );
      }
    });

    test('bloklar sonda hafif taşar (cubic-bezier .2,.9,.3,1.25)', () {
      final hal = acilisBlokHali(LogoBlogu.mango, _ms(80 + 300));
      expect(hal.olcek, greaterThan(1));
    });

    test('yazı 520 ms\'de başlar, 300 ms\'de yükselir', () {
      final bas = acilisYaziHali(_ms(520));
      expect(bas.saydamlik, 0);
      expect(bas.kayma, TayfamSizes.acilisYaziKaymasi);
      final son = acilisYaziHali(_ms(820));
      expect(son.saydamlik, 1);
      expect(son.kayma, 0);
      expect(TayfamMotion.acilisToplam, _ms(820));
    });
  });

  group('bileşen', () {
    ortakTestler(_acilis);

    for (final mod in temalar) {
      testWidgets('${mod.name}: logo kurulur, sonra durağan', (tester) async {
        await bileseniAc(tester, _acilis(), mod: mod);

        // İlk kare: bloklar görünmez, yazı görünmez.
        var boyaci = _boyaci(tester);
        for (final blok in LogoBlogu.values) {
          expect(boyaci.haller[blok]!.saydamlik, 0, reason: blok.name);
        }
        expect(_yaziSaydamligi(tester), 0);

        await tester.pump(TayfamMotion.acilisToplam);

        boyaci = _boyaci(tester);
        for (final blok in LogoBlogu.values) {
          expect(boyaci.haller[blok], BlokHali.normal, reason: blok.name);
        }
        expect(_yaziSaydamligi(tester), 1);
        // Açık temada brand zeminde L #FAF8FF, koyu temada ink zeminde
        // brand-dark.
        final l = mod == ThemeMode.dark
            ? TayfamLogoRenkleri.lKoyuZemin
            : TayfamLogoRenkleri.lMorZemin;
        expect(boyaci.renkler.l, l);
      });
    }

    testWidgets('hareketi azalt açıkken animasyonsuz', (tester) async {
      await bileseniAc(
        tester,
        _acilis(),
        mod: ThemeMode.light,
        hareketiAzalt: true,
      );

      final boyaci = _boyaci(tester);
      for (final blok in LogoBlogu.values) {
        expect(boyaci.haller[blok], BlokHali.normal, reason: blok.name);
      }
      expect(_yaziSaydamligi(tester), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('ekran okuyucu "Tayfam" başlığını okur', (tester) async {
      final kulp = tester.ensureSemantics();
      await bileseniAc(tester, _acilis(), mod: ThemeMode.light);

      expect(
        find.bySemanticsLabel(arbMetni('bilesen_logo_etiketi')),
        findsOneWidget,
      );
      kulp.dispose();
    });
  });
}
