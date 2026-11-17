import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/moduller/kesfet_yuvalari.dart';
import 'package:tayfam/core/push/push_kaydi.dart';
import 'package:tayfam/core/push/push_platformu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/kesfet/data/kesfet_deposu.dart';
import 'package:tayfam/features/kesfet/presentation/kesfet_ekrani.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/kabuk_iskeleti.dart';

import '../core/push/sahte_push.dart';
import '../features/bildirim/sahteler.dart';
import '../features/kesfet/sahteler.dart' show kesfetTasimasi;
import '../features/tayfa/sahteler.dart';
import '../yardimcilar.dart';

/// Keşfet sekmesi ve bildirim zili (istemci ADR-0030; issue #214).

Finder _sekme(String anahtar) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(arbMetni(anahtar)),
);

Finder _zil() => find.byKey(const ValueKey('bildirim-zili'));

/// En üstteki ekranın yolu (`push` ile açılanlar dahil).
String _yol(WidgetTester tester) => yonlendiriciyiAl(tester).state.uri.path;

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// Keşfet akışı dolu (bir öğe), gerçek ağ yok.
KesfetDeposu _doluKesfet() => KesfetDeposu(kesfetTasimasi());

/// Tayfa listesinde [ornekTayfaId] var (aktif tayfa).
List<Override> _tayfaUyesi() => tayfaOverridelari(
  tasima: SahteTayfaTasima({
    'GET /v1/tayfas': (_) => listeJson([etkinJson(ornekTayfaId)]),
  }),
);

void main() {
  testWidgets('dört sekme sırasıyla: Tayfa, Sohbet, Keşfet, Profil', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    final cubuk = tester.widget<NavigationBar>(find.byType(NavigationBar));
    final etiketler = [
      for (final hedef in cubuk.destinations)
        (hedef as NavigationDestination).label,
    ];
    expect(etiketler, [
      arbMetni('gezinme_sekme_tayfa'),
      arbMetni('gezinme_sekme_sohbet'),
      arbMetni('gezinme_sekme_kesfet'),
      arbMetni('gezinme_sekme_profil'),
    ]);
  });

  testWidgets('Keşfet sekmesi /kesfet; üst çubukta başlık ve zil', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester, kesfet: _doluKesfet());

    await _dokun(tester, _sekme('gezinme_sekme_kesfet'));

    expect(_yol(tester), Adresler.kesfet);
    expect(find.byType(KesfetEkrani), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: _zil()),
      findsOneWidget,
    );
    expect(find.text('Belgrad Ormanı sabah yürüyüşü'), findsOneWidget);
  });

  testWidgets('tayfa ana sayfasındaki zil Bildirimler\'i açar; geri döner', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final tasima = SahteTayfaTasima({
      'GET $bildirimlerYolu': (_) => bildirimListesiJson(const []),
      'GET $okunmamisYolu': (_) => okunmamisJson(2),
    });
    await uygulamayiAc(
      tester,
      tayfa: _tayfaUyesi(),
      bildirim: bildirimOverridelari(tasima: tasima),
    );
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
    expect(
      find.descendant(of: find.byType(TayfaUstBolumu), matching: _zil()),
      findsOneWidget,
    );
    final ilk = tasima.giden('GET', okunmamisYolu).length;

    await _dokun(tester, _zil());

    expect(_yol(tester), Adresler.bildirimler);
    expect(find.byType(BildirimlerEkrani), findsOneWidget);
    // Sekmelerin üstünde açılır; açılınca rozet sunucudan okunur.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(KabukIskeleti, skipOffstage: false), findsOneWidget);
    expect(tasima.giden('GET', okunmamisYolu).length, greaterThan(ilk));

    final islendi = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(islendi, isTrue);
    expect(_yol(tester), '/t/$ornekTayfaId');
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
  });

  testWidgets('Keşfet\'teki zil Bildirimler\'i açar; geri Keşfet\'e döner', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester, kesfet: _doluKesfet());
    await _dokun(tester, _sekme('gezinme_sekme_kesfet'));

    await _dokun(tester, _zil());
    expect(_yol(tester), Adresler.bildirimler);
    expect(find.byType(BildirimlerEkrani), findsOneWidget);

    await _dokun(tester, find.byType(BackButton));
    expect(_yol(tester), Adresler.kesfet);
    expect(find.byType(KesfetEkrani), findsOneWidget);
  });

  testWidgets('karşılama ekranındaki zil Bildirimler\'i açar', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);

    await _dokun(tester, _zil());
    expect(_yol(tester), Adresler.bildirimler);
  });

  testWidgets('zil rozeti: 0 iken yok, sayı varken 48 dp ve etiketli', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final tasima = SahteTayfaTasima({
      'GET $bildirimlerYolu': (_) => bildirimListesiJson(const []),
      'GET $okunmamisYolu': (_) => okunmamisJson(5),
    });
    await uygulamayiAc(
      tester,
      tayfa: _tayfaUyesi(),
      bildirim: bildirimOverridelari(tasima: tasima),
    );

    expect(
      find.descendant(of: _zil(), matching: find.byType(Badge)),
      findsOneWidget,
    );
    expect(find.descendant(of: _zil(), matching: find.text('5')), findsOne);
    expect(
      find.bySemanticsLabel('Bildirimler, 5 okunmamış bildirim'),
      findsOneWidget,
    );
    // Mor üst bölümde nar rozet 3:1'i tutmaz; mango zemin, ink metin.
    final rozet = tester.widget<Badge>(
      find.descendant(of: _zil(), matching: find.byType(Badge)),
    );
    expect(rozet.backgroundColor, TayfamColors.acik.mango);
    expect(rozet.textColor, TayfamColors.acik.vurguUstu);
    final boyut = tester.getSize(_zil());
    expect(boyut.width, greaterThanOrEqualTo(48));
    expect(boyut.height, greaterThanOrEqualTo(48));
  });

  testWidgets('bildirimden sekme adresine gidince Bildirimler kapanır', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1200);
    final tasima = SahteTayfaTasima({
      'GET $bildirimlerYolu': (_) => bildirimListesiJson([
        bildirimJson(
          bildirimId1,
          tur: 'join_request',
          tayfaId: ornekTayfaId,
          hedefTuru: 'membership',
          hedef: kisiId,
        ),
      ]),
      'GET $okunmamisYolu': (_) => okunmamisJson(1),
    });
    await uygulamayiAc(
      tester,
      tayfa: _tayfaUyesi(),
      bildirim: bildirimOverridelari(tasima: tasima),
      kesfet: _doluKesfet(),
      overrides: [
        profilSahtesi({kisiId: 'Ayşe'}),
      ],
    );
    // Keşfet sekmesinden açılan Bildirimler, Tayfa sekmesine götürür.
    await _dokun(tester, _sekme('gezinme_sekme_kesfet'));
    await _dokun(tester, _zil());
    await _dokun(tester, find.text('Ayşe tayfaya katılmak istiyor'));

    expect(_yol(tester), '/t/$ornekTayfaId');
    expect(find.byType(BildirimlerEkrani), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.container().read(aktifTayfaIdProvider), ornekTayfaId);
  });

  testWidgets('derin adres /bildirimler ve /kesfet doğrudan açılır', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester, kesfet: _doluKesfet());

    yonlendiriciyiAl(tester).go(Adresler.kesfet);
    await tester.pumpAndSettle();
    expect(find.byType(KesfetEkrani), findsOneWidget);
    final cubuk = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(cubuk.selectedIndex, 2);

    yonlendiriciyiAl(tester).go(Adresler.bildirimler);
    await tester.pumpAndSettle();
    expect(find.byType(BildirimlerEkrani), findsOneWidget);
  });

  testWidgets('tayfa panelindeki Keşfet satırı Keşfet sekmesine geçer', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      tayfa: _tayfaUyesi(),
      kesfet: _doluKesfet(),
      overrides: [kesfetGorunurProvider.overrideWithValue(true)],
    );
    unawaited(
      tayfaDegistirmePaneliniAc(tester.element(find.byType(TayfaAnaSayfa))),
    );
    await tester.pumpAndSettle();
    await _dokun(
      tester,
      find.descendant(
        of: find.byType(TayfaDegistirmePaneli),
        matching: find.text(arbMetni('kesfet_baslik')),
      ),
    );

    expect(_yol(tester), Adresler.kesfet);
    expect(find.byType(KesfetEkrani), findsOneWidget);
    expect(find.byType(TayfaDegistirmePaneli), findsNothing);
    final cubuk = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(cubuk.selectedIndex, 2);
  });

  group('push dokunma (istemci ADR-0019 §6)', () {
    List<Override> push(SahtePushPlatformu platform) => [
      pushPlatformuProvider.overrideWithValue(platform),
      pushTokenDeposuProvider.overrideWithValue(SahtePushTokenDeposu()),
    ];

    testWidgets('doğrulanamayan veri Bildirimler\'i sekmelerin üstünde açar', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final platform = SahtePushPlatformu();
      await uygulamayiAc(
        tester,
        tayfa: _tayfaUyesi(),
        overrides: push(platform),
      );

      platform.dokunma.add(const {'type': 'bozuk'});
      await tester.pumpAndSettle();
      expect(_yol(tester), Adresler.bildirimler);
      // Kabuk (WebSocket, push dinleyicisi) yığında kalır.
      expect(find.byType(KabukIskeleti, skipOffstage: false), findsOneWidget);

      // Ekran açıkken ikinci dokunma ikinci kez itmez.
      platform.dokunma.add(const {'type': 'bozuk'});
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_yol(tester), '/t/$ornekTayfaId');
    });

    testWidgets('tayfa hedefli bildirim tayfa sekmesine gider', (tester) async {
      ekranBoyutu(tester);
      final platform = SahtePushPlatformu();
      await uygulamayiAc(
        tester,
        tayfa: _tayfaUyesi(),
        kesfet: _doluKesfet(),
        overrides: push(platform),
      );
      await _dokun(tester, _sekme('gezinme_sekme_kesfet'));

      platform.dokunma.add(const {
        'notification_id': bildirimId1,
        'type': 'join_request',
        'target_type': 'membership',
        'target_id': kisiId,
        'tayfa_id': ornekTayfaId,
      });
      await tester.pumpAndSettle();
      expect(_yol(tester), startsWith('/t/$ornekTayfaId'));
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  test('sekmelerin üstündeki adresler', () {
    expect(Adresler.sekmelerinUstundeMi(Adresler.bildirimler), isTrue);
    expect(Adresler.sekmelerinUstundeMi(Adresler.kisi(kisiId)), isTrue);
    expect(Adresler.sekmelerinUstundeMi(Adresler.kesfet), isFalse);
    expect(Adresler.sekmelerinUstundeMi(Adresler.tayfa(ornekTayfaId)), isFalse);
    expect(Adresler.sekmelerinUstundeMi('/bildirimler-sahte'), isFalse);
  });
}
