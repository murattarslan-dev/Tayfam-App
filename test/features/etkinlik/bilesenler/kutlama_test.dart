import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('teams'),
  TemelBilesen('scoreboard'),
  KutlamaBileseni(),
];

const String _masaId = '0b1c2d3e-4f50-4a61-8b72-9c83d4e5f601';
const String _takimId = '1c2d3e4f-5061-4b72-9c83-ad94e5f60712';
const String _misafirId = '2d3e4f50-6172-4c83-ad94-be05f6071823';

/// Organizatör "Ayşe", katılımcı "Mert".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(id, id == organizatorId ? 'Ayşe' : 'Mert', ben: id == ben);
}

/// [tur] türünde (katalog fikstüründe araç buluşması: elle seçilen, oyun
/// (diğer): yazboz kaynaklı) başlamış bir etkinlik; kutlama ucu
/// [kutlama]'dır. Oturumdaki kullanıcı [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti kutlama,
  String tur = 'car_meet',
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
    'GET $kutlamaYolu': kutlama,
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
    find.descendant(of: find.byType(KutlamaFormu), matching: bulucu);

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(KutlamaBolumu), matching: bulucu);

Finder _pencerede(Finder bulucu) =>
    find.descendant(of: find.byType(AlertDialog), matching: bulucu);

/// Yazboz kaynaklı, üç türden kazananı olan kutlamanın yanıtları: masa
/// adı, takım adı ve misafirin takma adı.
Map<String, TayfaYaniti> get _kaynakYanitlari => {
  'GET $yazbozYolu': (_) =>
      yazbozJson(masalar: [yazbozMasasiJson(id: _masaId, bitti: true)]),
  'GET $takimYolu': (_) => takimlarJson(
    takimlar: [takimJson(id: _takimId, sira: 1, ad: 'Kırmızılar')],
  ),
  'GET $misafirlerYolu': (_) =>
      misafirlerJson(misafirler: [misafirJson(_misafirId, ad: 'Deniz')]),
};

List<Map<String, Object?>> get _ucKazanan => [
  kutlamaKazananiJson(kisi: katilimciId, masa: _masaId),
  kutlamaKazananiJson(takim: _takimId),
  kutlamaKazananiJson(misafir: _misafirId),
];

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe kutlama bileşenini kullanan türler var', () {
    final elle = turBilesenleri(testTuru('car_meet'))
        .where((b) => b.kind == 'celebration')
        .single;
    expect(bilesenAnahtari(elle), 'celebration');
    expect(BilesenParametreleri(elle.params).metin('source'), isNull);
    final kaynakli = turBilesenleri(testTuru('games_other'))
        .where((b) => b.kind == 'celebration')
        .single;
    expect(BilesenParametreleri(kaynakli.params).metin('source'), 'scoreboard');
  });

  test('kaynak ve elle seçilen kişiler okunur', () {
    final kutlama = EventCelebration.fromJson(
      kutlamaJson(
        kazananlar: [
          kutlamaKazananiJson(kisi: katilimciId),
          kutlamaKazananiJson(misafir: _misafirId),
        ],
      ),
    );
    expect(kutlamaKaynakli(kutlama), isFalse);
    expect(kutlamaKaynagiTanindi(kutlama), isTrue);
    expect(kutlamaKisileri(kutlama), [katilimciId]);
    final bilinmeyen = EventCelebration.fromJson(
      kutlamaJson(kaynak: 'yeni', kaynakTuru: 'gelecek_tur'),
    );
    expect(kutlamaKaynakli(bilinmeyen), isTrue);
    expect(kutlamaKaynagiTanindi(bilinmeyen), isFalse);
  });

  group('kaynaklı kutlama', () {
    for (final tema in _temalar) {
      testWidgets('kişi, takım ve misafir kazanan; kart tek öğe okunur '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          tur: 'games_other',
          ben: katilimciId,
          kutlama: (_) => kutlamaJson(
            kaynak: 'scoreboard',
            kazananlar: _ucKazanan,
            ilanEdildi: true,
          ),
          yanitlar: _kaynakYanitlari,
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final kart = _bolumde(find.byType(KutlamaKarti));
        await _gorunurYap(tester, kart);
        expect(
          _bolumde(find.text(m.bilesen_celebration_kazananlar)),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(m.bilesen_celebration_masada('Mert', 'Masa 1'))),
          findsOneWidget,
        );
        expect(_bolumde(find.text('Kırmızılar')), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_guest_ad_metni('Deniz'))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_celebration_ilan_edildi(''))),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              '${RegExp.escape(m.bilesen_celebration_kazananlar)}'
              r'[\s\S]*Mert[\s\S]*Kırmızılar[\s\S]*Deniz',
            ),
          ),
          findsOneWidget,
        );
        // Üye ilan edemez.
        expect(
          _bolumde(find.text(m.bilesen_celebration_ilan_et)),
          findsNothing,
        );
        expect(tasima.giden('GET', kutlamaYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'celebration',
        });
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    for (final tema in _temalar) {
      testWidgets('eşli masada kazanan eşin iki kişisi tek satırda '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        const esliKural = {
          'side': 'pair',
          'rounds': 'round',
          'winner': 'high',
          'result': 'points',
        };
        // Eş 1: Ayşe (koltuk 1) ve misafir Deniz (koltuk 3); eş 2: Mert ve
        // hesabı silinmiş kişi.
        final masa = yazbozMasasiJson(
          id: _masaId,
          kurallar: esliKural,
          bitti: true,
          yerler: [
            {...yazbozYeriJson('y1', 1, kisi: organizatorId), 'pair': 1},
            {...yazbozYeriJson('y2', 2, kisi: katilimciId), 'pair': 2},
            {...yazbozYeriJson('y3', 3, misafir: _misafirId), 'pair': 1},
            {...yazbozYeriJson('y4', 4), 'pair': 2},
          ],
          kazananlar: ['y1', 'y3'],
        );
        final tasima = _tasima(
          tur: 'games_other',
          ben: katilimciId,
          kutlama: (_) => kutlamaJson(
            kaynak: 'scoreboard',
            kazananlar: [
              kutlamaKazananiJson(kisi: organizatorId, masa: _masaId),
              kutlamaKazananiJson(misafir: _misafirId, masa: _masaId),
            ],
          ),
          yanitlar: {
            ..._kaynakYanitlari,
            'GET $yazbozYolu': (_) => yazbozJson(masalar: [masa]),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final kart = _bolumde(find.byType(KutlamaKarti));
        await _gorunurYap(tester, kart);
        expect(
          _bolumde(find.text(m.bilesen_celebration_kazananlar)),
          findsOneWidget,
        );
        final esler = m.bilesen_scoreboard_es_adlari(
          'Ayşe',
          m.bilesen_guest_ad_metni('Deniz'),
        );
        expect(
          _bolumde(find.text(m.bilesen_celebration_masada(esler, 'Masa 1'))),
          findsOneWidget,
        );
        expect(_bolumde(find.textContaining('Mert')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    test('kazananın eşi masadaki yerinden bulunur', () {
      final masa = EventScoreTable.fromJson(
        yazbozMasasiJson(
          id: _masaId,
          kurallar: const {'side': 'pair'},
          yerler: [
            yazbozYeriJson('y1', 1, kisi: organizatorId),
            yazbozYeriJson('y2', 2, kisi: katilimciId),
            yazbozYeriJson('y3', 3, misafir: _misafirId),
          ],
        ),
      );
      EventCelebrationWinner kazanan({String? kisi, String? misafir}) =>
          EventCelebrationWinner.fromJson(
            kutlamaKazananiJson(kisi: kisi, misafir: misafir, masa: _masaId),
          );
      expect(kutlamaKazananEsi(masa, kazanan(kisi: organizatorId)), 1);
      expect(kutlamaKazananEsi(masa, kazanan(kisi: katilimciId)), 2);
      expect(kutlamaKazananEsi(masa, kazanan(misafir: _misafirId)), 1);
      expect(kutlamaKazananEsi(masa, kazanan()), isNull);
      final bireysel = EventScoreTable.fromJson(
        yazbozMasasiJson(
          id: _masaId,
          yerler: [yazbozYeriJson('y1', 1, kisi: organizatorId)],
        ),
      );
      expect(kutlamaKazananEsi(bireysel, kazanan(kisi: organizatorId)), isNull);
    });

    testWidgets('organizatör onayla ilan eder; vazgeçerse istek gitmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'games_other',
        kutlama: (_) => kutlamaJson(
          kaynak: 'scoreboard',
          kazananlar: [kutlamaKazananiJson(kisi: katilimciId)],
          ilanEdebilir: true,
        ),
        yanitlar: {
          ..._kaynakYanitlari,
          'PUT $kutlamaYolu': (_) => kutlamaJson(
            kaynak: 'scoreboard',
            kazananlar: [kutlamaKazananiJson(kisi: katilimciId)],
            ilanEdildi: true,
            ilanEdebilir: true,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final dugme = _bolumde(find.text(m.bilesen_celebration_ilan_et));
      await _gorunurYap(tester, dugme);
      expect(
        _bolumde(find.text(m.bilesen_celebration_ilan_notu)),
        findsOneWidget,
      );
      expect(
        _bolumde(find.text(m.bilesen_celebration_kazanan)),
        findsOneWidget,
      );

      await _dokun(tester, dugme);
      expect(
        _pencerede(find.text(m.bilesen_celebration_ilan_onay_aciklama)),
        findsOneWidget,
      );
      await _dokun(tester, _pencerede(find.text(m.etkinlik_vazgec)));
      expect(tasima.giden('PUT', kutlamaYolu), isEmpty);

      await _dokun(tester, dugme);
      await _dokun(
        tester,
        _pencerede(find.text(m.bilesen_celebration_ilan_et)),
      );
      final istek = tasima.giden('PUT', kutlamaYolu).single;
      expect(istek.govde, <String, Object?>{});
      expect(
        _bolumde(find.textContaining(m.bilesen_celebration_ilan_edildi(''))),
        findsOneWidget,
      );
      expect(_bolumde(find.text(m.bilesen_celebration_ilan_et)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sonuç yoksa beklenir, ilan düğmesi yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'games_other',
        kutlama: (_) => kutlamaJson(kaynak: 'scoreboard', ilanEdebilir: true),
        yanitlar: _kaynakYanitlari,
      );
      await _detayiAc(tester, tasima);
      final bos = _bolumde(find.text(m.bilesen_celebration_sonuc_bekleniyor));
      await _gorunurYap(tester, bos);
      expect(bos, findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_celebration_ilan_et)), findsNothing);
    });

    testWidgets('gizli kutlamada kazanan gösterilmez, nedeni yazılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'games_other',
        ben: katilimciId,
        kutlama: (_) => kutlamaJson(
          kaynak: 'scoreboard',
          kazananlar: _ucKazanan,
          gizli: true,
          ilanEdildi: true,
        ),
        yanitlar: _kaynakYanitlari,
      );
      await _detayiAc(tester, tasima);
      final gizli = _bolumde(find.text(m.bilesen_celebration_gizli));
      await _gorunurYap(tester, gizli);
      expect(gizli, findsOneWidget);
      expect(_bolumde(find.byType(KutlamaKarti)), findsNothing);
    });

    testWidgets('tanınmayan kaynakta "güncelle" yazılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        tur: 'games_other',
        kutlama: (_) => kutlamaJson(
          kaynak: 'scoreboard',
          kaynakTuru: 'gelecek_tur',
          kazananlar: [kutlamaKazananiJson(kisi: katilimciId)],
        ),
        yanitlar: _kaynakYanitlari,
      );
      await _detayiAc(tester, tasima);
      final guncelle = _bolumde(find.text(m.bilesen_celebration_guncelle));
      await _gorunurYap(tester, guncelle);
      expect(guncelle, findsOneWidget);
      expect(_bolumde(find.byType(KutlamaKarti)), findsNothing);
    });
  });

  group('elle seçilen kutlama', () {
    for (final tema in _temalar) {
      testWidgets('organizatör kişi seçip onayla ilan eder; sunucu hatası '
          'formda kalır (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var ilk = true;
        final tasima = _tasima(
          kutlama: (_) => kutlamaJson(ilanEdebilir: true),
          yanitlar: {
            'PUT $kutlamaYolu': (_) {
              if (ilk) {
                ilk = false;
                return const ApiProblem(
                  type: ProblemType.celebrationNotParticipant,
                  status: 409,
                );
              }
              return kutlamaJson(
                kazananlar: [kutlamaKazananiJson(kisi: katilimciId)],
                ilanEdildi: true,
                ilanEdebilir: true,
              );
            },
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final bekleniyor = _bolumde(
          find.text(m.bilesen_celebration_ilan_bekleniyor),
        );
        await _gorunurYap(tester, bekleniyor);
        expect(bekleniyor, findsOneWidget);
        await _dokun(tester, _bolumde(find.text(m.bilesen_celebration_sec)));
        expect(find.byType(KutlamaFormu), findsOneWidget);

        final ilanEt = _formda(find.text(m.bilesen_celebration_ilan_et));
        await _dokun(tester, ilanEt);
        expect(
          _formda(find.text(m.bilesen_celebration_sec_hata)),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsNothing);

        await _dokun(tester, _formda(find.text('Mert')));
        await _dokun(tester, ilanEt);
        await _dokun(
          tester,
          _pencerede(find.text(m.bilesen_celebration_ilan_et)),
        );
        expect(
          _formda(find.text(m.hata_celebration_not_participant)),
          findsOneWidget,
        );
        expect(find.byType(KutlamaFormu), findsOneWidget);

        await _dokun(tester, ilanEt);
        await _dokun(
          tester,
          _pencerede(find.text(m.bilesen_celebration_ilan_et)),
        );
        final istekler = tasima.giden('PUT', kutlamaYolu);
        expect(istekler, hasLength(2));
        expect(istekler.last.govde, {
          'winner_ids': [katilimciId],
        });
        expect(find.byType(KutlamaFormu), findsNothing);
        await _gorunurYap(tester, _bolumde(find.byType(KutlamaKarti)));
        expect(_bolumde(find.text('Mert')), findsOneWidget);
        // İlan edildikten sonra seçim değiştirilebilir; onay istenmez.
        expect(
          _bolumde(find.text(m.bilesen_celebration_degistir)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('üye ilan düğmesini görmez; başlamadan metni', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: katilimciId,
        kutlama: (_) => kutlamaJson(),
        baslangic: ornekBaslangic,
      );
      await _detayiAc(tester, tasima);
      final bos = _bolumde(find.text(m.bilesen_celebration_baslamadi));
      await _gorunurYap(tester, bos);
      expect(bos, findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_celebration_sec)), findsNothing);
    });
  });

  group('hareket', () {
    Future<Duration> gecisSuresi(WidgetTester tester) async {
      final tasima = _tasima(
        kutlama: (_) => kutlamaJson(
          kazananlar: [kutlamaKazananiJson(kisi: katilimciId)],
          ilanEdildi: true,
        ),
      );
      await _detayiAc(tester, tasima);
      final kart = _bolumde(find.byType(KutlamaKarti));
      await _gorunurYap(tester, kart);
      final gecis = tester.widget<TweenAnimationBuilder<double>>(
        find.descendant(
          of: kart,
          matching: find.byType(TweenAnimationBuilder<double>),
        ),
      );
      return gecis.duration;
    }

    testWidgets('kart kısa bir geçişle gelir', (tester) async {
      ekranBoyutu(tester);
      expect(await gecisSuresi(tester), TayfamMotion.uzun);
    });

    testWidgets('"hareketi azalt" açıkken geçiş yok', (tester) async {
      ekranBoyutu(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      expect(await gecisSuresi(tester), Duration.zero);
    });
  });
}
