import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/tayfam_yukleniyor.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';
import 'package:tayfam/features/etkinlik/presentation/tur_secici.dart';

import '../../core/bilesenler/bilesen_test_yardimcisi.dart';
import '../../core/katalog/sahte_katalog.dart';

/// Seçimi kendisi tutan sarmalayıcı.
class _Secim extends StatefulWidget {
  const _Secim({this.ilgiAlanlari = const [], this.kapali = false});

  final List<String> ilgiAlanlari;
  final bool kapali;

  @override
  State<_Secim> createState() => _SecimState();
}

class _SecimState extends State<_Secim> {
  CatalogEventType? secili;

  @override
  Widget build(BuildContext context) => TurSecici(
    secili: secili?.key,
    ilgiAlanlari: widget.ilgiAlanlari,
    onSecildi: widget.kapali ? null : (tur) => setState(() => secili = tur),
  );
}

CatalogEventType? _secili(WidgetTester tester) =>
    tester.state<_SecimState>(find.byType(_Secim)).secili;

Finder _kutu(String ad) =>
    find.widgetWithText(TurKutusu, ad, skipOffstage: false);

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pump();
  await tester.tap(bulucu);
  await tester.pump();
}

void main() {
  // Her iki temada, 320 dp ve 2× yazıda: tayfanın ilgi alanlarıyla.
  ortakTestler(
    () => const _Secim(ilgiAlanlari: ['nature']),
    overrides: () => [katalogOverride()],
  );

  testWidgets('önce tayfanın ilgi alanları, sonra gruplu "Tüm türler"', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const _Secim(ilgiAlanlari: ['nature', 'bilinmeyen_alan']),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    expect(
      find.text(arbMetni('etkinlik_tur_ilgi_alanlari')),
      findsOneWidget,
    );
    expect(
      find.text(arbMetni('katalog_tum_turler'), skipOffstage: false),
      findsOneWidget,
    );
    // Doğa'daki türler hem önde hem "Tüm türler"de.
    expect(_kutu('Doğa yürüyüşü'), findsNWidgets(2));
    expect(_kutu('Kamp'), findsNWidgets(2));
    // Köpek yürüyüşü Doğa'da da listelenir; ana ilgi alanında bir kez.
    expect(_kutu('Köpek yürüyüşü'), findsNWidgets(2));
    expect(_kutu('Konvoy'), findsOneWidget);
    // İlgi alanı grup başlıkları katalog metni.
    for (final grup in ['Otomobil ve motor', 'Doğa', 'Su', 'Spor', 'Oyun']) {
      expect(find.text(grup, skipOffstage: false), findsOneWidget);
    }
    // Emekli tür ve türü olmayan emekli ilgi alanı listelenmez.
    expect(find.text('Eski tür', skipOffstage: false), findsNothing);
    expect(find.text('Eski ilgi alanı', skipOffstage: false), findsNothing);
  });

  testWidgets('ilgi alanı yoksa (anlık etkinlik) yalnızca "Tüm türler"', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const _Secim(),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    expect(find.text(arbMetni('etkinlik_tur_ilgi_alanlari')), findsNothing);
    expect(_kutu('Doğa yürüyüşü'), findsOneWidget);
  });

  testWidgets('tür seçilir; seçim ekran okuyucuya bildirilir', (tester) async {
    await bileseniAc(
      tester,
      const _Secim(),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    await _gorunurDokun(tester, find.text('Balıkçılık'));
    expect(_secili(tester)?.key, 'fishing');
    expect(
      tester.widget<TurKutusu>(_kutu('Balıkçılık')).secili,
      isTrue,
    );
    expect(tester.widget<TurKutusu>(_kutu('Kamp')).secili, isFalse);
    expect(find.byIcon(Icons.check, skipOffstage: false), findsOneWidget);
  });

  testWidgets('alan türü tanınmayan tür listelenir ama seçilemez', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const _Secim(),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    expect(
      tester.widget<TurKutusu>(_kutu('Gelecek tür')).guncellemeGerekli,
      isTrue,
    );
    expect(
      find.text(arbMetni('katalog_tur_guncelle'), skipOffstage: false),
      findsOneWidget,
    );
    await _gorunurDokun(tester, find.text('Gelecek tür'));
    expect(_secili(tester), isNull);
  });

  testWidgets('arama adı Türkçe küçük harfle süzer; sonuç yoksa metin', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      const _Secim(ilgiAlanlari: ['nature']),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    await tester.enterText(find.byType(TextField), 'YÜRÜYÜŞ');
    await tester.pump();
    // Aramada ilgi alanı grubu gizlenir; eşleşenler bir kez listelenir.
    expect(find.text(arbMetni('etkinlik_tur_ilgi_alanlari')), findsNothing);
    expect(_kutu('Doğa yürüyüşü'), findsOneWidget);
    expect(_kutu('Köpek yürüyüşü'), findsOneWidget);
    expect(_kutu('Kamp'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.byType(TurKutusu, skipOffstage: false), findsNothing);
    expect(find.text(arbMetni('katalog_tur_bulunamadi')), findsOneWidget);

    await tester.tap(find.byTooltip(arbMetni('katalog_aramayi_temizle')));
    await tester.pump();
    expect(_kutu('Kamp'), findsNWidgets(2));
  });

  test('turAra: I/İ ve ı/i Türkçe kurallarla eşleşir', () {
    final turler = testKatalogu().secilebilirTurler;
    expect(turAra(turler, 'BALIK', 'tr').map((t) => t.key), ['fishing']);
    expect(turAra(turler, '  ', 'tr'), turler);
    expect(turAra(turler, 'convoy', 'en').map((t) => t.key), ['convoy']);
    // Seçilen dilde adı olmayan tür tr adıyla aranır.
    expect(turAra(turler, 'kamp', 'en').map((t) => t.key), ['camp']);
  });

  testWidgets('kapalıyken tür seçilemez', (tester) async {
    await bileseniAc(
      tester,
      const _Secim(kapali: true),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
      overrides: [katalogOverride()],
    );
    await _gorunurDokun(tester, find.text('Kamp'));
    expect(_secili(tester), isNull);
  });

  for (final mod in temalar) {
    testWidgets('${mod.name}: katalog gelene kadar yükleniyor durumu', (
      tester,
    ) async {
      await bileseniAc(
        tester,
        const _Secim(),
        mod: mod,
        overrides: [
          katalogDurumuOverride(const AsyncLoading<Katalog?>()),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(TurKutusu), findsNothing);
      expect(
        tester.widget<TayfamYukleniyor>(find.byType(TayfamYukleniyor)).etiket,
        arbMetni('katalog_yukleniyor'),
      );
    });

    testWidgets('${mod.name}: okunamazsa hata ve "Tekrar dene"', (
      tester,
    ) async {
      late final SabitKatalogNotifier katalog;
      await bileseniAc(
        tester,
        const _Secim(),
        mod: mod,
        overrides: [
          katalogProvider.overrideWith(
            () => katalog = SabitKatalogNotifier(
              const AsyncError<Katalog?>(ApiOffline(), StackTrace.empty),
            ),
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      expect(find.text(arbMetni('katalog_yuklenemedi')), findsOneWidget);
      await tester.tap(find.text(arbMetni('katalog_tekrar_dene')));
      await tester.pump();
      expect(katalog.yenileme, 1);
      await erisilebilirlikDenetle(tester);
    });
  }
}
