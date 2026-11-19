import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  OlcumBileseni(),
  // Yürüyüşte mesafeye bağlı hedef de var (#234).
  HedefBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(id, id == organizatorId ? 'Ayşe' : 'Mert', ben: id == ben);
}

/// Yürüyüşün irtifa kazancı: m, tam sayı, 0–9000.
Map<String, Object?> _irtifa({num? toplam, bool yazabilir = false}) =>
    olcumJson(
      birim: 'm',
      enCok: 9000,
      basamak: 0,
      toplam: toplam,
      yazabilir: yazabilir,
    );

/// Doğa yürüyüşü (katalog fikstüründe `distance` ve `elevation_gain`
/// anahtarlı iki `measure` bileşeni olan tür). Ölçüm uçları bileşenin
/// anahtarına göre yanıt verir: [mesafe] `distance`'ın, [irtifa]
/// `elevation_gain`'in yanıtıdır. Oturumdaki kullanıcı [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti mesafe,
  TayfaYaniti? irtifa,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = organizatorId,
  DateTime? baslangic,
  String? katilim = 'attended',
}) {
  Object? olcum(TayfaIstegi i) {
    if (i.yolParametreleri['component_key'] == 'distance') return mesafe(i);
    return irtifa == null ? _irtifa() : irtifa(i);
  }

  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: 'hike',
      cevap: 'going',
      katilim: katilim,
      baslangic: baslangic ?? gecmisBaslangic,
      sure: const Duration(hours: 6),
    ),
    'GET $olcumYolu': olcum,
    ...yanitlar,
  });
  t.yanitlar['GET $profilYolu'] = (i) => _profil(i, ben);
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, bilesenler: _kayit),
  );
  yonlendiriciyiAl(tester).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
  await tester.pumpAndSettle();
}

Future<void> _gorunurYap(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _formda(Finder bulucu) =>
    find.descendant(of: find.byType(OlcumFormu), matching: bulucu);

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(OlcumBolumu), matching: bulucu);

Finder get _degerAlani => _formda(find.byType(TextField));

Finder get _kaydet => _formda(find.text(arbMetni('etkinlik_kaydet')));

EventMeasure _olcum(Map<String, Object?> json) => EventMeasure.fromJson(json);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe ölçüm bileşenini kullanan tür var', () {
    final olcumler = turBilesenleri(testTuru('hike'))
        .where((b) => b.kind == 'measure')
        .toList();
    expect(olcumler.map(bilesenAnahtari), ['distance', 'elevation_gain']);
    final mesafe = BilesenParametreleri(olcumler.first.params);
    expect(mesafe.metin('unit'), 'km');
    expect(mesafe.metin('scope'), 'total');
    expect(mesafe.metin('entered_by'), 'organizer');
    expect(mesafe.metin('prefill_from'), 'planned_distance');
    expect(BilesenParametreleri(olcumler.last.params).metin('unit'), 'm');
  });

  group('sayılar', () {
    test('Türkçe ondalık ayracıyla, basamağa yuvarlanmış gösterilir', () {
      expect(olcumSayisi(m, 12.4, 2), '12,4');
      expect(olcumSayisi(m, 12, 2), '12');
      expect(olcumSayisi(m, 3.14159, 2), '3,14');
      expect(olcumSayisi(m, 1250, 0), '1250');
      final mesafe = _olcum(olcumJson());
      expect(olcumDegeriMetni(m, mesafe, 12.4), '12,4 km');
      expect(olcumGirdisi(m, mesafe, 7.5), '7,5');
      expect(olcumGirdisi(m, mesafe, null), '');
    });

    test('virgül de nokta da kabul edilir; sınır ve basamak denetlenir', () {
      final mesafe = _olcum(olcumJson());
      expect(olcumGirdisiniOku(mesafe, '12,45').deger, 12.45);
      expect(olcumGirdisiniOku(mesafe, ' 12.5 ').deger, 12.5);
      expect(olcumGirdisiniOku(mesafe, '12,456').hata, AlanHatasi.basamak);
      expect(olcumGirdisiniOku(mesafe, '1000,5').hata, AlanHatasi.aralik);
      expect(olcumGirdisiniOku(mesafe, '-1').hata, AlanHatasi.aralik);
      expect(olcumGirdisiniOku(mesafe, 'on iki').hata, AlanHatasi.sayi);
      expect(olcumGirdisiniOku(mesafe, '').hata, AlanHatasi.zorunlu);
      expect(
        olcumHataMetni(m, mesafe, AlanHatasi.aralik),
        m.katalog_alan_aralik('0', '1000'),
      );

      // Basamağı 0 olan ölçüm tam sayıdır.
      final irtifa = _olcum(_irtifa());
      expect(olcumAlani(irtifa).kind, 'integer');
      expect(olcumGirdisiniOku(irtifa, '1250').deger, 1250);
      expect(olcumGirdisiniOku(irtifa, '12,5').hata, AlanHatasi.sayi);
    });

    test('kişisel değeri kimin değiştirebileceği ölçümün kuralına göre', () {
      const kayit = EventMeasureEntry(userId: organizatorId, value: 3);
      final kendisi = _olcum(
        olcumJson(kapsam: 'personal', giren: 'self', yazabilir: true),
      );
      expect(olcumKaydiDegisebilir(kendisi, kayit, organizatorId), isTrue);
      expect(olcumKaydiDegisebilir(kendisi, kayit, katilimciId), isFalse);
      final organizator = _olcum(
        olcumJson(kapsam: 'personal', giren: 'organizer', yazabilir: true),
      );
      expect(olcumKaydiDegisebilir(organizator, kayit, katilimciId), isTrue);
      final yazamaz = _olcum(olcumJson(kapsam: 'personal', giren: 'organizer'));
      expect(olcumKaydiDegisebilir(yazamaz, kayit, organizatorId), isFalse);
    });
  });

  group('toplam ölçüm', () {
    for (final tema in _temalar) {
      testWidgets('önerilen değer onaylanır; değerler birimiyle '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          mesafe: (_) => olcumJson(onerilen: 12.4, yazabilir: true),
          irtifa: (_) => _irtifa(toplam: 1250),
          yanitlar: {
            'PUT $olcumToplamiYolu': (_) =>
                olcumJson(toplam: 12.4, yazabilir: true),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        await _gorunurYap(tester, find.text('1250 m'));
        expect(find.text('Mesafe'), findsOneWidget);
        expect(find.text('İrtifa kazancı'), findsOneWidget);
        expect(
          tasima
              .giden('GET', olcumYolu)
              .map((i) => i.yolParametreleri['component_key'])
              .toSet(),
          {'distance', 'elevation_gain'},
        );
        expect(find.text('Önerilen: 12,4 km'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_measure_onerilen_notu')),
          findsOneWidget,
        );
        // Yazamayan ölçümde düzeltme düğmesi yok.
        expect(
          find.byTooltip(arbMetni('bilesen_measure_duzelt')),
          findsNothing,
        );

        await _dokun(tester, find.text(arbMetni('bilesen_measure_onayla')));
        final istek = tasima.giden('PUT', olcumToplamiYolu).single;
        expect(istek.yolParametreleri['component_key'], 'distance');
        expect(istek.govde, {'value': 12.4});
        expect(find.text('Önerilen: 12,4 km'), findsNothing);
        expect(find.text('12,4 km'), findsOneWidget);
        expect(
          find.byTooltip(arbMetni('bilesen_measure_duzelt')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('düzeltme: basamak hatası formda, değer virgülle gider', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        mesafe: (_) => olcumJson(toplam: 12.4, yazabilir: true),
        yanitlar: {
          'PUT $olcumToplamiYolu': (_) =>
              olcumJson(toplam: 13.45, yazabilir: true),
        },
      );
      await _detayiAc(tester, tasima);
      final duzelt = find.byTooltip(arbMetni('bilesen_measure_duzelt'));
      await _gorunurYap(tester, duzelt);
      await _dokun(tester, duzelt);

      expect(find.byType(OlcumFormu), findsOneWidget);
      expect(tester.widget<TextField>(_degerAlani).controller!.text, '12,4');
      expect(_formda(find.text('km')), findsOneWidget);
      expect(_formda(find.text('0 ile 1000 arasında')), findsOneWidget);

      await tester.enterText(_degerAlani, '13,456');
      await _dokun(tester, _kaydet);
      expect(tasima.giden('PUT', olcumToplamiYolu), isEmpty);
      expect(_formda(find.text(m.katalog_alan_basamak(2))), findsOneWidget);

      await tester.enterText(_degerAlani, '13,45');
      await _dokun(tester, _kaydet);
      expect(tasima.giden('PUT', olcumToplamiYolu).single.govde, {
        'value': 13.45,
      });
      expect(find.byType(OlcumFormu), findsNothing);
      expect(find.text('13,45 km'), findsOneWidget);
    });

    testWidgets('toplam onayla kaldırılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        mesafe: (_) => olcumJson(toplam: 12.4, yazabilir: true),
        yanitlar: {
          'DELETE $olcumToplamiYolu': (_) => olcumJson(yazabilir: true),
        },
      );
      await _detayiAc(tester, tasima);
      final kaldir = find.byTooltip(arbMetni('bilesen_measure_kaldir'));
      await _gorunurYap(tester, kaldir);
      await _dokun(tester, kaldir);
      expect(
        find.text(arbMetni('bilesen_measure_kaldir_onay')),
        findsOneWidget,
      );
      await _dokun(tester, find.text(arbMetni('bilesen_measure_kaldir')));
      expect(tasima.giden('DELETE', olcumToplamiYolu), hasLength(1));
      expect(find.text('12,4 km'), findsNothing);
      expect(find.text(arbMetni('bilesen_measure_gir')), findsOneWidget);
    });

    testWidgets('etkinlik başlamadan değer yerine bilgi; öneri yazamayana '
        'gösterilmez', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        mesafe: (_) => olcumJson(onerilen: 12.4),
        baslangic: ornekBaslangic,
        katilim: null,
      );
      await _detayiAc(tester, tasima);
      final bilgi = find.text(arbMetni('bilesen_measure_baslamadi'));
      await _gorunurYap(tester, bilgi.last);
      expect(bilgi, findsNWidgets(2));
      expect(find.textContaining('12,4'), findsNothing);
      expect(find.text(arbMetni('bilesen_measure_gir')), findsNothing);
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        mesafe: (_) {
          if (okundu) return olcumJson(toplam: 8);
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = find.descendant(
        of: find.byType(OlcumBolumu),
        matching: find.text(arbMetni('etkinlik_tekrar_dene')),
      );
      await _gorunurYap(tester, tekrar);
      expect(tekrar, findsOneWidget);
      await _dokun(tester, tekrar);
      expect(find.text('8 km'), findsOneWidget);
    });
  });

  group('kişisel ölçüm', () {
    for (final tema in _temalar) {
      testWidgets('kendi değerini düzeltir, kaldırır ve yeniden girer '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        Map<String, Object?> kisisel(List<Map<String, Object?>> kayitlar) =>
            olcumJson(
              kapsam: 'personal',
              giren: 'self',
              kayitlar: kayitlar,
              yazabilir: true,
            );
        final ayse = {'user_id': organizatorId, 'value': 5.5};
        final tasima = _tasima(
          ben: katilimciId,
          mesafe: (_) => kisisel([
            ayse,
            {'user_id': katilimciId, 'value': 7},
          ]),
          yanitlar: {
            'DELETE $olcumKaydiYolu': (_) => kisisel([ayse]),
            'PUT $olcumKaydiYolu': (_) => kisisel([
              ayse,
              {'user_id': katilimciId, 'value': 8},
            ]),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        await _gorunurYap(tester, find.text('7 km'));
        expect(_bolumde(find.text('Ayşe')), findsOneWidget);
        expect(find.text('5,5 km'), findsOneWidget);
        expect(_bolumde(find.text('Mert')), findsOneWidget);
        // Kişi yalnızca kendi değerini değiştirir.
        expect(
          find.byTooltip(arbMetni('bilesen_measure_kaldir')),
          findsOneWidget,
        );
        expect(find.text(arbMetni('bilesen_measure_kendi_gir')), findsNothing);

        await _dokun(
          tester,
          find.byTooltip(arbMetni('bilesen_measure_kaldir')),
        );
        await _dokun(tester, find.text(arbMetni('bilesen_measure_kaldir')));
        expect(tasima.giden('DELETE', olcumKaydiYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'distance',
          'user_id': katilimciId,
        });
        expect(find.text('7 km'), findsNothing);

        final gir = find.text(arbMetni('bilesen_measure_kendi_gir'));
        await _gorunurYap(tester, gir);
        await _dokun(tester, gir);
        expect(
          _formda(find.text(arbMetni('bilesen_measure_kisi_sec'))),
          findsNothing,
        );
        await tester.enterText(_degerAlani, '8');
        await _dokun(tester, _kaydet);
        final istek = tasima.giden('PUT', olcumKaydiYolu).single;
        expect(istek.yolParametreleri['user_id'], katilimciId);
        expect(istek.govde, {'value': 8});
        expect(find.byType(OlcumFormu), findsNothing);
        await _gorunurYap(tester, find.text('8 km'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('organizatör kişi seçerek girer; sunucu hatası formda kalır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var ilk = true;
      final tasima = _tasima(
        mesafe: (_) =>
            olcumJson(kapsam: 'personal', giren: 'organizer', yazabilir: true),
        yanitlar: {
          'PUT $olcumKaydiYolu': (_) {
            if (ilk) {
              ilk = false;
              return const ApiProblem(
                type: ProblemType.measurementNotParticipant,
                status: 409,
              );
            }
            return olcumJson(
              kapsam: 'personal',
              giren: 'organizer',
              kayitlar: [
                {'user_id': katilimciId, 'value': 3},
              ],
              yazabilir: true,
            );
          },
        },
      );
      await _detayiAc(tester, tasima);
      final ekle = find.text(arbMetni('bilesen_measure_kisi_ekle'));
      await _gorunurYap(tester, ekle);
      await _dokun(tester, ekle);
      expect(
        _formda(find.text(arbMetni('bilesen_measure_kisi_sec'))),
        findsOneWidget,
      );

      await tester.enterText(_degerAlani, '3');
      await _dokun(tester, _kaydet);
      expect(tasima.giden('PUT', olcumKaydiYolu), isEmpty);
      expect(
        _formda(find.text(arbMetni('bilesen_measure_kisi_sec_hata'))),
        findsOneWidget,
      );

      await _dokun(tester, _formda(find.text('Mert')));
      await _dokun(tester, _kaydet);
      expect(
        _formda(find.text(arbMetni('hata_measurement_not_participant'))),
        findsOneWidget,
      );
      expect(find.byType(OlcumFormu), findsOneWidget);

      await _dokun(tester, _kaydet);
      final istekler = tasima.giden('PUT', olcumKaydiYolu);
      expect(istekler, hasLength(2));
      expect(istekler.last.yolParametreleri['user_id'], katilimciId);
      expect(istekler.last.govde, {'value': 3});
      expect(find.byType(OlcumFormu), findsNothing);
      expect(find.text('3 km'), findsOneWidget);
    });

    testWidgets('katılımı doğrulanmamış kişiye neden giremediği söylenir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: katilimciId,
        katilim: null,
        mesafe: (_) => olcumJson(kapsam: 'personal', giren: 'self'),
      );
      await _detayiAc(tester, tasima);
      final not = find.text(arbMetni('bilesen_measure_katilim_notu'));
      await _gorunurYap(tester, not);
      expect(not, findsOneWidget);
      expect(find.text(arbMetni('bilesen_measure_kendi_gir')), findsNothing);
    });
  });
}
