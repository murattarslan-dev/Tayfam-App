import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/profil/presentation/bildirim_ayarlari_ekrani.dart';

import '../../core/push/sahte_push.dart';
import '../../yardimcilar.dart';

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  PushPlatformu platform, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  overrides: [
    pushPlatformuProvider.overrideWithValue(platform),
    pushTokenDeposuProvider.overrideWithValue(SahtePushTokenDeposu()),
    cihazAyarlariDeposuProvider.overrideWithValue(BellekCihazAyarlariDeposu()),
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
  ],
);

void main() {
  group('Profil → Bildirimler', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('izin varken durum ve sistem ayarı (${tema.name}, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const BildirimAyarlariEkrani(),
          SahtePushPlatformu(),
          themeMode: tema,
        );
        expect(_metin('bildirim_ayar_acik'), findsOneWidget);
        expect(_metin('bildirim_ayar_ac'), findsNothing);
        expect(_metin('bildirim_ayar_sistem'), findsOneWidget);
        expect(_metin('bildirim_ayar_gizlilik'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('izin yokken "Bildirimleri aç" (${tema.name}, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const BildirimAyarlariEkrani(),
          SahtePushPlatformu(izinDurumu: BildirimIzni.reddedildi),
          themeMode: tema,
        );
        expect(_metin('bildirim_ayar_kapali'), findsOneWidget);
        expect(_metin('bildirim_ayar_ac'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Bildirimleri aç" pencereyi, olmazsa sistem ayarını açar', (
      tester,
    ) async {
      final platform = SahtePushPlatformu(
        izinDurumu: BildirimIzni.reddedildi,
        istekSonucu: BildirimIzni.reddedildi,
      );
      await _ac(tester, const BildirimAyarlariEkrani(), platform);
      await tester.tap(_metin('bildirim_ayar_ac'));
      await tester.pumpAndSettle();
      expect(platform.izinIstegi, 1);
      expect(platform.ayarAcma, 1);
    });

    testWidgets('izin verilince durum "açık" olur', (tester) async {
      final platform = SahtePushPlatformu(
        izinDurumu: BildirimIzni.sorulmadi,
      );
      await _ac(tester, const BildirimAyarlariEkrani(), platform);
      await tester.tap(_metin('bildirim_ayar_ac'));
      await tester.pumpAndSettle();
      expect(_metin('bildirim_ayar_acik'), findsOneWidget);
      expect(platform.ayarAcma, 0);
    });

    testWidgets('sistem ayarları satırı ayarları açar', (tester) async {
      final platform = SahtePushPlatformu();
      await _ac(tester, const BildirimAyarlariEkrani(), platform);
      await tester.tap(_metin('bildirim_ayar_sistem'));
      await tester.pumpAndSettle();
      expect(platform.ayarAcma, 1);
    });

    testWidgets('push olmayan derlemede yalnızca bilgi', (tester) async {
      await _ac(
        tester,
        const BildirimAyarlariEkrani(),
        const KapaliPushPlatformu(),
      );
      expect(_metin('bildirim_ayar_yok'), findsOneWidget);
      expect(_metin('bildirim_ayar_ac'), findsNothing);
    });
  });

  group('Bildirim izni açıklama kartı', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('ihtiyaç doğunca görünür (${tema.name}, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        final platform = SahtePushPlatformu(
          izinDurumu: BildirimIzni.sorulmadi,
        );
        await _ac(
          tester,
          const BildirimIzniAlani(child: Scaffold(body: SizedBox.expand())),
          platform,
          themeMode: tema,
        );
        expect(_metin('bildirim_izni_baslik'), findsNothing);

        final container = tester.container();
        await container.read(bildirimIzniProvider.notifier).ihtiyacDogdu();
        await tester.pumpAndSettle();
        expect(_metin('bildirim_izni_baslik'), findsOneWidget);
        expect(_metin('bildirim_izni_aciklama'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"İzin ver" sistem penceresini açar, kart kapanır', (
      tester,
    ) async {
      final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
      await _ac(
        tester,
        const BildirimIzniAlani(child: Scaffold(body: SizedBox.expand())),
        platform,
      );
      await tester
          .container()
          .read(bildirimIzniProvider.notifier)
          .ihtiyacDogdu();
      await tester.pumpAndSettle();
      await tester.tap(_metin('bildirim_izni_ver'));
      await tester.pumpAndSettle();
      expect(platform.izinIstegi, 1);
      expect(_metin('bildirim_izni_baslik'), findsNothing);
    });

    testWidgets('"Şimdi değil" kartı kapatır, pencere açılmaz', (
      tester,
    ) async {
      final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
      await _ac(
        tester,
        const BildirimIzniAlani(child: Scaffold(body: SizedBox.expand())),
        platform,
      );
      await tester
          .container()
          .read(bildirimIzniProvider.notifier)
          .ihtiyacDogdu();
      await tester.pumpAndSettle();
      await tester.tap(_metin('bildirim_izni_simdi_degil'));
      await tester.pumpAndSettle();
      expect(platform.izinIstegi, 0);
      expect(_metin('bildirim_izni_baslik'), findsNothing);
    });
  });
}
