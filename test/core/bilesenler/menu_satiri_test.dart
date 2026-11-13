import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/etiket.dart';
import 'package:tayfam/core/bilesenler/menu_satiri.dart';

import 'bilesen_test_yardimcisi.dart';

Widget _satirlar() => Column(
  children: [
    MenuSatiri(
      ikon: Icons.settings_outlined,
      tur: MenuSatiriTuru.vurgulu,
      baslik: 'Tayfa ayarları',
      aciklama: 'Üyeler, istekler, davetler, modüller',
      sag: const SayiRozeti(metin: '3', etiket: '3 bekleyen katılım isteği'),
      onTap: () {},
    ),
    MenuSatiri(
      ikon: Icons.notifications_off_outlined,
      baslik: 'Bildirimleri sessize al',
      aciklama: 'Tayfada kalırsın, yalnızca bildirim gelmez',
      onTap: () {},
    ),
    MenuSatiri(
      ikon: Icons.logout,
      tur: MenuSatiriTuru.yikici,
      baslik: 'Tayfadan ayrıl',
      aciklama: 'Yeniden katılmak için kod ya da davet gerekir',
      onTap: () {},
    ),
    MenuSatiri(
      ikon: Icons.block,
      tur: MenuSatiriTuru.sadeYikici,
      baslik: 'Banla',
      altOge: const Etiket(metin: 'Onay bekliyor', ton: EtiketTonu.mango),
      onTap: () {},
    ),
  ],
);

void main() {
  ortakTestler(_satirlar);

  for (final mod in temalar) {
    testWidgets('${mod.name}: yıkıcı satır tint-nar kutu ve nar-metin ikon', (
      tester,
    ) async {
      final r = renklerOf(mod);
      await bileseniAc(tester, _satirlar(), mod: mod);

      final ikon = tester.widget<Icon>(find.byIcon(Icons.logout));
      expect(ikon.color, r.narMetin);
      final kutu = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byIcon(Icons.logout),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((kutu.decoration as BoxDecoration).color, r.tintNar);
      // Sade yıkıcı satırın başlığı nar-metin.
      expect(cizilenStil(tester, find.text('Banla')).color, r.narMetin);
    });

    testWidgets('${mod.name}: satırlar en az 64 px', (tester) async {
      await bileseniAc(tester, _satirlar(), mod: mod);
      final satirlar = find.byType(MenuSatiri);
      for (var i = 0; i < satirlar.evaluate().length; i++) {
        expect(
          tester.getSize(satirlar.at(i)).height,
          greaterThanOrEqualTo(64),
        );
      }
    });

    testWidgets('${mod.name}: etiket tonları kendi renk çiftleriyle', (
      tester,
    ) async {
      final r = renklerOf(mod);
      await bileseniAc(
        tester,
        const Wrap(
          children: [
            Etiket(metin: 'Moderatör', ton: EtiketTonu.teal),
            Etiket(metin: 'Banlı', ton: EtiketTonu.nar),
          ],
        ),
        mod: mod,
      );
      expect(
        cizilenStil(tester, find.text('Moderatör')).color,
        r.tintTealUstu,
      );
      expect(cizilenStil(tester, find.text('Banlı')).color, r.narMetin);
    });
  }
}
