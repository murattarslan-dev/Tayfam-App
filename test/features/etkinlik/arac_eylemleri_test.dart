import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/arac_eylemleri.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';

import 'sahteler.dart';

const LatLng _a = LatLng(lat: 40.1, lng: 29.1);

Event _etkinlik({
  DateTime? baslangic,
  bool yonetebilir = false,
  bool iptal = false,
}) => Event.fromJson(
  etkinlikJson(
    baslangic: baslangic ?? gecmisBaslangic,
    sure: const Duration(hours: 3),
    yonetebilir: yonetebilir,
    iptal: iptal,
  ),
);

void main() {
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
    });
  });
}
