import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/zaman/takvim_gunu.dart';

/// Türkiye saatinin UTC farkı ([istanbulSaatFarki]). Yalnızca tekrar
/// kuralının (`Europe/Istanbul`) son günü hesaplanırken kullanılır;
/// ekranlarda zaman cihazın saatiyle gösterilir ve girilir (ADR-0008).
const Duration istanbulFarki = istanbulSaatFarki;

/// Tekrar kuralının saat dilimi (sözleşme: boşsa da `Europe/Istanbul`).
const String istanbulSaatDilimi = 'Europe/Istanbul';

/// Türkiye saatiyle verilen duvar saatinin gerçek anı (UTC).
DateTime istanbulSaatinden(
  int yil,
  int ay,
  int gun, [
  int saat = 0,
  int dakika = 0,
  int saniye = 0,
]) => DateTime.utc(yil, ay, gun, saat, dakika, saniye).subtract(istanbulFarki);

/// Uygulamanın saati; testlerde sabit bir zaman verilir.
final etkinlikSaatiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'etkinlikSaatiProvider',
);
