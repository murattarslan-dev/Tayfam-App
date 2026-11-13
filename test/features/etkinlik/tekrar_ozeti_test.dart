import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

void main() {
  late AppLocalizations m;

  setUpAll(() async {
    await initializeDateFormatting('tr');
    m = await AppLocalizations.delegate.load(const Locale('tr', 'TR'));
  });

  // Cihazın saatiyle 14 Kasım 2026 Cumartesi 08:30 (özet cihazın saatinde).
  final cumartesi = DateTime(2026, 11, 14, 8, 30).toUtc();

  group('tekrarKisaOzeti', () {
    test('tek seferlik, sıklık ve aralık', () {
      expect(tekrarKisaOzeti(m, null), 'Tek seferlik');
      expect(tekrarKisaOzeti(m, const TekrarSecimi()), 'Her hafta');
      expect(
        tekrarKisaOzeti(m, const TekrarSecimi(aralik: 2)),
        '2 haftada bir',
      );
      expect(
        tekrarKisaOzeti(
          m,
          const TekrarSecimi(siklik: TekrarSikligi.aylik, aralik: 3),
        ),
        '3 ayda bir',
      );
    });

    test('bitiş: sayı ve son gün', () {
      expect(
        tekrarKisaOzeti(
          m,
          const TekrarSecimi(bitis: TekrarBitisi.sayi, sayi: 6),
        ),
        'Her hafta, 6 kez',
      );
      expect(
        tekrarKisaOzeti(
          m,
          TekrarSecimi(
            bitis: TekrarBitisi.tarih,
            sonGun: DateTime.utc(2026, 12, 20),
          ),
        ),
        'Her hafta, son gün 20 Ara 2026',
      );
    });
  });

  group('tekrarOzeti', () {
    test('tek seferlik: gün ve saat', () {
      expect(
        tekrarOzeti(m, null, cumartesi),
        'Tek seferlik: 14 Kasım Cumartesi 08:30.',
      );
    });

    test('her cumartesi, 6 kez: son etkinlik', () {
      expect(
        tekrarOzeti(
          m,
          const TekrarSecimi(bitis: TekrarBitisi.sayi, sayi: 6),
          cumartesi,
        ),
        'Her cumartesi 08:30, 6 kez: son etkinlik 19 Aralık.',
      );
    });

    test('iki haftada bir', () {
      expect(
        tekrarOzeti(
          m,
          const TekrarSecimi(aralik: 2, bitis: TekrarBitisi.sayi, sayi: 3),
          cumartesi,
        ),
        '2 haftada bir cumartesi 08:30, 3 kez: son etkinlik 12 Aralık.',
      );
    });

    test('bitiş yok', () {
      expect(
        tekrarOzeti(m, const TekrarSecimi(), cumartesi),
        'Her cumartesi 08:30, bitiş yok.',
      );
    });

    test('her ay, son günde biter; yıl farklıysa yazılır', () {
      final onBes = DateTime(2026, 11, 15, 8, 30).toUtc();
      expect(
        tekrarOzeti(
          m,
          TekrarSecimi(
            siklik: TekrarSikligi.aylik,
            bitis: TekrarBitisi.tarih,
            sonGun: DateTime.utc(2027, 3, 31),
          ),
          onBes,
        ),
        'Her ayın 15. günü 08:30, son gün 31 Mart 2027: 5 kez.',
      );
    });

    test('son gün seçilmemiş', () {
      expect(
        tekrarOzeti(
          m,
          const TekrarSecimi(bitis: TekrarBitisi.tarih),
          cumartesi,
        ),
        'Her cumartesi 08:30.',
      );
    });
  });
}
