import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';

import '../bilesenler/bilesen_test_yardimcisi.dart';
import 'sahte_katalog.dart';

/// Değerleri kendisi tutan sarmalayıcı (sihirbazdaki notifier'ın yerine).
class _Form extends StatefulWidget {
  const _Form({
    required this.alanlar,
    this.ilk = const {},
    this.hatalariGoster = false,
  });

  final List<CatalogField> alanlar;
  final AlanDegerleri ilk;
  final bool hatalariGoster;

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late AlanDegerleri degerler = widget.ilk;

  @override
  Widget build(BuildContext context) => KatalogAlanlari(
    alanlar: widget.alanlar,
    degerler: degerler,
    hatalar: widget.hatalariGoster
        ? alanHatalari(widget.alanlar, degerler)
        : const {},
    onDegisti: (d) => setState(() => degerler = d),
  );
}

AlanDegerleri _degerler(WidgetTester tester) =>
    tester.state<_FormState>(find.byType(_Form)).degerler;

Future<void> _ac(
  WidgetTester tester,
  Widget form, {
  ThemeMode mod = ThemeMode.light,
}) async {
  await bileseniAc(tester, form, mod: mod, overrides: [katalogOverride()]);
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

/// Üst zincirli yazım ("YKS › Matematik › Türev"), çeviri kalıbıyla.
String _yol(List<String> adlar) => adlar
    .skip(1)
    .fold<String>(
      adlar.first,
      (ust, alt) =>
          arbMetni('ders_konu_yol')
              .replaceAll('{ust}', ust)
              .replaceAll('{alt}', alt),
    );

void main() {
  final dersler = dersAlani('dersler', enCok: 2);
  final konu = dersAlani('konu', zorunlu: true);
  final sinav = dersAlani('sinav', enSig: 'level', enDerin: 'subject');
  final duzey = arbMetni('ders_konu_duzey');
  final ders = arbMetni('ders_konu_ders');
  final dersIstegeBagli = arbMetni('ders_konu_ders_istege_bagli');
  final konuEtiketi = arbMetni('ders_konu_konu');
  final emekli = arbMetni('ders_konu_emekli');
  final ekle = arbMetni('ders_konu_alan_ekle');
  // Kaldırma düğmesi; ipucu etiketin zinciriyle (Kaldır: …).
  final kaldir = find.byIcon(Icons.close);

  // Her iki temada, 320 dp ve 2× yazıda: boş, dolu (emekli dahil) ve
  // hatalı form.
  group('boş', () {
    ortakTestler(
      () => _Form(alanlar: [dersler, konu, sinav]),
      overrides: () => [katalogOverride()],
    );
  });
  group('dolu', () {
    ortakTestler(
      () => _Form(
        alanlar: [dersler, konu, sinav],
        ilk: const {
          'dersler': ['yks_matematik_eski', 'yks_fizik'],
          'konu': ['yks_matematik_turev'],
          'sinav': ['yks'],
        },
      ),
      overrides: () => [katalogOverride()],
    );
  });
  group('hatalarla', () {
    ortakTestler(
      () => _Form(alanlar: [dersler, konu], hatalariGoster: true),
      overrides: () => [katalogOverride()],
    );
  });

  testWidgets('tek seçim: ortak seçici, değer [konu ?? ders]', (tester) async {
    await _ac(tester, _Form(alanlar: [konu]));
    expect(find.text('konu'), findsOneWidget, reason: 'alanın adı');

    await _dokun(tester, find.text(duzey));
    await _dokun(tester, find.text('YKS'));
    expect(_degerler(tester), isEmpty, reason: 'düzey tek başına seçim değil');

    await _dokun(tester, find.text(ders));
    await _dokun(tester, find.text('Matematik'));
    expect(_degerler(tester), {
      'konu': ['yks_matematik'],
    });

    await _dokun(tester, find.text(konuEtiketi));
    expect(find.text('Eski konu'), findsNothing, reason: 'emekli sunulmaz');
    await _dokun(tester, find.text('Türev'));
    expect(_degerler(tester), {
      'konu': ['yks_matematik_turev'],
    });

    await _dokun(tester, find.text('Türev'));
    await _dokun(tester, find.text(arbMetni('ders_konu_konu_belirtme')));
    expect(_degerler(tester), {
      'konu': ['yks_matematik'],
    });
    // Zorunlu alanda "Seçimi kaldır" yok.
    expect(find.text(arbMetni('ders_konu_alan_temizle')), findsNothing);
  });

  testWidgets('tek seçim, düzey de seçilebilir: düzey ya da ders', (
    tester,
  ) async {
    await _ac(tester, _Form(alanlar: [sinav]));

    await _dokun(tester, find.text(duzey));
    expect(find.text('KPSS'), findsNothing, reason: 'emekli düzey sunulmaz');
    await _dokun(tester, find.text('YKS'));
    expect(_degerler(tester), {
      'sinav': ['yks'],
    });

    await _dokun(tester, find.text(dersIstegeBagli));
    expect(find.text(arbMetni('ders_konu_ders_belirtme')), findsOneWidget);
    await _dokun(tester, find.text('Fizik'));
    expect(_degerler(tester), {
      'sinav': ['yks_fizik'],
    });
    // En derin seviye ders: konu sorulmaz.
    expect(find.text(konuEtiketi), findsNothing);

    await _dokun(tester, find.text('Fizik'));
    await _dokun(tester, find.text(arbMetni('ders_konu_ders_belirtme')));
    expect(_degerler(tester), {
      'sinav': ['yks'],
    });

    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text('LGS'));
    expect(_degerler(tester), {
      'sinav': ['lgs'],
    });

    // İsteğe bağlı alanda seçim kaldırılabilir.
    await _dokun(tester, find.text(arbMetni('ders_konu_alan_temizle')));
    expect(_degerler(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çoklu seçim: zincirle gösterilir, eklenir, kaldırılır', (
    tester,
  ) async {
    await _ac(
      tester,
      _Form(
        alanlar: [dersler],
        ilk: const {
          'dersler': ['yks_matematik_turev'],
        },
      ),
    );
    expect(find.text(_yol(['YKS', 'Matematik', 'Türev'])), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await _dokun(tester, find.text(ekle));
    await _dokun(tester, find.text(duzey));
    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text(ders));
    await _dokun(tester, find.text('Fizik'));
    await _dokun(tester, find.text(ekle).last);
    expect(_degerler(tester), {
      'dersler': ['yks_matematik_turev', 'yks_fizik'],
    });
    expect(find.text(_yol(['YKS', 'Fizik'])), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      find.byTooltip(
        arbMetni('ders_konu_alan_kaldir')
            .replaceAll('{ad}', _yol(['YKS', 'Fizik'])),
      ),
      findsOneWidget,
    );

    // Dolu alanda "Ekle" kapalı.
    await tester.tap(find.text(ekle));
    await tester.pumpAndSettle();
    expect(find.text(duzey), findsNothing);

    await _dokun(tester, kaldir.first);
    expect(_degerler(tester), {
      'dersler': ['yks_fizik'],
    });
    await _dokun(tester, kaldir);
    expect(_degerler(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çoklu seçim: alanda olan etiket yeniden eklenemez', (
    tester,
  ) async {
    await _ac(
      tester,
      _Form(
        alanlar: [dersler],
        ilk: const {
          'dersler': ['yks_fizik'],
        },
      ),
    );
    await _dokun(tester, find.text(ekle));
    await _dokun(tester, find.text(duzey));
    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text(ders));
    await _dokun(tester, find.text('Fizik'));
    expect(find.text(arbMetni('ders_konu_alan_zaten')), findsOneWidget);
    await tester.tap(find.text(ekle).last);
    await tester.pumpAndSettle();
    expect(_degerler(tester), {
      'dersler': ['yks_fizik'],
    });
  });

  testWidgets('emekli mevcut seçim adıyla kalır, kaldırılınca geri gelmez', (
    tester,
  ) async {
    await _ac(
      tester,
      _Form(
        alanlar: [dersler],
        ilk: const {
          'dersler': ['yks_matematik_eski', 'bilinmeyen_konu'],
        },
      ),
    );
    expect(find.text(_yol(['YKS', 'Matematik', 'Eski konu'])), findsOneWidget);
    expect(find.text(emekli), findsOneWidget);
    // Listede hiç olmayan anahtar gösterilmez ama değerden düşmez.
    expect(find.textContaining('bilinmeyen'), findsNothing);
    expect(kaldir, findsOneWidget);

    await _dokun(tester, kaldir);
    expect(_degerler(tester), {
      'dersler': ['bilinmeyen_konu'],
    });

    await _dokun(tester, find.text(ekle));
    await _dokun(tester, find.text(duzey));
    await _dokun(tester, find.text('YKS'));
    await _dokun(tester, find.text(ders));
    await _dokun(tester, find.text('Matematik'));
    await _dokun(tester, find.text(konuEtiketi));
    expect(find.text('Eski konu'), findsNothing);
    expect(find.text('Türev'), findsOneWidget);
  });

  testWidgets('tek seçimde emekli mevcut değer notla gösterilir', (
    tester,
  ) async {
    await _ac(
      tester,
      _Form(
        alanlar: [konu],
        ilk: const {
          'konu': ['yks_eski_ders_ozet'],
        },
      ),
    );
    expect(find.text('Eski ders'), findsOneWidget);
    expect(find.text('Eski dersin konusu'), findsOneWidget);
    // Emekli dersin konusu da artık seçilemez.
    expect(find.text(emekli), findsNWidgets(2));
    expect(_degerler(tester), {
      'konu': ['yks_eski_ders_ozet'],
    });
  });

  testWidgets('detay değeri: üst zinciriyle, emekli de; liste yoksa yok', (
    tester,
  ) async {
    await _ac(tester, _Form(alanlar: [dersler]));
    final baglam = tester.element(find.byType(KatalogAlanlari));
    final agac = testKatalogu().dersKonu;
    String? deger(Object? d) =>
        katalogAlanDegeriMetni(baglam, dersler, d, dersKonu: agac);

    expect(
      deger(['yks_matematik_turev', 'lgs']),
      '${_yol(['YKS', 'Matematik', 'Türev'])}, LGS',
    );
    expect(deger(['kpss_tarih']), _yol(['KPSS', 'Tarih']));
    expect(deger(['bilinmeyen']), isNull);
    expect(deger('yks'), isNull);
    expect(
      katalogAlanDegeriMetni(baglam, dersler, ['yks']),
      isNull,
      reason: 'ders/konu listesi verilmedi',
    );
  });
}
