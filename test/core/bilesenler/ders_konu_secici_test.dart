import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/ders_konu_secici.dart';
import 'package:tayfam/core/katalog/katalog.dart';

import '../katalog/sahte_katalog.dart';
import 'bilesen_test_yardimcisi.dart';

/// Seçimi tutan kap: her değişiklik [kayit]'a yazılır.
class _Kap extends StatefulWidget {
  const _Kap({
    required this.kayit,
    this.ilk,
    this.acik = true,
    this.dersHatasi,
  });

  final List<DersKonuSecimi?> kayit;
  final DersKonuSecimi? ilk;
  final bool acik;
  final String? dersHatasi;

  @override
  State<_Kap> createState() => _KapState();
}

class _KapState extends State<_Kap> {
  late DersKonuSecimi? _secim = widget.ilk;

  @override
  Widget build(BuildContext context) => DersKonuSecici(
    secim: _secim,
    dersHatasi: widget.dersHatasi,
    onDegisti: !widget.acik
        ? null
        : (secim) {
            widget.kayit.add(secim);
            setState(() => _secim = secim);
          },
  );
}

Map<String, Object?> _etiket(String key, String ad, {String? ust, int p = 10}) =>
    {
      'key': key,
      'parent_key': ?ust,
      'position': p,
      'labels': {'tr': ad},
      'status': 'active',
    };

/// [etiketler] ders/konu listeli test kataloğu.
Katalog _katalog(List<Map<String, Object?>> etiketler) => Katalog(
  Catalog.fromJson({...testKataloguJson(), 'study_tags': etiketler}),
);

Future<void> _ac(
  WidgetTester tester,
  Widget bilesen, {
  ThemeMode mod = ThemeMode.light,
  Katalog? katalog,
}) async {
  await bileseniAc(
    tester,
    bilesen,
    mod: mod,
    overrides: [katalogOverride(katalog)],
  );
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

void main() {
  final duzey = arbMetni('ders_konu_duzey');
  final ders = arbMetni('ders_konu_ders');
  final konu = arbMetni('ders_konu_konu');
  final emekli = arbMetni('ders_konu_emekli');

  group('boş seçim', () {
    ortakTestler(
      () => const _Kap(kayit: []),
      overrides: () => [katalogOverride()],
    );
  });

  group('dolu seçim', () {
    ortakTestler(
      () => const _Kap(
        kayit: [],
        ilk: DersKonuSecimi(
          ders: 'yks_matematik',
          konu: 'yks_matematik_turev',
        ),
      ),
      overrides: () => [katalogOverride()],
    );
  });

  group('emekli mevcut değer', () {
    ortakTestler(
      () => const _Kap(
        kayit: [],
        ilk: DersKonuSecimi(ders: 'yks_eski_ders', konu: 'yks_eski_ders_ozet'),
      ),
      overrides: () => [katalogOverride()],
    );
  });

  testWidgets('üç seviye sırayla seçilir; emekliler sunulmaz', (tester) async {
    final kayit = <DersKonuSecimi?>[];
    await _ac(tester, _Kap(kayit: kayit));

    // Başta yalnızca düzey alanı var.
    expect(find.text(ders), findsNothing);
    await _dokun(tester, find.text(duzey));
    expect(find.text('YKS'), findsOneWidget);
    expect(find.text('LGS'), findsOneWidget);
    expect(find.text('KPSS'), findsNothing);
    await _dokun(tester, find.text('YKS'));
    expect(kayit, isEmpty);

    await _dokun(tester, find.text(ders));
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Fizik'), findsOneWidget);
    expect(find.text('Diğer'), findsOneWidget);
    expect(find.text('Eski ders'), findsNothing);
    await _dokun(tester, find.text('Matematik'));
    expect(kayit.last, const DersKonuSecimi(ders: 'yks_matematik'));

    await _dokun(tester, find.text(konu));
    expect(find.text(arbMetni('ders_konu_konu_belirtme')), findsOneWidget);
    expect(find.text('Türev'), findsOneWidget);
    expect(find.text('İntegral'), findsOneWidget);
    expect(find.text('Eski konu'), findsNothing);
    await _dokun(tester, find.text('Türev'));
    expect(
      kayit.last,
      const DersKonuSecimi(ders: 'yks_matematik', konu: 'yks_matematik_turev'),
    );

    // Konuyu boşaltmak.
    await _dokun(tester, find.text('Türev'));
    await _dokun(tester, find.text(arbMetni('ders_konu_konu_belirtme')));
    expect(kayit.last, const DersKonuSecimi(ders: 'yks_matematik'));

    // Düzey değişince ders ve konu düşer.
    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text('LGS'));
    expect(kayit.last, isNull);
    expect(find.text('Matematik'), findsNothing);
    expect(find.text(konu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aynı seçeneğe dokunmak seçimi değiştirmez', (tester) async {
    final kayit = <DersKonuSecimi?>[];
    await _ac(
      tester,
      _Kap(
        kayit: kayit,
        ilk: const DersKonuSecimi(ders: 'yks_fizik'),
      ),
    );
    expect(find.text('YKS'), findsOneWidget);
    await _dokun(tester, find.text('Fizik'));
    await _dokun(tester, find.text('Fizik').last);
    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text('YKS').last);
    expect(kayit, isEmpty);
  });

  testWidgets('emekli mevcut değer adıyla ve notla gösterilir', (
    tester,
  ) async {
    await _ac(
      tester,
      const _Kap(
        kayit: [],
        ilk: DersKonuSecimi(ders: 'yks_eski_ders', konu: 'yks_eski_ders_ozet'),
      ),
    );
    expect(find.text('YKS'), findsOneWidget);
    expect(find.text('Eski ders'), findsOneWidget);
    expect(find.text('Eski dersin konusu'), findsOneWidget);
    expect(find.text(emekli), findsNWidgets(2));
  });

  testWidgets('emekli düzeyin dersi adıyla gösterilir', (tester) async {
    await _ac(
      tester,
      const _Kap(kayit: [], ilk: DersKonuSecimi(ders: 'kpss_tarih')),
    );
    expect(find.text('KPSS'), findsOneWidget);
    expect(find.text('Tarih'), findsOneWidget);
  });

  testWidgets('katalogda olmayan değer anahtarıyla gösterilir', (
    tester,
  ) async {
    await _ac(
      tester,
      const _Kap(kayit: [], ilk: DersKonuSecimi(ders: 'bilinmeyen_ders')),
    );
    expect(find.text('bilinmeyen_ders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sunucunun ders hatası alanın altında', (tester) async {
    await _ac(
      tester,
      const _Kap(
        kayit: [],
        ilk: DersKonuSecimi(ders: 'yks_matematik'),
        dersHatasi: 'Ders hatası',
      ),
    );
    expect(find.text('Ders hatası'), findsOneWidget);
  });

  testWidgets('kapalı seçici liste açmaz', (tester) async {
    await _ac(tester, const _Kap(kayit: [], acik: false));
    await tester.tap(find.text(duzey));
    await tester.pumpAndSettle();
    expect(find.text('YKS'), findsNothing);
  });

  for (final mod in temalar) {
    testWidgets('${mod.name}: boş listede sakin boş durum', (tester) async {
      await _ac(tester, const _Kap(kayit: []), mod: mod, katalog: _katalog([]));
      expect(find.text(arbMetni('ders_konu_liste_bos')), findsOneWidget);
      expect(find.text(duzey), findsNothing);
      expect(tester.takeException(), isNull);
      await erisilebilirlikDenetle(tester);
    });

    testWidgets('${mod.name}: seçenek sayfası taşmaz ve erişilebilir', (
      tester,
    ) async {
      await _ac(
        tester,
        const _Kap(kayit: [], ilk: DersKonuSecimi(ders: 'yks_matematik')),
        mod: mod,
      );
      await _dokun(tester, find.text(konu));
      expect(tester.takeException(), isNull);
      await erisilebilirlikDenetle(tester);
    });
  }

  testWidgets('uzun listede Türkçe kurallarla arama', (tester) async {
    final katalog = _katalog([
      _etiket('dil', 'Dil'),
      for (var i = 0; i < 8; i++) _etiket('dil_d$i', 'Ders $i', ust: 'dil'),
      _etiket('dil_ingilizce', 'İngilizce', ust: 'dil', p: 20),
      _etiket('dil_isik', 'Işık', ust: 'dil', p: 30),
      _etiket('dil_other', 'Diğer', ust: 'dil', p: 90),
    ]);
    final kayit = <DersKonuSecimi?>[];
    await _ac(tester, _Kap(kayit: kayit), katalog: katalog);
    await _dokun(tester, find.text(duzey));
    // Az seçenekte arama yok.
    expect(find.byType(TextField), findsNothing);
    await _dokun(tester, find.text('Dil'));
    await _dokun(tester, find.text(ders));
    final arama = find.byType(TextField);
    expect(arama, findsOneWidget);

    await tester.enterText(arama, 'ingilizce');
    await tester.pumpAndSettle();
    expect(find.text('İngilizce'), findsOneWidget);
    expect(find.text('Ders 0'), findsNothing);

    await tester.enterText(arama, 'ışık');
    await tester.pumpAndSettle();
    expect(find.text('Işık'), findsOneWidget);
    expect(find.text('İngilizce'), findsNothing);

    await tester.enterText(arama, 'yok böyle');
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('ders_konu_sonuc_yok')), findsOneWidget);

    await tester.enterText(arama, 'IŞI');
    await tester.pumpAndSettle();
    await _dokun(tester, find.text('Işık'));
    expect(kayit.last, const DersKonuSecimi(ders: 'dil_isik'));
  });

  testWidgets('katalog yüklenirken bekleyici gösterilir', (tester) async {
    await bileseniAc(
      tester,
      const _Kap(kayit: []),
      mod: ThemeMode.light,
      overrides: [katalogDurumuOverride(const AsyncLoading())],
    );
    expect(find.text(duzey), findsNothing);
  });
}
