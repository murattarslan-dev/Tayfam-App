import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/surum/surum.dart';
import 'package:tayfam/core/surum/uygulama_surumu.dart';

Surum _s(String metin) => Surum.coz(metin)!;

void main() {
  group('Surum.coz', () {
    test('SemVer 2.0.0 sürümleri okunuyor', () {
      for (final metin in [
        '0.1.0',
        '1.4.2',
        '1.2.0-rc.1',
        '1.0.0-alpha.beta',
        '0.1.0+1',
        '1.2.0-rc.1+build.5',
        '10.20.30',
      ]) {
        expect(Surum.coz(metin), isNotNull, reason: metin);
      }
    });

    test('geçersiz değerler reddediliyor', () {
      for (final metin in [
        '',
        'v1.2.0',
        '1.2',
        '01.2.0',
        '1.02.0',
        '1.2.0-',
        '1.2.0-01',
        '1.2.0+',
        '1.2.0 ',
        'android/1.2.0',
        '1.2.0-rc..1',
        '1.${'9' * 70}.0',
      ]) {
        expect(Surum.coz(metin), isNull, reason: metin);
      }
    });
  });

  group('karşılaştırma', () {
    test('ön sürüm, sürümün kendisinden düşük (1.2.0-rc.1 < 1.2.0)', () {
      expect(_s('1.2.0-rc.1') < _s('1.2.0'), isTrue);
      expect(_s('1.2.0') < _s('1.2.0-rc.1'), isFalse);
    });

    test('derleme bilgisi sayılmıyor', () {
      expect(_s('1.2.0+5'), _s('1.2.0+9'));
      expect(_s('1.2.0+5') < _s('1.2.0'), isFalse);
      expect(_s('0.1.0+1') < _s('0.1.0'), isFalse);
    });

    test('SemVer sırası', () {
      final sirali = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '1.1.0',
        '1.9.0',
        '1.10.0',
        '2.0.0',
        '12345678901234567890.0.0',
      ];
      for (var i = 0; i + 1 < sirali.length; i++) {
        expect(
          _s(sirali[i]) < _s(sirali[i + 1]),
          isTrue,
          reason: '${sirali[i]} < ${sirali[i + 1]}',
        );
        expect(_s(sirali[i + 1]) < _s(sirali[i]), isFalse);
      }
    });
  });

  group('sürüm başlığı', () {
    String? baslik(String ad, String surum) =>
        surumBasligi(istemciAdi: ad, surum: surum);

    test('platform ve sürüm sözleşmenin biçiminde', () {
      expect(baslik('android', '0.1.0+1'), 'android/0.1.0+1');
      expect(baslik('ios', '1.2.0-rc.1'), 'ios/1.2.0-rc.1');
      expect(baslik('web', '1.0.0'), 'web/1.0.0');
      for (final ad in ['android', 'ios', 'web']) {
        expect(surumBasligiBicimi.hasMatch(baslik(ad, '1.0.0')!), isTrue);
      }
    });

    test('sürüm yoksa ya da geçersizse başlık yok', () {
      expect(baslik('android', ''), isNull);
      expect(baslik('android', 'v1.0.0'), isNull);
      expect(baslik('android', '1.0.0-${'a' * 70}'), isNull);
      expect(baslik('masaustu', '1.0.0'), isNull);
    });
  });
}
