import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_motion.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';

void _olcekDenetle(TextStyle? stil, double boyut, int agirlik, double satir) {
  expect(stil, isNotNull);
  expect(stil!.fontSize, boyut);
  expect(stil.fontWeight?.value, agirlik);
  expect(stil.height, satir);
  expect(stil.fontFamily, TayfamTypography.aile);
}

void main() {
  final temalar = {
    'açık': (TayfamTheme.acik(), TayfamColors.acik, Brightness.light),
    'koyu': (TayfamTheme.koyu(), TayfamColors.koyu, Brightness.dark),
  };

  for (final giris in temalar.entries) {
    final (tema, r, parlaklik) = giris.value;
    group('${giris.key} tema', () {
      test('token uzantısı ve renk şeması', () {
        expect(tema.brightness, parlaklik);
        expect(tema.extension<TayfamColors>(), same(r));
        final s = tema.colorScheme;
        expect(s.brightness, parlaklik);
        expect(s.primary, r.marka);
        expect(s.onPrimary, r.markaUstu);
        expect(s.surface, r.zemin);
        expect(s.onSurface, r.metin);
        expect(s.onSurfaceVariant, r.metinIkincil);
        expect(s.outline, r.girisKenari);
        expect(s.outlineVariant, r.cizgi);
        expect(s.tertiary, r.mango);
        expect(s.onTertiary, r.vurguUstu);
        expect(tema.scaffoldBackgroundColor, r.zemin);
      });

      test('yazı ölçeği ADR-0004 §4', () {
        final t = tema.textTheme;
        // Büyük başlık 28 / 750 (800 yuvası) / 1.1
        _olcekDenetle(t.headlineLarge, 28, 800, 1.1);
        _olcekDenetle(t.displaySmall, 28, 800, 1.1);
        // Ekran başlığı 22 / 700 / 1.1
        _olcekDenetle(t.titleLarge, 22, 700, 1.1);
        _olcekDenetle(t.headlineSmall, 22, 700, 1.1);
        // Gövde 17 / 400 / 1.5
        _olcekDenetle(t.bodyLarge, 17, 400, 1.5);
        _olcekDenetle(t.bodyMedium, 17, 400, 1.5);
        // İkincil 15 / 400 / 1.4
        _olcekDenetle(t.bodySmall, 15, 400, 1.4);
        expect(t.bodySmall!.color, r.metinIkincil);
        // Etiket 13–15 / 600–700 / 1.4
        _olcekDenetle(t.labelLarge, 15, 700, 1.4);
        _olcekDenetle(t.labelMedium, 13, 700, 1.4);
        _olcekDenetle(t.labelSmall, 13, 600, 1.4);
        expect(t.bodyLarge!.color, r.metin);
      });

      test('hiçbir yazı stili 13 px altına inmez', () {
        final t = tema.textTheme;
        final stiller = [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ];
        for (final stil in stiller) {
          expect(
            stil!.fontSize,
            greaterThanOrEqualTo(TayfamTypography.enKucukBoyut),
          );
          expect(stil.fontFamily, TayfamTypography.aile);
        }
      });

      test('dokunma alanı 48 dp, düğme odağında 3 px odak rengi', () {
        expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
        final stil = tema.filledButtonTheme.style!;
        final enAz = stil.minimumSize!.resolve(<WidgetState>{})!;
        expect(enAz.height, greaterThanOrEqualTo(48));
        final odak = stil.side!.resolve({WidgetState.focused})!;
        // Açık temada brand, koyu temada mango (ADR-0004 Notlar).
        expect(odak.color, r.odak);
        expect(odak.color, parlaklik == Brightness.dark ? r.mango : r.marka);
        expect(odak.width, 3);
        expect(stil.side!.resolve(<WidgetState>{}), isNull);
      });

      test('marka yüzeyi teması: odak mango, diğer renkler aynı', () {
        final yuzey = TayfamTheme.markaYuzeyi(tema);
        final yr = yuzey.extension<TayfamColors>()!;
        expect(yr.odak, r.mango);
        expect(yr.markaYuzey, r.markaYuzey);
        expect(yuzey.brightness, parlaklik);
        final kenar = yuzey.textButtonTheme.style!.side!;
        expect(kenar.resolve({WidgetState.focused})!.color, r.mango);
      });
    });
  }

  test('boşluk adımları ve yarıçaplar Standartlar ile aynı', () {
    expect(TayfamSpacing.adimlar, [4, 8, 12, 16, 20, 24, 32, 40, 56, 64]);
    expect(TayfamRadii.hap, 999);
    expect(TayfamRadii.kart, 22);
    expect(TayfamRadii.onizleme, 14);
    expect(TayfamRadii.dugme, 12);
    expect(TayfamRadii.balon, inInclusiveRange(16, 18));
    expect(TayfamRadii.balonKuyruk, 6);
    expect(TayfamSizes.odakKalinligi, 3);
    expect(TayfamSizes.odakBoslugu, 3);
    expect(TayfamSizes.dokunmaMin, greaterThanOrEqualTo(44));
  });

  test('geçiş süreleri 150–250 ms', () {
    for (final sure in [TayfamMotion.kisa, TayfamMotion.orta]) {
      expect(sure.inMilliseconds, inInclusiveRange(150, 250));
    }
    expect(TayfamMotion.uzun.inMilliseconds, inInclusiveRange(150, 250));
  });

  testWidgets('context.renkler etkin temayı izler', (tester) async {
    late TayfamColors okunan;
    await tester.pumpWidget(
      MaterialApp(
        theme: TayfamTheme.acik(),
        darkTheme: TayfamTheme.koyu(),
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            okunan = context.renkler;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(okunan.zemin, TayfamColors.koyu.zemin);
  });
}
