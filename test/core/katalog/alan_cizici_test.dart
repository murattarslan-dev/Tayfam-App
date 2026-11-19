import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../bilesenler/bilesen_test_yardimcisi.dart';
import 'sahte_katalog.dart';

/// Değerleri kendisi tutan sarmalayıcı: alan çizicinin her değişikliği
/// yeniden çizilir (sihirbazdaki notifier'ın yerine).
class _Form extends StatefulWidget {
  const _Form({
    required this.alanlar,
    this.ilk = const {},
    this.hatalariGoster = false,
    this.kapali = false,
  });

  final List<CatalogField> alanlar;
  final AlanDegerleri ilk;
  final bool hatalariGoster;
  final bool kapali;

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
    onDegisti: widget.kapali ? null : (d) => setState(() => degerler = d),
  );
}

AlanDegerleri _degerler(WidgetTester tester) =>
    tester.state<_FormState>(find.byType(_Form)).degerler;

String _istegeBagli(String ad) =>
    arbMetni('katalog_alan_istege_bagli').replaceAll('{ad}', ad);

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pump();
  await tester.tap(bulucu);
  await tester.pump();
}

void main() {
  final alanlar = testTuru('ornek_alanlar').definition.fields!;

  // Her iki temada, 320 dp ve 2× yazıda: boş form, hatalı form.
  ortakTestler(() => _Form(alanlar: alanlar));
  group('hatalarla', () {
    ortakTestler(
      () => _Form(
        alanlar: alanlar,
        hatalariGoster: true,
        ilk: const {'kisi': '99', 'mesafe': 'abc', 'seviye': 'yok'},
      ),
    );
  });

  testWidgets('dokuz alan türü tanımdaki sırayla ve adlarıyla çizilir', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    // Zorunlu alanlar yalın adla, diğerleri "(isteğe bağlı)" ile.
    expect(find.text('Kısa ad'), findsOneWidget);
    expect(find.text('Diller'), findsOneWidget);
    for (final ad in [
      'Notlar',
      'Kişi sayısı',
      'Planlanan mesafe',
      'Seviye',
      'Su var mı',
      'Son kayıt günü',
      'Tahmini süre',
    ]) {
      expect(find.text(_istegeBagli(ad), skipOffstage: false), findsOneWidget);
    }
    // Metin ve sayı alanları: metin, uzun metin, tam sayı, ondalık, süre.
    expect(find.byType(TextField, skipOffstage: false), findsNWidgets(5));
    // Birimler çeviri dosyasından.
    expect(
      find.text(arbMetni('katalog_birim_km'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(arbMetni('katalog_birim_minute'), skipOffstage: false),
      findsOneWidget,
    );
    // Seçenek adları katalogdan; adı olmayan seçenek olduğu gibi.
    expect(find.text('Başlangıç', skipOffstage: false), findsOneWidget);
    expect(find.text('4', skipOffstage: false), findsOneWidget);
    expect(find.text('Almanca', skipOffstage: false), findsOneWidget);
  });

  testWidgets('değerler alan türüne göre toplanır', (tester) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    await tester.enterText(
      find.byKey(const ValueKey('katalog-alan-baslik')),
      'Göl turu',
    );
    await tester.enterText(
      find.byKey(const ValueKey('katalog-alan-kisi')),
      '12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('katalog-alan-mesafe')),
      '12,5',
    );
    await tester.pump();
    await _gorunurDokun(tester, find.text('İleri'));
    await _gorunurDokun(tester, find.text('Türkçe'));
    await _gorunurDokun(tester, find.text('Almanca'));
    await _gorunurDokun(tester, find.text(arbMetni('katalog_hayir')));

    expect(_degerler(tester), {
      'baslik': 'Göl turu',
      'kisi': '12',
      'mesafe': '12,5',
      'seviye': 'ileri',
      'diller': ['tr', 'de'],
      'su_var': false,
    });
    expect(alanGovdesi(alanlar, _degerler(tester)), {
      'baslik': 'Göl turu',
      'kisi': 12,
      'mesafe': 12.5,
      'seviye': 'ileri',
      'diller': ['tr', 'de'],
      'su_var': false,
    });
  });

  testWidgets('sayı alanına harf yazılamaz', (tester) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    await tester.enterText(
      find.byKey(const ValueKey('katalog-alan-kisi')),
      '1a2,b5',
    );
    await tester.pump();
    expect(_degerler(tester)['kisi'], '125');
  });

  testWidgets('çoklu seçimde en çok seçime ulaşınca diğerleri kapanır', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(
        alanlar: alanlar,
        ilk: const {
          'diller': ['tr', 'en'],
        },
      ),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    FilterChip cip(String ad) => tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, ad, skipOffstage: false),
    );
    expect(cip('Türkçe').selected, isTrue);
    expect(cip('Almanca').onSelected, isNull, reason: 'en çok 2 seçim');
    expect(
      cip('Türkçe').onSelected,
      isNotNull,
      reason: 'seçili kaldırılabilir',
    );

    await _gorunurDokun(tester, find.text('Türkçe'));
    expect(_degerler(tester)['diller'], ['en']);
    expect(cip('Almanca').onSelected, isNotNull);
  });

  testWidgets('isteğe bağlı seçimde seçiliye dokunmak seçimi kaldırır', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar, ilk: const {'seviye': 'uzman', 'su_var': true}),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    await _gorunurDokun(tester, find.text('Uzman'));
    await _gorunurDokun(tester, find.text(arbMetni('katalog_evet')));
    expect(_degerler(tester), isEmpty);
  });

  testWidgets('tarih: seçilen gün YYYY-MM-DD olarak tutulur ve temizlenir', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar, ilk: const {'son_kayit': '2026-11-30'}),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    final baglam = tester.element(find.byType(KatalogAlanlari));
    final gosterilen = MaterialLocalizations.of(baglam)
        .formatMediumDate(DateTime.utc(2026, 11, 30));
    expect(find.text(gosterilen, skipOffstage: false), findsOneWidget);

    await _gorunurDokun(
      tester,
      find.byTooltip(arbMetni('katalog_tarih_temizle')),
    );
    expect(_degerler(tester).containsKey('son_kayit'), isFalse);
    expect(
      find.text(arbMetni('katalog_tarih_sec'), skipOffstage: false),
      findsOneWidget,
    );

    await _gorunurDokun(tester, find.text(arbMetni('katalog_tarih_sec')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text(MaterialLocalizations.of(baglam).okButtonLabel));
    await tester.pumpAndSettle();
    final secilen = _degerler(tester)['son_kayit']! as String;
    expect(alanTarihiCoz(secilen), isNotNull);
  });

  testWidgets('hatalar alanın yanında, çeviri dosyasındaki metinle', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(
        alanlar: alanlar,
        hatalariGoster: true,
        ilk: const {
          'kisi': '99',
          'mesafe': '1,23',
          'seviye': 'yok',
          'son_kayit': '2026-02-30',
        },
      ),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    final m = AppLocalizations.of(tester.element(find.byType(KatalogAlanlari)));
    // Zorunlu metin alanı ve zorunlu çoklu seçim boş.
    expect(
      find.text(m.katalog_alan_zorunlu, skipOffstage: false),
      findsNWidgets(2),
    );
    expect(
      find.text(m.katalog_alan_aralik('1', '50'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(m.katalog_alan_basamak(1), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(m.katalog_alan_secim, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(m.katalog_alan_tarih, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('kapalıyken alanlar değiştirilemez', (tester) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar, kapali: true),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    final alan = tester.widget<TextField>(
      find.byKey(const ValueKey('katalog-alan-baslik')),
    );
    expect(alan.enabled, isFalse);
    final cip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Uzman', skipOffstage: false),
    );
    expect(cip.onSelected, isNull);
  });

  testWidgets('tanınmayan türdeki alan çizilmez', (tester) async {
    await bileseniAc(
      tester,
      _Form(alanlar: testTuru('gelecek_tur').definition.fields!),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    expect(find.text(_istegeBagli('Tablo')), findsNothing);
    expect(find.text(_istegeBagli('Ad')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('katalog metni düz metindir ve kırpılır', (tester) async {
    final alan = CatalogField.fromJson({
      'key': 'x',
      'kind': 'boolean',
      'required': true,
      'labels': {'tr': '<b>Kalın</b>\n${'a' * 100}'},
    });
    await bileseniAc(
      tester,
      _Form(alanlar: [alan]),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    final ad = katalogAlanAdi(alan, 'tr');
    expect(ad, startsWith('<b>Kalın</b> a'));
    expect(ad.runes.length, 61);
    expect(find.text(ad), findsOneWidget);
  });

  testWidgets('detay değerleri: birim, seçenek adı, evet/hayır, süre', (
    tester,
  ) async {
    await bileseniAc(
      tester,
      _Form(alanlar: alanlar),
      mod: ThemeMode.light,
      yaziOlcegi: 1,
    );
    final baglam = tester.element(find.byType(KatalogAlanlari));
    CatalogField alan(String anahtar) =>
        alanlar.firstWhere((a) => a.key == anahtar);
    String? deger(String anahtar, Object? d) =>
        katalogAlanDegeriMetni(baglam, alan(anahtar), d);

    expect(deger('kisi', 12), '12 ${arbMetni('katalog_birim_piece')}');
    expect(deger('mesafe', 12.5), '12,5 km');
    expect(deger('mesafe', 12), '12 km');
    expect(deger('seviye', 'baslangic'), 'Başlangıç');
    expect(deger('seviye', '4'), '4');
    expect(deger('diller', ['tr', 'de']), 'Türkçe, Almanca');
    expect(deger('su_var', true), arbMetni('katalog_evet'));
    expect(deger('sure', 90), '90 dk');
    expect(deger('baslik', '  Göl\nturu '), 'Göl turu');
    // Türüne uymayan değer gösterilmez.
    expect(deger('kisi', 'on iki'), isNull);
    expect(deger('su_var', 'evet'), isNull);
    expect(deger('son_kayit', '2026-02-30'), isNull);
    expect(deger('diller', const <Object?>[]), isNull);
  });
}
