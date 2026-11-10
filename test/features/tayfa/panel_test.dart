import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const String _bekleyenId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

Finder get _adDugmesi => find
    .descendant(
      of: find.byType(TayfaUstBolumu),
      matching: find.byType(TextButton),
    )
    .first;

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('etkin tayfalar ve "Onay bekliyor" etiketli istek listede', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => listeJson([
        etkinJson(ornekTayfaId, ad: 'Klasikçiler'),
        bekleyenJson(_bekleyenId, ad: 'Kampçılar'),
        etkinJson(ikinciTayfaId, ad: 'Balıkçılar'),
      ]),
    });
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: tasima));
    expect(_yol(tester), '/t/$ornekTayfaId');

    await tester.tap(_adDugmesi);
    await tester.pumpAndSettle();

    final panel = find.byType(TayfaDegistirmePaneli);
    for (final ad in ['Klasikçiler', 'Kampçılar', 'Balıkçılar']) {
      expect(
        find.descendant(of: panel, matching: find.text(ad)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: panel, matching: find.byType(Etiket)),
      findsOneWidget,
    );
    expect(find.text(arbMetni('tayfa_onay_bekliyor')), findsOneWidget);
    // Aktif tayfa işaretli; ekran okuyucu "Seçili tayfa" der.
    expect(
      find.byWidgetPredicate(
        (w) => w is Icon && w.semanticLabel == arbMetni('tayfa_secili'),
      ),
      findsOneWidget,
    );
    expect(find.text(arbMetni('tayfa_tayfalarim_bos')), findsNothing);
  });

  testWidgets('etkin tayfaya dokununca aktif tayfa ve adres değişiyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => listeJson([
        etkinJson(ornekTayfaId, ad: 'Klasikçiler'),
        etkinJson(ikinciTayfaId, ad: 'Balıkçılar'),
      ]),
    });
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: tasima));

    await tester.tap(_adDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(TayfaDegistirmePaneli),
        matching: find.text('Balıkçılar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TayfaDegistirmePaneli), findsNothing);
    expect(tester.container().read(aktifTayfaIdProvider), ikinciTayfaId);
    expect(_yol(tester), '/t/$ikinciTayfaId');
  });

  testWidgets('bekleyen istek onayla geri çekiliyor', (tester) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? listeJson([
              etkinJson(ornekTayfaId),
              bekleyenJson(_bekleyenId, ad: 'Kampçılar'),
            ])
          : listeJson([etkinJson(ornekTayfaId)]),
      'DELETE /v1/tayfas/{tayfa_id}/membership': (_) => null,
    });
    await uygulamayiAc(tester, tayfa: tayfaOverridelari(tasima: tasima));

    await tester.tap(_adDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kampçılar'));
    await tester.pumpAndSettle();

    // Önce vazgeç: istek gitmez.
    expect(find.text(arbMetni('tayfa_geri_cek_baslik')), findsOneWidget);
    await tester.tap(find.text(arbMetni('tayfa_vazgec')));
    await tester.pumpAndSettle();
    expect(tasima.giden('DELETE', '/v1/tayfas/{tayfa_id}/membership'), isEmpty);

    await tester.tap(find.text('Kampçılar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('tayfa_geri_cek_onayla')));
    await tester.pumpAndSettle();

    final silme = tasima.giden('DELETE', '/v1/tayfas/{tayfa_id}/membership');
    expect(silme.single.yolParametreleri['tayfa_id'], _bekleyenId);
    expect(find.text('Kampçılar'), findsNothing);
    expect(find.text(arbMetni('tayfa_geri_cekildi')), findsOneWidget);
  });

  testWidgets('liste alınamazsa panelde hata ve "Tekrar dene"', (tester) async {
    ekranBoyutu(tester);
    var cagri = 0;
    final tasima = SahteTayfaTasima({
      'GET /v1/tayfas': (_) => cagri++ == 0
          ? const ApiOffline()
          : listeJson([etkinJson(ornekTayfaId, ad: 'Klasikçiler')]),
    });
    await widgetAc(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => unawaited(tayfaDegistirmePaneliniAc(context)),
            child: const Text('ac'),
          ),
        ),
      ),
      tayfa: tayfaOverridelari(tasima: tasima),
      overrides: [
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
      ],
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    expect(find.byType(HataSatiri), findsOneWidget);
    await tester.tap(find.text(arbMetni('tayfa_tekrar_dene')));
    await tester.pumpAndSettle();

    expect(find.text('Klasikçiler'), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda dolu panel taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final tasima = SahteTayfaTasima({
        'GET /v1/tayfas': (_) => listeJson([
          etkinJson(ornekTayfaId, ad: 'Çok uzun adlı klasik otomobil tayfası'),
          etkinJson(ikinciTayfaId, ad: 'Balıkçılar'),
          bekleyenJson(_bekleyenId, ad: 'Kamp ve doğa yürüyüşü tayfası'),
        ]),
      });
      await uygulamayiAc(
        tester,
        themeMode: mod,
        tayfa: tayfaOverridelari(tasima: tasima),
      );

      await tester.tap(_adDugmesi);
      await tester.pumpAndSettle();
      expect(find.byType(TayfaDegistirmePaneli), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
