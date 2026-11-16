import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/zaman/takvim_gunu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/arkadas/application/bos_vakit.dart';
import 'package:tayfam/features/arkadas/application/kisi_eylemleri.dart';
import 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/bos_vakit_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

/// Testlerin sabit anı: 16 Kasım 2026 Pazartesi, İstanbul'da 12.00.
final DateTime _simdi = DateTime.utc(2026, 11, 16, 9);

/// Sabit saatle ve [tasima]'yla açar; gerçek ağ yok.
Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override> ek = const [],
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: [
    ...arkadasOverridelari(tasima),
    simdiProvider.overrideWithValue(() => _simdi),
    ...ek,
  ],
);

/// Tembel kurulan listede [hedef] kurulana kadar kaydırır ([yukari] ise
/// başa doğru).
Future<void> _gorunur(
  WidgetTester tester,
  Finder hedef, {
  bool yukari = false,
}) async {
  if (hedef.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    hedef,
    yukari ? -200 : 200,
    scrollable: find.byType(Scrollable).first,
  );
}

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await _gorunur(tester, hedef);
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// Kendi üç günün (bugün, cumartesi notlu, cuma iki dilim) ve iki arkadaş:
/// biri bugün boş, biri cumartesi boş.
SahteTayfaTasima _doluTasima() => arkadasTasimasi({
  'GET $bosGunlerimYolu': yanit({
    'days': [
      bosGunJson('2026-11-16'),
      bosGunJson(
        '2026-11-21',
        dilimler: ['all_day'],
        not: 'Kampa gitmek isteyen?',
      ),
      bosGunJson('2026-11-27', dilimler: ['evening', 'morning']),
    ],
  }),
  'GET $arkadaslarYolu': yanit(
    arkadasListesiJson([
      arkadasJson(kisiId1, bosGun: '2026-11-16'),
      arkadasJson(kisiId2, bosGun: '2026-11-21'),
    ]),
  ),
  'GET $arkadasBosGunleriYolu': yanit({
    'days': [
      bosGunJson('2026-11-21', dilimler: ['all_day'], not: 'Kamp?'),
      bosGunJson('2026-12-05', dilimler: ['morning', 'afternoon']),
    ],
  }),
  'PUT $bosGunumYolu': (i) => bosGunJson(
    i.yolParametreleri['date']!,
    dilimler: [for (final d in (i.govde! as Map)['slots'] as List) d as String],
  ),
  'DELETE $bosGunumYolu': yanit(null),
});

/// "Mesaj gönder" yerine geçen sahte kişi eylemi.
Widget? _sahteMesaj(BuildContext context, KisiProfiliBilgisi kisi) =>
    kisi.arkadas ? const Text('Mesaj-düğmesi') : null;

final Map<String, Widget Function()> _ekranlar = {
  'boş vaktin': () => const BosVakitEkrani(),
  'boş gün ekle': () => const BosGunEkleEkrani(),
  'arkadaşlar (rozet)': () => const ArkadaslarEkrani(),
};

void main() {
  group('takvim günü', () {
    test('İstanbul bugünü UTC+3 ile hesaplanır', () {
      expect(
        istanbulBugunu(DateTime.utc(2026, 11, 16, 20, 59)),
        DateTime.utc(2026, 11, 16),
      );
      expect(
        istanbulBugunu(DateTime.utc(2026, 11, 16, 21)),
        DateTime.utc(2026, 11, 17),
      );
    });

    test('biçim ve geçersiz tarihler', () {
      expect(takvimGunuMetni(DateTime.utc(2026, 3, 7)), '2026-03-07');
      expect(takvimGunuOku('2026-03-07'), DateTime.utc(2026, 3, 7));
      expect(takvimGunuOku('2026-02-30'), isNull);
      expect(takvimGunuOku('2026-3-7'), isNull);
      expect(takvimGunuOku('2026-03-07T00:00:00Z'), isNull);
      expect(gunKaydir(DateTime.utc(2026, 11, 30), 1), DateTime.utc(2026, 12));
    });
  });

  group('dilimler ve not', () {
    test('sözleşme sırası; tüm gün tek başına', () {
      expect(
        dilimleriSirala([DaySlot.evening, DaySlot.morning, DaySlot.unknown]),
        [DaySlot.morning, DaySlot.evening],
      );
      expect(dilimleriSirala([DaySlot.morning, DaySlot.allDay]), [
        DaySlot.allDay,
      ]);
    });

    test('tüm gün diğerlerini, diğerleri tüm günü kaldırır', () {
      var s = <DaySlot>{};
      s = dilimDegistir(s, DaySlot.morning);
      s = dilimDegistir(s, DaySlot.evening);
      expect(s, {DaySlot.morning, DaySlot.evening});
      s = dilimDegistir(s, DaySlot.allDay);
      expect(s, {DaySlot.allDay});
      s = dilimDegistir(s, DaySlot.afternoon);
      expect(s, {DaySlot.afternoon});
      s = dilimDegistir(s, DaySlot.afternoon);
      expect(s, isEmpty);
    });

    test('not: yasak karakter süzülür, emoji birleştiricisi kalır', () {
      final zwsp = String.fromCharCode(0x200B);
      final rlo = String.fromCharCode(0x202E);
      final zwj = String.fromCharCode(0x200D);
      expect(notuHazirla('  Akşam\n$zwsp yürüyüş$rlo  '), 'Akşam yürüyüş');
      expect(notuHazirla('a${zwj}b'), 'a${zwj}b');
      expect(notuHazirla('  \n '), isNull);
    });
  });

  group('rozet günü', () {
    final bugun = DateTime.utc(2026, 11, 16);
    Friend arkadas(String? gun, {List<String> dilimler = const ['evening']}) =>
        Friend.fromJson({
          ...arkadasJson(kisiId1),
          if (gun != null) 'next_available': {'date': gun, 'slots': dilimler},
        });

    test('bugün … bugün + 6 içinde görünür', () {
      expect(rozetGunu(arkadas('2026-11-16'), bugun), bugun);
      expect(
        rozetGunu(arkadas('2026-11-22'), bugun),
        DateTime.utc(2026, 11, 22),
      );
    });

    test('pencere dışı, geçmiş, okunamayan ya da dilimsiz: rozet yok', () {
      expect(rozetGunu(arkadas(null), bugun), isNull);
      expect(rozetGunu(arkadas('2026-11-23'), bugun), isNull);
      expect(rozetGunu(arkadas('2026-11-15'), bugun), isNull);
      expect(rozetGunu(arkadas('16.11.2026'), bugun), isNull);
      expect(
        rozetGunu(arkadas('2026-11-17', dilimler: ['night']), bugun),
        isNull,
      );
    });
  });

  group('notifier', () {
    ProviderContainer kap(SahteTayfaTasima tasima) {
      final c = ProviderContainer(overrides: arkadasOverridelari(tasima));
      addTearDown(c.dispose);
      return c;
    }

    test('kaydet: dilimler sıralı, not kırpılmış gider', () async {
      final tasima = _doluTasima();
      final c = kap(tasima);
      final abone = c.listen(bosVakitlerimProvider, (_, _) {});
      addTearDown(abone.close);
      await c.read(bosVakitlerimProvider.future);
      final hata = await c.read(bosVakitlerimProvider.notifier).kaydet(
        DateTime.utc(2026, 11, 18),
        {DaySlot.evening, DaySlot.morning},
        '  Çay?  ',
      );
      expect(hata, isNull);
      final istek = tasima.giden('PUT', bosGunumYolu).single;
      expect(istek.yolParametreleri['date'], '2026-11-18');
      expect(istek.govde, {
        'slots': ['morning', 'evening'],
        'note': 'Çay?',
      });
      expect(
        c.read(bosVakitlerimProvider).value!.map((g) => g.date),
        contains('2026-11-18'),
      );
    });

    test('boş not gönderilmez', () async {
      final tasima = _doluTasima();
      final c = kap(tasima);
      final abone = c.listen(bosVakitlerimProvider, (_, _) {});
      addTearDown(abone.close);
      await c.read(bosVakitlerimProvider.future);
      await c.read(bosVakitlerimProvider.notifier).kaydet(
        DateTime.utc(2026, 11, 18),
        {DaySlot.allDay},
        '   ',
      );
      expect(tasima.giden('PUT', bosGunumYolu).single.govde, {
        'slots': ['all_day'],
      });
    });

    test('çoklu kaydetme bir gün düşünce durur, kalanı döner', () async {
      final tasima = _doluTasima();
      tasima.yanitlar['PUT $bosGunumYolu'] = (i) =>
          i.yolParametreleri['date'] == '2026-11-19'
          ? const ApiProblem(type: ProblemType.invalidRequest, status: 400)
          : bosGunJson(i.yolParametreleri['date']!);
      final c = kap(tasima);
      final abone = c.listen(bosVakitlerimProvider, (_, _) {});
      addTearDown(abone.close);
      await c.read(bosVakitlerimProvider.future);
      final sonuc = await c
          .read(bosVakitlerimProvider.notifier)
          .cokluKaydet(
            [
              DateTime.utc(2026, 11, 20),
              DateTime.utc(2026, 11, 18),
              DateTime.utc(2026, 11, 19),
            ],
            {DaySlot.morning},
            '',
          );
      expect(sonuc.hata, isA<ApiProblem>());
      expect(sonuc.kalan, [
        DateTime.utc(2026, 11, 19),
        DateTime.utc(2026, 11, 20),
      ]);
      expect(
        [
          for (final i in tasima.giden('PUT', bosGunumYolu))
            i.yolParametreleri['date'],
        ],
        ['2026-11-18', '2026-11-19'],
      );
    });

    test('sil: gün listeden çıkar', () async {
      final tasima = _doluTasima();
      final c = kap(tasima);
      final abone = c.listen(bosVakitlerimProvider, (_, _) {});
      addTearDown(abone.close);
      await c.read(bosVakitlerimProvider.future);
      final hata = await c
          .read(bosVakitlerimProvider.notifier)
          .sil(DateTime.utc(2026, 11, 21));
      expect(hata, isNull);
      expect(
        tasima.giden('DELETE', bosGunumYolu).single.yolParametreleri['date'],
        '2026-11-21',
      );
      expect(
        c.read(bosVakitlerimProvider).value!.map((g) => g.date),
        isNot(contains('2026-11-21')),
      );
    });
  });

  group('iki tema, 2× yazı, 320 dp', () {
    for (final MapEntry(key: ad, value: ekran) in _ekranlar.entries) {
      for (final tema in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$ad (${tema.name}) taşmaz', (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _ac(tester, ekran(), _doluTasima(), themeMode: tema);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('boş vaktin, gün yok (${tema.name}) taşmaz', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const BosVakitEkrani(),
          arkadasTasimasi(),
          themeMode: tema,
        );
        await _gorunur(tester, find.text(arbMetni('bosum_liste_bos')));
        expect(find.text(arbMetni('bosum_liste_bos')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('düzenleme sayfası (${tema.name}) taşmaz', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const BosVakitEkrani(),
          _doluTasima(),
          themeMode: tema,
        );
        await _dokun(tester, find.text('“Kampa gitmek isteyen?”'));
        expect(find.text(arbMetni('bosum_sil')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('arkadaşın günleri (${tema.name}) taşmaz', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const ArkadaslarEkrani(),
          _doluTasima(),
          themeMode: tema,
          ek: [
            kisiProfiliEylemleriProvider.overrideWithValue(const [_sahteMesaj]),
          ],
        );
        await _dokun(
          tester,
          find.textContaining(arbMetni('bosum_rozet_bugun')),
        );
        expect(find.text('Mesaj-düğmesi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('boş vaktin', () {
    testWidgets('açıklama, günler ve notlar', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const BosVakitEkrani(), _doluTasima());
      expect(find.text(arbMetni('bosum_aciklama')), findsOneWidget);
      expect(find.text(arbMetni('bosum_bugun')), findsOneWidget);
      expect(find.text('21 Kasım Cumartesi'), findsOneWidget);
      expect(find.text('“Kampa gitmek isteyen?”'), findsOneWidget);
      // Dilimler sözleşme sırasıyla.
      expect(find.text('Sabah · Akşam'), findsOneWidget);
      expect(find.text(arbMetni('bosum_dilim_tum_gun')), findsOneWidget);
    });

    testWidgets('gün yoksa boş metni', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const BosVakitEkrani(), arkadasTasimasi());
      expect(find.text(arbMetni('bosum_liste_bos')), findsOneWidget);
    });

    testWidgets('ilk yükleme hatasında Tekrar dene', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'GET $bosGunlerimYolu': yanit(const ApiOffline()),
      });
      await _ac(tester, const BosVakitEkrani(), tasima);
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      tasima.yanitlar['GET $bosGunlerimYolu'] = yanit({'days': <Object?>[]});
      await _dokun(tester, find.text(arbMetni('yukleme_hatasi_tekrar_dene')));
      expect(find.text(arbMetni('bosum_liste_bos')), findsOneWidget);
    });

    testWidgets('düzenleme: dilim değişir ve kaydedilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima();
      await _ac(tester, const BosVakitEkrani(), tasima);
      await _dokun(tester, find.text('“Kampa gitmek isteyen?”'));
      // Tüm gün seçili; sabah seçilince tüm gün kalkar.
      await _dokun(
        tester,
        find.widgetWithText(FilterChip, arbMetni('bosum_dilim_sabah')),
      );
      await _dokun(tester, find.text(arbMetni('bosum_kaydet')));
      final istek = tasima.giden('PUT', bosGunumYolu).single;
      expect(istek.yolParametreleri['date'], '2026-11-21');
      expect(istek.govde, {
        'slots': ['morning'],
        'note': 'Kampa gitmek isteyen?',
      });
      // Sayfa kapandı, satır güncellendi.
      expect(find.text(arbMetni('bosum_sil')), findsNothing);
      expect(find.text(arbMetni('bosum_dilim_tum_gun')), findsNothing);
    });

    testWidgets('düzenleme: Bu günü sil', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima();
      await _ac(tester, const BosVakitEkrani(), tasima);
      await _dokun(tester, find.text('“Kampa gitmek isteyen?”'));
      await _dokun(tester, find.text(arbMetni('bosum_sil')));
      expect(
        tasima.giden('DELETE', bosGunumYolu).single.yolParametreleri['date'],
        '2026-11-21',
      );
      expect(find.text('21 Kasım Cumartesi'), findsNothing);
    });

    testWidgets('düzenleme hatası sayfada kalır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima();
      tasima.yanitlar['DELETE $bosGunumYolu'] = yanit(const ApiOffline());
      await _ac(tester, const BosVakitEkrani(), tasima);
      await _dokun(tester, find.text('“Kampa gitmek isteyen?”'));
      await _dokun(tester, find.text(arbMetni('bosum_sil')));
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      expect(find.text(arbMetni('bosum_sil')), findsOneWidget);
    });
  });

  group('boş gün ekle', () {
    testWidgets('ekli gün seçilemez; gün ve dilim seçilince kaydedilir', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = _doluTasima();
      await _ac(tester, const BosGunEkleEkrani(), tasima);
      final kaydet = find.widgetWithText(
        FilledButton,
        arbMetni('bosum_kaydet'),
      );
      // 21 Kasım ekli: devre dışı.
      final ekli = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Cmt 21'),
      );
      expect(ekli.onSelected, isNull);
      expect(find.bySemanticsLabel('21 Kasım Cumartesi, zaten ekli'), findsOne);
      // Gün yokken kaydet kapalı.
      expect(tester.widget<FilledButton>(kaydet).onPressed, isNull);
      await _dokun(tester, find.widgetWithText(FilterChip, 'Çar 18'));
      await _dokun(tester, find.widgetWithText(FilterChip, 'Paz 22'));
      // Dilim yokken de kapalı.
      final iki = find.widgetWithText(FilledButton, '2 günü kaydet');
      expect(tester.widget<FilledButton>(iki).onPressed, isNull);
      await _dokun(
        tester,
        find.widgetWithText(FilterChip, arbMetni('bosum_dilim_aksam')),
      );
      await tester.enterText(find.byType(TextField), 'Film?');
      await _dokun(tester, iki);
      final giden = tasima.giden('PUT', bosGunumYolu);
      expect(
        [for (final i in giden) i.yolParametreleri['date']],
        ['2026-11-18', '2026-11-22'],
      );
      for (final i in giden) {
        expect(i.govde, {
          'slots': ['evening'],
          'note': 'Film?',
        });
      }
    });

    testWidgets('kaydetme hatası: kalan günler seçili, hata görünür', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = _doluTasima();
      tasima.yanitlar['PUT $bosGunumYolu'] = (i) =>
          i.yolParametreleri['date'] == '2026-11-22'
          ? const ApiOffline()
          : bosGunJson(i.yolParametreleri['date']!);
      await _ac(tester, const BosGunEkleEkrani(), tasima);
      await _dokun(tester, find.widgetWithText(FilterChip, 'Çar 18'));
      await _dokun(tester, find.widgetWithText(FilterChip, 'Paz 22'));
      await _dokun(
        tester,
        find.widgetWithText(FilterChip, arbMetni('bosum_dilim_sabah')),
      );
      await _dokun(tester, find.text('2 günü kaydet'));
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      // 18 kaydedildi: artık ekli; 22 hâlâ seçili.
      await _gorunur(
        tester,
        find.widgetWithText(FilterChip, 'Çar 18'),
        yukari: true,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Çar 18'))
            .onSelected,
        isNull,
      );
      expect(find.text('1 günü kaydet'), findsOneWidget);
    });

    testWidgets('not 60 kod noktasında durur, satır sonu süzülür', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 900);
      await _ac(tester, const BosGunEkleEkrani(), _doluTasima());
      await _gorunur(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'a\nb');
      await tester.pump();
      expect(find.text('ab'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'x' * 61);
      await tester.pump();
      expect(find.text('2/60'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'x' * 60);
      await tester.pump();
      expect(find.text('60/60'), findsOneWidget);
    });
  });

  group('arkadaş listesinde rozet', () {
    testWidgets('bugün ve gün adıyla; giriş satırı sayıyla', (tester) async {
      final anlam = tester.ensureSemantics();
      ekranBoyutu(tester, yukseklik: 900);
      await _ac(tester, const ArkadaslarEkrani(), _doluTasima());
      expect(
        find.textContaining(arbMetni('bosum_rozet_bugun')),
        findsOneWidget,
      );
      expect(find.textContaining('Cumartesi boş'), findsOneWidget);
      expect(find.text('3 gün boşsun · arkadaşların görür'), findsOneWidget);
      // Rozet satırın düğmesine birleşmez: ayrı, dokunulabilir düğüm.
      final rozet = find.bySemanticsLabel(
        'Kişi 2: Cumartesi boş. Boş günlerini gör',
      );
      expect(rozet, findsOneWidget);
      expect(
        tester.getSemantics(rozet),
        matchesSemantics(
          label: 'Kişi 2: Cumartesi boş. Boş günlerini gör',
          isButton: true,
          hasTapAction: true,
        ),
      );
      anlam.dispose();
    });

    testWidgets('rozet yoksa ya da pencere dışındaysa görünmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'GET $arkadaslarYolu': yanit(
          arkadasListesiJson([
            arkadasJson(kisiId1),
            arkadasJson(kisiId2, bosGun: '2026-11-30'),
          ]),
        ),
      });
      await _ac(tester, const ArkadaslarEkrani(), tasima);
      expect(find.textContaining(' boş'), findsNothing);
      expect(find.text(arbMetni('bosum_giris_yok')), findsOneWidget);
    });

    testWidgets('rozete dokununca günler ve mesaj eylemi', (tester) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = _doluTasima();
      await _ac(
        tester,
        const ArkadaslarEkrani(),
        tasima,
        ek: [
          kisiProfiliEylemleriProvider.overrideWithValue(const [_sahteMesaj]),
        ],
      );
      await _dokun(tester, find.textContaining('Cumartesi boş'));
      expect(
        tasima.giden('GET', arkadasBosGunleriYolu).single.yolParametreleri,
        {'user_id': kisiId2},
      );
      expect(find.text(arbMetni('bosum_arkadas_alt')), findsOneWidget);
      expect(find.text('“Kamp?”'), findsOneWidget);
      expect(find.text('5 Aralık Cumartesi'), findsOneWidget);
      expect(find.text('Sabah · Öğleden sonra'), findsOneWidget);
      expect(find.text('Mesaj-düğmesi'), findsOneWidget);
    });

    testWidgets('görünmüyorsa ortak metin, mesaj eylemi yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = _doluTasima();
      tasima.yanitlar['GET $arkadasBosGunleriYolu'] = yanit(
        const ApiProblem(type: ProblemType.userNotFound, status: 404),
      );
      await _ac(
        tester,
        const ArkadaslarEkrani(),
        tasima,
        ek: [
          kisiProfiliEylemleriProvider.overrideWithValue(const [_sahteMesaj]),
        ],
      );
      await _dokun(tester, find.textContaining('Cumartesi boş'));
      expect(
        find.text(arbMetni('profil_goruntulenemiyor_baslik')),
        findsOneWidget,
      );
      expect(find.text('Mesaj-düğmesi'), findsNothing);
    });

    testWidgets('boş ve hata durumları', (tester) async {
      ekranBoyutu(tester, yukseklik: 900);
      final tasima = _doluTasima();
      tasima.yanitlar['GET $arkadasBosGunleriYolu'] = yanit(const ApiOffline());
      await _ac(tester, const ArkadaslarEkrani(), tasima);
      await _dokun(tester, find.textContaining('Cumartesi boş'));
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      tasima.yanitlar['GET $arkadasBosGunleriYolu'] = yanit({
        'days': <Object?>[],
      });
      await _dokun(tester, find.text(arbMetni('yukleme_hatasi_tekrar_dene')));
      expect(find.text(arbMetni('bosum_arkadas_bos')), findsOneWidget);
    });
  });
}
