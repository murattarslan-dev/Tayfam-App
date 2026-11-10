import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/google_marka.dart';
import 'package:tayfam/core/tema/kontrast.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';

void main() {
  test('Google düğmesi metni zeminde 4.5:1', () {
    expect(
      kontrastOrani(GoogleMarka.metin, GoogleMarka.zemin),
      greaterThanOrEqualTo(KontrastEsigi.metin),
    );
  });

  test('Google düğmesi mor marka yüzeyinde ayırt ediliyor (3:1)', () {
    for (final r in [TayfamColors.acik, TayfamColors.koyu]) {
      expect(
        kontrastOrani(GoogleMarka.zemin, r.markaYuzey),
        greaterThanOrEqualTo(KontrastEsigi.buyukMetinVeArayuz),
      );
      // Odak çerçevesi (mango) düğmenin beyaz zemininde de yüzeyde de
      // görünür kalmalı; çerçeve yüzeyin üstünde çizilir.
      expect(
        kontrastOrani(r.markaYuzeyOdak, r.markaYuzey),
        greaterThanOrEqualTo(KontrastEsigi.buyukMetinVeArayuz),
      );
    }
  });
}
