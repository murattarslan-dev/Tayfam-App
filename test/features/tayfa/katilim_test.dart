import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/presentation/kodla_katilma_sayfasi.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _bekleyenId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

/// Karşılamadan katılım sayfasını açar.
Future<SahteTayfaTasima> _ac(
  WidgetTester tester,
  Map<String, TayfaYaniti> yanitlar, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final tasima = SahteTayfaTasima(yanitlar);
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: tayfaOverridelari(tasima: tasima),
  );
  await tester.ensureVisible(find.text(arbMetni('karsilama_kodum_var')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(arbMetni('karsilama_kodum_var')));
  await tester.pumpAndSettle();
  expect(find.byType(KodlaKatilmaSayfasi), findsOneWidget);
  return tasima;
}

Future<void> _gonder(WidgetTester tester, String kod) async {
  await tester.enterText(find.byType(TextField), kod);
  await tester.ensureVisible(find.text(arbMetni('katilim_gonder')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(arbMetni('katilim_gonder')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('açık tayfa: sayfa kapanıyor, tayfanın ana sayfası açılıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = await _ac(tester, {
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? listeJson(const [])
          : listeJson([etkinJson(ornekTayfaId, ad: 'Klasikçiler')]),
      'POST /v1/tayfa-joins': (_) => uyelikJson(ornekTayfaId),
    });

    await _gonder(tester, '  $sahteKod ');

    expect(tasima.giden('POST', '/v1/tayfa-joins').single.govde, {
      'code': sahteKod,
    });
    expect(find.byType(KodlaKatilmaSayfasi), findsNothing);
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
    expect(_yol(tester), '/t/$ornekTayfaId');
    expect(tester.container().read(aktifTayfaIdProvider), ornekTayfaId);
  });

  testWidgets('onaylı tayfa: "İsteğin gönderildi", karşılamada kart', (
    tester,
  ) async {
    ekranBoyutu(tester);
    var cagri = 0;
    await _ac(tester, {
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? listeJson(const [])
          : listeJson([bekleyenJson(_bekleyenId, ad: 'Kampçılar')]),
      'POST /v1/tayfa-joins': (_) => uyelikJson(_bekleyenId, durum: 'pending'),
    });

    await _gonder(tester, sahteKod);

    expect(find.text(arbMetni('katilim_gonderildi_baslik')), findsOneWidget);
    await tester.tap(find.text(arbMetni('katilim_tamam')));
    await tester.pumpAndSettle();

    expect(find.byType(KodlaKatilmaSayfasi), findsNothing);
    expect(find.byType(KarsilamaEkrani), findsOneWidget);
    expect(find.byType(BekleyenIstekKarti), findsOneWidget);
  });

  testWidgets('boş kodda alan hatası, istek yok', (tester) async {
    ekranBoyutu(tester);
    final tasima = await _ac(tester, {});

    await _gonder(tester, '   ');

    expect(find.text(arbMetni('katilim_kod_hata')), findsOneWidget);
    expect(tasima.giden('POST', '/v1/tayfa-joins'), isEmpty);
  });

  testWidgets('kod alanı en çok 32 karakter', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, {});

    final alan = tester.widget<TextField>(find.byType(TextField));
    expect(alan.maxLength, 32);
  });

  for (final (tur, anahtar) in [
    (ProblemType.invalidJoinCode, 'hata_invalid_join_code'),
    (ProblemType.rateLimited, 'hata_rate_limited'),
  ]) {
    testWidgets('${tur.name}: ortak hata metni, sayfa açık', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, {
        'POST /v1/tayfa-joins': (_) => ApiProblem(type: tur, status: 400),
      });

      await _gonder(tester, sahteKod);

      expect(find.byType(KodlaKatilmaSayfasi), findsOneWidget);
      expect(find.byType(HataSatiri), findsOneWidget);
      expect(find.text(arbMetni(anahtar)), findsOneWidget);
    });
  }

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda sayfa taşmıyor', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, {
        'POST /v1/tayfa-joins': (_) =>
            const ApiProblem(type: ProblemType.invalidJoinCode, status: 404),
      }, themeMode: mod);
      expect(tester.takeException(), isNull);

      await _gonder(tester, sahteKod);
      expect(find.byType(HataSatiri), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${mod.name} temada 2× yazıda gönderildi ekranı', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, {
        'POST /v1/tayfa-joins': (_) =>
            uyelikJson(_bekleyenId, durum: 'pending'),
      }, themeMode: mod);

      await _gonder(tester, sahteKod);
      expect(find.text(arbMetni('katilim_gonderildi_baslik')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
