import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';

import '../../yardimcilar.dart';
import 'sahte_push.dart';

void main() {
  late SahtePushPlatformu platform;
  late SahtePushTokenDeposu depo;
  late BellekCihazAyarlariDeposu ayarlar;

  ProviderContainer kur({Set<CihazBayragi> bayraklar = const {}}) {
    ayarlar = BellekCihazAyarlariDeposu(bayraklar);
    final container = ProviderContainer(
      overrides: [
        pushPlatformuProvider.overrideWithValue(platform),
        pushTokenDeposuProvider.overrideWithValue(depo),
        cihazAyarlariDeposuProvider.overrideWithValue(ayarlar),
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
    depo = SahtePushTokenDeposu();
  });

  test('ilk ihtiyaçta önce açıklama kartı gösterilir', () async {
    final c = kur();
    await c.read(bildirimIzniProvider.notifier).ihtiyacDogdu();
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isTrue);
    expect(platform.izinIstegi, 0);
  });

  test('"İzin ver": sistem penceresi, bayrak ve token kaydı', () async {
    final c = kur();
    final izin = c.read(bildirimIzniProvider.notifier);
    await izin.ihtiyacDogdu();
    await izin.aciklamayiKabulEt();
    await pumpEventQueue();
    expect(platform.izinIstegi, 1);
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isFalse);
    expect(c.read(bildirimIzniProvider).izin, BildirimIzni.verildi);
    expect(ayarlar.konmuslar, contains(CihazBayragi.bildirimIzniSoruldu));
    expect(depo.kaydedilen.toSet(), {sahteToken});
  });

  test('"Şimdi değil": pencere açılmaz, bir daha sorulmaz', () async {
    final c = kur();
    final izin = c.read(bildirimIzniProvider.notifier);
    await izin.ihtiyacDogdu();
    await izin.aciklamayiReddet();
    expect(platform.izinIstegi, 0);
    expect(ayarlar.konmuslar, contains(CihazBayragi.bildirimIzniSoruldu));

    await izin.ihtiyacDogdu();
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isFalse);
  });

  test('daha önce sorulduysa kart gösterilmez', () async {
    final c = kur(bayraklar: {CihazBayragi.bildirimIzniSoruldu});
    await c.read(bildirimIzniProvider.notifier).ihtiyacDogdu();
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isFalse);
  });

  test('izin zaten verildiyse kart gösterilmez', () async {
    platform.izinDurumu = BildirimIzni.verildi;
    final c = kur();
    await c.read(bildirimIzniProvider.notifier).ihtiyacDogdu();
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isFalse);
  });

  test('reddedilince sistem penceresinden sonra ayar açılmaz', () async {
    platform.istekSonucu = BildirimIzni.reddedildi;
    final c = kur();
    final izin = c.read(bildirimIzniProvider.notifier);
    await izin.ihtiyacDogdu();
    await izin.aciklamayiKabulEt();
    expect(platform.ayarAcma, 0);
    expect(depo.kaydedilen, isEmpty);
  });

  test('Profil\'den aç: pencere sonuç vermezse sistem ayarı açılır', () async {
    platform
      ..izinDurumu = BildirimIzni.reddedildi
      ..istekSonucu = BildirimIzni.reddedildi;
    final c = kur(bayraklar: {CihazBayragi.bildirimIzniSoruldu});
    await c.read(bildirimIzniProvider.notifier).ac();
    expect(platform.izinIstegi, 1);
    expect(platform.ayarAcma, 1);
  });

  test('ön plana dönüşte izin yeni verildiyse token kaydedilir', () async {
    platform.izinDurumu = BildirimIzni.reddedildi;
    final c = kur();
    final izin = c.read(bildirimIzniProvider.notifier);
    await izin.yenile();
    expect(depo.kaydedilen, isEmpty);
    platform.izinDurumu = BildirimIzni.verildi;
    await izin.yenile();
    await pumpEventQueue();
    expect(depo.kaydedilen.toSet(), {sahteToken});
  });

  test('push kapalı platformda kart hiç gösterilmez', () async {
    final c = ProviderContainer(
      overrides: [
        cihazAyarlariDeposuProvider.overrideWithValue(
          BellekCihazAyarlariDeposu(),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(bildirimIzniProvider.notifier).ihtiyacDogdu();
    expect(c.read(bildirimIzniProvider).aciklamaGoster, isFalse);
  });
}
