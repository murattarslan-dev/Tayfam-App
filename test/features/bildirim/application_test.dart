import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/bildirim/application/bildirim_listesi_notifier.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

final class _Kurulum {
  _Kurulum(
    Map<String, TayfaYaniti> yanitlar, {
    OturumDurumu oturum = OturumDurumu.acik,
  }) : tasima = SahteTayfaTasima(yanitlar) {
    kap = ProviderContainer.test(
      overrides: [
        ...bildirimOverridelari(tasima: tasima),
        oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(oturum)),
      ],
    );
  }

  final SahteTayfaTasima tasima;
  late final ProviderContainer kap;

  Future<int> rozet() async {
    kap.listen(okunmamisBildirimProvider, (_, _) {});
    return kap.read(okunmamisBildirimProvider.future);
  }

  int get rozetDegeri => kap.read(okunmamisBildirimProvider).value ?? -1;

  Future<BildirimListesiNotifier> liste() async {
    kap.listen(bildirimListesiProvider, (_, _) {});
    await kap.read(bildirimListesiProvider.future);
    return kap.read(bildirimListesiProvider.notifier);
  }

  List<bool> get okunduDurumlari => [
    for (final b in kap.read(bildirimListesiProvider).requireValue.ogeler)
      b.read,
  ];
}

TayfaYaniti _yanit(Object? deger) =>
    (_) => deger;

void main() {
  group('okunmamış sayısı', () {
    test('oturum açıkken sunucudan okunuyor', () async {
      final k = _Kurulum({'GET $okunmamisYolu': _yanit(okunmamisJson(7))});
      expect(await k.rozet(), 7);
    });

    test('oturum açık değilse istek yok ve 0', () async {
      final k = _Kurulum({
        'GET $okunmamisYolu': _yanit(okunmamisJson(7)),
      }, oturum: OturumDurumu.girisYok);
      expect(await k.rozet(), 0);
      await k.kap.read(okunmamisBildirimProvider.notifier).yenile();
      expect(k.tasima.giden('GET', okunmamisYolu), isEmpty);
    });

    test('yenile yeni sayıyı alıyor; hata eldeki sayıyı koruyor', () async {
      var sayi = 2;
      Object? hata;
      final k = _Kurulum({
        'GET $okunmamisYolu': (_) => hata ?? okunmamisJson(sayi),
      });
      expect(await k.rozet(), 2);

      sayi = 5;
      await k.kap.read(okunmamisBildirimProvider.notifier).yenile();
      expect(k.rozetDegeri, 5);

      hata = const ApiOffline();
      await k.kap.read(okunmamisBildirimProvider.notifier).yenile();
      expect(k.rozetDegeri, 5);
    });
  });

  group('liste', () {
    Map<String, TayfaYaniti> yanitlar({Object? okunduHatasi}) => {
      'GET $bildirimlerYolu': _yanit(
        bildirimListesiJson([
          bildirimJson(bildirimId1),
          bildirimJson(bildirimId2, okundu: true),
          bildirimJson(bildirimId3, tur: 'announcement'),
        ]),
      ),
      'GET $okunmamisYolu': _yanit(okunmamisJson(2)),
      'PUT $okunduYolu': (_) => okunduHatasi,
    };

    test('okundu işaretleme isteği gidiyor; liste ve rozet düşüyor', () async {
      final k = _Kurulum(yanitlar());
      await k.rozet();
      final liste = await k.liste();

      await liste.okunduIsaretle(bildirimId1);

      final giden = k.tasima.giden('PUT', okunduYolu);
      expect(giden, hasLength(1));
      expect(giden.single.yolParametreleri['notification_id'], bildirimId1);
      expect(k.okunduDurumlari, [true, true, false]);
      expect(k.rozetDegeri, 1);
    });

    test('zaten okunmuş bildirim için istek gitmiyor', () async {
      final k = _Kurulum(yanitlar());
      final liste = await k.liste();
      await liste.okunduIsaretle(bildirimId2);
      expect(k.tasima.giden('PUT', okunduYolu), isEmpty);
    });

    test('okundu işaretlenemezse liste ve rozet yeniden okunuyor', () async {
      final k = _Kurulum(yanitlar(okunduHatasi: const ApiOffline()));
      await k.rozet();
      final liste = await k.liste();

      await liste.okunduIsaretle(bildirimId1);

      expect(k.tasima.giden('GET', bildirimlerYolu), hasLength(2));
      expect(k.tasima.giden('GET', okunmamisYolu), hasLength(2));
      expect(k.okunduDurumlari, [false, true, false]);
      expect(k.rozetDegeri, 2);
    });

    test('hepsini okundu say: istek, liste ve rozet sıfır', () async {
      final k = _Kurulum(yanitlar());
      await k.rozet();
      final liste = await k.liste();

      expect(await liste.hepsiniOkunduSay(), isNull);

      expect(k.tasima.giden('POST', hepsiOkunduYolu), hasLength(1));
      expect(k.okunduDurumlari, [true, true, true]);
      expect(k.rozetDegeri, 0);
    });

    test('hepsini okundu say başarısızsa hata dönüyor, liste aynı', () async {
      final k = _Kurulum({
        ...yanitlar(),
        'POST $hepsiOkunduYolu': _yanit(const ApiOffline()),
      });
      await k.rozet();
      final liste = await k.liste();

      expect(await liste.hepsiniOkunduSay(), isA<ApiOffline>());
      expect(k.okunduDurumlari, [false, true, false]);
      expect(k.rozetDegeri, 2);
    });
  });
}
