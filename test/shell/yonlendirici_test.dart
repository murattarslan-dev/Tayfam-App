import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';
import 'package:tayfam/features/profil/profil.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/shell/okunmamis.dart';

import '../features/profil/sahteler.dart' show SahteTasima, profilYanitlari;
import '../features/tayfa/sahteler.dart';
import '../yardimcilar.dart';

Finder _sekme(String anahtar) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(arbMetni(anahtar)),
);

Finder _semantikEtiketi(String etiket) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == etiket,
);

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

Future<void> _aktifTayfaSec(WidgetTester tester, String tayfaId) async {
  tester.container().read(aktifTayfaIdProvider.notifier).sec(tayfaId);
  await tester.pumpAndSettle();
}

/// Profil sekmesinin uçları ve tema deposu için sahteler (gerçek ağ ve
/// güvenli depo yok).
List<Override> _profilSahteleri() => [
  profilDeposuProvider.overrideWithValue(
    ProfilDeposu(SahteTasima(profilYanitlari())),
  ),
  temaTercihiDeposuProvider.overrideWithValue(BellekTemaTercihiDeposu()),
];

void main() {
  testWidgets('tayfası yokken Tayfa sekmesi karşılamayı gösteriyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester, overrides: _profilSahteleri());

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.text(arbMetni('karsilama_kodum_var')), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/karsilama',
    );

    // Diğer sekmeler çalışıyor.
    await tester.tap(_sekme('gezinme_sekme_profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilEkrani), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/profil',
    );
  });

  testWidgets('aktif tayfa seçilince Tayfa sekmesi tayfanın ana sayfası', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    await _aktifTayfaSec(tester, ornekTayfaId);

    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
    // Ad tayfa sunucudan tazelenince gelir (sahte yanıt).
    expect(find.text('Klasikçiler'), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/t/$ornekTayfaId',
    );
  });

  testWidgets('geçersiz tayfa kimliği karşılamaya yönleniyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    yonlendiriciyiAl(tester).go('/t/gecersiz-kimlik');
    await tester.pumpAndSettle();

    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.byType(TayfaAnaSayfa), findsNothing);
  });

  testWidgets('sekmeler geçmişini koruyor; geri tuşu önce sekme içinde', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      overrides: [
        tayfaModulleriProvider.overrideWithValue(const [DenemeModulu()]),
      ],
    );
    await _aktifTayfaSec(tester, ornekTayfaId);

    // Tayfa sekmesinde bir alt sayfaya git.
    yonlendiriciyiAl(tester).go('/t/$ornekTayfaId/deneme');
    await tester.pumpAndSettle();
    expect(find.text(DenemeModulu.sayfaMetni), findsOneWidget);

    // Sohbet'e geç ve geri dön: Tayfa sekmesi kaldığı yerde.
    await tester.tap(_sekme('gezinme_sekme_sohbet'));
    await tester.pumpAndSettle();
    expect(find.text(DenemeModulu.sayfaMetni), findsNothing);
    expect(find.text(arbMetni('gezinme_yer_tutucu_aciklama')), findsOneWidget);

    await tester.tap(_sekme('gezinme_sekme_tayfa'));
    await tester.pumpAndSettle();
    expect(find.text(DenemeModulu.sayfaMetni), findsOneWidget);

    // Android geri tuşu önce sekmenin kendi yığınında geri gider.
    final islendi = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(islendi, isTrue);
    expect(find.text(DenemeModulu.sayfaMetni), findsNothing);
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/t/$ornekTayfaId',
    );
  });

  testWidgets('seçili sekmeye yeniden dokunmak sekmenin köküne döndürüyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      overrides: [
        tayfaModulleriProvider.overrideWithValue(const [DenemeModulu()]),
      ],
    );
    await _aktifTayfaSec(tester, ornekTayfaId);
    yonlendiriciyiAl(tester).go('/t/$ornekTayfaId/deneme');
    await tester.pumpAndSettle();

    await tester.tap(_sekme('gezinme_sekme_tayfa'));
    await tester.pumpAndSettle();

    expect(find.text(DenemeModulu.sayfaMetni), findsNothing);
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
  });

  group('tayfa listesi ve adres (ADR-0014 §1)', () {
    const ucuncuTayfaId = '5e6f7a8b-9c0d-4e1f-a2b3-c4d5e6f7a8b9';

    List<Override> ikiTayfa() => tayfaOverridelari(
      tasima: SahteTayfaTasima({
        'GET /v1/tayfas': (_) => listeJson([
          etkinJson(ornekTayfaId),
          etkinJson(ikinciTayfaId, ad: 'Balıkçılar'),
        ]),
      }),
    );

    testWidgets('açılışta ilk etkin tayfanın ana sayfası', (tester) async {
      ekranBoyutu(tester);
      await uygulamayiAc(tester, tayfa: ikiTayfa());

      expect(find.byType(TayfaAnaSayfa), findsOneWidget);
      expect(_yol(tester), '/t/$ornekTayfaId');
    });

    testWidgets('son kullanılan tayfa hatırlanıyor', (tester) async {
      ekranBoyutu(tester);
      await uygulamayiAc(
        tester,
        tayfa: tayfaOverridelari(
          tasima: SahteTayfaTasima({
            'GET /v1/tayfas': (_) =>
                listeJson([etkinJson(ornekTayfaId), etkinJson(ikinciTayfaId)]),
          }),
          sonTayfa: BellekSonTayfaDeposu(ikinciTayfaId),
        ),
      );

      expect(_yol(tester), '/t/$ikinciTayfaId');
    });

    testWidgets('adresteki etkin tayfa aktif oluyor', (tester) async {
      ekranBoyutu(tester);
      await uygulamayiAc(tester, tayfa: ikiTayfa());

      yonlendiriciyiAl(tester).go('/t/$ikinciTayfaId');
      await tester.pumpAndSettle();

      expect(_yol(tester), '/t/$ikinciTayfaId');
      expect(tester.container().read(aktifTayfaIdProvider), ikinciTayfaId);
    });

    testWidgets('üye olunmayan tayfa adresi ana adrese dönüyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await uygulamayiAc(tester, tayfa: ikiTayfa());

      yonlendiriciyiAl(tester).go('/t/$ucuncuTayfaId');
      await tester.pumpAndSettle();

      expect(_yol(tester), '/t/$ornekTayfaId');
      expect(tester.container().read(aktifTayfaIdProvider), ornekTayfaId);
    });
  });

  testWidgets('400 px genişlikte alt gezinme çubuğu', (tester) async {
    ekranBoyutu(tester, genislik: 400, yukseklik: 800);
    await uygulamayiAc(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('800 px genişlikte dikey gezinme çubuğu', (tester) async {
    ekranBoyutu(tester, genislik: 800, yukseklik: 1280);
    await uygulamayiAc(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(4));

    // Dikey çubukta da sekme değişiyor.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(arbMetni('gezinme_sekme_bildirimler')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/bildirimler',
    );
  });

  testWidgets('okunmamış rozeti 0 iken gizli, sayı varken etiketli', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(
      tester,
      overrides: [
        okunmamisSohbetSayisiProvider.overrideWithValue(3),
        okunmamisBildirimSayisiProvider.overrideWithValue(150),
      ],
    );

    expect(find.byType(Badge), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(find.text(arbMetni('gezinme_rozet_cok')), findsOneWidget);
    // Rozetteki sayı yerine ekran okuyucuya açıklayıcı etiket verilir.
    expect(_semantikEtiketi('3 okunmamış mesaj'), findsOneWidget);
    expect(_semantikEtiketi('150 okunmamış bildirim'), findsOneWidget);
  });

  testWidgets('okunmamış yokken rozet gösterilmiyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('oturum kapanınca giriş ekranına yönleniyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    tester
        .container()
        .read(oturumDurumuProvider.notifier)
        .ayarla(OturumDurumu.girisYok);
    await tester.pumpAndSettle();

    expect(find.byType(GirisEkrani), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/giris',
    );
  });

  testWidgets('bilinmeyen adres "bulunamadı" sayfasını gösteriyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);

    yonlendiriciyiAl(tester).go('/boyle-bir-sayfa-yok');
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('gezinme_bulunamadi_baslik')), findsOneWidget);

    await tester.tap(find.text(arbMetni('gezinme_ana_sayfaya_don')));
    await tester.pumpAndSettle();
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazı ölçeğinde kabuk taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      ikiKatYazi(tester);
      await uygulamayiAc(
        tester,
        themeMode: mod,
        overrides: [
          okunmamisSohbetSayisiProvider.overrideWithValue(12),
          ..._profilSahteleri(),
        ],
      );
      expect(tester.takeException(), isNull);

      for (final anahtar in [
        'gezinme_sekme_sohbet',
        'gezinme_sekme_bildirimler',
        'gezinme_sekme_profil',
      ]) {
        await tester.tap(_sekme(anahtar));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: anahtar);
      }
    });

    testWidgets('${mod.name} temada 2× yazıda dikey çubuk taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 800, yukseklik: 600);
      ikiKatYazi(tester);
      await uygulamayiAc(tester, themeMode: mod);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
