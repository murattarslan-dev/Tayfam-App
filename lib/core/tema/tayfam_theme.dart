import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';

/// Açık ve koyu `ThemeData` (Material 3, ADR-0004).
///
/// `ColorScheme` ve `TextTheme` token'lardan kurulur; [TayfamColors]
/// tema uzantısı olarak eklenir ve `context.renkler` ile okunur.
abstract final class TayfamTheme {
  /// Açık tema.
  static ThemeData acik() => _olustur(TayfamColors.acik, Brightness.light);

  /// Koyu tema (ADR-0004 §2).
  static ThemeData koyu() => _olustur(TayfamColors.koyu, Brightness.dark);

  static ThemeData _olustur(TayfamColors r, Brightness parlaklik) {
    final renkSemasi = ColorScheme(
      brightness: parlaklik,
      primary: r.marka,
      onPrimary: r.markaUstu,
      primaryContainer: r.tintMarka,
      onPrimaryContainer: r.tintMarkaUstu,
      secondary: r.teal,
      onSecondary: r.vurguUstu,
      tertiary: r.mango,
      onTertiary: r.vurguUstu,
      tertiaryContainer: r.tintMango,
      onTertiaryContainer: r.tintMangoUstu,
      // Nar yalnızca zemin ve kenar olarak kullanılır; hata metni
      // ana metin rengindedir (vurgu renkleri metin rengi olmaz).
      error: r.nar,
      onError: r.vurguUstu,
      errorContainer: r.nar,
      onErrorContainer: r.vurguUstu,
      surface: r.zemin,
      onSurface: r.metin,
      onSurfaceVariant: r.metinIkincil,
      surfaceContainerLowest: r.kart,
      surfaceContainerLow: r.kart,
      surfaceContainer: r.kart,
      surfaceContainerHigh: r.kart,
      surfaceContainerHighest: r.tintMarka,
      outline: r.girisKenari,
      outlineVariant: r.cizgi,
      inverseSurface: r.metin,
      onInverseSurface: r.zemin,
      shadow: r.golge,
    );
    final metinTemasi = TayfamTypography.metinTemasi(
      metin: r.metin,
      ikincil: r.metinIkincil,
    );
    final dugmeStili = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(TayfamSizes.dokunmaMin, TayfamSizes.dokunmaMin),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: TayfamSpacing.s20,
          vertical: TayfamSpacing.s12,
        ),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: TayfamRadii.dugmeKoseleri),
      ),
      textStyle: WidgetStatePropertyAll(metinTemasi.labelLarge),
      // Odak çerçevesi: 3 px mango (ADR-0004, Hareket ve erişilebilirlik).
      side: WidgetStateProperty.resolveWith(
        (durum) => durum.contains(WidgetState.focused)
            ? BorderSide(
                color: r.odak,
                width: TayfamSizes.odakKalinligi,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
      ),
    );

    return ThemeData(
      brightness: parlaklik,
      colorScheme: renkSemasi,
      extensions: [r],
      fontFamily: TayfamTypography.aile,
      textTheme: metinTemasi,
      scaffoldBackgroundColor: r.zemin,
      dividerColor: r.cizgi,
      // Dokunma alanı en az 48 dp (Material varsayılanı korunur).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(style: dugmeStili),
      outlinedButtonTheme: OutlinedButtonThemeData(style: dugmeStili),
      textButtonTheme: TextButtonThemeData(style: dugmeStili),
    );
  }
}
