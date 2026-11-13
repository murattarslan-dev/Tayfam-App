import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/presentation/kuruldu_ekrani.dart';
import 'package:tayfam/features/tayfa/presentation/olusturma_ekrani.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _yeniId = '1f2e3d4c-5b6a-4978-8a6b-5c4d3e2f1a0b';

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

/// "Tayfa kuruldu" ekranının başlığı.
String _kurulduBasligi(String ad) =>
    arbMetni('kuruldu_baslik').replaceAll('{ad}', ad);

/// Karşılamadan sihirbazı açar.
Future<SahteTayfaTasima> _ac(
  WidgetTester tester, {
  Map<String, TayfaYaniti>? yanitlar,
  ThemeMode themeMode = ThemeMode.light,
  SahtePaylasici? paylasici,
  List<Override> overrides = const [],
}) async {
  final tasima = SahteTayfaTasima(yanitlar);
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: tayfaOverridelari(tasima: tasima, paylasici: paylasici),
    overrides: overrides,
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

/// [anahtar] türünün ilgi kartındaki onay kutusu.
Checkbox _onayKutusu(WidgetTester tester, String anahtar) =>
    tester.widget<Checkbox>(
      find.descendant(
        of: find.widgetWithText(IlgiKarti, arbMetni(anahtar)),
        matching: find.byType(Checkbox),
      ),
    );

/// Başarılı oluşturma ve ardından yeni tayfayı döndüren liste yanıtları.
Map<String, TayfaYaniti> _basariliYanitlar() {
  var cagri = 0;
  return {
    'GET /v1/tayfas': (_) => cagri++ == 0
        ? listeJson(const [])
        : listeJson([etkinJson(_yeniId, rol: 'admin', kod: sahteKod)]),
    'POST /v1/tayfas': (_) => tayfaJson(id: _yeniId, kod: sahteKod),
    'GET /v1/tayfas/{tayfa_id}': (_) =>
        gorunumJson(_yeniId, rol: 'admin', kod: sahteKod),
  };
}

/// Ad girer ve iki adım ilerleyip son adıma gelir.
Future<void> _sonAdima(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'Klasikçiler');
  await _dokun(tester, 'olusturma_ileri');
  await _dokun(tester, 'olusturma_ileri');
}

void main() {
  testWidgets('adım adım oluşturma; "Tayfa kuruldu" ekranı ve tayfaya git', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final paylasici = SahtePaylasici();
    final tasima = await _ac(
      tester,
      yanitlar: _basariliYanitlar(),
      paylasici: paylasici,
    );

    expect(find.text(arbMetni('olusturma_baslik')), findsOneWidget);
    expect(find.text('Adım 1 / 3'), findsOneWidget);
    // İlk adımda "Geri" yok.
    expect(find.text(arbMetni('olusturma_geri')), findsNothing);
    await tester.enterText(find.byType(TextField), 'Klasikçiler');
    await tester.pump();
    expect(find.text(arbMetni('olusturma_onizleme_ad')), findsOneWidget);
    await _dokun(tester, 'olusturma_ileri');

    expect(find.text('Adım 2 / 3'), findsOneWidget);
    expect(find.byType(IlgiKarti), findsNWidgets(7));
    await _dokun(tester, 'etkinlik_turu_convoy');
    await _dokun(tester, 'etkinlik_turu_camp');
    expect(_onayKutusu(tester, 'etkinlik_turu_convoy').value, isTrue);
    expect(_onayKutusu(tester, 'etkinlik_turu_hike').value, isFalse);
    expect(find.text(arbMetni('olusturma_onizleme_ilgi')), findsOneWidget);
    await _dokun(tester, 'olusturma_ileri');

    expect(find.text('Adım 3 / 3'), findsOneWidget);
    // Onaylı varsayılan ve "Önerilen" etiketli; altta kurallar.
    expect(find.text(arbMetni('olusturma_onerilen')), findsOneWidget);
    expect(find.text(arbMetni('olusturma_kurallar')), findsOneWidget);
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
    expect(tester.container().read(aktifTayfaIdProvider), _yeniId);

    // Sihirbazın yerine "Tayfa kuruldu" ekranı; oluşturma yanıtıyla
    // çizilir.
    expect(find.byType(TayfaKurulduEkrani), findsOneWidget);
    expect(find.text(_kurulduBasligi('Klasikçiler')), findsOneWidget);
    expect(find.text(sahteKod), findsOneWidget);
    // Davet akışı kayıtlı değilse davet düğmesi yok.
    expect(find.text(arbMetni('kuruldu_davet')), findsNothing);

    await _dokun(tester, 'kuruldu_kopyala');
    expect(paylasici.kopyalanan, [sahteKod]);

    await _dokun(tester, 'kuruldu_tayfaya_git');
    expect(find.byType(TayfaKurulduEkrani), findsNothing);
    expect(find.byType(OlusturmaEkrani), findsNothing);
    expect(_yol(tester), '/t/$_yeniId');
    // Ana sayfada kurulum adımları (ADR-0015 Notlar 2026-11-13).
    expect(find.byType(TayfaKurulumKarti), findsOneWidget);
  });

  testWidgets('kuruldu: davet linki akışı açılıyor; geri ana sayfaya', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final davetler = <String>[];
    await _ac(
      tester,
      yanitlar: _basariliYanitlar(),
      overrides: [
        tayfaDavetiProvider.overrideWithValue((_, tayfaId) async {
          davetler.add(tayfaId);
        }),
      ],
    );
    await _sonAdima(tester);
    await _dokun(tester, 'olusturma_gonder');
    expect(find.byType(TayfaKurulduEkrani), findsOneWidget);

    await _dokun(tester, 'kuruldu_davet');
    expect(davetler, [_yeniId]);

    // Sistem geri tuşu sihirbaza değil ana sayfaya gider.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TayfaKurulduEkrani), findsNothing);
    expect(find.byType(OlusturmaEkrani), findsNothing);
    expect(_yol(tester), '/t/$_yeniId');
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
    await _dokun(tester, 'etkinlik_turu_hike');
    await _dokun(tester, 'olusturma_ileri');
    await tester.enterText(find.byType(TextField), 'Açıklama');

    // Android geri tuşu önce önceki adıma döner.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Adım 2 / 3'), findsOneWidget);
    expect(_onayKutusu(tester, 'etkinlik_turu_hike').value, isTrue);

    await _dokun(tester, 'olusturma_geri');
    expect(find.widgetWithText(TextField, 'Klasikçiler'), findsOneWidget);

    await _dokun(tester, 'olusturma_ileri');
    await _dokun(tester, 'olusturma_ileri');
    expect(find.widgetWithText(TextField, 'Açıklama'), findsOneWidget);
  });

  testWidgets('örnek ad çipi alana yazılıyor', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester);

    await _dokun(tester, 'olusturma_ornek_kamp');
    expect(
      find.widgetWithText(TextField, arbMetni('olusturma_ornek_kamp')),
      findsOneWidget,
    );
    await _dokun(tester, 'olusturma_ileri');
    expect(find.text('Adım 2 / 3'), findsOneWidget);
  });

  testWidgets('girilen varken X vazgeç onayı soruyor; boşken kapanıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester);

    await tester.enterText(find.byType(TextField), 'Klasikçiler');
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('olusturma_vazgec_baslik')), findsOneWidget);

    await _dokun(tester, 'olusturma_vazgec_devam');
    expect(find.byType(OlusturmaEkrani), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Klasikçiler'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await _dokun(tester, 'olusturma_vazgec');
    expect(find.byType(OlusturmaEkrani), findsNothing);

    // Yeniden açılan sihirbaz boştur; X onaysız kapanır.
    await _dokun(tester, 'karsilama_tayfa_olustur');
    expect(find.byType(OlusturmaEkrani), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('olusturma_vazgec_baslik')), findsNothing);
    expect(find.byType(OlusturmaEkrani), findsNothing);
  });

  testWidgets('günlük sınır: tint-nar kutu; girilenler duruyor, aynı id', (
    tester,
  ) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = await _ac(
      tester,
      yanitlar: {
        'POST /v1/tayfas': (_) => cagri++ == 0
            ? const ApiProblem(type: ProblemType.tayfaCreateLimit, status: 429)
            : tayfaJson(id: _yeniId, kod: sahteKod),
      },
    );
    // Oluşturmadan sonraki yenilemede sunucu yeni tayfayı döndürür.
    tasima.yanitlar['GET /v1/tayfas'] = (_) =>
        listeJson([etkinJson(_yeniId, rol: 'admin', kod: sahteKod)]);
    await _sonAdima(tester);
    await tester.enterText(find.byType(TextField), 'Kamp tayfası');

    await _dokun(tester, 'olusturma_gonder');
    expect(
      find.textContaining(arbMetni('olusturma_sinir_baslik')),
      findsOneWidget,
    );
    expect(
      find.textContaining(arbMetni('olusturma_sinir_metni')),
      findsOneWidget,
    );
    expect(find.text('Adım 3 / 3'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kamp tayfası'), findsOneWidget);

    await _dokun(tester, 'olusturma_gonder');
    final istekler = tasima.giden('POST', '/v1/tayfas');
    expect(istekler, hasLength(2));
    expect(
      istekler.map(
        (i) => (i.govde! as Map<String, Object?>)['client_request_id'],
      ),
      [sahteIstekKimligi, sahteIstekKimligi],
    );
    expect(find.byType(TayfaKurulduEkrani), findsOneWidget);
  });

  testWidgets('hız sınırı da tint-nar kutuda', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      yanitlar: {
        'POST /v1/tayfas': (_) =>
            const ApiProblem(type: ProblemType.rateLimited, status: 429),
      },
    );
    await _sonAdima(tester);
    await _dokun(tester, 'olusturma_gonder');
    expect(find.textContaining(arbMetni('hata_rate_limited')), findsOneWidget);
    expect(
      find.textContaining(arbMetni('olusturma_girilenler_duruyor')),
      findsOneWidget,
    );
    expect(find.byType(OlusturmaEkrani), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda adımlar ve kuruldu taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, yanitlar: _basariliYanitlar(), themeMode: mod);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'Klasikçiler');
      await _dokun(tester, 'olusturma_ileri');
      expect(find.byType(IlgiKarti), findsNWidgets(7));
      expect(tester.takeException(), isNull);

      await _dokun(tester, 'etkinlik_turu_gaming');
      await _dokun(tester, 'olusturma_ileri');
      expect(find.text(arbMetni('olusturma_onayli')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _dokun(tester, 'olusturma_gonder');
      expect(find.byType(TayfaKurulduEkrani), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
