import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/zaman/goreli_zaman.dart';
import 'package:tayfam/l10n/app_localizations.dart';

void main() {
  late AppLocalizations m;

  setUpAll(() async {
    await initializeDateFormatting('tr');
    m = await AppLocalizations.delegate.load(const Locale('tr', 'TR'));
  });

  // Yerel saatle kurulur: hesap cihazın saat diliminde, takvim gününe göre.
  final simdi = DateTime(2026, 11, 13, 15);

  group('goreliGecmis', () {
    final ornekler = <String, (DateTime, String)>{
      'az önce': (simdi.subtract(const Duration(seconds: 20)), 'az önce'),
      'dakika': (simdi.subtract(const Duration(minutes: 5)), '5 dk önce'),
      'saat': (simdi.subtract(const Duration(hours: 3)), '3 saat önce'),
      'dün': (DateTime(2026, 11, 12, 23, 30), 'dün'),
      'gün': (DateTime(2026, 11, 9, 8), '4 gün önce'),
      'gelecek': (simdi.add(const Duration(minutes: 1)), 'az önce'),
    };
    for (final MapEntry(key: ad, value: (an, beklenen)) in ornekler.entries) {
      test(ad, () => expect(goreliGecmis(m, an, simdi), beklenen));
    }

    test('bir haftadan eskisi tarihle; ay adı büyük harfe çevrilmez', () {
      expect(goreliGecmis(m, DateTime(2026, 11, 2, 10), simdi), '2 Kas');
    });
  });

  group('geriSayim', () {
    test('bugün, yarın, gün sonra', () {
      expect(geriSayim(m, DateTime(2026, 11, 13, 20), simdi), 'bugün');
      expect(geriSayim(m, DateTime(2026, 11, 14, 6), simdi), 'yarın');
      expect(geriSayim(m, DateTime(2026, 11, 16, 9), simdi), '3 gün sonra');
    });

    test('başlamış ve bitmemişse şimdi', () {
      expect(
        geriSayim(
          m,
          DateTime(2026, 11, 13, 14),
          simdi,
          bitis: DateTime(2026, 11, 13, 18),
        ),
        'şimdi',
      );
    });
  });
}
