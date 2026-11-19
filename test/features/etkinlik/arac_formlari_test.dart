import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/arac_formlari.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';

import 'sahteler.dart';

const LatLng _a = LatLng(lat: 40.1, lng: 29.1);

Event _etkinlik({
  DateTime? baslangic,
  bool yonetebilir = false,
  String? cevap,
  String? katilim,
  bool iptal = false,
}) => Event.fromJson(
  etkinlikJson(
    baslangic: baslangic ?? gecmisBaslangic,
    sure: const Duration(hours: 3),
    yonetebilir: yonetebilir,
    cevap: cevap,
    katilim: katilim,
    iptal: iptal,
  ),
);

void main() {
  group('araç formu', () {
    test('yalnızca marka zorunlu; boş alanlar gönderilmez', () {
      final sonuc = aracIstegi(marka: ' Anadol ', buYil: 2026);
      expect(sonuc.hatalar, isEmpty);
      expect(sonuc.istek!.toJson(), {'make': 'Anadol'});
    });

    test('tüm alanlar; plaka harf, rakam ve tek boşluk', () {
      final sonuc = aracIstegi(
        marka: 'Anadol',
        model: 'A1',
        yil: '1972',
        renk: 'Turuncu',
        plaka: '34 AB 1972',
        buYil: 2026,
      );
      expect(sonuc.istek!.toJson(), {
        'make': 'Anadol',
        'model': 'A1',
        'model_year': 1972,
        'color': 'Turuncu',
        'plate': '34 AB 1972',
      });
    });

    test('hatalar: marka, yıl ve plaka', () {
      expect(aracIstegi(marka: '  ', buYil: 2026).hatalar, {AracHatasi.marka});
      expect(aracIstegi(marka: 'A' * 41, buYil: 2026).hatalar, {
        AracHatasi.marka,
      });
      for (final yil in ['1899', '2028', 'yetmiş']) {
        expect(aracIstegi(marka: 'Anadol', yil: yil, buYil: 2026).hatalar, {
          AracHatasi.yil,
        }, reason: yil);
      }
      expect(
        aracIstegi(marka: 'Anadol', yil: '2027', buYil: 2026).hatalar,
        isEmpty,
        reason: 'gelecek yıl olabilir',
      );
      for (final plaka in ['3', '34  AB 12', '34-AB-12', 'A' * 17]) {
        expect(aracIstegi(marka: 'Anadol', plaka: plaka, buYil: 2026).hatalar, {
          AracHatasi.plaka,
        }, reason: plaka);
      }
    });
  });

  group('kamp malzemesi formu', () {
    test('ad zorunlu; adet boşsa gönderilmez', () {
      expect(malzemeIstegi(ad: ' Çadır ').istek!.toJson(), {'name': 'Çadır'});
      expect(malzemeIstegi(ad: 'Ocak', adet: '2').istek!.toJson(), {
        'name': 'Ocak',
        'quantity': 2,
      });
      expect(malzemeIstegi(ad: '').hatalar, {MalzemeHatasi.ad});
      expect(malzemeIstegi(ad: 'Ocak', adet: '1000').hatalar, {
        MalzemeHatasi.adet,
      });
    });

    test('adet 1–999 (issue #187)', () {
      expect(malzemeIstegi(ad: 'Ocak', adet: '0').hatalar, {
        MalzemeHatasi.adet,
      });
      expect(malzemeIstegi(ad: 'Ocak', adet: '1').istek!.quantity, 1);
      expect(malzemeIstegi(ad: 'Ocak', adet: '999').istek!.quantity, 999);
    });

    test('"Kim getirecek?": seçilen kişi assigned_user_id olur, "Henüz '
        'kimse"de alan yok', () {
      const kisi = '0d1e2f3a-4b5c-4d6e-8f7a-8b9c0d1e2f3a';
      expect(
        malzemeIstegi(ad: 'Ocak', adet: '1', getiren: kisi).istek!.toJson(),
        {'name': 'Ocak', 'quantity': 1, 'assigned_user_id': kisi},
      );
      expect(
        malzemeIstegi(
          ad: 'Ocak',
          adet: '1',
        ).istek!.toJson().containsKey('assigned_user_id'),
        isFalse,
      );
    });
  });

  group('av formu', () {
    test('varsayılan görünürlük "Yalnızca ben" (self); yer seçilmeden yer '
        've görünürlük gönderilmez (issue #187)', () {
      final varsayilan = avIstegi(
        tur: 'Levrek',
        boy: '40',
        yer: _a,
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(varsayilan.istek!.toJson()['visibility'], 'self');

      final yersiz = avIstegi(
        tur: 'Levrek',
        boy: '40',
        gorunurluk: FishingCatchCreateRequestVisibility.tayfa,
        istekKimligi: sahteEtkinlikIstekKimligi,
      ).istek!.toJson();
      expect(yersiz.containsKey('location'), isFalse);
      expect(yersiz.containsKey('visibility'), isFalse);
    });

    test('boy bir ondalığa yuvarlanır, virgül kabul edilir', () {
      final sonuc = avIstegi(
        tur: 'Levrek',
        boy: '42,56',
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek!.toJson(), {
        'species': 'Levrek',
        'length_cm': 42.6,
        'client_request_id': sahteEtkinlikIstekKimligi,
      });
    });

    test('yer seçildiyse görünürlüğüyle gider', () {
      final sonuc = avIstegi(
        tur: 'Levrek',
        boy: '40',
        yer: _a,
        gorunurluk: FishingCatchCreateRequestVisibility.tayfa,
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek!.toJson(), {
        'species': 'Levrek',
        'length_cm': 40.0,
        'location': {'lat': 40.1, 'lng': 29.1},
        'visibility': 'tayfa',
        'client_request_id': sahteEtkinlikIstekKimligi,
      });
    });

    test('hatalar: tür ve boy', () {
      for (final boy in ['', '0', '-3', '1000.1', 'uzun']) {
        expect(
          avIstegi(
            tur: 'Levrek',
            boy: boy,
            istekKimligi: sahteEtkinlikIstekKimligi,
          ).hatalar,
          {AvHatasi.boy},
          reason: boy,
        );
      }
      expect(
        avIstegi(
          tur: ' ',
          boy: '30',
          istekKimligi: sahteEtkinlikIstekKimligi,
        ).hatalar,
        {AvHatasi.tur},
      );
    });
  });

  group('görünürlük kuralları', () {
    test('organizatör düzeltmesi: bitişten sonraki yedi gün', () {
      final e = _etkinlik(yonetebilir: true);
      expect(katilimDuzeltmeAcik(e, sabitSimdi), isTrue);
      expect(katilimDuzeltmeAcik(e, e.endsAt), isTrue);
      expect(
        katilimDuzeltmeAcik(e, e.endsAt.subtract(const Duration(minutes: 1))),
        isFalse,
        reason: 'etkinlik bitmeden',
      );
      expect(
        katilimDuzeltmeAcik(e, e.endsAt.add(katilimDuzeltmeSuresi)),
        isFalse,
      );
      expect(katilimDuzeltmeAcik(_etkinlik(), sabitSimdi), isFalse);
      expect(
        katilimDuzeltmeAcik(
          _etkinlik(yonetebilir: true, iptal: true),
          sabitSimdi,
        ),
        isFalse,
      );
    });

    test('av ekleme: doğrulanmış katılım, bitişten sonraki yedi gün', () {
      expect(avEklenebilir(_etkinlik(katilim: 'attended'), sabitSimdi), isTrue);
      expect(avEklenebilir(_etkinlik(), sabitSimdi), isFalse);
      final e = _etkinlik(katilim: 'attended');
      expect(avEklenebilir(e, e.endsAt.add(avEklemeSuresi)), isFalse);
    });

    test('araç ekleme: "Geliyorum" ve bitmemiş etkinlik', () {
      final yakin = _etkinlik(baslangic: yakinBaslangic, cevap: 'going');
      expect(aracEklenebilir(yakin, sabitSimdi), isTrue);
      expect(
        aracEklenebilir(
          _etkinlik(baslangic: yakinBaslangic, cevap: 'maybe'),
          sabitSimdi,
        ),
        isFalse,
      );
      expect(
        aracEklenebilir(_etkinlik(cevap: 'going'), sabitSimdi),
        isFalse,
        reason: 'bitmiş',
      );
    });
  });

  group('konvoy', () {
    test('rota etkinlik isteklerinde gitmez (route bileşeni, #227)', () {
      final taslak = EtkinlikTaslagi(
        istekKimligi: sahteEtkinlikIstekKimligi,
        tur: 'convoy',
        baslik: 'Sapanca turu',
        baslangic: ornekBaslangic,
        bitis: ornekBaslangic.add(const Duration(hours: 4)),
        yer: const YerBilgisi(nokta: _a, il: 'Sakarya', ilce: 'Sapanca'),
      );
      expect(olusturmaIstegi(taslak).toJson().containsKey('convoy'), isFalse);

      final eski = Event.fromJson(
        etkinlikJson(tur: 'convoy', ayrinti: {'vehicles': const <Object?>[]}),
      );
      final t = duzenlemeTaslagi(eski, sahteEtkinlikIstekKimligi);
      expect(duzenlemeIstegi(t, eski), isNull, reason: 'değişiklik yok');
      expect(
        duzenlemeIstegi(t.kopya(ayrintiDegisti: true), eski),
        isNull,
        reason: 'konvoyun türe özel ayrıntısı yok',
      );
    });
  });
}
