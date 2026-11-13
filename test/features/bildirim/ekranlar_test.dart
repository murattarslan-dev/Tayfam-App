import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/features/bildirim/presentation/bildirimler_ekrani.dart';
import 'package:tayfam/features/bildirim/presentation/sekme_kartlari.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';

import '../../core/push/sahte_push.dart';
import '../../yardimcilar.dart';
import '../arkadas/sahteler.dart' as arkadas;
import '../etkinlik/sahteler.dart' as etkinlik;
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Finder _okunmadi() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == arbMetni('bildirim_okunmadi'),
);

TayfaYaniti _yanit(Object? deger) =>
    (_) => deger;

/// Testlerin "şimdi"si: 13 Kasım 2026 Cuma, 15:00 (yerel saat).
final DateTime _simdi = DateTime(2026, 11, 13, 15);

/// [an] (yerel saat) bildirim JSON'undaki biçimde.
String _zaman(DateTime an) => an.toUtc().toIso8601String();

/// Tayfa listesinde [bildirimTayfaId] "Klasikçiler" adıyla vardır.
List<Override> _tayfa() => tayfaOverridelari(
  tasima: SahteTayfaTasima({
    'GET /v1/tayfas': _yanit(listeJson([etkinJson(bildirimTayfaId)])),
  }),
);

Future<void> _ekraniAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  List<String>? istenenProfiller,
  List<Override> overrides = const [],
}) => widgetAc(
  tester,
  const BildirimlerEkrani(),
  themeMode: themeMode,
  tayfa: _tayfa(),
  overrides: [
    ...bildirimOverridelari(tasima: tasima),
    arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(tasima)),
    etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
    simdiProvider.overrideWithValue(() => _simdi),
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
    profilSahtesi({kisiId: 'Ayşe'}, istenen: istenenProfiller),
    ...overrides,
  ],
);

SahteTayfaTasima _liste(
  List<Map<String, Object?>> bildirimler, {
  int okunmamis = 0,
}) => SahteTayfaTasima({
  'GET $bildirimlerYolu': _yanit(bildirimListesiJson(bildirimler)),
  'GET $okunmamisYolu': _yanit(okunmamisJson(okunmamis)),
});

/// Farklı türlerden örnek bildirimler (içerik alanı yoktur).
List<Map<String, Object?>> _karisik() => [
  bildirimJson(bildirimId1),
  bildirimJson(
    bildirimId2,
    tur: 'join_request',
    hedefTuru: 'membership',
    hedef: kisiId,
    okundu: true,
  ),
  bildirimJson(
    bildirimId3,
    tur: 'dm_message',
    tayfaId: null,
    hedefTuru: 'dm_conversation',
    sayi: 3,
  ),
];

Map<String, Object?> _arkadaslikIstegi({bool okundu = false}) => bildirimJson(
  'bbbbbbbb-0000-4000-8000-000000000001',
  tur: 'friend_request',
  tayfaId: null,
  hedefTuru: 'user',
  hedef: kisiId,
  okundu: okundu,
  zaman: _zaman(DateTime(2026, 11, 13, 13, 10)),
);

Map<String, Object?> _tayfaDaveti() => bildirimJson(
  'bbbbbbbb-0000-4000-8000-000000000002',
  tur: 'tayfa_invitation',
  aktor: kisiId,
  hedefTuru: 'tayfa',
  hedef: bildirimTayfaId,
  zaman: _zaman(DateTime(2026, 11, 12, 21, 40)),
);

Map<String, Object?> _yuruyusUyarisi({bool okundu = false}) => bildirimJson(
  'bbbbbbbb-0000-4000-8000-000000000003',
  tur: 'hike_overdue',
  yuruyuscu: kisiId,
  okundu: okundu,
  zaman: _zaman(DateTime(2026, 11, 13, 14, 45)),
);

void main() {
  group('liste', () {
    testWidgets('metin türden, tayfa adı ve kişi adıyla kuruluyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final istenen = <String>[];
      await _ekraniAc(
        tester,
        _liste(_karisik(), okunmamis: 2),
        istenenProfiller: istenen,
      );

      expect(find.byType(BildirimSatiri), findsNWidgets(3));
      expect(find.text(arbMetni('bildirim_etkinlik_eklendi')), findsOneWidget);
      expect(find.text('Ayşe tayfaya katılmak istiyor'), findsOneWidget);
      expect(find.text(arbMetni('bildirim_mesaj')), findsOneWidget);
      // Tayfaya bağlı iki bildirimde tayfanın adı var; DM'de yok.
      expect(find.text('Klasikçiler'), findsNWidgets(2));
      // Ad yalnızca katılım isteğindeki kişi için istendi; DM için değil
      // (kesin kural 7: DM bildiriminde gönderen yok).
      expect(istenen, [kisiId]);
      // Okunmamış iki bildirim ekran okuyucuya "Okunmadı" diyor.
      expect(_okunmadi(), findsNWidgets(2));
      // Katılım isteğinde "İncele".
      expect(find.text(arbMetni('bildirim_incele')), findsOneWidget);
      expect(find.text(arbMetni('bildirim_saklama')), findsOneWidget);
    });

    testWidgets('zamana göre gruplar ve göreli zaman', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _ekraniAc(
        tester,
        _liste([
          bildirimJson(
            bildirimId1,
            zaman: _zaman(DateTime(2026, 11, 13, 14, 32)),
          ),
          bildirimJson(
            bildirimId2,
            tur: 'announcement',
            hedefTuru: 'announcement',
            okundu: true,
            zaman: _zaman(DateTime(2026, 11, 12, 18, 22)),
          ),
          bildirimJson(
            bildirimId3,
            tur: 'answer_received',
            hedefTuru: 'answer',
            okundu: true,
            zaman: _zaman(DateTime(2026, 11, 10, 9)),
          ),
          bildirimJson(
            'aaaaaaaa-0000-4000-8000-000000000009',
            tur: 'data_export_ready',
            tayfaId: null,
            hedefTuru: 'data_export',
            okundu: true,
            zaman: _zaman(DateTime(2026, 11, 3, 9)),
          ),
        ], okunmamis: 1),
      );

      for (final anahtar in [
        'bildirim_grup_bugun',
        'bildirim_grup_dun',
        'bildirim_grup_bu_hafta',
        'bildirim_grup_daha_eski',
      ]) {
        expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
      }
      expect(find.text('14:32'), findsOneWidget);
      expect(find.text('18:22'), findsOneWidget);
      expect(find.text('Salı'), findsOneWidget);
      expect(find.text('3 Kas'), findsOneWidget);
      expect(find.byType(ListeKarti), findsNWidgets(4));
    });

    testWidgets('boşken logo, boş metin ve açıklama; "Hepsini okundu say" '
        'yok', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(tester, _liste(const []));
      expect(find.byType(BosBildirimler), findsOneWidget);
      expect(find.byType(TayfamLogo), findsOneWidget);
      expect(find.text(arbMetni('bildirim_bos')), findsOneWidget);
      expect(find.text(arbMetni('bildirim_bos_aciklama')), findsOneWidget);
      expect(find.text(arbMetni('bildirim_hepsini_okundu_say')), findsNothing);
    });

    testWidgets('hepsi okunmuşsa "Hepsini okundu say" yok', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(
        tester,
        _liste([bildirimJson(bildirimId1, okundu: true)]),
      );
      expect(find.byType(BildirimSatiri), findsOneWidget);
      expect(find.text(arbMetni('bildirim_hepsini_okundu_say')), findsNothing);
    });

    testWidgets('"Hepsini okundu say" isteği gönderiyor ve düğme kalkıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste(_karisik(), okunmamis: 2);
      await _ekraniAc(tester, tasima);

      await tester.tap(find.text(arbMetni('bildirim_hepsini_okundu_say')));
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', hepsiOkunduYolu), hasLength(1));
      expect(find.text(arbMetni('bildirim_hepsini_okundu_say')), findsNothing);
      expect(_okunmadi(), findsNothing);
    });

    testWidgets('liste okunamazsa hata satırı ve "Tekrar dene"', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var hata = true;
      final tasima = SahteTayfaTasima({
        'GET $bildirimlerYolu': (_) => hata
            ? const ApiOffline()
            : bildirimListesiJson([bildirimJson(bildirimId1)]),
      });
      await _ekraniAc(tester, tasima);
      expect(find.byType(HataSatiri), findsOneWidget);

      hata = false;
      await tester.tap(find.text(arbMetni('tayfa_ana_tekrar_dene')));
      await tester.pumpAndSettle();
      expect(find.byType(BildirimSatiri), findsOneWidget);
    });

    testWidgets('sayfalama: "Daha fazla göster" sonraki sayfayı ekliyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = SahteTayfaTasima({
        'GET $bildirimlerYolu': (i) => switch (i.sorgu['page_token']) {
          null => bildirimListesiJson([
            bildirimJson(bildirimId1),
          ], sonraki: 'opak-1'),
          _ => bildirimListesiJson([
            bildirimJson(bildirimId2, tur: 'announcement'),
          ]),
        },
      });
      await _ekraniAc(tester, tasima);
      expect(find.text(arbMetni('bildirim_duyuru')), findsNothing);

      await tester.tap(find.text(arbMetni('tayfa_ana_daha_fazla')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('bildirim_duyuru')), findsOneWidget);
      expect(
        tasima.giden('GET', bildirimlerYolu).last.sorgu['page_token'],
        'opak-1',
      );
    });
  });

  group('satır içi işlem', () {
    testWidgets('arkadaşlık isteği kabul: uç çağrılır, sonuç görünür, '
        'okundu olur', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_arkadaslikIstegi()], okunmamis: 1)
        ..yanitlar['POST ${arkadas.kabulYolu}'] = _yanit(
          arkadas.arkadasJson(kisiId),
        );
      await _ekraniAc(tester, tasima);

      expect(find.text('Ayşe sana arkadaşlık isteği gönderdi'), findsOneWidget);
      await tester.tap(find.text(arbMetni('arkadas_kabul_et')));
      await tester.pumpAndSettle();

      final kabul = tasima.giden('POST', arkadas.kabulYolu).single;
      expect(kabul.yolParametreleri['user_id'], kisiId);
      expect(find.text(arbMetni('bildirim_sonuc_arkadas')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_kabul_et')), findsNothing);
      expect(find.text(arbMetni('arkadas_reddet')), findsNothing);
      expect(tasima.giden('PUT', okunduYolu), hasLength(1));
      expect(_okunmadi(), findsNothing);
    });

    testWidgets('arkadaşlık isteği reddi: "Reddedildi"', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_arkadaslikIstegi()], okunmamis: 1)
        ..yanitlar['DELETE ${arkadas.arkadasYolu}'] = _yanit(null);
      await _ekraniAc(tester, tasima);

      await tester.tap(find.text(arbMetni('arkadas_reddet')));
      await tester.pumpAndSettle();

      expect(tasima.giden('DELETE', arkadas.arkadasYolu), hasLength(1));
      expect(find.text(arbMetni('bildirim_sonuc_reddedildi')), findsOneWidget);
    });

    testWidgets('onaylı tayfanın daveti: "İsteğin gönderildi"', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_tayfaDaveti()], okunmamis: 1)
        ..yanitlar['POST ${arkadas.davetKabulYolu}'] = _yanit(
          uyelikJson(bildirimTayfaId, durum: 'pending'),
        );
      await _ekraniAc(tester, tasima);

      expect(find.text('Ayşe seni bir tayfaya davet etti'), findsOneWidget);
      await tester.tap(find.text(arbMetni('arkadas_davet_kabul')));
      await tester.pumpAndSettle();

      final kabul = tasima.giden('POST', arkadas.davetKabulYolu).single;
      expect(kabul.yolParametreleri['tayfa_id'], bildirimTayfaId);
      expect(
        find.text(arbMetni('bildirim_sonuc_istek_gonderildi')),
        findsOneWidget,
      );
    });

    testWidgets('açık tayfanın daveti: "Katıldın"', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_tayfaDaveti()], okunmamis: 1)
        ..yanitlar['POST ${arkadas.davetKabulYolu}'] = _yanit(
          uyelikJson(bildirimTayfaId),
        );
      await _ekraniAc(tester, tasima);

      await tester.tap(find.text(arbMetni('arkadas_davet_kabul')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('bildirim_sonuc_katildin')), findsOneWidget);
    });

    testWidgets('işlem başarısızsa düğmeler kalır ve hata gösterilir', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_arkadaslikIstegi()], okunmamis: 1)
        ..yanitlar['POST ${arkadas.kabulYolu}'] = _yanit(const ApiOffline());
      await _ekraniAc(tester, tasima);

      await tester.tap(find.text(arbMetni('arkadas_kabul_et')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(arbMetni('arkadas_kabul_et')), findsOneWidget);
      expect(find.text(arbMetni('bildirim_sonuc_arkadas')), findsNothing);
      expect(tasima.giden('PUT', okunduYolu), isEmpty);
    });
  });

  group('güvenlik uyarısı', () {
    testWidgets('okunmamış hike_overdue en üstte sabit kartta, etkinlik '
        'adıyla', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final bildirimler = [
        bildirimJson(
          bildirimId1,
          zaman: _zaman(DateTime(2026, 11, 13, 14, 50)),
        ),
        _yuruyusUyarisi(),
      ];
      final tasima = _liste(bildirimler, okunmamis: 2);
      tasima.yanitlar['GET ${etkinlik.etkinlikYolu}'] = _yanit(
        etkinlik.etkinlikJson(id: hedefId, baslik: 'Orman yürüyüşü'),
      );
      await _ekraniAc(tester, tasima);

      expect(find.byType(GuvenlikUyarisiKarti), findsOneWidget);
      expect(find.text('Ayşe yürüyüşten zamanında dönmedi'), findsOneWidget);
      expect(
        find.text('Orman yürüyüşü · Klasikçiler · 14:45'),
        findsOneWidget,
      );
      expect(find.text(arbMetni('bildirim_yoklamayi_ac')), findsOneWidget);
      // Uyarı listede ikinci kez görünmez.
      expect(find.byType(BildirimSatiri), findsOneWidget);
      // Kart listenin üstünde.
      expect(
        tester.getTopLeft(find.byType(GuvenlikUyarisiKarti)).dy,
        lessThan(tester.getTopLeft(find.byType(BildirimSatiri)).dy),
      );
    });

    testWidgets('etkinlik okunamazsa kart tayfa ve zamanla', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([_yuruyusUyarisi()], okunmamis: 1)
        ..yanitlar['GET ${etkinlik.etkinlikYolu}'] = _yanit(
          const ApiOffline(),
        );
      await _ekraniAc(tester, tasima);
      expect(find.text('Klasikçiler · 14:45'), findsOneWidget);
    });

    testWidgets('okunmuş uyarı listedeki yerinde', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _ekraniAc(tester, _liste([_yuruyusUyarisi(okundu: true)]));
      expect(find.byType(GuvenlikUyarisiKarti), findsNothing);
      expect(find.byType(BildirimSatiri), findsOneWidget);
    });
  });

  group('izin kartı', () {
    List<Override> push(SahtePushPlatformu platform) => [
      pushPlatformuProvider.overrideWithValue(platform),
      pushTokenDeposuProvider.overrideWithValue(SahtePushTokenDeposu()),
      cihazAyarlariDeposuProvider.overrideWithValue(
        BellekCihazAyarlariDeposu(),
      ),
    ];

    testWidgets('izin yokken mor kart; "Şimdi değil" kapatır', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
      await _ekraniAc(
        tester,
        _liste([bildirimJson(bildirimId1)], okunmamis: 1),
        overrides: push(platform),
      );
      expect(find.byType(IzinKarti), findsOneWidget);
      expect(find.text(arbMetni('bildirim_izni_aciklama')), findsOneWidget);

      await tester.tap(find.text(arbMetni('bildirim_izni_simdi_degil')));
      await tester.pumpAndSettle();
      expect(find.byType(IzinKarti), findsNothing);
      expect(platform.izinIstegi, 0);
    });

    testWidgets('"İzin ver" sistem penceresini açar', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final platform = SahtePushPlatformu(izinDurumu: BildirimIzni.sorulmadi);
      await _ekraniAc(tester, _liste(const []), overrides: push(platform));
      await tester.tap(find.text(arbMetni('bildirim_izni_ver')));
      await tester.pumpAndSettle();
      expect(platform.izinIstegi, 1);
      expect(find.byType(IzinKarti), findsNothing);
    });

    testWidgets('izin varken kart yok', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(
        tester,
        _liste(const []),
        overrides: push(SahtePushPlatformu()),
      );
      expect(find.byType(IzinKarti), findsNothing);
    });
  });

  group('tema ve yazı ölçeği', () {
    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp genişlikte taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final bildirimler = [
          ..._karisik(),
          _arkadaslikIstegi(),
          _tayfaDaveti(),
          _yuruyusUyarisi(),
          bildirimJson(
            'aaaaaaaa-0000-4000-8000-000000000009',
            tur: 'tayfa_warned',
            hedefTuru: 'tayfa',
            hedef: bildirimTayfaId,
            uyari: 'few_members',
          ),
        ];
        final tasima = _liste(bildirimler, okunmamis: 3);
        tasima.yanitlar['GET ${etkinlik.etkinlikYolu}'] = _yanit(
          etkinlik.etkinlikJson(id: hedefId),
        );
        await _ekraniAc(
          tester,
          tasima,
          themeMode: mod,
          overrides: [
            pushPlatformuProvider.overrideWithValue(
              SahtePushPlatformu(izinDurumu: BildirimIzni.reddedildi),
            ),
            pushTokenDeposuProvider.overrideWithValue(SahtePushTokenDeposu()),
            cihazAyarlariDeposuProvider.overrideWithValue(
              BellekCihazAyarlariDeposu(),
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(IzinKarti), findsOneWidget);
        expect(find.byType(GuvenlikUyarisiKarti), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -4000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('${mod.name} temada 2× yazıda boş durum taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ekraniAc(tester, _liste(const []), themeMode: mod);
        expect(tester.takeException(), isNull);
        expect(find.byType(BosBildirimler), findsOneWidget);
      });
    }
  });

  group('uygulamada', () {
    /// Tayfa listesinde [ornekTayfaId] var (aktif tayfa).
    List<Override> tayfaUyesi() => tayfaOverridelari(
      tasima: SahteTayfaTasima({
        'GET /v1/tayfas': _yanit(listeJson([etkinJson(ornekTayfaId)])),
      }),
    );

    Finder sekme() => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(arbMetni('gezinme_sekme_bildirimler')),
    );

    String yol(WidgetTester tester) =>
        yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

    testWidgets('rozet sunucudaki okunmamış sayısını gösteriyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await uygulamayiAc(
        tester,
        bildirim: bildirimOverridelari(tasima: _liste(const [], okunmamis: 4)),
      );
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('sekme açılınca ve ön plana dönünce rozet yenileniyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _liste(const [], okunmamis: 1);
      await uygulamayiAc(
        tester,
        bildirim: bildirimOverridelari(tasima: tasima),
      );
      final ilk = tasima.giden('GET', okunmamisYolu).length;

      await tester.tap(sekme());
      await tester.pumpAndSettle();
      expect(yol(tester), '/bildirimler');
      expect(tasima.giden('GET', okunmamisYolu).length, ilk + 1);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', okunmamisYolu).length, ilk + 2);
    });

    testWidgets('ekranı olmayan hedef: okundu işaretlenip tayfa açılıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([
        bildirimJson(
          bildirimId1,
          tur: 'join_request',
          tayfaId: ornekTayfaId,
          hedefTuru: 'membership',
          hedef: kisiId,
        ),
      ], okunmamis: 1);
      await uygulamayiAc(
        tester,
        tayfa: tayfaUyesi(),
        bildirim: bildirimOverridelari(tasima: tasima),
        overrides: [
          profilSahtesi({kisiId: 'Ayşe'}),
        ],
      );

      await tester.tap(sekme());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayşe tayfaya katılmak istiyor'));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', okunduYolu), hasLength(1));
      expect(yol(tester), '/t/$ornekTayfaId');
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('tayfasız bildirim yalnızca okundu işaretleniyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _liste([
        bildirimJson(
          bildirimId1,
          tur: 'dm_request',
          tayfaId: null,
          hedefTuru: 'user',
        ),
      ], okunmamis: 1);
      await uygulamayiAc(
        tester,
        tayfa: tayfaUyesi(),
        bildirim: bildirimOverridelari(tasima: tasima),
      );

      await tester.tap(sekme());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BildirimSatiri));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', okunduYolu), hasLength(1));
      expect(yol(tester), '/bildirimler');
    });
  });
}
