import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';

void main() {
  // 14 Kasım 2026 Cumartesi 09:00, Türkiye saati.
  final baslangic = DateTime.utc(2026, 11, 14, 6);

  group('rruleUret', () {
    test('her hafta, bitişsiz: yalnızca FREQ (BYDAY yok, başlangıç uyar)', () {
      expect(rruleUret(const TekrarSecimi()), 'FREQ=WEEKLY');
    });

    test('her ay', () {
      expect(
        rruleUret(const TekrarSecimi(siklik: TekrarSikligi.aylik)),
        'FREQ=MONTHLY',
      );
    });

    test('aralık 1 değilse INTERVAL yazılır', () {
      expect(
        rruleUret(const TekrarSecimi(aralik: 2)),
        'FREQ=WEEKLY;INTERVAL=2',
      );
      expect(
        rruleUret(
          const TekrarSecimi(siklik: TekrarSikligi.aylik, aralik: 3),
        ),
        'FREQ=MONTHLY;INTERVAL=3',
      );
    });

    test('belirli sayıda: COUNT', () {
      expect(
        rruleUret(const TekrarSecimi(bitis: TekrarBitisi.sayi, sayi: 6)),
        'FREQ=WEEKLY;COUNT=6',
      );
    });

    test('belirli günde: UNTIL o günün sonu (Türkiye saati), UTC', () {
      final secim = TekrarSecimi(
        siklik: TekrarSikligi.aylik,
        aralik: 2,
        bitis: TekrarBitisi.tarih,
        sonGun: DateTime.utc(2027, 3, 31),
      );
      expect(rruleUret(secim), 'FREQ=MONTHLY;INTERVAL=2;UNTIL=20270331T205959Z');
    });

    test('sözleşmenin alt kümesinde kalır ve 256 karakteri geçmez', () {
      final secim = TekrarSecimi(
        aralik: tekrarAralikEnCok,
        bitis: TekrarBitisi.tarih,
        sonGun: DateTime.utc(2031, 1, 1),
      );
      final kural = rruleUret(secim);
      expect(kural.length, lessThanOrEqualTo(256));
      expect(
        kural,
        matches(RegExp(r'^FREQ=(WEEKLY|MONTHLY)(;INTERVAL=\d+)?'
            r'(;(COUNT=\d+|UNTIL=\d{8}T\d{6}Z))?$')),
      );
    });

    test('tekrar kuralı Europe/Istanbul saat dilimiyle', () {
      final kural = tekrarKurali(const TekrarSecimi());
      expect(kural.rrule, 'FREQ=WEEKLY');
      expect(kural.timeZone, istanbulSaatDilimi);
      expect(kural.toJson(), {
        'rrule': 'FREQ=WEEKLY',
        'time_zone': 'Europe/Istanbul',
      });
    });
  });

  group('tekrarHatasi', () {
    test('geçerli seçimler', () {
      expect(tekrarHatasi(const TekrarSecimi(), baslangic), isNull);
      expect(
        tekrarHatasi(
          const TekrarSecimi(aralik: 52, bitis: TekrarBitisi.sayi, sayi: 500),
          baslangic,
        ),
        isNull,
      );
      expect(
        tekrarHatasi(
          TekrarSecimi(
            bitis: TekrarBitisi.tarih,
            sonGun: DateTime.utc(2026, 11, 14),
          ),
          baslangic,
        ),
        isNull,
      );
    });

    test('aralık 1–52', () {
      expect(
        tekrarHatasi(const TekrarSecimi(aralik: 0), baslangic),
        TekrarHatasi.aralik,
      );
      expect(
        tekrarHatasi(const TekrarSecimi(aralik: 53), baslangic),
        TekrarHatasi.aralik,
      );
    });

    test('sayı 1–500', () {
      expect(
        tekrarHatasi(
          const TekrarSecimi(bitis: TekrarBitisi.sayi, sayi: 0),
          baslangic,
        ),
        TekrarHatasi.sayi,
      );
      expect(
        tekrarHatasi(
          const TekrarSecimi(bitis: TekrarBitisi.sayi, sayi: 501),
          baslangic,
        ),
        TekrarHatasi.sayi,
      );
    });

    test('son gün: seçilmemiş, başlangıçtan önce ya da beş yıldan uzak', () {
      expect(
        tekrarHatasi(const TekrarSecimi(bitis: TekrarBitisi.tarih), baslangic),
        TekrarHatasi.tarih,
      );
      expect(
        tekrarHatasi(
          TekrarSecimi(
            bitis: TekrarBitisi.tarih,
            sonGun: DateTime.utc(2026, 11, 13),
          ),
          baslangic,
        ),
        TekrarHatasi.tarih,
      );
      expect(
        tekrarHatasi(
          TekrarSecimi(
            bitis: TekrarBitisi.tarih,
            sonGun: DateTime.utc(2032, 1, 1),
          ),
          baslangic,
        ),
        TekrarHatasi.tarih,
      );
    });
  });

  group('Türkiye saati', () {
    test('UTC+3, yaz saati yok', () {
      expect(istanbulSaatine(DateTime.utc(2026, 7, 1, 21)).day, 2);
      expect(istanbulSaatine(DateTime.utc(2026, 7, 1, 21)).hour, 0);
      expect(
        istanbulSaatinden(2026, 1, 15, 9),
        DateTime.utc(2026, 1, 15, 6),
      );
    });
  });
}
