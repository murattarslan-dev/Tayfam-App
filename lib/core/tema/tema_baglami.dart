import 'package:flutter/material.dart';

import 'package:tayfam/core/tema/tayfam_colors.dart';

/// Token'lara kısa erişim: `context.renkler.marka`, `context.yazi.bodySmall`.
///
/// Renk her zaman temadan gelir; böylece açık/koyu geçişinde ve testlerde
/// doğru değer kullanılır ve ekranlarda sabit renk yazmaya gerek kalmaz.
extension TemaBaglami on BuildContext {
  /// Etkin temanın renk token'ları.
  TayfamColors get renkler => Theme.of(this).extension<TayfamColors>()!;

  /// Etkin temanın yazı ölçeği (ADR-0004 §4).
  TextTheme get yazi => Theme.of(this).textTheme;
}
