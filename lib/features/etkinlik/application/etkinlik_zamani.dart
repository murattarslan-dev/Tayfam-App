import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Türkiye saatinin UTC farkı. Türkiye 2016'dan beri yaz saati
/// uygulamıyor; `Europe/Istanbul` sabit UTC+3'tür. Saat dilimi veritabanı
/// paketi gerektirmemek için fark sabittir. Yalnızca tekrar kuralının
/// (`Europe/Istanbul`) son günü hesaplanırken kullanılır; ekranlarda zaman
/// cihazın saatiyle gösterilir ve girilir (ADR-0008).
const Duration istanbulFarki = Duration(hours: 3);

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
