import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_radii.dart';
import 'package:tayfam/core/tema/tayfam_sizes.dart';
import 'package:tayfam/core/tema/tayfam_spacing.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';

/// Açık ve koyu `ThemeData` (Material 3, ADR-0004).
///
/// `ColorScheme` ve `TextTheme` token'lardan kurulur; [TayfamColors]
/// tema uzantısı olarak eklenir ve `context.renkler` ile okunur. Etkinlik
/// türü renkleri [TayfamTurRenkleri] uzantısındadır (`context.turRenkleri`).
abstract final class TayfamTheme {
  /// Açık tema.
  static ThemeData acik() => _olustur(TayfamColors.acik, Brightness.light);

  /// Koyu tema (ADR-0004 §2).
  static ThemeData koyu() => _olustur(TayfamColors.koyu, Brightness.dark);

  /// Mor marka yüzeyinin (tayfa ana sayfasının üst bölümü, ADR-0004 §2a)
  /// altında geçerli tema: odak çerçevesi iki temada da mango
  /// ([TayfamColors.markaYuzeyOdak]). `MarkaYuzeyi` bileşeni kullanır.
  static ThemeData markaYuzeyi(ThemeData tema) {
    final r = tema.extension<TayfamColors>()!;
    // Mor yüzeyde brand dolgulu tür çipi (oyun) görünmez; koyu temanın tür
    // renkleri (oyun brand-dark + ink) iki temada da kullanılır (Design:
    // Giriş, "Oyun gecesi" çipi #A98BFF).
    return _olustur(
      r.markaYuzeyIcin(),
      tema.brightness,
      turRenkleri: TayfamTurRenkleri.koyu,
    );
  }

  static ThemeData _olustur(
    TayfamColors r,
    Brightness parlaklik, {
    TayfamTurRenkleri? turRenkleri,
  }) {
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
      // Odak çerçevesi: 3 px, renk yüzeye göre `odak` (ADR-0004 Notlar,
      // 2026-11-10). Dış boşluklu çerçeveyi ortak bileşenlerde
      // OdakCercevesi çizer; bu, bileşensiz Material düğmeleri içindir.
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
      extensions: [
        r,
        turRenkleri ??
            (parlaklik == Brightness.dark
                ? TayfamTurRenkleri.koyu
                : TayfamTurRenkleri.acik),
      ],
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
