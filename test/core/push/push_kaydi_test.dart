import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('oturum açık ve izin varsa token PUT edilir', () async {
      await kur().esitle();
      expect(depo.kaydedilen, [sahteToken]);
    });

    test('izin yoksa token istenmez ve gönderilmez', () async {
      platform.izinDurumu = BildirimIzni.reddedildi;
      await kur().esitle();
      expect(depo.kaydedilen, isEmpty);
    });

    test('oturum açık değilse gönderilmez', () async {
      oturumAcik = false;
      await kur().esitle();
      expect(depo.kaydedilen, isEmpty);
    });

    test('FCM token yenilenince yenisi PUT edilir', () async {
      final kayit = kur();
      await kayit.baslat();
      platform.yenileme.add('yeni-token:0002');
      await pumpEventQueue();
      expect(depo.kaydedilen, ['yeni-token:0002']);
      kayit.dispose();
    });

    test('oturum kapalıyken gelen yenileme gönderilmez', () async {
      final kayit = kur();
      await kayit.baslat();
      oturumAcik = false;
      platform.yenileme.add('yeni-token:0002');
      await pumpEventQueue();
      expect(depo.kaydedilen, isEmpty);
      kayit.dispose();
    });

    test('çıkışta sunucudan ve cihazdan silinir', () async {
      await kur().cikisOncesi();
      expect(depo.silme, 1);
      expect(platform.tokenSilme, 1);
    });

    test('sunucuya ulaşılamasa da cihazdaki token silinir', () async {
      depo.hata = Exception('ağ yok');
      await kur().cikisOncesi();
      expect(platform.tokenSilme, 1);
      expect(gunluk, ['push: token sunucudan silinemedi']);
    });

    test('kayıt hatası fırlatılmaz; günlükte token yoktur', () async {
      depo.hata = Exception('503');
      await kur().esitle();
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
      expect(depo.kaydedilen, isEmpty);
      expect(depo.silme, 0);
    });
  });

  group('pushKaydiProvider', () {
    test('oturum açılınca eşitler, kapanınca cihaz token\'ını siler', () async {
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
      expect(platform.tokenSilme, 1);
    });

    test('açılışta oturum yoksa token silinmez ve gönderilmez', () async {
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
      expect(platform.tokenSilme, 0);
    });
  });
}
