import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_karti.dart';
import 'package:tayfam/features/bildirim/presentation/bildirimler_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Finder _okunmadi() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == arbMetni('bildirim_okunmadi'),
);

TayfaYaniti _yanit(Object? deger) =>
    (_) => deger;

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
}) => widgetAc(
  tester,
  const BildirimlerEkrani(),
  themeMode: themeMode,
  tayfa: _tayfa(),
  overrides: [
    ...bildirimOverridelari(tasima: tasima),
    oturumDurumuProvider.overrideWith(
      () => SabitOturumDurumu(OturumDurumu.acik),
    ),
    profilSahtesi({kisiId: 'Ayşe'}, istenen: istenenProfiller),
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

      expect(find.byType(BildirimKarti), findsNWidgets(3));
      expect(
        find.text(arbMetni('bildirim_etkinlik_eklendi')),
        findsOneWidget,
      );
      expect(find.text('Ayşe tayfaya katılmak istiyor'), findsOneWidget);
      expect(find.text(arbMetni('bildirim_mesaj')), findsOneWidget);
      // Tayfaya bağlı iki bildirimde tayfanın adı var; DM'de yok.
      expect(find.text('Klasikçiler'), findsNWidgets(2));
      // Ad yalnızca katılım isteğindeki kişi için istendi; DM için değil.
      expect(istenen, [kisiId]);
      // Okunmamış iki bildirim ekran okuyucuya "Okunmadı" diyor.
      expect(_okunmadi(), findsNWidgets(2));
    });

    testWidgets('boşken boş metin; "Hepsini okundu say" yok', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(tester, _liste(const []));
      expect(find.text(arbMetni('bildirim_bos')), findsOneWidget);
      expect(
        find.text(arbMetni('bildirim_hepsini_okundu_say')),
        findsNothing,
      );
    });

    testWidgets('hepsi okunmuşsa "Hepsini okundu say" yok', (tester) async {
      ekranBoyutu(tester);
      await _ekraniAc(
        tester,
        _liste([bildirimJson(bildirimId1, okundu: true)]),
      );
      expect(find.byType(BildirimKarti), findsOneWidget);
      expect(
        find.text(arbMetni('bildirim_hepsini_okundu_say')),
        findsNothing,
      );
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
      expect(
        find.text(arbMetni('bildirim_hepsini_okundu_say')),
        findsNothing,
      );
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
      expect(find.byType(BildirimKarti), findsOneWidget);
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

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('${mod.name} temada 2× yazıda 320 dp genişlikte taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ekraniAc(
          tester,
          _liste([
            ..._karisik(),
            bildirimJson(
              'aaaaaaaa-0000-4000-8000-000000000009',
              tur: 'tayfa_warned',
              hedefTuru: 'tayfa',
              hedef: bildirimTayfaId,
              uyari: 'few_members',
            ),
          ], okunmamis: 3),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
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
        overrides: [profilSahtesi({kisiId: 'Ayşe'})],
      );

      await tester.tap(sekme());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BildirimKarti));
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
          hedefTuru: 'dm_conversation',
        ),
      ], okunmamis: 1);
      await uygulamayiAc(
        tester,
        tayfa: tayfaUyesi(),
        bildirim: bildirimOverridelari(tasima: tasima),
      );

      await tester.tap(sekme());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BildirimKarti));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', okunduYolu), hasLength(1));
      expect(yol(tester), '/bildirimler');
    });
  });
}
