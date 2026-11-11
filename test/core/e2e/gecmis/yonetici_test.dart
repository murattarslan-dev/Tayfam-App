import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yoneticisi.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';

import '../../../yardimcilar.dart';
import '../signal/sahte_signal_motoru.dart';
import 'sahteler.dart';

/// Elle beslenen mesaj ve sinyal akışları.
final class _Akislar implements CozulmusMesajAkisi, E2eSinyalleri {
  final StreamController<ArsivlenecekMesaj> m = StreamController.broadcast();
  final StreamController<E2eSinyali> s = StreamController.broadcast();

  @override
  Stream<ArsivlenecekMesaj> get mesajlar => m.stream;

  @override
  Stream<E2eSinyali> get sinyaller => s.stream;
}

ProviderContainer _kap(
  SahteKaynak kaynak,
  SahteTasima tasima, {
  BellekE2eDepo? depo,
  _Akislar? akislar,
}) {
  final a = akislar ?? _Akislar();
  final c = ProviderContainer(
    overrides: [
      oturumDurumuProvider.overrideWith(
        () => SabitOturumDurumu(OturumDurumu.acik),
      ),
      e2eCihazDurumuKaynagiProvider.overrideWithValue(kaynak),
      e2eDepoErisimiProvider.overrideWithValue(depo ?? BellekE2eDepo()),
      kendiCihazOturumuProvider.overrideWithValue(SahteKendiOturum(cihazA)),
      cozulmusMesajAkisiProvider.overrideWithValue(a),
      e2eSinyalleriProvider.overrideWithValue(a),
      gecmisMotoruProvider.overrideWithValue(SahteSignalMotoru()),
      gecmisApiProvider.overrideWithValue(GecmisApi(tasima)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('uyarı mantığı', () {
    test('tek cihaz: eşleştirilmiş ve başka eşleştirilmiş cihaz yok', () {
      final kaynak = SahteKaynak(bilgi());
      final c = _kap(kaynak, SahteTasima());
      expect(c.read(tekCihazUyarisiProvider), isTrue);
      expect(c.read(qrOnerisiProvider), isFalse);

      kaynak.yayinla(bilgi(baska: true));
      expect(c.read(tekCihazUyarisiProvider), isFalse);

      kaynak.yayinla(bilgi(eslesmis: false, baska: true));
      expect(c.read(tekCihazUyarisiProvider), isFalse);
      expect(c.read(qrOnerisiProvider), isTrue);

      kaynak.yayinla(null);
      expect(c.read(tekCihazUyarisiProvider), isFalse);
      expect(c.read(qrOnerisiProvider), isFalse);
    });

    test('E2E kapalıyken (web, iOS) E2 bağlantısı null verir, uyarı yok', () {
      final c = ProviderContainer(
        overrides: [
          oturumDurumuProvider.overrideWith(
            () => SabitOturumDurumu(OturumDurumu.acik),
          ),
          e2eEtkinProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(tekCihazUyarisiProvider), isFalse);
      expect(c.read(gecmisCihazBilgisiProvider), isNull);
    });

    test('ilk E2E bilgisi bir kez gösterilir', () async {
      final depo = BellekE2eDepo();
      final c = _kap(SahteKaynak(bilgi()), SahteTasima(), depo: depo);
      expect(await c.read(tekCihazBilgisiProvider.future), isTrue);
      await c.read(tekCihazBilgisiProvider.notifier).goruldu();
      expect(c.read(tekCihazBilgisiProvider).value, isFalse);
      expect(depo.kayitlar, contains(tekCihazBilgisiAnahtari));

      final c2 = _kap(SahteKaynak(bilgi()), SahteTasima(), depo: depo);
      expect(await c2.read(tekCihazBilgisiProvider.future), isFalse);
    });
  });

  group('GecmisYoneticisi', () {
    test('eşleştirilmemiş ilk cihaz anahtarı alır; önceki sürüm varsa '
        '"eski arşiv okunamaz" bildirilir', () async {
      final kaynak = SahteKaynak(bilgi(eslesmis: false, surum: 2));
      final tasima = SahteTasima({
        anahtarAl: (_) => {'history_key_version': 3},
      });
      final depo = BellekE2eDepo();
      final c = _kap(kaynak, tasima, depo: depo);
      c.listen(gecmisYoneticisiProvider, (_, _) {});
      await pumpEventQueue();
      expect(tasima.giden(anahtarAl), hasLength(1));
      expect(depo.kayitlar.keys, contains('e2e.gecmis.3'));
      expect(c.read(gecmisYoneticisiProvider).eskiArsivOkunamaz, isTrue);
      c.read(gecmisYoneticisiProvider.notifier).eskiArsivBilgisiGoruldu();
      expect(c.read(gecmisYoneticisiProvider).eskiArsivOkunamaz, isFalse);
    });

    test('eşleştirilmiş cihaz: açılışta paylaşım çeker, yenileme gerekiyorsa '
        'yeniler, çözülen mesajları arşive yazar', () async {
      final kaynak = SahteKaynak(bilgi(surum: 1, yenile: true));
      final depo = BellekE2eDepo();
      final akislar = _Akislar();
      final tasima = SahteTasima({
        paylasimlarUc: (_) => {'shares': <Object?>[]},
        yenileUc: (_) => null,
        arsivYaz: (_) => {'accepted_message_ids': <Object?>[]},
      });
      depo.kayitlar['e2e.gecmis.1'] = anahtar(1);
      final c = _kap(kaynak, tasima, depo: depo, akislar: akislar);
      kaynak.sonraki = () => bilgi(surum: 2);
      c.listen(gecmisYoneticisiProvider, (_, _) {});
      await pumpEventQueue();
      expect(tasima.giden(paylasimlarUc), isNotEmpty);
      expect(tasima.giden(yenileUc), hasLength(1));
      expect(depo.kayitlar.keys, contains('e2e.gecmis.2'));

      akislar.m.add(
        ArsivlenecekMesaj(
          mesajId: mesajId(1),
          konusmaId: konusmaId,
          gonderenId: kullaniciId,
          olusturma: DateTime.utc(2026),
          govde: 'merhaba',
        ),
      );
      await pumpEventQueue();
      expect(tasima.giden(arsivYaz).single.json['history_key_version'], 2);

      final once = tasima.giden(paylasimlarUc).length;
      akislar.s.add(const GecmisAnahtariPaylasildi());
      await pumpEventQueue();
      expect(tasima.giden(paylasimlarUc), hasLength(once + 1));
    });

    test('arka plan hatası yutulur', () async {
      final kaynak = SahteKaynak(bilgi(eslesmis: false, surum: 0));
      final tasima = SahteTasima({anahtarAl: (_) => const ApiOffline()});
      final c = _kap(kaynak, tasima);
      c.listen(gecmisYoneticisiProvider, (_, _) {});
      await pumpEventQueue();
      expect(c.read(gecmisYoneticisiProvider).eskiArsivOkunamaz, isFalse);
    });

    test('konuşma arşivi sağlayıcısı: E2E yoksa boş, eşleştirilmiş cihazda '
        'çözülmüş mesajlar', () async {
      final kaynak = SahteKaynak(null);
      final tasima = SahteTasima({
        arsivOku: (_) => {'entries': <Object?>[]},
      });
      final c = _kap(kaynak, tasima);
      final bos = await c.read(konusmaArsiviProvider(konusmaId).future);
      expect(bos.mesajlar, isEmpty);
      expect(tasima.istekler, isEmpty);
    });
  });

  test('e2e-devices-changed problemi cihaz listeleriyle okunur', () async {
    final tasima = HttpTasima(
      istemci: MockClient(
        (_) async => http.Response(
          '{"type":"https://tayfam.app/problems/e2e-devices-changed",'
          '"title":"x","status":409,'
          '"missing_device_ids":["$cihazB","gecersiz"],'
          '"stale_device_ids":["$cihazC"]}',
          409,
          headers: {'content-type': 'application/problem+json'},
        ),
      ),
      tabanAdres: Uri.parse('https://api.ornek.test'),
      istemciAdi: 'android',
    );
    try {
      await tasima.gonder(
        method: 'POST',
        pathTemplate: '/v1/me/e2e/history-key/rotate',
        body: const <String, Object?>{},
        expect: ResponseKind.none,
        erisimTokeni: 'erisim',
      );
      fail('hata bekleniyordu');
    } on ApiProblem catch (p) {
      expect(p.type, ProblemType.e2eDevicesChanged);
      expect(p.cihazFarki!.eksik, [cihazB]);
      expect(p.cihazFarki!.eski, [cihazC]);
    }
  });
}
