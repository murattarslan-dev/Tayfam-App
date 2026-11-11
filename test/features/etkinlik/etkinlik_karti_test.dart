import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import '../duyuru/sahteler.dart';

Event _etkinlik({
  String tur = 'convoy',
  String mod = 'in_person',
  String? yer = 'Moda Sahili',
  String? il,
  String? ilce,
  int kontenjan = 0,
  int gelen = 4,
  int bekleme = 0,
  String durum = 'scheduled',
  String? cevap,
  String baslik = 'Sabah konvoyu',
}) => Event.fromJson(
  etkinlikJson(
    etkinlikId1,
    tur: tur,
    mod: mod,
    yer: yer,
    il: il,
    ilce: ilce,
    kontenjan: kontenjan,
    gelen: gelen,
    bekleme: bekleme,
    durum: durum,
    cevap: cevap,
    baslik: baslik,
  ),
);

Future<void> _ac(
  WidgetTester tester,
  Event etkinlik, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(TayfamSpacing.kenarMobil),
      children: [EtkinlikKarti(etkinlik: etkinlik)],
    ),
  ),
  themeMode: themeMode,
);

AppLocalizations _metinler(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(EtkinlikKarti)));

void main() {
  testWidgets('tür çipi, başlık, zaman, yer ve katılım', (tester) async {
    ekranBoyutu(tester);
    final etkinlik = _etkinlik();
    await _ac(tester, etkinlik);

    final cip = tester.widget<EtkinlikTuruCipi>(find.byType(EtkinlikTuruCipi));
    expect(cip.tur, EventType.convoy);
    expect(find.text(arbMetni('etkinlik_turu_convoy')), findsOneWidget);
    expect(find.text('Sabah konvoyu'), findsOneWidget);
    final m = _metinler(tester);
    expect(find.text(etkinlikZamani(m, etkinlik.startsAt)), findsOneWidget);
    expect(find.text('Moda Sahili'), findsOneWidget);
    expect(find.text('4 kişi geliyor'), findsOneWidget);
    expect(find.text(arbMetni('etkinlik_karti_iptal')), findsNothing);
  });

  testWidgets('zaman cihazın saatinde; Türkiye dışındaysa dilim yazılı', (
    tester,
  ) async {
    ekranBoyutu(tester);
    final etkinlik = _etkinlik();
    await _ac(tester, etkinlik);

    final yerel = etkinlik.startsAt.toLocal();
    final metin = etkinlikZamani(_metinler(tester), etkinlik.startsAt);
    final dakika = yerel.minute.toString().padLeft(2, '0');
    expect(metin, contains('${yerel.hour.toString().padLeft(2, '0')}:$dakika'));
    expect(metin, contains('${yerel.day}'));
    if (yerel.timeZoneOffset == turkiyeSaatFarki) {
      expect(metin, isNot(contains('(')));
    } else {
      expect(metin, endsWith('(${yerel.timeZoneName})'));
    }
  });

  test('yer: çevrimiçi, nokta adı, ilçe ve il', () {
    final m = lookupAppLocalizations(const Locale('tr'));
    expect(
      etkinlikYeri(m, _etkinlik(mod: 'online', yer: null)),
      arbMetni('etkinlik_karti_cevrimici'),
    );
    expect(etkinlikYeri(m, _etkinlik()), 'Moda Sahili');
    expect(
      etkinlikYeri(m, _etkinlik(yer: null, ilce: 'Kadıköy', il: 'İstanbul')),
      'Kadıköy, İstanbul',
    );
    expect(etkinlikYeri(m, _etkinlik(yer: null, il: 'İzmir')), 'İzmir');
    expect(etkinlikYeri(m, _etkinlik(yer: null)), isNull);
  });

  test('cevap metinleri', () {
    final m = lookupAppLocalizations(const Locale('tr'));
    expect(
      etkinlikCevabi(m, RsvpStatus.going),
      arbMetni('etkinlik_karti_cevap_geliyorum'),
    );
    expect(
      etkinlikCevabi(m, RsvpStatus.waitlist),
      arbMetni('etkinlik_karti_cevap_bekleme'),
    );
    expect(etkinlikCevabi(m, RsvpStatus.unknown), isNull);
    expect(etkinlikCevabi(m, null), isNull);
  });

  testWidgets('kontenjan, bekleme listesi ve cevap', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      _etkinlik(kontenjan: 10, gelen: 10, bekleme: 2, cevap: 'waitlist'),
    );

    expect(find.text('10/10 kişi geliyor'), findsOneWidget);
    expect(find.text('2 kişi bekleme listesinde'), findsOneWidget);
    expect(find.text(arbMetni('etkinlik_karti_cevap_bekleme')), findsOneWidget);
  });

  testWidgets('çevrimiçi etkinlikte yer yerine "Çevrimiçi"', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, _etkinlik(mod: 'online', yer: null, tur: 'gaming'));

    expect(find.text(arbMetni('etkinlik_karti_cevrimici')), findsOneWidget);
    expect(find.text(arbMetni('etkinlik_turu_gaming')), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    final r = mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;

    testWidgets('${mod.name}: iptal edilen kart soluk ve etiketli', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(tester, _etkinlik(durum: 'cancelled'), themeMode: mod);

      expect(find.text(arbMetni('etkinlik_karti_iptal')), findsOneWidget);
      expect(find.byType(Etiket), findsOneWidget);
      final baslik = tester.widget<Text>(find.text('Sabah konvoyu'));
      expect(baslik.style?.color, r.metinIkincil);
    });

    testWidgets('${mod.name}: 2× yazıda 320 dp taşmıyor', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(
        tester,
        _etkinlik(
          baslik: 'Çok uzun başlıklı bir hafta sonu konvoy buluşması',
          yer: 'Çok uzun adlı bir buluşma noktası, sahil yolu üzeri',
          kontenjan: 120,
          gelen: 118,
          bekleme: 12,
          cevap: 'going',
          durum: 'cancelled',
        ),
        themeMode: mod,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
