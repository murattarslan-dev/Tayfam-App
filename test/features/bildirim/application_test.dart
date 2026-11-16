import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
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

  group('gösterilmeyen öneri bildirimi (27-arkadas-onerisi)', () {
    Map<String, Object?> oneri(
      String id, {
      String? cozum,
      bool okundu = false,
    }) => bildirimJson(
      id,
      tur: 'friend_suggestion',
      tayfaId: null,
      hedefTuru: 'user',
      hedef: kisiId,
      cozum: cozum,
      okundu: okundu,
    );

    const gizli1 = 'dddddddd-0000-4000-8000-000000000001';
    const gizli2 = 'dddddddd-0000-4000-8000-000000000002';
    const okunmusGizli = 'dddddddd-0000-4000-8000-000000000003';
    const bekleyen = 'dddddddd-0000-4000-8000-000000000004';

    Map<String, TayfaYaniti> yanitlar({
      required int Function() sayi,
      Object? okunduHatasi,
    }) => {
      'GET $bildirimlerYolu': _yanit(
        bildirimListesiJson([
          oneri(gizli1, cozum: 'expired'),
          oneri(gizli2), // durum yok
          oneri(okunmusGizli, cozum: 'declined', okundu: true),
          oneri(bekleyen, cozum: 'pending'),
          bildirimJson(bildirimId1),
        ]),
      ),
      'GET $okunmamisYolu': (_) => okunmamisJson(sayi()),
      'PUT $okunduYolu': (_) => okunduHatasi,
    };

    Future<void> bosalt() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('okunmamış gizliler sessizce okundu işaretleniyor; görünenler '
        've okunmuşlar dokunulmuyor; rozet yeniden okunuyor', () async {
      var sayi = 4;
      final k = _Kurulum(yanitlar(sayi: () => sayi));
      expect(await k.rozet(), 4);
      sayi = 2;
      await k.liste();
      await bosalt();

      final giden = [
        for (final i in k.tasima.giden('PUT', okunduYolu))
          i.yolParametreleri['notification_id'],
      ];
      expect(giden, unorderedEquals([gizli1, gizli2]));
      // Liste gizlileri okunmuş tutar; görünenler okunmamış kalır.
      expect(k.okunduDurumlari, [true, true, true, false, false]);
      expect(k.rozetDegeri, 2);
    });

    test('işaretleme başarısızsa hata yok, rozet yeniden okunmuyor; '
        'sonraki okumada yeniden deneniyor', () async {
      final k = _Kurulum(
        yanitlar(sayi: () => 4, okunduHatasi: const ApiOffline()),
      );
      await k.rozet();
      final liste = await k.liste();
      await bosalt();

      expect(k.tasima.giden('PUT', okunduYolu), hasLength(2));
      expect(k.tasima.giden('GET', okunmamisYolu), hasLength(1));
      expect(k.tasima.giden('GET', bildirimlerYolu), hasLength(1));

      await liste.yenile();
      await bosalt();
      expect(k.tasima.giden('PUT', okunduYolu), hasLength(4));
    });

    test('gizli bildirim yoksa istek gitmiyor', () async {
      final k = _Kurulum({
        'GET $bildirimlerYolu': _yanit(
          bildirimListesiJson([
            oneri(bekleyen, cozum: 'pending'),
            bildirimJson(bildirimId1),
          ]),
        ),
        'GET $okunmamisYolu': _yanit(okunmamisJson(2)),
      });
      await k.liste();
      await bosalt();
      expect(k.tasima.giden('PUT', okunduYolu), isEmpty);
    });
  });

  group('okunmusHali', () {
    test('öneri durumu (resolution) ve öteki alanlar korunuyor', () {
      final b = Notification.fromJson(
        bildirimJson(
          bildirimId1,
          tur: 'friend_suggestion',
          tayfaId: null,
          hedefTuru: 'user',
          hedef: kisiId,
          cozum: 'pending',
        ),
      );
      final okunmus = okunmusHali(b);
      expect(okunmus.read, isTrue);
      expect(okunmus.resolution, NotificationResolution.pending);
      expect(okunmus.toJson()..remove('read'), b.toJson()..remove('read'));
    });
  });
}
