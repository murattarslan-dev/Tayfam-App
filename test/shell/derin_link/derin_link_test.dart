import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/shell/derin_link/derin_link.dart';
import 'package:tayfam/shell/derin_link/derin_link_kutusu.dart';

/// Biçimi geçerli sahte davet token'ı (base64url, 43 karakter; gerçek değil).
const String _token = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE';

GelenAdres _ayristir(String adres) => gelenAdresiAyristir(Uri.parse(adres));

void main() {
  group('gelenAdresiAyristir: davet linki', () {
    test('tam uygulama linki', () {
      expect(
        _ayristir('https://tayfam.app/davet#$_token'),
        const DavetLinki(_token),
      );
    });

    test('sondaki eğik çizgi ve sorgu bozmaz', () {
      expect(
        _ayristir('https://tayfam.app/davet/?utm=x#$_token'),
        const DavetLinki(_token),
      );
    });

    test('alan adı büyük harfle gelse de kabul edilir', () {
      expect(
        _ayristir('https://TAYFAM.app/davet#$_token'),
        const DavetLinki(_token),
      );
    });

    test('yalnızca yol + fragment (eski gömücü biçimi)', () {
      expect(_ayristir('/davet#$_token'), const DavetLinki(_token));
    });

    test('fragmentsiz iç /davet adresi uygulamanın kendi ekranı', () {
      expect(_ayristir('/davet'), isA<IcAdres>());
    });

    for (final adres in [
      'https://tayfam.app/davet',
      'https://tayfam.app/davet#',
      'https://tayfam.app/davet#kısa token',
      'https://tayfam.app/davet#${'a' * 65}',
      'https://tayfam.app/davet#abc%2Fdef',
      '/davet#a.b',
    ]) {
      test('bozuk token geçersiz: $adres', () {
        expect(_ayristir(adres), isA<GecersizLink>());
      });
    }
  });

  group('gelenAdresiAyristir: referans linki', () {
    for (final kod in ['TYF-8K2M4Q', 'tyf-8k2m4q', '8K2M4Q']) {
      test('geçerli kod: $kod', () {
        expect(_ayristir('https://tayfam.app/r/$kod'), ReferansLinki(kod));
      });
    }

    test('yalnızca yol', () {
      expect(_ayristir('/r/TYF-8K2M4Q'), const ReferansLinki('TYF-8K2M4Q'));
    });

    for (final adres in [
      'https://tayfam.app/r/',
      'https://tayfam.app/r/TYF-8K2M4',
      'https://tayfam.app/r/TYF-8K2M4QQ',
      // Karışan harfler (0, 1, I, L, O) kodda yoktur.
      'https://tayfam.app/r/TYF-0K2M4Q',
      'https://tayfam.app/r/TYF-IK2M4Q',
      'https://tayfam.app/r/TYF-8K2M4Q/fazla',
      '/r/<script>',
    ]) {
      test('bozuk kod geçersiz: $adres', () {
        expect(_ayristir(adres), isA<GecersizLink>());
      });
    }
  });

  group('gelenAdresiAyristir: yalnızca beklenen alan adı ve yol', () {
    for (final adres in [
      'http://tayfam.app/davet#$_token',
      'https://www.tayfam.app/davet#$_token',
      'https://tayfam.app.ornek.test/davet#$_token',
      'https://ornek.test/davet#$_token',
      'https://kisi@tayfam.app/davet#$_token',
      'https://tayfam.app:8443/davet#$_token',
      'tayfam://davet#$_token',
      'https://tayfam.app/t/0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10',
      'https://tayfam.app/',
      'https://tayfam.app/davetler#$_token',
    ]) {
      test('geçersiz: $adres', () {
        expect(_ayristir(adres), isA<GecersizLink>());
      });
    }

    for (final adres in ['/', '/karsilama', '/t/x/etkinlikler', '/giris']) {
      test('iç adres: $adres', () {
        expect(_ayristir(adres), isA<IcAdres>());
      });
    }
  });

  test('toString token ve kodu içermez (kesin kural 3)', () {
    expect(const DavetLinki(_token).toString(), isNot(contains(_token)));
    expect(
      const ReferansLinki('TYF-8K2M4Q').toString(),
      isNot(contains('8K2M4Q')),
    );
  });

  group('DerinLinkKutusu', () {
    test('davet linki saklanır, yönlendirme köke döner', () {
      final kutu = DerinLinkKutusu();
      final konum = kutu.yakala(
        Uri.parse('https://tayfam.app/davet#$_token'),
        oturumAcik: false,
      );
      expect(konum.toString(), '/');
      expect(kutu.davetToken, _token);
      expect(kutu.davetBekliyor, isTrue);

      kutu.davetiBirak();
      expect(kutu.davetToken, isNull);
      expect(kutu.davetBekliyor, isFalse);
    });

    test('yeni davet eskisinin yerine geçer', () {
      final kutu = DerinLinkKutusu()
        ..yakala(Uri.parse('/davet#eski'), oturumAcik: true)
        ..yakala(Uri.parse('/davet#yeni'), oturumAcik: true);
      expect(kutu.davetToken, 'yeni');
    });

    test('iç adres olduğu gibi döner, kutu değişmez', () {
      final kutu = DerinLinkKutusu();
      final adres = Uri.parse('/t/x/etkinlikler');
      expect(identical(kutu.yakala(adres, oturumAcik: true), adres), isTrue);
      expect(kutu.davetBekliyor, isFalse);
      expect(kutu.referansKodu, isNull);
    });

    test('referans kodu yalnızca oturum açık değilken saklanır', () {
      final kutu = DerinLinkKutusu();
      final link = Uri.parse('https://tayfam.app/r/TYF-8K2M4Q');
      kutu.yakala(link, oturumAcik: true);
      expect(kutu.referansKodu, isNull);

      final konum = kutu.yakala(link, oturumAcik: false);
      expect(konum.toString(), '/');
      expect(kutu.referansKodu, 'TYF-8K2M4Q');

      kutu.referansiBirak();
      expect(kutu.referansKodu, isNull);
    });

    test('geçersiz link saklanmaz, köke döner', () {
      final kutu = DerinLinkKutusu();
      final konum = kutu.yakala(
        Uri.parse('https://ornek.test/davet#$_token'),
        oturumAcik: true,
      );
      expect(konum.toString(), '/');
      expect(kutu.davetBekliyor, isFalse);
    });
  });
}
