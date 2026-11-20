import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/derece/derece_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  DereceBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(id, id == organizatorId ? 'Ayşe' : 'Mert', ben: id == ben);
}

/// [tur] türünde (katalog fikstüründe koşu: ölçümden, yüzme: elle süre)
/// başlamış bir etkinlik; derece ucu [derece]'dir. Oturumdaki kullanıcı
/// [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti derece,
  String tur = 'swimming',
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = organizatorId,
  DateTime? baslangic,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: tur,
      cevap: 'going',
      katilim: baslangic == null ? 'attended' : null,
      baslangic: baslangic ?? gecmisBaslangic,
      sure: const Duration(hours: 3),
    ),
    'GET $dereceYolu': derece,
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
    find.descendant(of: find.byType(DereceFormu), matching: bulucu);

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(DereceBolumu), matching: bulucu);

Finder get _degerAlani => _formda(find.byType(TextField));

Finder get _kaydet => _formda(find.text(arbMetni('etkinlik_kaydet')));

EventRanking _derece(Map<String, Object?> json) => EventRanking.fromJson(json);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe derece bileşenini kullanan türler var', () {
    final kosu = turBilesenleri(testTuru('running'))
        .where((b) => b.kind == 'ranking')
        .single;
    expect(bilesenAnahtari(kosu), 'ranking');
    expect(BilesenParametreleri(kosu.params).metin('source'), 'duration');
    final yuzme = turBilesenleri(testTuru('swimming'))
        .where((b) => b.kind == 'ranking')
        .single;
    expect(BilesenParametreleri(yuzme.params).metin('metric'), 'duration');
  });

  group('süre', () {
    test('Türkçe yazılır: saat varsa s:dd:ss, salise virgülle', () {
      expect(sureMetni(m, 3723.45), '1:02:03,45');
      expect(sureMetni(m, 3723.4), '1:02:03,40');
      expect(sureMetni(m, 2700), '45:00');
      expect(sureMetni(m, 45.5), '0:45,50');
      expect(sureMetni(m, 36000), '10:00:00');
      expect(sureMetni(m, dereceSureEnCok), '277:46:40');
    });

    test('ekran okuyucu metni birimleriyle', () {
      expect(sureOkunusu(m, 3723.45), '1 saat 2 dakika 3,45 saniye');
      expect(sureOkunusu(m, 2700), '45 dakika');
      expect(sureOkunusu(m, 3600), '1 saat');
      expect(sureOkunusu(m, 0.5), '0,50 saniye');
    });

    test('girdi: s:dd:ss, dd:ss ya da saniye; virgül de nokta da', () {
      expect(sureGirdisiniOku('1:02:03,45').deger, 3723.45);
      expect(sureGirdisiniOku(' 62:03.4 ').deger, 3723.4);
      expect(sureGirdisiniOku('45,5').deger, 45.5);
      expect(sureGirdisiniOku('3723').deger, 3723);
      expect(sureGirdisiniOku('0:00:01').deger, 1);
      expect(sureGirdisiniOku('').hata, DereceHatasi.zorunlu);
      expect(sureGirdisiniOku('1:75').hata, DereceHatasi.bicim);
      expect(sureGirdisiniOku('1:60:00').hata, DereceHatasi.bicim);
      expect(sureGirdisiniOku('1:2:3:4').hata, DereceHatasi.bicim);
      expect(sureGirdisiniOku('1::03').hata, DereceHatasi.bicim);
      expect(sureGirdisiniOku('a:03').hata, DereceHatasi.bicim);
      expect(sureGirdisiniOku('3,456').hata, DereceHatasi.basamak);
      expect(sureGirdisiniOku('0').hata, DereceHatasi.aralik);
      expect(sureGirdisiniOku('0:00,00').hata, DereceHatasi.aralik);
      expect(sureGirdisiniOku('277:46:40').deger, dereceSureEnCok);
      expect(sureGirdisiniOku('277:46:40,01').hata, DereceHatasi.aralik);
      expect(sureGirdisiniOku('9999999999').hata, DereceHatasi.aralik);
    });

    test('elle sıra 1–10000 arası tam sayı', () {
      expect(siraGirdisiniOku('3').deger, 3);
      expect(siraGirdisiniOku('0').hata, DereceHatasi.aralik);
      expect(siraGirdisiniOku('10001').hata, DereceHatasi.aralik);
      expect(siraGirdisiniOku('2,5').hata, DereceHatasi.bicim);
      expect(siraGirdisiniOku('').hata, DereceHatasi.zorunlu);
    });

    test('değer derecenin türüne göre yazılır', () {
      final sure = _derece(dereceJson());
      expect(dereceDegeriMetni(m, sure, 3723.45), '1:02:03,45');
      expect(
        dereceDegeriOkunusu(m, sure, 3723.45),
        '1 saat 2 dakika 3,45 saniye',
      );
      expect(dereceDegeriMetni(m, _derece(dereceJson(olcut: 'rank')), 2), null);
      final olcumden = _derece(
        dereceJson(kaynak: 'duration', birim: 'km', basamak: 2),
      );
      expect(dereceDegeriMetni(m, olcumden, 12.4), '12,4 km');
      expect(dereceDegeriOkunusu(m, olcumden, 12.4), null);
      expect(
        dereceHataMetni(m, sure, DereceHatasi.aralik),
        m.bilesen_ranking_sure_aralik('277:46:40'),
      );
    });
  });

  group('ölçümden hesaplanan derece', () {
    for (final tema in _temalar) {
      testWidgets('eşitler aynı sırada, kendi satırı "Sen"; satır tek öğe '
          'okunur (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          tur: 'running',
          ben: katilimciId,
          derece: (_) => dereceJson(
            kaynak: 'duration',
            birim: 'minute',
            basamak: 2,
            kayitlar: [
              dereceKaydiJson(organizatorId, 30.5, 1),
              dereceKaydiJson(katilimciId, 30.5, 1),
            ],
          ),
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final not = _bolumde(find.text(m.bilesen_ranking_olcumden));
        await _gorunurYap(tester, not);
        expect(not, findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_ranking_sira(1))),
          findsNWidgets(2),
        );
        final deger = m.katalog_birimli_deger('30,5', m.katalog_birim_minute);
        expect(_bolumde(find.text(deger)), findsNWidgets(2));
        expect(_bolumde(find.text(m.bilesen_ranking_sen)), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(
              '${RegExp.escape(m.bilesen_ranking_sira_okunus(1))}'
              r'[\s\S]*Mert[\s\S]*'
              '${RegExp.escape(m.bilesen_ranking_sen)}'
              r'[\s\S]*'
              '${RegExp.escape(deger)}',
            ),
          ),
          findsOneWidget,
        );
        // Ölçümden hesaplanan derece elle girilmez.
        expect(_bolumde(find.text(m.bilesen_ranking_kisi_ekle)), findsNothing);
        expect(find.byTooltip(m.bilesen_ranking_duzelt), findsNothing);
        expect(tasima.giden('GET', dereceYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'ranking',
        });
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    testWidgets('hassas ölçümde derece gösterilmez, nedeni yazılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'running',
        ben: katilimciId,
        derece: (_) => dereceJson(kaynak: 'duration', gizli: true),
      );
      await _detayiAc(tester, tasima);
      final gizli = _bolumde(find.text(m.bilesen_ranking_gizli));
      await _gorunurYap(tester, gizli);
      expect(gizli, findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_ranking_sira(1))), findsNothing);
      expect(_bolumde(find.text(m.bilesen_ranking_olcum_yok)), findsNothing);
    });

    testWidgets('kaynak ölçüm kapalıysa söylenir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'running',
        derece: (_) => dereceJson(kaynak: 'duration', olcumAcik: false),
      );
      await _detayiAc(tester, tasima);
      final kapali = _bolumde(find.text(m.bilesen_ranking_olcum_kapali));
      await _gorunurYap(tester, kapali);
      expect(kapali, findsOneWidget);
    });
  });

  group('elle girilen süre', () {
    for (final tema in _temalar) {
      testWidgets('organizatör düzeltir ve kaldırır '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        Map<String, Object?> elle(List<Map<String, Object?>> kayitlar) =>
            dereceJson(kayitlar: kayitlar, yazabilir: true);
        final tasima = _tasima(
          derece: (_) => elle([dereceKaydiJson(katilimciId, 3723.45, 1)]),
          yanitlar: {
            'PUT $dereceKaydiYolu': (_) =>
                elle([dereceKaydiJson(katilimciId, 3723.4, 1)]),
            'DELETE $dereceKaydiYolu': (_) => elle(const []),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        await _gorunurYap(tester, _bolumde(find.text('1:02:03,45')));
        expect(_bolumde(find.text('Mert')), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_ranking_sen)), findsNothing);

        await _dokun(tester, find.byTooltip(m.bilesen_ranking_duzelt));
        expect(_formda(find.text(m.bilesen_ranking_kisi_sec)), findsNothing);
        expect(_formda(find.text('1:02:03,45')), findsOneWidget);
        await tester.enterText(_degerAlani, '1:75');
        await _dokun(tester, _kaydet);
        expect(
          _formda(find.text(m.bilesen_ranking_sure_bicim)),
          findsOneWidget,
        );
        expect(tasima.giden('PUT', dereceKaydiYolu), isEmpty);

        await tester.enterText(_degerAlani, '62:03,4');
        await _dokun(tester, _kaydet);
        final istek = tasima.giden('PUT', dereceKaydiYolu).single;
        expect(istek.yolParametreleri['user_id'], katilimciId);
        expect(istek.govde, {'value': 3723.4});
        expect(find.byType(DereceFormu), findsNothing);
        await _gorunurYap(tester, _bolumde(find.text('1:02:03,40')));

        await _dokun(tester, find.byTooltip(m.bilesen_ranking_kaldir));
        await _dokun(tester, find.text(m.bilesen_ranking_kaldir).last);
        expect(tasima.giden('DELETE', dereceKaydiYolu), hasLength(1));
        await _gorunurYap(tester, _bolumde(find.text(m.bilesen_ranking_yok)));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kişi seçerek girer; sunucu hatası formda kalır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var ilk = true;
      final tasima = _tasima(
        derece: (_) => dereceJson(yazabilir: true),
        yanitlar: {
          'PUT $dereceKaydiYolu': (_) {
            if (ilk) {
              ilk = false;
              return const ApiProblem(
                type: ProblemType.rankingNotParticipant,
                status: 409,
              );
            }
            return dereceJson(
              kayitlar: [dereceKaydiJson(katilimciId, 45.5, 1)],
              yazabilir: true,
            );
          },
        },
      );
      await _detayiAc(tester, tasima);
      final ekle = _bolumde(find.text(m.bilesen_ranking_kisi_ekle));
      await _gorunurYap(tester, ekle);
      await _dokun(tester, ekle);
      expect(_formda(find.text(m.bilesen_ranking_kisi_sec)), findsOneWidget);

      await tester.enterText(_degerAlani, '45,5');
      await _dokun(tester, _kaydet);
      expect(tasima.giden('PUT', dereceKaydiYolu), isEmpty);
      expect(
        _formda(find.text(m.bilesen_ranking_kisi_sec_hata)),
        findsOneWidget,
      );

      await _dokun(tester, _formda(find.text('Mert')));
      await _dokun(tester, _kaydet);
      expect(
        _formda(find.text(m.hata_ranking_not_participant)),
        findsOneWidget,
      );
      expect(find.byType(DereceFormu), findsOneWidget);

      await _dokun(tester, _kaydet);
      final istekler = tasima.giden('PUT', dereceKaydiYolu);
      expect(istekler, hasLength(2));
      expect(istekler.last.govde, {'value': 45.5});
      expect(find.byType(DereceFormu), findsNothing);
      expect(_bolumde(find.text('0:45,50')), findsOneWidget);
    });

    testWidgets('elle sıra: değer ayrıca yazılmaz', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        derece: (_) => dereceJson(
          olcut: 'rank',
          kayitlar: [dereceKaydiJson(katilimciId, 2, 2)],
        ),
      );
      await _detayiAc(tester, tasima);
      final sira = _bolumde(find.text(m.bilesen_ranking_sira(2)));
      await _gorunurYap(tester, sira);
      expect(sira, findsOneWidget);
      expect(_bolumde(find.text('2')), findsNothing);
      expect(_bolumde(find.text(m.bilesen_ranking_kisi_ekle)), findsNothing);
    });

    testWidgets('etkinlik başlamadan boş metni', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        derece: (_) => dereceJson(),
        baslangic: ornekBaslangic,
      );
      await _detayiAc(tester, tasima);
      final bos = _bolumde(find.text(m.bilesen_ranking_baslamadi));
      await _gorunurYap(tester, bos);
      expect(bos, findsOneWidget);
    });
  });
}
