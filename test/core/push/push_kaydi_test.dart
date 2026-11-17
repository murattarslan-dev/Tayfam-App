import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import 'sahte_push.dart';

void main() {
  final metinler = lookupAppLocalizations(const Locale('tr', 'TR'));

  group('PushKaydi', () {
    late SahtePushPlatformu platform;
    late SahtePushTokenDeposu depo;
    late List<String> gunluk;
    var oturumAcik = true;

    PushKaydi kur() => PushKaydi(
      platform: platform,
      depo: depo,
      oturumAcik: () => oturumAcik,
      metinler: metinler,
      gunluk: gunluk.add,
    );

    setUp(() {
      platform = SahtePushPlatformu();
      depo = SahtePushTokenDeposu();
      gunluk = [];
      oturumAcik = true;
    });

    test('başlatınca üç kanalı çeviriden kurar', () async {
      final kayit = kur();
      await kayit.baslat();
      expect(platform.kurulanKanallar.single.map((k) => k.id), [
        'tayfam_messages',
        'tayfam_alerts',
        'tayfam_general',
      ]);
      final mesajlar = platform.kurulanKanallar.single.first;
      expect(mesajlar.ad, arbMetni('push_kanal_mesajlar'));
      expect(mesajlar.yuksekOncelik, isTrue);
      expect(platform.kurulanKanallar.single.last.yuksekOncelik, isFalse);
      kayit.dispose();
    });

    Future<PushKaydi> baslamis() async {
      final kayit = kur();
      addTearDown(kayit.dispose);
      await kayit.baslat();
      return kayit;
    }

    test(
      'oturum açık ve izin varsa kaydolunur, FID fid türüyle PUT edilir',
      () async {
        final kayit = await baslamis();
        await kayit.esitle();
        await pumpEventQueue();
        expect(platform.kayitIstegi, 1);
        expect(depo.kaydedilen, [sahteToken]);
      },
    );

    test('izin yoksa kaydolunmaz ve gönderilmez', () async {
      platform.izinDurumu = BildirimIzni.reddedildi;
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      expect(platform.kayitIstegi, 0);
      expect(depo.kaydedilen, isEmpty);
    });

    test('oturum açık değilse kaydolunmaz ve gönderilmez', () async {
      oturumAcik = false;
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      expect(platform.kayitIstegi, 0);
      expect(depo.kaydedilen, isEmpty);
    });

    test('kimlik gelmezse hiçbir şey gönderilmez', () async {
      platform.mevcutKimlik = null;
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      expect(platform.kayitIstegi, 1);
      expect(depo.kaydedilen, isEmpty);
    });

    test('FID değişince (onRegistered) yenisi PUT edilir', () async {
      final kayit = await baslamis();
      await kayit.esitle();
      platform.kayitlar.add('yeniFid0002');
      await pumpEventQueue();
      expect(depo.kaydedilen, [sahteToken, 'yeniFid0002']);
    });

    test('aynı FID yeniden yayınlanınca tekrar gönderilmez', () async {
      final kayit = await baslamis();
      await kayit.esitle();
      await kayit.esitle();
      platform.kayitlar.add(sahteToken);
      await pumpEventQueue();
      expect(platform.kayitIstegi, 2);
      expect(depo.kaydedilen, [sahteToken]);
    });

    test('kayıt başarısızsa bir sonraki yayında yeniden denenir', () async {
      depo.hata = Exception('503');
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      depo.hata = null;
      await kayit.esitle();
      await pumpEventQueue();
      expect(depo.kaydedilen, [sahteToken]);
    });

    test('oturum kapalıyken gelen kimlik gönderilmez', () async {
      await baslamis();
      oturumAcik = false;
      platform.kayitlar.add('yeniFid0002');
      await pumpEventQueue();
      expect(depo.kaydedilen, isEmpty);
    });

    test('izin yokken gelen kimlik gönderilmez', () async {
      await baslamis();
      platform.izinDurumu = BildirimIzni.reddedildi;
      platform.kayitlar.add('yeniFid0002');
      await pumpEventQueue();
      expect(depo.kaydedilen, isEmpty);
    });

    test('çıkışta sunucudan silinir ve cihaz kaydı kaldırılır', () async {
      await kur().cikisOncesi();
      expect(depo.silme, 1);
      expect(platform.kayitSilme, 1);
    });

    test('sunucuya ulaşılamasa da cihaz kaydı kaldırılır', () async {
      depo.hata = Exception('ağ yok');
      await kur().cikisOncesi();
      expect(platform.kayitSilme, 1);
      expect(gunluk, ['push: token sunucudan silinemedi']);
    });

    test('çıkıştan sonra yeni oturumda aynı FID yeniden gönderilir', () async {
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      await kayit.cikisOncesi();
      await kayit.esitle();
      await pumpEventQueue();
      expect(depo.kaydedilen, [sahteToken, sahteToken]);
    });

    test('oturum başka yoldan kapanınca cihaz kaydı kaldırılır, sonraki '
        'oturumda yeniden gönderilir', () async {
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      await kayit.oturumKapandi();
      expect(platform.kayitSilme, 1);
      expect(depo.silme, 0);
      await kayit.esitle();
      await pumpEventQueue();
      expect(depo.kaydedilen, [sahteToken, sahteToken]);
    });

    test('kayıt hatası fırlatılmaz; günlükte kimlik yoktur', () async {
      depo.hata = Exception('503');
      final kayit = await baslamis();
      await kayit.esitle();
      await pumpEventQueue();
      expect(gunluk, ['push: token kaydedilemedi']);
      expect(gunluk.join(), isNot(contains(sahteToken)));
    });

    test('push kapalı platformda hiçbir şey yapılmaz', () async {
      final kayit = PushKaydi(
        platform: const KapaliPushPlatformu(),
        depo: depo,
        oturumAcik: () => true,
        metinler: metinler,
      );
      await kayit.baslat();
      await kayit.esitle();
      await kayit.cikisOncesi();
      await kayit.oturumKapandi();
      expect(depo.kaydedilen, isEmpty);
      expect(depo.silme, 0);
    });
  });

  group('ApiPushTokenDeposu', () {
    test('FID token_type: fid ile PUT edilir (Tayfam-Api ADR-0036)', () async {
      final tasima = _KayitTasima();
      final depo = ApiPushTokenDeposu(
        tasima,
        platform: PushTokenRegistrationPlatform.android,
      );
      await depo.kaydet(sahteToken);
      await depo.sil();
      expect(tasima.istekler.map((i) => i.$1), [
        'PUT /v1/me/push-token',
        'DELETE /v1/me/push-token',
      ]);
      expect(tasima.istekler.first.$2, {
        'token': sahteToken,
        'platform': 'android',
        'token_type': 'fid',
      });
      expect(tasima.istekler.last.$2, isNull);
    });
  });

  group('pushKaydiProvider', () {
    test('oturum açılınca eşitler, kapanınca cihaz kaydını kaldırır', () async {
      final platform = SahtePushPlatformu();
      final depo = SahtePushTokenDeposu();
      final container = ProviderContainer(
        overrides: [
          pushPlatformuProvider.overrideWithValue(platform),
          pushTokenDeposuProvider.overrideWithValue(depo),
          oturumDurumuProvider.overrideWith(
            () => SabitOturumDurumu(OturumDurumu.acik),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(pushKaydiProvider);
      await pumpEventQueue();
      expect(platform.baslatma, 1);
      expect(depo.kaydedilen, [sahteToken]);

      container
          .read(oturumDurumuProvider.notifier)
          .ayarla(OturumDurumu.girisYok);
      await pumpEventQueue();
      expect(platform.kayitSilme, 1);
    });

    test('açılışta oturum yoksa kayıt kaldırılmaz ve gönderilmez', () async {
      final platform = SahtePushPlatformu();
      final depo = SahtePushTokenDeposu();
      final container = ProviderContainer(
        overrides: [
          pushPlatformuProvider.overrideWithValue(platform),
          pushTokenDeposuProvider.overrideWithValue(depo),
          oturumDurumuProvider.overrideWith(
            () => SabitOturumDurumu(OturumDurumu.girisYok),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(pushKaydiProvider);
      await pumpEventQueue();
      expect(depo.kaydedilen, isEmpty);
      expect(platform.kayitIstegi, 0);
      expect(platform.kayitSilme, 0);
    });
  });
}

/// İstekleri kaydeden sahte taşıma; gerçek ağ yok.
final class _KayitTasima implements ApiTransport {
  final List<(String, Object?)> istekler = [];

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) async {
    istekler.add(('$method $pathTemplate', body));
    return null;
  }
}
