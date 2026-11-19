import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/hedef/hedef_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_bileseni.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../core/realtime/sahte_soket.dart';
import '../../../core/zaman_sahteleri.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  OlcumBileseni(),
  HedefBileseni(),
];

const HedefKimligi _kimlik = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
  anahtar: 'goal',
  olcumAnahtari: 'distance',
);

/// Doğa yürüyüşü (katalog fikstüründe mesafeye bağlı, varsayılan hedefi
/// 10 km olan `goal` bileşeni var). [hedef] hedefin yanıtıdır.
SahteTayfaTasima _tasima({
  required TayfaYaniti hedef,
  Map<String, TayfaYaniti> yanitlar = const {},
}) => etkinlikTasimasi({
  'GET $etkinlikYolu': (_) => etkinlikJson(
    tur: 'hike',
    cevap: 'going',
    katilim: 'attended',
    baslangic: gecmisBaslangic,
    sure: const Duration(hours: 6),
  ),
  'GET $hedefYolu': hedef,
  ...yanitlar,
});

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
    find.descendant(of: find.byType(HedefFormu), matching: bulucu);

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(HedefBolumu), matching: bulucu);

Finder get _degerAlani => _formda(find.byType(TextField));

Finder get _kaydet => _formda(find.text(arbMetni('etkinlik_kaydet')));

EventGoal _hedef(Map<String, Object?> json) => EventGoal.fromJson(json);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe hedef bileşenini kullanan tür var', () {
    final hedefler = turBilesenleri(
      testTuru('hike'),
    ).where((b) => b.kind == 'goal').toList();
    expect(hedefler, hasLength(1));
    expect(bilesenAnahtari(hedefler.single), 'goal');
    final params = BilesenParametreleri(hedefler.single.params);
    expect(params.metin('measure'), 'distance');
    expect(params.sayi('default_target'), 10);
  });

  group('sayılar', () {
    test('yüzde aşağı yuvarlanır, hedefi aşınca 100\'ü geçer', () {
      expect(hedefYuzdesi(_hedef(hedefJson(mevcut: 4.5))), 45);
      expect(hedefYuzdesi(_hedef(hedefJson(hedef: 12.5, mevcut: 4.5))), 36);
      expect(hedefYuzdesi(_hedef(hedefJson(mevcut: 9.999))), 99);
      expect(hedefYuzdesi(_hedef(hedefJson(mevcut: 12))), 120);
      expect(hedefYuzdesi(_hedef(hedefJson(gizli: true))), isNull);
      expect(hedefYuzdesi(_hedef(hedefJson(hedef: null))), isNull);

      expect(hedefOrani(_hedef(hedefJson(mevcut: 9.999))), 0.99);
      expect(hedefOrani(_hedef(hedefJson(mevcut: 12))), 1);
      expect(hedefOrani(_hedef(hedefJson(mevcut: 0))), 0);

      final hedef = _hedef(hedefJson());
      expect(hedefDegeriMetni(m, hedef, 12.5), '12,5 km');
      expect(hedefDegeriMetni(m, hedef, 10), '10 km');
    });

    test('hedef sıfırdan büyük olmalı; basamak denetlenir', () {
      final mesafe = _hedef(hedefJson());
      expect(hedefEnAz(mesafe), 0.01);
      expect(hedefGirdisiniOku(mesafe, '0').hata, AlanHatasi.aralik);
      expect(hedefGirdisiniOku(mesafe, '0,01').deger, 0.01);
      expect(hedefGirdisiniOku(mesafe, ' 12.5 ').deger, 12.5);
      expect(hedefGirdisiniOku(mesafe, '12,456').hata, AlanHatasi.basamak);
      expect(hedefGirdisiniOku(mesafe, 'on').hata, AlanHatasi.sayi);
      expect(hedefGirdisiniOku(mesafe, '').hata, AlanHatasi.zorunlu);

      final tam = _hedef(hedefJson(birim: 'piece', basamak: 0));
      expect(hedefEnAz(tam), 1);
      expect(hedefAlani(tam).kind, 'integer');
      expect(hedefGirdisiniOku(tam, '3').deger, 3);
      expect(hedefGirdisiniOku(tam, '12,5').hata, AlanHatasi.sayi);
    });
  });

  group('hedef kartı', () {
    for (final tema in _temalar) {
      testWidgets('ilerleme yazılı ve okunur; organizatör hedefi değiştirir, '
          'varsayılana döner (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          hedef: (_) => hedefJson(mevcut: 4.5, degistirebilir: true),
          yanitlar: {
            'PUT $hedefDegeriYolu': (_) => hedefJson(
              hedef: 12.5,
              konuldu: true,
              mevcut: 4.5,
              degistirebilir: true,
            ),
            'DELETE $hedefDegeriYolu': (_) =>
                hedefJson(mevcut: 4.5, degistirebilir: true),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        await _gorunurYap(tester, find.text('%45'));
        expect(_bolumde(find.text(arbMetni('bilesen_goal_ad'))), findsOneWidget);
        expect(find.text('Hedef: 10 km'), findsOneWidget);
        expect(find.text('4,5 / 10 km'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_goal_varsayilan_notu')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Hedefe ilerleme: 4,5 / 10 km, yüzde 45'),
          findsOneWidget,
        );
        expect(find.text(arbMetni('bilesen_goal_ulasildi')), findsNothing);
        expect(
          tasima.giden('GET', hedefYolu).single.yolParametreleri,
          {
            'tayfa_id': ornekTayfaId,
            'event_id': ornekEtkinlikId,
            'component_key': 'goal',
          },
        );
        // Varsayılan hedef kaldırılamaz, yalnızca değiştirilir.
        expect(
          find.byTooltip(arbMetni('bilesen_goal_varsayilana_don')),
          findsNothing,
        );

        await _dokun(tester, find.byTooltip(arbMetni('bilesen_goal_degistir')));
        expect(find.byType(HedefFormu), findsOneWidget);
        expect(tester.widget<TextField>(_degerAlani).controller!.text, '10');
        expect(_formda(find.text('km')), findsOneWidget);

        await tester.enterText(_degerAlani, '0');
        await _dokun(tester, _kaydet);
        expect(tasima.giden('PUT', hedefDegeriYolu), isEmpty);
        expect(
          _formda(find.text(arbMetni('bilesen_goal_hedef_pozitif'))),
          findsOneWidget,
        );

        await tester.enterText(_degerAlani, '12,5');
        await _dokun(tester, _kaydet);
        expect(tasima.giden('PUT', hedefDegeriYolu).single.govde, {
          'target': 12.5,
        });
        expect(find.byType(HedefFormu), findsNothing);
        expect(find.text('Hedef: 12,5 km'), findsOneWidget);
        expect(find.text('4,5 / 12,5 km'), findsOneWidget);
        expect(find.text('%36'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_goal_varsayilan_notu')),
          findsNothing,
        );

        await _dokun(
          tester,
          find.byTooltip(arbMetni('bilesen_goal_varsayilana_don')),
        );
        expect(
          find.text(m.bilesen_goal_varsayilana_don_onay('10 km')),
          findsOneWidget,
        );
        await _dokun(
          tester,
          find.text(arbMetni('bilesen_goal_varsayilana_don')),
        );
        expect(tasima.giden('DELETE', hedefDegeriYolu), hasLength(1));
        expect(find.text('Hedef: 10 km'), findsOneWidget);
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    for (final tema in _temalar) {
      testWidgets('hassas ölçümde ilerleme gösterilmez, nedeni yazılır '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(hedef: (_) => hedefJson(gizli: true));
        await _detayiAc(tester, tasima, themeMode: tema);

        final neden = find.text(arbMetni('bilesen_goal_gizli'));
        await _gorunurYap(tester, neden);
        expect(neden, findsOneWidget);
        expect(find.text('Hedef: 10 km'), findsOneWidget);
        expect(find.byType(HedefCubugu), findsNothing);
        expect(_bolumde(find.textContaining('%')), findsNothing);
        expect(
          find.byTooltip(arbMetni('bilesen_goal_degistir')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('hedefe ulaşınca ikon ve metin; yüzde 100\'ü geçebilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(hedef: (_) => hedefJson(mevcut: 12));
      await _detayiAc(tester, tasima);
      final ulasildi = find.text(arbMetni('bilesen_goal_ulasildi'));
      await _gorunurYap(tester, ulasildi);
      expect(ulasildi, findsOneWidget);
      expect(find.text('12 / 10 km'), findsOneWidget);
      expect(find.text('%120'), findsOneWidget);
    });

    testWidgets('bağlı ölçüm kapalıysa ilerleme yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(hedef: (_) => hedefJson(olcumAcik: false));
      await _detayiAc(tester, tasima);
      final bilgi = find.text(arbMetni('bilesen_goal_olcum_kapali'));
      await _gorunurYap(tester, bilgi);
      expect(bilgi, findsOneWidget);
      expect(find.byType(HedefCubugu), findsNothing);
    });

    testWidgets('hedef yoksa organizatör koyar, sonra kaldırır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        hedef: (_) =>
            hedefJson(hedef: null, varsayilan: null, degistirebilir: true),
        yanitlar: {
          'PUT $hedefDegeriYolu': (_) => hedefJson(
            hedef: 5,
            varsayilan: null,
            konuldu: true,
            mevcut: 1,
            degistirebilir: true,
          ),
          'DELETE $hedefDegeriYolu': (_) =>
              hedefJson(hedef: null, varsayilan: null, degistirebilir: true),
        },
      );
      await _detayiAc(tester, tasima);
      final yok = find.text(arbMetni('bilesen_goal_yok'));
      await _gorunurYap(tester, yok);
      expect(yok, findsOneWidget);
      expect(find.byType(HedefCubugu), findsNothing);

      await _dokun(tester, find.text(arbMetni('bilesen_goal_koy')));
      expect(find.byType(HedefFormu), findsOneWidget);
      expect(tester.widget<TextField>(_degerAlani).controller!.text, isEmpty);
      await tester.enterText(_degerAlani, '5');
      await _dokun(tester, _kaydet);
      expect(tasima.giden('PUT', hedefDegeriYolu).single.govde, {'target': 5});
      expect(find.text('Hedef: 5 km'), findsOneWidget);
      expect(find.text('%20'), findsOneWidget);

      await _dokun(tester, find.byTooltip(arbMetni('bilesen_goal_kaldir')));
      expect(find.text(arbMetni('bilesen_goal_kaldir_onay')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('bilesen_goal_kaldir')));
      expect(tasima.giden('DELETE', hedefDegeriYolu), hasLength(1));
      expect(find.text(arbMetni('bilesen_goal_yok')), findsOneWidget);
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        hedef: (_) {
          if (okundu) return hedefJson(mevcut: 2);
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(arbMetni('etkinlik_tekrar_dene')));
      await _gorunurYap(tester, tekrar);
      expect(tekrar, findsOneWidget);
      await _dokun(tester, tekrar);
      expect(find.text('2 / 10 km'), findsOneWidget);
    });
  });

  test('hedef de bağlı ölçüm de canlı değişince yeniden okunur', () async {
    final tasima = etkinlikTasimasi();
    final zaman = SahteZamanlayici();
    final soketler = <SahteSoket>[];
    final realtime = RealtimeIstemcisi(
      adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
      baglayici: (adres, basliklar) {
        final s = SahteSoket(adres, basliklar);
        soketler.add(s);
        return s;
      },
      tokenAl: () async => 'token',
      reddedildi: (_) async => 'token',
      oturumuKapat: () async {},
      zamanlayici: zaman.kur,
      rastgele: Random(1),
      gunluk: (_) {},
    );
    final c = ProviderContainer(
      overrides: [
        etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
        realtimeIstemcisiProvider.overrideWithValue(realtime),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(realtime.dispose);
    int okuma() => tasima.giden('GET', hedefYolu).length;
    Future<void> bekle() async {
      await pumpEventQueue();
      await c.read(hedefProvider(_kimlik).future);
    }

    void degisti(String anahtar) => soketler.single.cerceve(
      'event.component_changed',
      {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
        'component_key': anahtar,
      },
    );

    final durum = c.listen(hedefProvider(_kimlik), (_, _) {});
    await bekle();
    expect(okuma(), 1);

    realtime.baslat();
    await pumpEventQueue();
    await soketler.single.ac();
    await bekle();
    final once = okuma();
    expect(once, greaterThan(1));

    // Bağlı ölçüm değişti: çerçeve ölçümün anahtarıyla gelir.
    degisti('distance');
    await bekle();
    expect(okuma(), once + 1);

    // Hedefin kendisi değişti.
    degisti('goal');
    await bekle();
    expect(okuma(), once + 2);

    // Başka bir ölçüm hedefi etkilemez.
    degisti('elevation_gain');
    await bekle();
    expect(okuma(), once + 2);

    durum.close();
  });
}
