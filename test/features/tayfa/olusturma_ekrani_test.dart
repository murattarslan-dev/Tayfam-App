import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/hata_satiri.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _yeniId = '1f2e3d4c-5b6a-4978-8a6b-5c4d3e2f1a0b';

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

/// Karşılamadan sihirbazı açar.
Future<SahteTayfaTasima> _ac(
  WidgetTester tester, [
  Map<String, TayfaYaniti>? yanitlar,
  ThemeMode themeMode = ThemeMode.light,
]) async {
  final tasima = SahteTayfaTasima(yanitlar);
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: tayfaOverridelari(tasima: tasima),
  );
  await tester.ensureVisible(find.text(arbMetni('karsilama_tayfa_olustur')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(arbMetni('karsilama_tayfa_olustur')));
  await tester.pumpAndSettle();
  expect(find.byType(OlusturmaEkrani), findsOneWidget);
  return tasima;
}

Future<void> _dokun(WidgetTester tester, String anahtar) async {
  await tester.ensureVisible(find.text(arbMetni(anahtar)));
  await tester.tap(find.text(arbMetni(anahtar)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adım adım oluşturma; tayfa açılıyor, davet kısayolu var', (
    tester,
  ) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = await _ac(tester, {
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? listeJson(const [])
          : listeJson([etkinJson(_yeniId, rol: 'admin', kod: sahteKod)]),
      'POST /v1/tayfas': (_) => tayfaJson(id: _yeniId, kod: sahteKod),
      'GET /v1/tayfas/{tayfa_id}': (_) =>
          gorunumJson(_yeniId, rol: 'admin', kod: sahteKod),
    });

    expect(find.text('Adım 1 / 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Klasikçiler');
    await _dokun(tester, 'olusturma_ileri');

    expect(find.text('Adım 2 / 3'), findsOneWidget);
    await _dokun(tester, 'tayfa_tur_convoy');
    await _dokun(tester, 'tayfa_tur_camp');
    final cip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, arbMetni('tayfa_tur_convoy')),
    );
    expect(cip.selected, isTrue);
    await _dokun(tester, 'olusturma_ileri');

    expect(find.text('Adım 3 / 3'), findsOneWidget);
    await _dokun(tester, 'olusturma_acik');
    await tester.enterText(find.byType(TextField), 'Hafta sonu turları');
    await _dokun(tester, 'olusturma_gonder');

    final govde =
        tasima.giden('POST', '/v1/tayfas').single.govde!
            as Map<String, Object?>;
    expect(govde, {
      'name': 'Klasikçiler',
      'description': 'Hafta sonu turları',
      'interests': ['convoy', 'camp'],
      'join_policy': 'open',
      'client_request_id': sahteIstekKimligi,
    });
    expect(find.byType(OlusturmaEkrani), findsNothing);
    expect(_yol(tester), '/t/$_yeniId');
    expect(tester.container().read(aktifTayfaIdProvider), _yeniId);
    expect(find.byType(DavetKisayolu), findsOneWidget);
  });

  testWidgets('geçersiz adda hata; geri gelince girilenler yerinde', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester);

    await tester.enterText(find.byType(TextField), 'ab');
    await _dokun(tester, 'olusturma_ileri');
    expect(find.text(arbMetni('olusturma_ad_hata')), findsOneWidget);
    expect(find.text('Adım 1 / 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Klasikçiler');
    await _dokun(tester, 'olusturma_ileri');
    await _dokun(tester, 'tayfa_tur_hike');
    await _dokun(tester, 'olusturma_ileri');
    await tester.enterText(find.byType(TextField), 'Açıklama');

    // Android geri tuşu önce önceki adıma döner.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Adım 2 / 3'), findsOneWidget);
    final cip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, arbMetni('tayfa_tur_hike')),
    );
    expect(cip.selected, isTrue);

    await _dokun(tester, 'olusturma_geri');
    expect(find.widgetWithText(TextField, 'Klasikçiler'), findsOneWidget);

    await _dokun(tester, 'olusturma_ileri');
    await _dokun(tester, 'olusturma_ileri');
    expect(find.widgetWithText(TextField, 'Açıklama'), findsOneWidget);
  });

  testWidgets('oluşturma sınırı: ortak bekleme metni; aynı id ile tekrar', (
    tester,
  ) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = await _ac(tester, {
      'POST /v1/tayfas': (_) => cagri++ == 0
          ? const ApiProblem(type: ProblemType.tayfaCreateLimit, status: 429)
          : tayfaJson(id: _yeniId, kod: sahteKod),
    });
    // Oluşturmadan sonraki yenilemede sunucu yeni tayfayı döndürür.
    tasima.yanitlar['GET /v1/tayfas'] = (_) =>
        listeJson([etkinJson(_yeniId, rol: 'admin', kod: sahteKod)]);
    await tester.enterText(find.byType(TextField), 'Klasikçiler');
    await _dokun(tester, 'olusturma_ileri');
    await _dokun(tester, 'olusturma_ileri');

    await _dokun(tester, 'olusturma_gonder');
    expect(find.byType(HataSatiri), findsOneWidget);
    expect(find.text(arbMetni('hata_tayfa_create_limit')), findsOneWidget);
    expect(find.byType(OlusturmaEkrani), findsOneWidget);

    await _dokun(tester, 'olusturma_gonder');
    final istekler = tasima.giden('POST', '/v1/tayfas');
    expect(istekler, hasLength(2));
    expect(
      istekler.map(
        (i) => (i.govde! as Map<String, Object?>)['client_request_id'],
      ),
      [sahteIstekKimligi, sahteIstekKimligi],
    );
    expect(_yol(tester), '/t/$_yeniId');
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda üç adım da taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, null, mod);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Klasikçiler');
      await _dokun(tester, 'olusturma_ileri');
      expect(find.byType(FilterChip), findsNWidgets(7));
      expect(tester.takeException(), isNull);

      await _dokun(tester, 'tayfa_tur_gaming');
      await _dokun(tester, 'olusturma_ileri');
      expect(find.text(arbMetni('olusturma_onayli')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
