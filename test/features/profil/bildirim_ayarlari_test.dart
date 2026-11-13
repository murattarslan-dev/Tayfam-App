import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/bildirim_izni.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/profil/data/bildirim_tercihleri_deposu.dart';
import 'package:tayfam/features/profil/presentation/bildirim_ayarlari_ekrani.dart';

import '../../core/push/sahte_push.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

Finder _metin(String anahtar) => find.text(arbMetni(anahtar));

const String _tercihlerYolu = '/v1/notification-preferences';
const String _tayfaTercihiYolu =
    '/v1/notification-preferences/tayfas/{tayfa_id}';
const String _konusmaId = '7a1b2c3d-0000-4000-8000-000000000001';
const String _bilinmeyenTayfaId = '7a1b2c3d-0000-4000-8000-0000000000ff';

/// Testlerin "şimdi"si: 13 Kasım 2026, 15:00 (yerel saat).
final DateTime _simdi = DateTime(2026, 11, 13, 15);

TayfaYaniti _yanit(Object? deger) =>
    (_) => deger;

/// `NotificationPreference` JSON'u.
Map<String, Object?> _tercih(
  String kapsamId, {
  String kapsam = 'tayfa',
  String seviye = 'none',
  DateTime? bitis,
}) => {
  'scope_type': kapsam,
  'scope_id': kapsamId,
  'level': seviye,
  'mute_until': ?bitis?.toUtc().toIso8601String(),
  'updated_at': '2026-11-10T10:00:00Z',
};

/// Tercih uçları: [tercihler] listelenir, tayfa tercihi silinebilir.
SahteTayfaTasima _tercihler([
  List<Map<String, Object?>> tercihler = const [],
]) => SahteTayfaTasima({
  'GET $_tercihlerYolu': _yanit({'preferences': tercihler}),
  'DELETE $_tayfaTercihiYolu': _yanit(null),
});

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  PushPlatformu platform, {
  ThemeMode themeMode = ThemeMode.light,
  SahteTayfaTasima? tercihler,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: tayfaOverridelari(
    tasima: SahteTayfaTasima({
      'GET /v1/tayfas': _yanit(
        listeJson([
          etkinJson(ornekTayfaId, ad: 'Doğa Tayfası'),
          etkinJson(ikinciTayfaId, ad: 'Halısaha'),
        ]),
      ),
    }),
  ),
  overrides: [
    bildirimTercihleriDeposuProvider.overrideWithValue(
      BildirimTercihleriDeposu(tercihler ?? _tercihler()),
    ),
    simdiProvider.overrideWithValue(() => _simdi),
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
      final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
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

  group('Bildirim ayarları · sessize alınanlar', () {
    testWidgets('sessizdeki tayfalar ad ve bitişle; süresi dolan yok', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(
        tester,
        const BildirimAyarlariEkrani(),
        SahtePushPlatformu(),
        tercihler: _tercihler([
          _tercih(ornekTayfaId),
          _tercih(
            ikinciTayfaId,
            seviye: 'mentions',
            bitis: DateTime(2026, 11, 20, 18),
          ),
          // Süresi dolmuş: listelenmez.
          _tercih(
            _bilinmeyenTayfaId,
            bitis: DateTime(2026, 11, 12, 18),
          ),
          _tercih(_konusmaId, kapsam: 'dm_conversation'),
        ]),
      );

      expect(_metin('bildirim_ayar_baslik'), findsOneWidget);
      expect(_metin('bildirim_ayar_sessiz_tayfalar'), findsOneWidget);
      expect(find.text('Doğa Tayfası'), findsOneWidget);
      expect(find.text('Halısaha'), findsOneWidget);
      expect(
        find.textContaining(arbMetni('birebir_sessiz_sure_suresiz')),
        findsOneWidget,
      );
      expect(find.textContaining('20 Kasım'), findsOneWidget);
      expect(find.text(arbMetni('birebir_sessiz_ac')), findsNWidgets(2));
      // Birebir konuşmalar listelenmez; yalnızca sayı.
      expect(find.textContaining('1 konuşma sessizde'), findsOneWidget);
      expect(_metin('bildirim_ayar_gizlilik'), findsOneWidget);
    });

    testWidgets('"Sesi aç" tercihi siler ve satır kalkar', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = _tercihler([_tercih(ornekTayfaId)]);
      await _ac(
        tester,
        const BildirimAyarlariEkrani(),
        SahtePushPlatformu(),
        tercihler: tasima,
      );

      await tester.tap(find.text(arbMetni('birebir_sessiz_ac')));
      await tester.pumpAndSettle();

      final silme = tasima.giden('DELETE', _tayfaTercihiYolu).single;
      expect(silme.yolParametreleri['tayfa_id'], ornekTayfaId);
      expect(find.text(arbMetni('birebir_sessiz_ac')), findsNothing);
      expect(_metin('bildirim_ayar_sessiz_tayfa_yok'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('hiçbir şey sessizde değilse boş metinler', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await _ac(tester, const BildirimAyarlariEkrani(), SahtePushPlatformu());
      expect(_metin('bildirim_ayar_sessiz_tayfa_yok'), findsOneWidget);
      expect(
        find.text('Sessize aldığın birebir konuşma yok.'),
        findsOneWidget,
      );
    });

    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('sessiz listesi ${tema.name} temada 2× yazıda taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const BildirimAyarlariEkrani(),
          SahtePushPlatformu(izinDurumu: BildirimIzni.reddedildi),
          themeMode: tema,
          tercihler: _tercihler([
            _tercih(ornekTayfaId),
            _tercih(ikinciTayfaId, bitis: DateTime(2026, 11, 20, 18)),
            _tercih(_konusmaId, kapsam: 'dm_conversation'),
          ]),
        );
        expect(tester.takeException(), isNull);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Bildirim izni açıklama kartı', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('ihtiyaç doğunca görünür (${tema.name}, 2×)', (tester) async {
        ekranBoyutu(tester);
        ikiKatYazi(tester);
        final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
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

    testWidgets('"Şimdi değil" kartı kapatır, pencere açılmaz', (tester) async {
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
