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
  });

  group('konvoy', () {
    test('rota ve araçlar etkinlik isteklerinde gitmez (bileşenler, '
        '#227, #228)', () {
      final taslak = EtkinlikTaslagi(
        istekKimligi: sahteEtkinlikIstekKimligi,
        tur: 'convoy',
        baslik: 'Sapanca turu',
        baslangic: ornekBaslangic,
        bitis: ornekBaslangic.add(const Duration(hours: 4)),
        yer: const YerBilgisi(nokta: _a, il: 'Sakarya', ilce: 'Sapanca'),
      );
      expect(olusturmaIstegi(taslak).toJson().containsKey('convoy'), isFalse);

      final eski = Event.fromJson(etkinlikJson(tur: 'convoy'));
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
