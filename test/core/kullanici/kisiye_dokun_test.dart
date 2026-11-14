import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kullanici/kisiye_dokun.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/kullanici/kullanici_adi_metni.dart';
import 'package:tayfam/core/tema/tema.dart';

import '../../yardimcilar.dart';

const String _deniz = '0e0d0c0b-0000-4000-8000-000000000001';
const String _silinmis = '0e0d0c0b-0000-4000-8000-000000000002';

final _adlar = profilOkuyucuProvider.overrideWithValue(
  (id) async => switch (id) {
    _deniz => const KullaniciAdi('Deniz Örnek'),
    _ => const KullaniciAdi.silinmis(),
  },
);

/// Küçük avatar ve ad; issue #185'teki tipik kullanım.
Widget _satir(String? kimlik) => Scaffold(
  body: Center(
    child: KisiyeDokun(
      kullaniciId: kimlik,
      ipucu: 'ipucu',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KimlikAvatari(kullaniciId: kimlik, cap: TayfamSizes.avatarYigini),
          if (kimlik != null)
            Flexible(child: KullaniciAdiMetni(kullaniciId: kimlik)),
        ],
      ),
    ),
  ),
);

Future<void> _ac(
  WidgetTester tester,
  String? kimlik, {
  ThemeMode tema = ThemeMode.light,
}) => widgetAc(
  tester,
  _satir(kimlik),
  themeMode: tema,
  overrides: [_adlar],
  yonlendirici: true,
);

void main() {
  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('dokununca kişi profili açılıyor (${tema.name}, 2×, 320 dp)', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(tester, _deniz, tema: tema);

      expect(find.text('Deniz Örnek'), findsOneWidget);
      await tester.tap(find.byType(KisiyeDokun));
      await tester.pumpAndSettle();

      expect(kisiSayfasi(_deniz), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ekran okuyucu "<Ad> profilini aç"; avatar ve ad ayrıca '
      'okunmuyor; 48 dp', (tester) async {
    ekranBoyutu(tester);
    final kulp = tester.ensureSemantics();
    await _ac(tester, _deniz);

    final etiket = arbMetni('kisi_profilini_ac')
        .replaceAll('{ad}', 'Deniz Örnek');
    expect(
      tester.getSemantics(find.byType(KisiyeDokun)),
      matchesSemantics(
        label: etiket,
        hint: 'ipucu',
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('Deniz Örnek'), findsNothing);
    final boyut = tester.getSize(find.byType(InkWell));
    expect(boyut.width, greaterThanOrEqualTo(TayfamSizes.dokunmaMin));
    expect(boyut.height, greaterThanOrEqualTo(TayfamSizes.dokunmaMin));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    kulp.dispose();
  });

  testWidgets('ekran okuyucuyla dokunma da profili açıyor', (tester) async {
    ekranBoyutu(tester);
    final kulp = tester.ensureSemantics();
    await _ac(tester, _deniz);

    tester.semantics.tap(
      find.semantics.byLabel(
        arbMetni('kisi_profilini_ac').replaceAll('{ad}', 'Deniz Örnek'),
      ),
    );
    await tester.pumpAndSettle();
    expect(kisiSayfasi(_deniz), findsOneWidget);
    kulp.dispose();
  });

  testWidgets('silinmiş hesapta (kimlik yok) dokunulamıyor', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, null);

    expect(find.byType(InkWell), findsNothing);
    await tester.tap(find.byType(KimlikAvatari));
    await tester.pumpAndSettle();
    expect(herhangiKisiSayfasi(), findsNothing);
  });

  testWidgets('ad önbelleği "Silinmiş kullanıcı" diyorsa dokunulamıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester, _silinmis);

    expect(find.text(arbMetni('kullanici_silinmis')), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
    await tester.tap(find.text(arbMetni('kullanici_silinmis')));
    await tester.pumpAndSettle();
    expect(herhangiKisiSayfasi(), findsNothing);
  });

  testWidgets('ekranOkuyucu false: dokunma çalışır, ayrı öğe olmaz', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final kulp = tester.ensureSemantics();
    await widgetAc(
      tester,
      const Scaffold(
        body: Center(
          child: KisiyeDokun(
            kullaniciId: _deniz,
            ekranOkuyucu: false,
            child: KimlikAvatari(kullaniciId: _deniz),
          ),
        ),
      ),
      overrides: [_adlar],
      yonlendirici: true,
    );
    expect(
      find.bySemanticsLabel(
        arbMetni('kisi_profilini_ac').replaceAll('{ad}', 'Deniz Örnek'),
      ),
      findsNothing,
    );
    await tester.tap(find.byType(KisiyeDokun));
    await tester.pumpAndSettle();
    expect(kisiSayfasi(_deniz), findsOneWidget);
    kulp.dispose();
  });
}
