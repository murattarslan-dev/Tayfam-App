import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/sohbet/application/kanal_kitlesi.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ortak.dart';
import 'package:tayfam/l10n/app_localizations.dart';

void main() {
  late AppLocalizations m;

  setUpAll(() async {
    await initializeDateFormatting('tr');
    m = await AppLocalizations.delegate.load(const Locale('tr', 'TR'));
  });

  // Yerel saatle kurulur: hesap cihazın saat diliminde, takvim gününe göre.
  final simdi = DateTime(2026, 11, 15, 10);

  group('kapanış bandı', () {
    test('N gün sonra; açıklamada arşiv tarihi', () {
      final bant = kapanisBandi(DateTime(2026, 11, 20, 21, 5), simdi);
      expect(bant, isA<KapanisGunSonra>());
      expect(kapanisBasligi(m, bant!), 'Kanal 5 gün sonra kapanacak');
      expect(
        kapanisAciklamasi(m, bant),
        'Etkinlik bitti. 20 Kasım tarihinde arşivlenir; sonra mesajlar '
        'okunur ama yazılamaz.',
      );
    });

    test('takvim gününe göre: ertesi gün sabah "yarın"', () {
      final bant = kapanisBandi(DateTime(2026, 11, 16, 9), simdi);
      expect(bant, isA<KapanisYarin>());
      expect(kapanisBasligi(m, bant!), 'Kanal yarın kapanacak');
      // 23 saatten az kalsa da iki takvim günü sonrası "2 gün".
      final gece = kapanisBandi(
        DateTime(2026, 11, 17, 0, 30),
        DateTime(2026, 11, 15, 23, 50),
      );
      expect(kapanisBasligi(m, gece!), 'Kanal 2 gün sonra kapanacak');
    });

    test('aynı gün saatiyle ve doğru ekle', () {
      String baslik(int saat, int dakika) =>
          kapanisBasligi(m, kapanisBandi(
            DateTime(2026, 11, 15, saat, dakika),
            simdi,
          )!);
      expect(baslik(21, 5), "Kanal bugün 21:05'te kapanacak");
      expect(baslik(14, 30), "Kanal bugün 14:30'da kapanacak");
      expect(baslik(14, 0), "Kanal bugün 14:00'te kapanacak");
      expect(baslik(18, 40), "Kanal bugün 18:40'ta kapanacak");
      expect(baslik(10, 42), "Kanal bugün 10:42'de kapanacak");
    });

    test('arşiv zamanı geçtiyse (sunucu henüz arşivlemedi) bugün', () {
      final bant = kapanisBandi(DateTime(2026, 11, 15, 9), simdi);
      expect(bant, isA<KapanisBugun>());
    });

    test('etkinlik bitmeden (arşive 7 günden fazla varken) bant yok', () {
      expect(kapanisBandi(DateTime(2026, 11, 22, 10, 1), simdi), isNull);
      expect(kapanisBandi(DateTime(2026, 11, 22, 10), simdi), isNotNull);
    });

    test('sunucunun UTC zamanı cihazın saat diliminde gösterilir', () {
      final yerel = DateTime(2026, 11, 15, 21, 5);
      final bant = kapanisBandi(yerel.toUtc(), simdi.toUtc());
      expect(bant, isA<KapanisBugun>());
      expect(kapanisBasligi(m, bant!), "Kanal bugün 21:05'te kapanacak");
    });
  });

  test('saat eki son okunan sayıya göre', () {
    final ornekler = {
      (0, 0): 'da',
      (9, 0): 'da',
      (10, 0): 'da',
      (20, 0): 'de',
      (13, 0): 'te',
      (8, 1): 'de',
      (8, 3): 'te',
      (8, 6): 'da',
      (8, 7): 'de',
      (8, 9): 'da',
      (8, 30): 'da',
      (8, 40): 'ta',
      (8, 50): 'de',
    };
    for (final MapEntry(key: (saat, dakika), value: ek) in ornekler.entries) {
      expect(
        saatEki(DateTime(2026, 11, 15, saat, dakika)),
        ek,
        reason: '$saat:$dakika',
      );
    }
  });

  test('etkinlik başlığından kanal adı', () {
    expect(etkinlikKanalAdi('Boğaz sabah turu'), 'boğaz-sabah-turu');
    expect(etkinlikKanalAdi('  İzmir  Iğdır '), 'izmir-ığdır');
    final uzun = etkinlikKanalAdi('a' * 39 + ' bcd');
    expect(uzun.runes.length, lessThanOrEqualTo(kanalAdiEnUzun));
    expect(uzun.endsWith('-'), isFalse);
  });

  test('kitle görünürlükten okunur; tanınmayan bütün tayfa sayılır', () {
    Channel kanal(String gorunurluk) => Channel.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'tayfa_id': '22222222-2222-4222-8222-222222222222',
      'name': 'genel',
      'visibility': gorunurluk,
      'slow_mode_seconds': 0,
      'created_at': '2026-11-01T10:00:00Z',
      'updated_at': '2026-11-01T10:00:00Z',
    });
    expect(KanalKitlesi.kanaldan(kanal('event')), KanalKitlesi.etkinlik);
    expect(KanalKitlesi.kanaldan(kanal('selected')), KanalKitlesi.secili);
    expect(KanalKitlesi.kanaldan(kanal('staff')), KanalKitlesi.yonetim);
    expect(KanalKitlesi.kanaldan(kanal('yeni-tur')), KanalKitlesi.herkes);
    expect(KanalKitlesi.secili.sabit, isTrue);
    expect(KanalKitlesi.yonetim.sabit, isFalse);
  });
}
