import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/shell/derin_link/derin_link_rotalari.dart';

import '../../features/hesap/sahteler.dart';
import '../../yardimcilar.dart';

const String _kod = 'TYF-8K2M4Q';

Future<SahteOturum> _ac(WidgetTester tester, String link) async {
  tester.platformDispatcher.defaultRouteNameTestValue = link;
  addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
  final oturum = SahteOturum();
  await uygulamayiAc(
    tester,
    oturum: OturumDurumu.kayitBekliyor,
    overrides: hesapOverridelari(
      tasima: SahteTasima({'GET /v1/registration/requirements': surumGovdesi}),
      oturum: oturum,
    ),
  );
  return oturum;
}

String? _referansAlani(WidgetTester tester) {
  final alan = find.widgetWithText(TextField, arbMetni('hesap_kayit_referans'));
  if (alan.evaluate().isEmpty) return null;
  return tester.widget<TextField>(alan).controller?.text;
}

void main() {
  testWidgets('referans linki kayıt formundaki kodu dolduruyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester, 'https://tayfam.app/r/$_kod');

    expect(find.byType(KayitEkrani), findsOneWidget);
    expect(_referansAlani(tester), _kod);
    expect(
      yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
      '/kayit',
    );
  });

  testWidgets('kayıt bitince (oturum açık) kod bırakılıyor', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, 'https://tayfam.app/r/$_kod');
    final kutu = tester.container().read(derinLinkKutusuProvider);
    expect(kutu.referansKodu, _kod);

    tester
        .container()
        .read(oturumDurumuProvider.notifier)
        .ayarla(OturumDurumu.acik);
    await tester.pumpAndSettle();

    expect(kutu.referansKodu, isNull);
  });

  testWidgets('bozuk referans linki formu doldurmuyor', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, 'https://tayfam.app/r/0000');

    expect(find.byType(KayitEkrani), findsOneWidget);
    expect(_referansAlani(tester), isEmpty);
  });
}
