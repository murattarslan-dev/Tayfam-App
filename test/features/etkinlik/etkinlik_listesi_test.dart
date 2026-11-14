import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';

import '../../yardimcilar.dart';
import '../duyuru/sahteler.dart';

void main() {
  test('yaklaşan etkinlikler sayfalı okunuyor', () async {
    final tasima = modulTasimasi({
      'GET $etkinliklerYolu': (i) => switch (i.sorgu['page_token']) {
        null => etkinlikListesiJson([
          etkinlikJson(etkinlikId1),
        ], sonraki: 'opak-1'),
        _ => etkinlikListesiJson([
          etkinlikJson(etkinlikId2, baslangic: '2026-11-15T06:00:00Z'),
        ]),
      },
    });
    final kap = ProviderContainer.test(overrides: modulOverridelari(tasima));
    final saglayici = etkinlikListesiProvider(ornekTayfaId);
    kap.listen(saglayici, (_, _) {});

    await kap.read(saglayici.future);
    await kap.read(saglayici.notifier).dahaFazla();

    final liste = kap.read(saglayici).requireValue;
    expect(liste.ogeler.map((e) => e.id), [etkinlikId1, etkinlikId2]);
    expect(liste.dahaVar, isFalse);
    final istekler = tasima.giden('GET', etkinliklerYolu);
    expect(istekler.map((i) => i.sorgu['page_token']), [null, 'opak-1']);
    expect(istekler.first.yolParametreleri['tayfa_id'], ornekTayfaId);
    expect(istekler.first.sorgu['page_size'], '20');
  });

  testWidgets('liste ekranı: kartlar ve boş durum', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const EtkinliklerEkrani(tayfaId: ornekTayfaId),
      tayfa: modulOverridelari(modulTasimasi()),
    );

    expect(find.text(arbMetni('tayfa_ana_etkinlikler_bos')), findsOneWidget);
  });

  testWidgets('liste ekranı: hata HataSatiri ile', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const EtkinliklerEkrani(tayfaId: ornekTayfaId),
      tayfa: modulOverridelari(
        modulTasimasi({'GET $etkinliklerYolu': yanit(const ApiOffline())}),
      ),
    );

    expect(find.byType(HataSatiri), findsOneWidget);
    expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name}: liste 2× yazıda 320 dp taşmıyor', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await widgetAc(
        tester,
        const EtkinliklerEkrani(tayfaId: ornekTayfaId),
        themeMode: mod,
        tayfa: modulOverridelari(
          modulTasimasi({
            'GET $etkinliklerYolu': yanit(
              etkinlikListesiJson([
                etkinlikJson(etkinlikId1, kontenjan: 20, cevap: 'maybe'),
                etkinlikJson(etkinlikId2, mod: 'online', yer: null),
              ], sonraki: 'opak-1'),
            ),
          }),
        ),
      );
      expect(find.byType(YaklasanSatiri), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.text(arbMetni('tayfa_ana_daha_fazla')),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
