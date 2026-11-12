import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/marka_yuzeyi.dart';
import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_logo_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

import 'bilesen_test_yardimcisi.dart';

Finder get _boyaci =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is LogoBoyaci);

LogoBoyaci _cizilen(WidgetTester tester) {
  return tester.widget<CustomPaint>(_boyaci).painter! as LogoBoyaci;
}

Finder get _yazi => find.text(arbMetni('bilesen_logo_yazisi'));

/// Mor marka yüzeyinde, zemini `markaYuzey` verilmiş yazılı logo.
Widget _markaYuzeyinde() {
  return MarkaYuzeyi(
    child: Builder(
      builder: (context) =>
          TayfamLogo.yazili(zemin: context.renkler.markaYuzey),
    ),
  );
}

/// SVG dosyasındaki `<path>` öğelerinin `d` ve `fill` değerleri, sırayla.
List<(String, String?)> _svgYollari(String dosya) {
  final svg = File('assets/marka/logo/$dosya').readAsStringSync();
  return [
    for (final m in RegExp(r'<path\b[^>]*>').allMatches(svg))
      (
        RegExp(r'\bd="([^"]*)"').firstMatch(m[0]!)![1]!,
        RegExp(r'\bfill="([^"]*)"').firstMatch(m[0]!)?[1],
      ),
  ];
}

String _hex(Color renk) {
  final rgb = renk.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// SVG dosyalarındaki blok sırası: sol üst, sağ üst, sağ alt, L.
const List<LogoBlogu> _svgSirasi = [
  LogoBlogu.mango,
  LogoBlogu.nar,
  LogoBlogu.turkuaz,
  LogoBlogu.l,
];

void main() {
  group('yazılı', () {
    ortakTestler(() => const TayfamLogo.yazili());
  });

  group('yalnız simge', () {
    ortakTestler(() => const TayfamLogo());
  });

  group('rozet', () {
    ortakTestler(() => const TayfamLogo.rozet(boyut: TayfamSizes.logoBuyuk));
  });

  group('tek renk', () {
    ortakTestler(() => const TayfamLogo.tekRenk());
  });

  group('marka yüzeyinde', () {
    ortakTestler(_markaYuzeyinde);
  });

  group('renkler', () {
    test('blok renkleri tema token\'larıyla aynı', () {
      const acik = TayfamColors.acik;
      const koyu = TayfamColors.koyu;
      expect(TayfamLogoRenkleri.mango, acik.mango);
      expect(TayfamLogoRenkleri.nar, acik.nar);
      expect(TayfamLogoRenkleri.turkuaz, acik.teal);
      expect(TayfamLogoRenkleri.lAcikZemin, acik.markaYuzey);
      expect(TayfamLogoRenkleri.lKoyuZemin, koyu.marka);
      expect(TayfamLogoRenkleri.lMorZemin, acik.zemin);
      expect(TayfamLogoRenkleri.koyuSplashZemini, koyu.zemin);
    });

    test('L parçası açık zeminlerde brand', () {
      const r = TayfamColors.acik;
      for (final zemin in [r.zemin, r.kart, r.tintMarka, r.tintMango]) {
        expect(
          TayfamLogoRenkleri.lParcasi(zemin),
          TayfamLogoRenkleri.lAcikZemin,
        );
      }
    });

    test('L parçası koyu zeminlerde brand-dark', () {
      const r = TayfamColors.koyu;
      for (final zemin in [r.zemin, r.kart, r.gelenBalon]) {
        expect(
          TayfamLogoRenkleri.lParcasi(zemin),
          TayfamLogoRenkleri.lKoyuZemin,
        );
      }
    });

    test('L parçası mor zeminde #FAF8FF', () {
      for (final r in [TayfamColors.acik, TayfamColors.koyu]) {
        expect(
          TayfamLogoRenkleri.lParcasi(r.markaYuzey),
          TayfamLogoRenkleri.lMorZemin,
        );
      }
    });

    test('yazı rengi: açık zeminde ana metin, mor ve koyu zeminde beyaz', () {
      const acik = TayfamColors.acik;
      const koyu = TayfamColors.koyu;
      expect(logoYaziRengi(acik, acik.zemin), acik.metin);
      expect(logoYaziRengi(acik, acik.markaYuzey), acik.markaYuzeyUstu);
      expect(logoYaziRengi(koyu, koyu.zemin), koyu.metin);
      expect(logoYaziRengi(koyu, koyu.markaYuzey), koyu.markaYuzeyUstu);
    });
  });

  group('yollar SVG kaynaklarıyla aynı', () {
    String sade(String d) => d.replaceAll(RegExp(r'\s+'), ' ').trim();

    test('tayfam-logo.svg (açık zemin)', () {
      final yollar = _svgYollari('tayfam-logo.svg');
      expect(yollar, hasLength(4));
      for (final (i, blok) in _svgSirasi.indexed) {
        expect(sade(yollar[i].$1), sade(LogoYollari.tamRenk[blok]!));
      }
      final renkler = LogoRenkleri.zemineGore(TayfamColors.acik.zemin);
      expect([for (final y in yollar) y.$2], [
        for (final blok in _svgSirasi) _hex(renkler.blok(blok)),
      ]);
    });

    test('tayfam-logo-dark.svg (koyu zemin)', () {
      final yollar = _svgYollari('tayfam-logo-dark.svg');
      final renkler = LogoRenkleri.zemineGore(TayfamColors.koyu.zemin);
      for (final (i, blok) in _svgSirasi.indexed) {
        expect(sade(yollar[i].$1), sade(LogoYollari.tamRenk[blok]!));
        expect(yollar[i].$2, _hex(renkler.blok(blok)));
      }
    });

    test('tayfam-app-icon.svg (mor zemin)', () {
      final yollar = _svgYollari('tayfam-app-icon.svg');
      final renkler = LogoRenkleri.zemineGore(TayfamColors.acik.markaYuzey);
      for (final (i, blok) in _svgSirasi.indexed) {
        expect(sade(yollar[i].$1), sade(LogoYollari.tamRenk[blok]!));
        expect(yollar[i].$2, _hex(renkler.blok(blok)));
      }
    });

    test('tayfam-tek-renk.svg', () {
      final yollar = _svgYollari('tayfam-tek-renk.svg');
      for (final (i, blok) in _svgSirasi.indexed) {
        expect(sade(yollar[i].$1), sade(LogoYollari.tamRenk[blok]!));
        expect(yollar[i].$2, isNull);
      }
    });

    test('tayfam-rozet.svg', () {
      final yollar = _svgYollari('tayfam-rozet.svg');
      for (final (i, blok) in _svgSirasi.indexed) {
        expect(sade(yollar[i].$1), sade(LogoYollari.rozet[blok]!));
        expect(yollar[i].$2, _hex(LogoRenkleri.rozet.blok(blok)));
      }
    });
  });

  group('SVG yolu çevirici', () {
    test('blokların sınır kutusu ve animasyon merkezleri', () {
      const beklenen = {
        LogoBlogu.mango: Rect.fromLTRB(8, 14, 40, 32),
        LogoBlogu.nar: Rect.fromLTRB(52, 14, 92, 32),
        LogoBlogu.turkuaz: Rect.fromLTRB(52, 44, 92, 64),
        LogoBlogu.l: Rect.fromLTRB(8, 44, 92, 92),
      };
      for (final MapEntry(key: blok, value: kutu) in beklenen.entries) {
        final sinir = svgYolu(LogoYollari.tamRenk[blok]!).getBounds();
        expect(sinir.left, moreOrLessEquals(kutu.left), reason: blok.name);
        expect(sinir.top, moreOrLessEquals(kutu.top), reason: blok.name);
        expect(sinir.right, moreOrLessEquals(kutu.right), reason: blok.name);
        expect(sinir.bottom, moreOrLessEquals(kutu.bottom), reason: blok.name);
        expect(LogoYollari.merkezler[blok], kutu.center, reason: blok.name);
      }
    });

    test('desteklenmeyen komut ve eksik koordinat reddedilir', () {
      expect(() => svgYolu('M0 0 C1 1 2 2 3 3'), throwsFormatException);
      expect(() => svgYolu('M0 0 H'), throwsFormatException);
      expect(() => svgYolu('M0'), throwsFormatException);
    });
  });

  for (final mod in temalar) {
    group(mod.name, () {
      testWidgets('sayfa zemininde L temaya göre', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, const TayfamLogo.yazili(), mod: mod);

        final renkler = _cizilen(tester).renkler;
        final l = mod == ThemeMode.light ? r.markaYuzey : r.marka;
        expect(renkler.l, l);
        expect(renkler.mango, r.mango);
        expect(renkler.nar, r.nar);
        expect(renkler.turkuaz, r.teal);
        expect(cizilenStil(tester, _yazi).color, r.metin);
      });

      testWidgets('mor marka yüzeyinde L #FAF8FF, yazı beyaz', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, _markaYuzeyinde(), mod: mod);

        expect(_cizilen(tester).renkler.l, TayfamLogoRenkleri.lMorZemin);
        expect(cizilenStil(tester, _yazi).color, r.markaYuzeyUstu);
      });

      testWidgets('rozet temadan bağımsız ve daireye kesilir', (tester) async {
        await bileseniAc(tester, const TayfamLogo.rozet(), mod: mod);

        final boyaci = _cizilen(tester);
        expect(boyaci.rozet, isTrue);
        expect(boyaci.renkler, LogoRenkleri.rozet);
      });

      testWidgets('tek renk verilen renkte', (tester) async {
        final r = renklerOf(mod);
        await bileseniAc(tester, TayfamLogo.tekRenk(renk: r.metin), mod: mod);

        expect(_cizilen(tester).renkler, LogoRenkleri.tek(r.metin));
      });
    });
  }

  testWidgets('yazı ile simge arası simge genişliğinin %30\'u', (tester) async {
    // Dar alanda logo orantılı küçülür; bu boyut 320 dp'ye sığar.
    const boyut = 32.0;
    await bileseniAc(
      tester,
      const Center(child: TayfamLogo.yazili(boyut: boyut)),
      mod: ThemeMode.light,
    );

    final simge = tester.getRect(_boyaci);
    final yazi = tester.getRect(_yazi);
    expect(simge.size, const Size.square(boyut));
    const bosluk = boyut * TayfamSizes.logoYaziBoslukOrani;
    expect(yazi.left - simge.right, moreOrLessEquals(bosluk));
  });

  testWidgets('dar alanda bütün logo orantılı küçülür, taşmaz', (tester) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamLogo.yazili()),
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
      const Center(child: TayfamLogo.yazili(boyut: TayfamSizes.logoBaslik)),
      mod: ThemeMode.light,
    );

    final stil = cizilenStil(tester, _yazi);
    expect(
      stil.fontSize,
      moreOrLessEquals(TayfamSizes.logoBaslik * TayfamSizes.logoYaziOrani),
    );
    expect(tester.widget<Text>(_yazi).textScaler, TextScaler.noScaling);
  });

  testWidgets('24 px altında yazısız', (tester) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamLogo.yazili(boyut: TayfamSizes.logoEnKucuk)),
      mod: ThemeMode.light,
    );

    expect(_yazi, findsNothing);
    expect(tester.getSize(_boyaci), const Size.square(TayfamSizes.logoEnKucuk));
  });

  testWidgets('24 px ve üstünde yazılı', (tester) async {
    await bileseniAc(
      tester,
      const Center(child: TayfamLogo.yazili(boyut: TayfamSizes.logoYaziEsigi)),
      mod: ThemeMode.light,
    );

    expect(_yazi, findsOneWidget);
  });

  test('16 px\'ten küçük boyut kabul edilmez', () {
    TayfamLogo olustur(double boyut) => TayfamLogo(boyut: boyut);
    expect(() => olustur(TayfamSizes.logoEnKucuk - 1), throwsAssertionError);
    expect(olustur(TayfamSizes.logoEnKucuk).boyut, TayfamSizes.logoEnKucuk);
  });

  testWidgets('ekran okuyucu tek bir "Tayfam" görseli okur', (tester) async {
    final kulp = tester.ensureSemantics();
    await bileseniAc(
      tester,
      const TayfamLogo.yazili(baslik: true),
      mod: ThemeMode.light,
    );

    final dugum = tester.getSemantics(find.byType(TayfamLogo));
    expect(
      dugum,
      isSemantics(
        label: arbMetni('bilesen_logo_etiketi'),
        isImage: true,
        isHeader: true,
      ),
    );
    kulp.dispose();
  });

  test('renk, biçim ya da blok hali değişince yeniden çizilir', () {
    final acik = LogoRenkleri.zemineGore(TayfamColors.acik.zemin);
    final koyu = LogoRenkleri.zemineGore(TayfamColors.koyu.zemin);
    final a = LogoBoyaci(renkler: acik);
    final b = LogoBoyaci(renkler: koyu);
    final c = LogoBoyaci(renkler: acik);
    const d = LogoBoyaci(renkler: LogoRenkleri.rozet, rozet: true);
    final e = LogoBoyaci(
      renkler: acik,
      haller: const {LogoBlogu.nar: BlokHali(olcek: .7)},
    );
    final f = LogoBoyaci(
      renkler: acik,
      haller: const {LogoBlogu.nar: BlokHali.normal},
    );
    expect(b.shouldRepaint(a), isTrue);
    expect(c.shouldRepaint(a), isFalse);
    expect(d.shouldRepaint(a), isTrue);
    expect(e.shouldRepaint(a), isTrue);
    expect(f.shouldRepaint(a), isFalse);
  });
}
