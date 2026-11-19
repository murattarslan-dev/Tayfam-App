import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ikonlar.dart';
import 'package:tayfam/core/katalog/ilgi_alani_secimi.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_gorunumu.dart';
import 'package:tayfam/core/katalog/katalog_metni.dart';
import 'package:tayfam/core/katalog/katalog_renkleri.dart';
import 'package:tayfam/core/tema/tayfam_tur_renkleri.dart';

import 'sahte_katalog.dart';

void main() {
  group('katalog', () {
    final katalog = testKatalogu();

    test('sürüm ve ETag (sözleşme: tırnak içinde sürüm)', () {
      expect(katalog.surum, 7);
      expect(katalog.etag, '"7"');
    });

    test('tür ve ilgi alanı anahtarla bulunur; katalogda olmayan null', () {
      expect(katalog.tur('hike')?.labels['tr'], 'Doğa yürüyüşü');
      expect(katalog.tur('yepyeni_tur'), isNull);
      expect(katalog.ilgiAlani('water')?.icon, 'water');
      expect(katalog.ilgiAlani('yok'), isNull);
    });

    test('emekli tür ve ilgi alanı seçilemez ama katalogda durur', () {
      expect(katalog.tur('eski_tur'), isNotNull);
      expect(
        katalog.secilebilirTurler.map((t) => t.key),
        isNot(contains('eski_tur')),
      );
      expect(katalog.ilgiAlani('eski_alan'), isNotNull);
      expect(
        katalog.secilebilirIlgiAlanlari.map((i) => i.key),
        isNot(contains('eski_alan')),
      );
    });

    test('tür birden fazla ilgi alanında listelenir (interest_keys)', () {
      expect(katalog.ilgiAlanininTurleri('nature').map((t) => t.key), [
        'hike',
        'camp',
        'dog_walk',
      ]);
      expect(katalog.ilgiAlanininTurleri('sports').map((t) => t.key), [
        'sports',
        'dog_walk',
      ]);
    });

    test('biçimi geçersiz anahtar ve yinelenen kayıt atlanır', () {
      final json = testKataloguJson();
      final turler = (json['event_types']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final bozuk = Katalog(
        Catalog.fromJson({
          ...json,
          'event_types': [
            {...turler.first, 'key': 'Bozuk Anahtar'},
            turler.first,
            {
              ...turler.first,
              'labels': {'tr': 'İkinci kopya'},
            },
          ],
        }),
      );
      expect(bozuk.turler, hasLength(1));
      expect(bozuk.tur('convoy')?.labels['tr'], 'Konvoy');
    });

    test('anahtar biçimi', () {
      expect(katalogAnahtariMi('hike'), isTrue);
      expect(katalogAnahtariMi('board_game_night'), isTrue);
      expect(katalogAnahtariMi('Hike'), isFalse);
      expect(katalogAnahtariMi('h'), isFalse);
      expect(katalogAnahtariMi('../hike'), isFalse);
      expect(katalogAnahtariMi('a' * 41), isFalse);
    });
  });

  group('metinler (ADR-0024 §2)', () {
    test('yerel ayardaki dil, yoksa tr', () {
      const adlar = {'tr': 'Konvoy', 'en': 'Convoy'};
      expect(katalogAdi(adlar, 'en'), 'Convoy');
      expect(katalogAdi(adlar, 'tr'), 'Konvoy');
      // Eksik dil: tr'ye düşer.
      expect(katalogAdi(adlar, 'de'), 'Konvoy');
      expect(katalogAdi(const {'tr': 'Kamp'}, 'en'), 'Kamp');
    });

    test('hiç metin yoksa ya da boşsa null', () {
      expect(katalogAdi(null, 'tr'), isNull);
      expect(katalogAdi(const {}, 'tr'), isNull);
      expect(katalogAdi(const {'en': 'Only'}, 'tr'), isNull);
      expect(katalogAdi(const {'tr': '   '}, 'tr'), isNull);
      // Seçilen dil boşsa tr'ye düşer.
      expect(katalogAdi(const {'en': ' ', 'tr': 'Kamp'}, 'en'), 'Kamp');
    });

    test('uzunluk sınırıyla kırpılır', () {
      final uzun = 'a' * 200;
      final kirpik = katalogDuzMetni(uzun)!;
      expect(kirpik.runes.length, katalogMetniEnCok + 1);
      expect(kirpik, endsWith('…'));
      expect(katalogDuzMetni('a' * katalogMetniEnCok), 'a' * katalogMetniEnCok);
      expect(katalogDuzMetni('abcdef', enCok: 3), 'abc…');
    });

    test('düz metin: tek satır, görünmeyen karakterler atılır', () {
      expect(katalogDuzMetni('  Doğa \n yürüyüşü\t '), 'Doğa yürüyüşü');
      // Çift yönlü metin işareti ve sıfır genişlikli boşluk.
      expect(katalogDuzMetni('Ka‮mp​'), 'Kamp');
      // Biçim ve bağlantı yorumlanmaz: olduğu gibi kalır.
      expect(
        katalogDuzMetni('<b>Kamp</b> [x](https://ornek.test)'),
        '<b>Kamp</b> [x](https://ornek.test)',
      );
    });
  });

  group('ikonlar (ADR-0024 §2)', () {
    test('bilinen anahtar haritadan çözülür', () {
      expect(katalogIkonu('hiking'), Icons.hiking);
      expect(katalogIkonu('phishing'), Icons.phishing);
    });

    test('bilinmeyen anahtar → ilgi alanının ikonu → genel ikon', () {
      expect(
        katalogIkonu('bilinmeyen_ikon', ilgiAlaniIkonu: 'forest'),
        Icons.forest,
      );
      expect(
        katalogIkonu('bilinmeyen_ikon', ilgiAlaniIkonu: 'o_da_yok'),
        katalogGenelIkonu,
      );
      expect(katalogIkonu(null), katalogGenelIkonu);
    });

    test('anahtarlar katalog anahtarı biçiminde ve sıralı', () {
      final anahtarlar = katalogIkonlari.keys.toList();
      expect(anahtarlar.every(katalogAnahtariMi), isTrue);
      expect(anahtarlar, [...anahtarlar]..sort());
    });

    test(
      'test kataloğundaki ikonlar (bilerek bilinmeyen dışında) haritada',
      () {
        final katalog = testKatalogu();
        final kullanilan = {
          for (final i in katalog.ilgiAlanlari) i.icon,
          for (final t in katalog.turler) t.icon,
        }..remove('bilinmeyen_ikon');
        expect(katalogIkonlari.keys, containsAll(kullanilan));
      },
    );
  });

  group('görünüm', () {
    final katalog = testKatalogu();

    test('tür: ad katalogdan, ikonu tanınmıyorsa ilgi alanınınki', () {
      final gorunum = turTanimiGorunumu(
        katalog.tur('ornek_alanlar')!,
        katalog,
        'tr',
      );
      expect(gorunum.ad, 'Örnek alanlar');
      expect(gorunum.ikon, Icons.event);
      expect(gorunum.renk, TurRengi.genel);
    });

    test('katalogda olmayan tür: ad yok, genel ikon', () {
      final gorunum = turGorunumu('yepyeni_tur', null, katalog, 'tr');
      expect(gorunum.ad, isNull);
      expect(gorunum.ikon, katalogGenelIkonu);
      expect(gorunum.renk, TurRengi.genel);
    });

    test('katalog gelmeden renk yine anahtardan gelir', () {
      expect(turGorunumu('convoy', null, null, 'tr').renk, TurRengi.konvoy);
      expect(ilgiAlaniGorunumu('water', null, 'tr').renk, TurRengi.balik);
      expect(ilgiAlaniGorunumu('water', null, 'tr').ad, isNull);
    });

    test('renk: tür → ana ilgi alanı → genel', () {
      expect(katalogRengi('hike'), TurRengi.yuruyus);
      expect(
        katalogRengi('dog_walk', ilgiAlanlari: const ['nature', 'sports']),
        TurRengi.kamp,
      );
      expect(katalogRengi('yepyeni_tur'), TurRengi.genel);
    });
  });

  group('ilgi alanı seçimi', () {
    final katalog = testKatalogu();

    test('emekli ilgi alanı yalnızca seçiliyse gösterilir', () {
      expect(
        gosterilenIlgiAlanlari(katalog, const {}).map((i) => i.key),
        isNot(contains('eski_alan')),
      );
      expect(
        gosterilenIlgiAlanlari(katalog, const {'eski_alan'}).map((i) => i.key),
        contains('eski_alan'),
      );
    });

    test('kataloğun sırasına dizilir; bilinmeyen anahtar sonda kalır', () {
      expect(
        ilgiAlanlariniSirala(katalog, const ['water', 'bilinmeyen', 'nature']),
        ['nature', 'water', 'bilinmeyen'],
      );
      expect(ilgiAlanlariniSirala(null, const ['water', 'nature']), [
        'water',
        'nature',
      ]);
    });
  });
}
