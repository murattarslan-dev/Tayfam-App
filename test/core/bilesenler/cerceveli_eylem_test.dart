import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/bolum_etiketi.dart';
import 'package:tayfam/core/bilesenler/cerceveli_eylem.dart';

import 'bilesen_test_yardimcisi.dart';

void main() {
  ortakTestler(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BolumEtiketi(
          baslik: 'Arkadaşlar',
          sag: BaglantiEylemi(etiket: 'Arkadaş ekle', onPressed: () {}),
        ),
        CerceveliEylem(
          etiket: 'Kodumu paylaş',
          ikon: Icons.share_outlined,
          onPressed: () {},
        ),
        CerceveliEylem(etiket: 'Çıkış yap', notr: true, onPressed: () {}),
      ],
    ),
  );

  for (final mod in temalar) {
    testWidgets('${mod.name}: çerçeveli düğme marka tonunda', (tester) async {
      final r = renklerOf(mod);
      await bileseniAc(
        tester,
        CerceveliEylem(etiket: 'Kodumu paylaş', onPressed: () {}),
        mod: mod,
      );
      final stil = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(stil.foregroundColor!.resolve(const {}), r.tintMarkaUstu);
      expect(stil.side!.resolve(const {})!.color, r.tintMarkaUstu);
      dokunmaAlaniEnAz44(tester, find.byType(OutlinedButton));
    });

    testWidgets('${mod.name}: nötr çerçeveli düğme çizgi kenarlı', (
      tester,
    ) async {
      final r = renklerOf(mod);
      await bileseniAc(
        tester,
        CerceveliEylem(etiket: 'Çıkış yap', notr: true, onPressed: () {}),
        mod: mod,
      );
      final stil = tester
          .widget<OutlinedButton>(find.byType(OutlinedButton))
          .style!;
      expect(stil.foregroundColor!.resolve(const {}), r.metin);
      expect(stil.side!.resolve(const {})!.color, r.cizgi);
    });

    testWidgets('${mod.name}: bağlantının ekran okuyucu etiketi', (
      tester,
    ) async {
      await bileseniAc(
        tester,
        BaglantiEylemi(
          etiket: 'Tümünü gör',
          semantikEtiketi: 'Tüm katılımların',
          onPressed: () {},
        ),
        mod: mod,
      );
      final kulp = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Tüm katılımların'), findsOneWidget);
      kulp.dispose();
      dokunmaAlaniEnAz44(tester, find.byType(TextButton));
    });

    testWidgets('${mod.name}: odak çerçevesi', (tester) async {
      await odakCercevesiDenetle(
        tester,
        CerceveliEylem(etiket: 'Kodumu paylaş', onPressed: () {}),
        mod: mod,
      );
    });
  }

  testWidgets('bölüm etiketi başlık olarak okunur', (tester) async {
    await bileseniAc(
      tester,
      const BolumEtiketi(baslik: 'Gizlilik'),
      mod: ThemeMode.light,
    );
    final kulp = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.text('Gizlilik')),
      containsSemantics(label: 'Gizlilik', isHeader: true),
    );
    kulp.dispose();
  });
}
