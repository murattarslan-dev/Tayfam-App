import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilim_gecisi.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const EtkinlikAnahtari _anahtar = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
);

void main() {
  group('katilimiUygula', () {
    test('cevapsızdan Geliyorum: gelen bir artar', () {
      final e = katilimiUygula(ornekEtkinlik(), RsvpStatus.going);
      expect(e.callerRsvp, RsvpStatus.going);
      expect((e.goingCount, e.maybeCount, e.waitlistCount), (4, 1, 0));
    });

    test('Belki → Gelmiyorum: belki bir azalır', () {
      final e = katilimiUygula(
        ornekEtkinlik(cevap: 'maybe'),
        RsvpStatus.notGoing,
      );
      expect(e.callerRsvp, RsvpStatus.notGoing);
      expect((e.goingCount, e.maybeCount, e.waitlistCount), (3, 0, 0));
    });

    test('dolu etkinlikte Geliyorum bekleme listesine düşer', () {
      final e = katilimiUygula(
        ornekEtkinlik(kontenjan: 3, cevap: 'maybe'),
        RsvpStatus.waitlist,
      );
      expect(e.callerRsvp, RsvpStatus.waitlist);
      expect((e.goingCount, e.maybeCount, e.waitlistCount), (3, 0, 1));
    });

    test('Geliyorum → Belki, bekleyen varsa: sıradaki gelir, gelen aynı', () {
      final e = katilimiUygula(
        ornekEtkinlik(kontenjan: 3, cevap: 'going', bekleyen: 2),
        RsvpStatus.maybe,
      );
      expect((e.goingCount, e.maybeCount, e.waitlistCount), (3, 2, 1));
    });

    test('bekleme listesinden Gelmiyorum: bekleyen bir azalır', () {
      final e = katilimiUygula(
        ornekEtkinlik(kontenjan: 3, cevap: 'waitlist', bekleyen: 1),
        RsvpStatus.notGoing,
      );
      expect((e.goingCount, e.maybeCount, e.waitlistCount), (3, 1, 0));
    });

    test('aynı cevap bir şey değiştirmez', () {
      final once = ornekEtkinlik(cevap: 'going');
      expect(katilimiUygula(once, RsvpStatus.going), same(once));
    });

    test('kontenjan dolu ve katılım açık mı', () {
      expect(kontenjanDolu(ornekEtkinlik()), isFalse);
      expect(kontenjanDolu(ornekEtkinlik(kontenjan: 3)), isTrue);
      expect(kontenjanDolu(ornekEtkinlik(kontenjan: 4)), isFalse);
      expect(katilimAcik(ornekEtkinlik(), sabitSimdi), isTrue);
      expect(katilimAcik(ornekEtkinlik(), DateTime.utc(2027, 1, 1)), isFalse);
      final iptal = Event.fromJson(etkinlikJson(iptal: true));
      expect(katilimAcik(iptal, sabitSimdi), isFalse);
    });
  });

  group('EtkinlikEylemNotifier', () {
    ProviderContainer kapsayici(
      SahteTayfaTasima tasima, {
      SahteTakvimPaylasici? takvim,
    }) {
      final c = ProviderContainer(
        overrides: etkinlikOverridelari(tasima: tasima, takvim: takvim),
      );
      addTearDown(c.dispose);
      // Ekran gibi detayı ve işlemleri dinler.
      c.listen(etkinlikDetayProvider(_anahtar), (_, _) {});
      c.listen(etkinlikEylemProvider(_anahtar), (_, _) {});
      return c;
    }

    test('Geliyorum: PUT gövdesi, kaydedilen cevap ve sayılar', () async {
      var okuma = 0;
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => okuma++ == 0
            ? etkinlikJson()
            : etkinlikJson(cevap: 'going', gelen: 4),
        'PUT $katilimYolu': (_) => {'status': 'going'},
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      final hata = await c
          .read(etkinlikEylemProvider(_anahtar).notifier)
          .katil(RsvpRequestStatus.going);

      expect(hata, isNull);
      final istek = tasima.giden('PUT', katilimYolu).single;
      expect(istek.govde, {'status': 'going'});
      expect(istek.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
      });
      final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
      expect(e.callerRsvp, RsvpStatus.going);
      expect(e.goingCount, 4);
      expect(c.read(etkinlikEylemProvider(_anahtar)), isNull);
    });

    test('dolu etkinlik: sunucu bekleme listesine aldı', () async {
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(kontenjan: 3),
        'PUT $katilimYolu': (_) => {'status': 'waitlist'},
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      await c
          .read(etkinlikEylemProvider(_anahtar).notifier)
          .katil(RsvpRequestStatus.going);

      final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
      expect(e.callerRsvp, RsvpStatus.waitlist);
    });

    test('hata döner, cevap değişmez', () async {
      final tasima = etkinlikTasimasi({
        'PUT $katilimYolu': (_) =>
            const ApiProblem(type: ProblemType.eventCancelled, status: 409),
      });
      final c = kapsayici(tasima);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      final hata = await c
          .read(etkinlikEylemProvider(_anahtar).notifier)
          .katil(RsvpRequestStatus.maybe);

      expect(hata, isA<ApiProblem>());
      expect(c.read(etkinlikDetayProvider(_anahtar)).value!.callerRsvp, isNull);
    });

    test(
      'iptal: gerekçe gövdede, detay güncellenir; boş gerekçe gitmez',
      () async {
        final tasima = etkinlikTasimasi({
          'POST $iptalYolu': (_) => etkinlikJson(iptal: true),
        });
        final c = kapsayici(tasima);
        await c.read(etkinlikDetayProvider(_anahtar).future);
        final n = c.read(etkinlikEylemProvider(_anahtar).notifier);

        expect(await n.iptalEt('   '), isNull);
        expect(tasima.giden('POST', iptalYolu), isEmpty);

        expect(await n.iptalEt(' Hava kötü '), isNull);
        expect(tasima.giden('POST', iptalYolu).single.govde, {
          'reason': 'Hava kötü',
        });
        final e = c.read(etkinlikDetayProvider(_anahtar)).value!;
        expect(iptalEdildi(e), isTrue);
      },
    );

    test('takvime ekle: .ics metni paylaşıcıya gider', () async {
      final takvim = SahteTakvimPaylasici();
      final tasima = etkinlikTasimasi({
        'GET $takvimYolu': (_) => 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
      });
      final c = kapsayici(tasima, takvim: takvim);
      await c.read(etkinlikDetayProvider(_anahtar).future);

      final hata = await c
          .read(etkinlikEylemProvider(_anahtar).notifier)
          .takvimeEkle();

      expect(hata, isNull);
      expect(takvim.paylasilan, ['BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n']);
    });
  });
}
