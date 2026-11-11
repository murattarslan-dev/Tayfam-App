import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Türkiye saatinin UTC farkı. Türkiye 2016'dan beri yaz saati
/// uygulamıyor; `Europe/Istanbul` sabit UTC+3'tür. Saat dilimi veritabanı
/// paketi gerektirmemek için fark sabittir (ADR-0015 §3: etkinlik zamanı
/// `Europe/Istanbul` ile gösterilir ve girilir).
const Duration istanbulFarki = Duration(hours: 3);

/// Tekrar kuralının saat dilimi (sözleşme: boşsa da `Europe/Istanbul`).
const String istanbulSaatDilimi = 'Europe/Istanbul';

/// [an]'ın Türkiye saatindeki duvar saati. Dönen değer UTC işaretlidir;
/// yalnızca alanları (yıl, ay, gün, saat, dakika) okunur ve biçimlenir.
DateTime istanbulSaatine(DateTime an) => an.toUtc().add(istanbulFarki);

/// Türkiye saatiyle verilen duvar saatinin gerçek anı (UTC).
DateTime istanbulSaatinden(
  int yil,
  int ay,
  int gun, [
  int saat = 0,
  int dakika = 0,
  int saniye = 0,
]) => DateTime.utc(yil, ay, gun, saat, dakika, saniye).subtract(istanbulFarki);

/// Cihazın saat dilimi Türkiye saatinden farklı mı; farklıysa zamanın
/// yanında "Türkiye saati" belirtilir (ADR-0008).
bool turkiyeDisindaMi(DateTime simdi) =>
    simdi.toLocal().timeZoneOffset != istanbulFarki;

/// Uygulamanın saati; testlerde sabit bir zaman verilir.
final etkinlikSaatiProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'etkinlikSaatiProvider',
);
