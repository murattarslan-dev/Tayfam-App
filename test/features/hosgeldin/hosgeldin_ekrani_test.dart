import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/cihaz/cihaz_ayarlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/hosgeldin/hosgeldin.dart';

import '../../yardimcilar.dart';

const List<String> _basliklar = [
  'hosgeldin_tayfa_baslik',
  'hosgeldin_etkinlik_baslik',
  'hosgeldin_soru_baslik',
  'hosgeldin_sohbet_baslik',
  'hosgeldin_katil_baslik',
];

const List<String> _metinler = [
  'hosgeldin_tayfa_metin',
  'hosgeldin_etkinlik_metin',
  'hosgeldin_soru_metin',
  'hosgeldin_sohbet_metin',
  'hosgeldin_katil_metin',
];

String _sayfaEtiketi(int sayfa) {
  final kalip = arbMetni('hosgeldin_sayfa');
  final sayfali = kalip.replaceAll('{sayfa}', '$sayfa');
  return sayfali.replaceAll('{toplam}', '${_basliklar.length}');
}

Finder get _ileri => find.text(arbMetni('hosgeldin_ileri'));

Finder get _atla => find.text(arbMetni('hosgeldin_atla'));

Finder get _baslayalim => find.text(arbMetni('hosgeldin_baslayalim'));

double? _sayfaKonumu(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller!.page;

Future<void> _ekraniAc(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await widgetAc(
    tester,
    const HosGeldinEkrani(),
    themeMode: themeMode,
    overrides: [
      cihazAyarlariDeposuProvider.overrideWithValue(
        BellekCihazAyarlariDeposu(),
      ),
    ],
  );
}

void main() {
  test('beş sayfa var, sırası ADR-0017 §2 ile aynı', () {
    expect(tanitimSayfalari, hasLength(5));
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 320 px, 2× yazıda her sayfa taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ekraniAc(tester, themeMode: mod);

      for (var i = 0; i < _basliklar.length; i++) {
        expect(find.text(arbMetni(_basliklar[i])), findsOneWidget);
        expect(find.text(arbMetni(_metinler[i])), findsOneWidget);
        expect(_atla, findsOneWidget, reason: 'Her sayfada "Atla" var.');
        final son = i == _basliklar.length - 1;
        expect(_ileri, son ? findsNothing : findsOneWidget);
        expect(_baslayalim, son ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
        if (!son) {
          await tester.tap(_ileri);
          await tester.pumpAndSettle();
        }
      }

      final context = tester.element(find.byType(HosGeldinEkrani));
      expect(
        Theme.of(context).brightness,
        mod == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
    });
  }

  testWidgets('kaydırmayla da sayfa geçiyor', (tester) async {
    ekranBoyutu(tester);
    await _ekraniAc(tester);

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(arbMetni(_basliklar[1])), findsOneWidget);
  });

  testWidgets('ekran okuyucu "Sayfa n / 5" okuyor, görseller gizli', (
    tester,
  ) async {
    final semantik = tester.ensureSemantics();
    ekranBoyutu(tester);
    await _ekraniAc(tester);

    expect(find.bySemanticsLabel(_sayfaEtiketi(1)), findsOneWidget);
    // Görsel süstür: ekranda var, ekran okuyucuda yok.
    final ornek = arbMetni('hosgeldin_ornek_tayfa_adi');
    expect(find.text(ornek), findsOneWidget);
    expect(find.bySemanticsLabel(ornek), findsNothing);

    await tester.tap(_ileri);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(_sayfaEtiketi(2)), findsOneWidget);
    final balon = arbMetni('hosgeldin_ornek_etkinlik_basligi');
    expect(find.text(balon), findsOneWidget);
    expect(find.bySemanticsLabel(balon), findsNothing);
    // Görseldeki "Geldim" düğmesi ekran okuyucuya düğme olarak görünmüyor.
    expect(
      find.bySemanticsLabel(arbMetni('etkinlik_varis_geldim')),
      findsNothing,
    );
    semantik.dispose();
  });

  testWidgets('"Hareketi azalt" açıkken İleri animasyonsuz geçiyor', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    ekranBoyutu(tester);
    await _ekraniAc(tester);

    await tester.tap(_ileri);
    await tester.pump();
    expect(_sayfaKonumu(tester), 1);
  });

  testWidgets('İleri animasyonla geçiyor', (tester) async {
    ekranBoyutu(tester);
    await _ekraniAc(tester);

    await tester.tap(_ileri);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_sayfaKonumu(tester), allOf(greaterThan(0), lessThan(1)));
    await tester.pumpAndSettle();
    expect(_sayfaKonumu(tester), 1);
  });

  testWidgets('geri tuşu bir önceki sayfaya dönüyor', (tester) async {
    ekranBoyutu(tester);
    await _ekraniAc(tester);
    await tester.tap(_ileri);
    await tester.pumpAndSettle();
    await tester.tap(_ileri);
    await tester.pumpAndSettle();
    expect(_sayfaKonumu(tester), 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_sayfaKonumu(tester), 1);
    expect(find.text(arbMetni(_basliklar[1])), findsOneWidget);
  });

  group('uygulamanın içinde (yönlendirmeyle)', () {
    Uri konum(WidgetTester tester) =>
        yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri;

    Future<BellekCihazAyarlariDeposu> ac(
      WidgetTester tester, {
      OturumDurumu oturum = OturumDurumu.girisYok,
      Set<CihazBayragi> bayraklar = const {},
    }) async {
      final depo = BellekCihazAyarlariDeposu(bayraklar);
      ekranBoyutu(tester);
      await uygulamayiAc(
        tester,
        oturum: oturum,
        tanitim: null,
        cihazAyarlari: depo,
      );
      return depo;
    }

    testWidgets('ilk açılışta girişten önce tanıtım', (tester) async {
      await ac(tester);
      expect(find.byType(HosGeldinEkrani), findsOneWidget);
      expect(find.byType(GirisEkrani), findsNothing);
      expect(konum(tester).path, '/hos-geldin');
    });

    testWidgets('Atla bayrağı koyup girişe geçiyor', (tester) async {
      final depo = await ac(tester);
      await tester.tap(_atla);
      await tester.pumpAndSettle();

      expect(find.byType(GirisEkrani), findsOneWidget);
      expect(konum(tester).path, '/giris');
      expect(depo.konmuslar, {CihazBayragi.tanitimGosterildi});
    });

    testWidgets('Başlayalım bayrağı koyup girişe geçiyor', (tester) async {
      final depo = await ac(tester);
      for (var i = 0; i < _basliklar.length - 1; i++) {
        await tester.tap(_ileri);
        await tester.pumpAndSettle();
      }
      expect(depo.konmuslar, isEmpty);
      await tester.tap(_baslayalim);
      await tester.pumpAndSettle();

      expect(find.byType(GirisEkrani), findsOneWidget);
      expect(konum(tester).path, '/giris');
      expect(depo.konmuslar, {CihazBayragi.tanitimGosterildi});
    });

    testWidgets('ikinci açılışta tanıtım atlanıyor', (tester) async {
      await ac(tester, bayraklar: {CihazBayragi.tanitimGosterildi});
      expect(find.byType(HosGeldinEkrani), findsNothing);
      expect(find.byType(GirisEkrani), findsOneWidget);
    });

    testWidgets('oturum kapanınca bayrak kalıyor, tanıtım dönmüyor', (
      tester,
    ) async {
      final depo = await ac(
        tester,
        oturum: OturumDurumu.acik,
        bayraklar: {CihazBayragi.tanitimGosterildi},
      );
      tester
          .container()
          .read(oturumDurumuProvider.notifier)
          .ayarla(OturumDurumu.girisYok);
      await tester.pumpAndSettle();

      expect(find.byType(GirisEkrani), findsOneWidget);
      expect(find.byType(HosGeldinEkrani), findsNothing);
      expect(depo.konmuslar, {CihazBayragi.tanitimGosterildi});
    });

    testWidgets('tanıtım bitince korunan hedef yoldan geçiliyor', (
      tester,
    ) async {
      await ac(tester);
      yonlendiriciyiAl(tester).go('/profil');
      await tester.pumpAndSettle();
      expect(konum(tester).queryParameters['hedef'], '/profil');

      await tester.tap(_atla);
      await tester.pumpAndSettle();
      // Oturum yok: korumalar hedefi girişe çeviriyor.
      expect(konum(tester).path, '/giris');
    });
  });
}
