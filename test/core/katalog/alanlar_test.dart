import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alanlar.dart';

import 'sahte_katalog.dart';

void main() {
  final alanlar = testTuru('ornek_alanlar').definition.fields!;
  CatalogField alan(String anahtar) =>
      alanlar.firstWhere((a) => a.key == anahtar);

  /// Bütün alanları geçerli değerlerle dolu form.
  const dolu = <String, Object?>{
    'baslik': ' Göl turu ',
    'notlar': 'Çadırını getir.',
    'kisi': '12',
    'mesafe': '12,5',
    'seviye': 'ileri',
    'diller': ['tr', 'en'],
    'su_var': false,
    'son_kayit': '2026-11-30',
    'sure': '90',
  };

  test('test kataloğu bütün alan türlerini kullanır (ADR-0024 §7)', () {
    expect(
      alanlar.map((a) => AlanTuru.coz(a.kind)).toSet(),
      AlanTuru.values.toSet(),
    );
  });

  group('alan türü', () {
    test('kapalı liste; tanınmayan tür null', () {
      expect(AlanTuru.coz('long_text'), AlanTuru.uzunMetin);
      expect(AlanTuru.coz('multi_choice'), AlanTuru.cokluSecim);
      expect(AlanTuru.coz('matrix'), isNull);
      expect(AlanTuru.coz('url'), isNull);
    });

    test('tanınmayan alan türü içeren türde oluşturma kapalı', () {
      expect(alanlarTaniniyor(alanlar), isTrue);
      expect(
        alanlarTaniniyor(testTuru('gelecek_tur').definition.fields!),
        isFalse,
      );
      expect(alanlarTaniniyor(const []), isTrue);
    });
  });

  group('doğrulama', () {
    test('geçerli form hatasız', () {
      expect(alanHatalari(alanlar, dolu), isEmpty);
    });

    test('zorunlu alanlar: boş, yalnızca boşluk ve boş liste', () {
      expect(alanHatalari(alanlar, const {}), {
        'baslik': AlanHatasi.zorunlu,
        'diller': AlanHatasi.zorunlu,
      });
      expect(
        alanHatalari(alanlar, const {'baslik': '   ', 'diller': <String>[]}),
        {'baslik': AlanHatasi.zorunlu, 'diller': AlanHatasi.zorunlu},
      );
    });

    test('metin uzunluğu tanımdan (harf sayısı)', () {
      expect(
        alanHatalari(alanlar, {...dolu, 'baslik': 'ğ' * 41}),
        {'baslik': AlanHatasi.uzunluk},
      );
      expect(alanHatalari(alanlar, {...dolu, 'baslik': 'ğ' * 40}), isEmpty);
      expect(
        alanHatalari(alanlar, {...dolu, 'notlar': 'a' * 301}),
        {'notlar': AlanHatasi.uzunluk},
      );
    });

    test('tam sayı: biçim ve aralık', () {
      for (final kotu in ['abc', '1.5', '1e3', '']) {
        final hatalar = alanHatalari(alanlar, {...dolu, 'kisi': kotu});
        expect(
          hatalar['kisi'],
          kotu.isEmpty ? isNull : AlanHatasi.sayi,
          reason: kotu,
        );
      }
      expect(
        alanHatalari(alanlar, {...dolu, 'kisi': '0'}),
        {'kisi': AlanHatasi.aralik},
      );
      expect(
        alanHatalari(alanlar, {...dolu, 'kisi': '51'}),
        {'kisi': AlanHatasi.aralik},
      );
      expect(alanHatalari(alanlar, {...dolu, 'kisi': '50'}), isEmpty);
    });

    test('ondalık: virgül ve nokta, basamak sayısı, aralık', () {
      expect(alanHatalari(alanlar, {...dolu, 'mesafe': '12.5'}), isEmpty);
      expect(
        alanHatalari(alanlar, {...dolu, 'mesafe': '12,55'}),
        {'mesafe': AlanHatasi.basamak},
      );
      expect(
        alanHatalari(alanlar, {...dolu, 'mesafe': '0,4'}),
        {'mesafe': AlanHatasi.aralik},
      );
      expect(
        alanHatalari(alanlar, {...dolu, 'mesafe': '1,2,3'}),
        {'mesafe': AlanHatasi.sayi},
      );
    });

    test('süre: dakika, tam sayı, en az tanımdan', () {
      expect(
        alanHatalari(alanlar, {...dolu, 'sure': '4'}),
        {'sure': AlanHatasi.aralik},
      );
      expect(
        alanHatalari(alanlar, {...dolu, 'sure': '1,5'}),
        {'sure': AlanHatasi.sayi},
      );
    });

    test('seçim: tanımda olmayan seçenek ve en çok seçim', () {
      expect(
        alanHatalari(alanlar, {...dolu, 'seviye': 'efsane'}),
        {'seviye': AlanHatasi.secim},
      );
      expect(
        alanHatalari(alanlar, {
          ...dolu,
          'diller': ['tr', 'xx'],
        }),
        {'diller': AlanHatasi.secim},
      );
      expect(
        alanHatalari(alanlar, {
          ...dolu,
          'diller': ['tr', 'en', 'de'],
        }),
        {'diller': AlanHatasi.cokSecim},
      );
    });

    test('tarih: geçerli takvim günü', () {
      expect(
        alanHatalari(alanlar, {...dolu, 'son_kayit': '2026-02-30'}),
        {'son_kayit': AlanHatasi.tarih},
      );
      expect(
        alanHatalari(alanlar, {...dolu, 'son_kayit': '30.11.2026'}),
        {'son_kayit': AlanHatasi.tarih},
      );
      expect(alanTarihiCoz('2028-02-29'), DateTime.utc(2028, 2, 29));
      expect(alanTarihiYaz(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('tanınmayan türdeki alan denetlenmez', () {
      final gelecek = testTuru('gelecek_tur').definition.fields!;
      expect(alanHatalari(gelecek, const {'tablo': 'x'}), isEmpty);
    });
  });

  group('sınırlar (tanım girdidir)', () {
    CatalogField ozel(Map<String, Object?> ek) => CatalogField.fromJson({
      'key': 'x',
      'kind': 'integer',
      'labels': {'tr': 'X'},
      ...ek,
    });

    test('varsayılanlar: min 0, süre 1, ondalık 2 basamak', () {
      expect(alanAraligi(ozel(const {})).enAz, 0);
      expect(alanAraligi(ozel(const {'kind': 'duration'})).enAz, 1);
      expect(alanBasamagi(ozel(const {'kind': 'decimal'})), 2);
      expect(alanBasamagi(ozel(const {'kind': 'decimal', 'decimals': 9})), 2);
    });

    test('metin sınırı sözleşmedeki üst sınırı aşamaz', () {
      expect(alanMetinSiniri(ozel(const {'kind': 'text'})), 120);
      expect(
        alanMetinSiniri(ozel(const {'kind': 'text', 'max_length': 5000})),
        120,
      );
      expect(alanMetinSiniri(ozel(const {'kind': 'long_text'})), 1000);
      expect(
        alanMetinSiniri(ozel(const {'kind': 'text', 'max_length': 30})),
        30,
      );
    });

    test('tutarsız aralıkta üst sınır alt sınıra çekilir', () {
      final aralik = alanAraligi(ozel(const {'min': 10, 'max': 5}));
      expect(aralik.enAz, 10);
      expect(aralik.enCok, 10);
    });

    test('seçenekler: biçimsiz ve yinelenen atılır', () {
      final secenekler = alanSecenekleri(
        ozel(const {
          'kind': 'choice',
          'options': ['a', 'a', 'B', '1', 'x y', ''],
        }),
      );
      expect(secenekler, ['a', '1']);
    });
  });

  group('gövde (EventFieldValues)', () {
    test('değerler alan türüne göre JSON olur; metin kırpılır', () {
      expect(alanGovdesi(alanlar, dolu), {
        'baslik': 'Göl turu',
        'notlar': 'Çadırını getir.',
        'kisi': 12,
        'mesafe': 12.5,
        'seviye': 'ileri',
        'diller': ['tr', 'en'],
        'su_var': false,
        'son_kayit': '2026-11-30',
        'sure': 90,
      });
    });

    test('değeri olmayan alan gövdede yok; null gönderilmez', () {
      final govde = alanGovdesi(alanlar, const {
        'baslik': 'Tur',
        'notlar': '  ',
        'diller': ['tr'],
      });
      expect(govde, {
        'baslik': 'Tur',
        'diller': ['tr'],
      });
      expect(govde.values, everyElement(isNotNull));
    });

    test('tanımda olmayan anahtar ve tanınmayan türdeki alan gönderilmez', () {
      expect(alanGovdesi(alanlar, {...dolu, 'yabanci': 'x'}).keys, dolu.keys);
      final gelecek = testTuru('gelecek_tur').definition.fields!;
      expect(alanGovdesi(gelecek, const {'tablo': 'x', 'ad': 'Y'}), {'ad': 'Y'});
    });

    test('alan hiç yoksa boş nesne', () {
      expect(alanGovdesi(const [], dolu), isEmpty);
    });
  });

  group('sunucudan okuma (düzenleme)', () {
    test('gövde forma döner ve aynı gövdeyi üretir', () {
      final govde = alanGovdesi(alanlar, dolu);
      final form = alanDegerleriOku(alanlar, govde);
      expect(form['kisi'], '12');
      expect(form['mesafe'], '12.5');
      expect(form['su_var'], false);
      expect(alanGovdesi(alanlar, form), govde);
    });

    test('türüne uymayan değer atlanır', () {
      final form = alanDegerleriOku(alanlar, const {
        'baslik': 42,
        'kisi': 'on iki',
        'diller': ['tr', 7],
        'su_var': 'evet',
        'seviye': 'ileri',
        'yabanci': true,
      });
      expect(form, {'seviye': 'ileri'});
      expect(alanDegerleriOku(alanlar, null), isEmpty);
    });

    test('tam sayı değerli ondalık sade yazılır', () {
      expect(sayiMetni(12.0), '12');
      expect(sayiMetni(12.5), '12.5');
      expect(sayiMetni(7), '7');
    });
  });

  test('aynı girdi: boş değerler yok sayılır, listeler içerikle', () {
    expect(
      ayniAlanDegerleri(const {'a': 'x', 'b': ''}, const {'a': 'x'}),
      isTrue,
    );
    expect(
      ayniAlanDegerleri(
        const {
          'd': ['tr', 'en'],
        },
        {
          'd': ['tr', 'en'],
        },
      ),
      isTrue,
    );
    expect(ayniAlanDegerleri(const {'a': 'x'}, const {'a': 'y'}), isFalse);
    expect(ayniAlanDegerleri(const {}, const {'s': false}), isFalse);
  });
}
