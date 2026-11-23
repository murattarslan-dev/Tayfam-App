import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/takim/takim_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  TakimBileseni(),
];

const String _takim1 = '01970000-0000-7000-8000-000000000201';
const String _takim2 = '01970000-0000-7000-8000-000000000202';
const String _ucuncuId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';

/// İki takım: ilki adsız (katılımcı), ikincisi "Kartallar" (üçüncü kişi).
List<Map<String, Object?>> _takimlar() => [
  takimJson(id: _takim1, sira: 1, uyeler: [katilimciId]),
  takimJson(id: _takim2, sira: 2, ad: 'Kartallar', uyeler: [_ucuncuId]),
];

/// Bilgi yarışması gecesi (katalog fikstüründe takım kurma bileşeni var).
/// [takimlar] takımların yanıtıdır; kendi kimliği [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti takimlar,
  Map<String, TayfaYaniti> yanitlar = const {},
  List<String> gelenler = const [organizatorId, katilimciId, _ucuncuId],
  String ben = katilimciId,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) =>
        etkinlikJson(tur: 'quiz_night', mod: 'online', cevap: 'going'),
    'GET $takimYolu': takimlar,
    'GET $katilimcilarYolu': (_) => katilimcilarJson(gelenler),
    ...yanitlar,
  });
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

/// [anahtar]'lı kişi satırındaki seçimi açıp [secenek]'i seçer.
Future<void> _sec(WidgetTester tester, String anahtar, String secenek) async {
  await _dokun(
    tester,
    find.descendant(
      of: find.byKey(ValueKey(anahtar)),
      matching: find.byType(DropdownButton<int>),
    ),
  );
  await tester.tap(find.text(secenek).last);
  await tester.pumpAndSettle();
}

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(TakimBolumu), matching: bulucu);

Finder _elleFormda(Finder bulucu) =>
    find.descendant(of: find.byType(TakimElleFormu), matching: bulucu);

Finder _seviyeFormunda(Finder bulucu) =>
    find.descendant(of: find.byType(TakimSeviyeFormu), matching: bulucu);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe takım kurma bileşenini kullanan tür var', () {
    final takimlar = turBilesenleri(testTuru('quiz_night'))
        .where((b) => b.kind == 'teams')
        .toList();
    expect(takimlar, hasLength(1));
    expect(bilesenAnahtari(takimlar.single), 'teams');
    final mod = secimliParametreler(takimlar.single).single;
    expect(mod.ad, 'mode');
    expect(mod.secenekler, ['manual', 'random']);
    expect(mod.varsayilan, 'random');
  });

  group('istekler', () {
    test('elle kurma: adlar kırpılır, boş ad gönderilmez; sıra korunur', () {
      final sonuc = takimIstegi(
        adlar: ['  Şimşekler ', '   ', ''],
        atama: {_ucuncuId: 0, katilimciId: 0, organizatorId: 1, 'yok': 7},
        kisiSirasi: [katilimciId, organizatorId, _ucuncuId],
      );
      expect(sonuc.dolanlar, isEmpty);
      expect(sonuc.istek!.toJson(), {
        'teams': [
          {
            'name': 'Şimşekler',
            'member_ids': [katilimciId, _ucuncuId],
          },
          {
            'member_ids': [organizatorId],
          },
          {'member_ids': <String>[]},
        ],
      });
      expect(
        takimIstegi(
          adlar: const [],
          atama: const {},
          kisiSirasi: const [],
        ).istek!.toJson(),
        {'teams': <Object?>[]},
      );
    });

    test('elle kurma: kişi sınırını aşan takım', () {
      final sonuc = takimIstegi(
        adlar: ['', ''],
        atama: {katilimciId: 1, organizatorId: 1, _ucuncuId: 0},
        kisiSirasi: [katilimciId, organizatorId, _ucuncuId],
        kisiSiniri: 1,
      );
      expect(sonuc.istek, isNull);
      expect(sonuc.dolanlar, {1});
    });

    test('kişi sınırı yalnızca takım sayısı ve büyüklüğü birlikteyken', () {
      EventTeams takimlar({int? sayi, int? buyukluk}) => EventTeams.fromJson(
        takimlarJson(takimSayisi: sayi, takimBuyuklugu: buyukluk),
      );
      expect(takimKisiSiniri(takimlar(sayi: 3, buyukluk: 2)), 2);
      expect(takimKisiSiniri(takimlar(buyukluk: 2)), isNull);
      expect(takimKisiSiniri(takimlar(sayi: 3)), isNull);
      expect(takimSiniri(takimlar(sayi: 3)), 3);
      expect(takimSiniri(takimlar()), takimSayisiEnCok);
    });

    test('taslak: takım yoksa takım sayısı kadar (yoksa 2) boş takım; '
        'varsa sırasıyla', () {
      expect(takimTaslagi(EventTeams.fromJson(takimlarJson())), hasLength(2));
      expect(
        takimTaslagi(EventTeams.fromJson(takimlarJson(takimSayisi: 4))),
        hasLength(4),
      );
      final taslak = takimTaslagi(
        EventTeams.fromJson(
          takimlarJson(takimlar: _takimlar().reversed.toList()),
        ),
      );
      expect(taslak.map((t) => t.ad), ['', 'Kartallar']);
      expect(taslak.first.uyeler, [katilimciId]);
    });

    test('dengeli kurma: yalnızca 3 olmayan geçerli seviyeler gider', () {
      expect(takimSeviyeIstegi(const {}).toJson(), isEmpty);
      expect(takimSeviyeIstegi({katilimciId: 3, organizatorId: 5}).toJson(), {
        'levels': [
          {'user_id': organizatorId, 'level': 5},
        ],
      });
      expect(
        takimSeviyeIstegi({katilimciId: 0, organizatorId: 6}).levels,
        isNull,
      );
    });

    test('takımın adı ya da numarası yazılır', () {
      expect(takimEtiketi(m, 2, null), m.bilesen_teams_takim_no(2));
      expect(takimEtiketi(m, 2, '  '), m.bilesen_teams_takim_no(2));
      expect(takimEtiketi(m, 2, ' Kartallar '), 'Kartallar');
    });
  });

  group('takım bölümü', () {
    for (final tema in _temalar) {
      testWidgets('üye takımları okur: ad ya da numara, kişi sayısı, '
          '"Senin takımın" (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          takimlar: (_) => takimlarJson(takimlar: _takimlar()),
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final kartallar = _bolumde(find.text('Kartallar'));
        await _gorunurYap(tester, kartallar);
        expect(kartallar, findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_teams_takim_no(1))),
          findsOneWidget,
        );
        expect(
          _bolumde(
            find.text(
              m.bilesen_teams_ozet(
                m.bilesen_teams_takim_no(2),
                m.bilesen_teams_kisi_sayisi(1),
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_teams_senin)), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_teams_mod_random)), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_teams_ad)), findsOneWidget);
        // Üyelerin adları profilden.
        expect(_bolumde(find.text('Mert')), findsNWidgets(2));
        expect(_bolumde(find.text(m.bilesen_teams_kur)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_teams_yeniden_kur)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_teams_elle_duzenle)), findsNothing);
        expect(tasima.giden('GET', takimYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'teams',
        });
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('düzenleyen rastgele yeniden kurar ve elle düzenler '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          takimlar: (_) => takimlarJson(
            takimlar: _takimlar(),
            takimSayisi: 2,
            takimBuyuklugu: 2,
            duzenleyebilir: true,
          ),
          yanitlar: {
            'POST $takimKurmaYolu': (_) => takimlarJson(
              takimlar: [
                takimJson(id: _takim1, sira: 1, uyeler: [_ucuncuId]),
                takimJson(
                  id: _takim2,
                  sira: 2,
                  ad: 'Kartallar',
                  uyeler: [katilimciId],
                ),
              ],
              takimSayisi: 2,
              takimBuyuklugu: 2,
              duzenleyebilir: true,
            ),
            'PUT $takimYolu': (_) => takimlarJson(
              takimlar: [
                takimJson(
                  id: _takim1,
                  sira: 1,
                  ad: 'Şimşekler',
                  uyeler: [organizatorId, katilimciId],
                ),
                takimJson(
                  id: _takim2,
                  sira: 2,
                  ad: 'Kartallar',
                  uyeler: [_ucuncuId],
                ),
              ],
              takimSayisi: 2,
              takimBuyuklugu: 2,
              duzenleyebilir: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        // Yeniden kur: onaydan sonra, gövde boş nesne.
        final yeniden = _bolumde(find.text(m.bilesen_teams_yeniden_kur));
        await _gorunurYap(tester, yeniden);
        await _dokun(tester, yeniden);
        expect(find.text(m.bilesen_teams_yeniden_onay), findsOneWidget);
        await _dokun(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(m.bilesen_teams_yeniden_kur),
          ),
        );
        expect(
          tasima.giden('POST', takimKurmaYolu).single.govde,
          <String, Object?>{},
        );

        // Elle düzenle: takımlar ve kişiler formda.
        await _dokun(tester, _bolumde(find.text(m.bilesen_teams_elle_duzenle)));
        expect(find.byType(TakimElleFormu), findsOneWidget);
        expect(
          _elleFormda(find.text(m.bilesen_teams_kisi_siniri(2))),
          findsOneWidget,
        );
        // Takım sayısı sınırda: "Takım ekle" yok.
        expect(
          _elleFormda(find.text(m.bilesen_teams_takim_ekle)),
          findsNothing,
        );
        await tester.enterText(
          find.byKey(const ValueKey('takim-adi-0')),
          'Şimşekler',
        );
        await tester.pumpAndSettle();
        // Kurulumdan sonra ilk takımda üçüncü kişi var: ikisi daha
        // eklenince sınır aşılır, istek gitmez.
        await _sec(tester, 'takim-kisi-$organizatorId', 'Şimşekler');
        await _sec(tester, 'takim-kisi-$katilimciId', 'Şimşekler');
        await _dokun(tester, _elleFormda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('PUT', takimYolu), isEmpty);
        expect(
          _elleFormda(find.text(m.bilesen_teams_takim_dolu(2))),
          findsOneWidget,
        );

        await _sec(tester, 'takim-kisi-$_ucuncuId', 'Kartallar');
        await _dokun(tester, _elleFormda(find.text(m.etkinlik_kaydet)));
        expect(tasima.giden('PUT', takimYolu).single.govde, {
          'teams': [
            {
              'name': 'Şimşekler',
              'member_ids': [organizatorId, katilimciId],
            },
            {
              'name': 'Kartallar',
              'member_ids': [_ucuncuId],
            },
          ],
        });
        expect(find.byType(TakimElleFormu), findsNothing);
        expect(_bolumde(find.text('Şimşekler')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('dengeli modda seviyeler formda verilir, yalnızca '
          'değişenler gider (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          gelenler: const [organizatorId, katilimciId],
          takimlar: (_) => takimlarJson(mod: 'balanced', duzenleyebilir: true),
          yanitlar: {
            'POST $takimKurmaYolu': (_) => takimlarJson(
              mod: 'balanced',
              takimlar: [
                takimJson(id: _takim1, sira: 1, uyeler: [organizatorId]),
                takimJson(id: _takim2, sira: 2, uyeler: [katilimciId]),
              ],
              duzenleyebilir: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final bos = _bolumde(find.text(m.bilesen_teams_yok));
        await _gorunurYap(tester, bos);
        expect(
          _bolumde(find.text(m.bilesen_teams_mod_balanced)),
          findsOneWidget,
        );
        await _dokun(tester, _bolumde(find.text(m.bilesen_teams_kur)));
        expect(find.byType(TakimSeviyeFormu), findsOneWidget);
        expect(
          _seviyeFormunda(find.text(m.bilesen_teams_seviye_aciklama)),
          findsOneWidget,
        );
        // Varsayılan seviye 3.
        expect(
          _seviyeFormunda(find.text(m.bilesen_teams_seviye(3))),
          findsNWidgets(2),
        );
        await _sec(
          tester,
          'takim-seviye-$katilimciId',
          m.bilesen_teams_seviye(5),
        );
        await _dokun(tester, _seviyeFormunda(find.text(m.bilesen_teams_kur)));
        expect(tasima.giden('POST', takimKurmaYolu).single.govde, {
          'levels': [
            {'user_id': katilimciId, 'level': 5},
          ],
        });
        expect(find.byType(TakimSeviyeFormu), findsNothing);
        expect(
          _bolumde(find.text(m.bilesen_teams_takim_no(2))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('elle modda yalnızca elle düzenleme; kurulamazsa hata', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        takimlar: (_) => takimlarJson(mod: 'manual', duzenleyebilir: true),
      );
      await _detayiAc(tester, tasima);
      final elle = _bolumde(find.text(m.bilesen_teams_elle_duzenle));
      await _gorunurYap(tester, elle);
      expect(elle, findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_teams_kur)), findsNothing);
      expect(_bolumde(find.text(m.bilesen_teams_mod_manual)), findsOneWidget);

      // Takım yokken iki boş takımla açılır; hepsi çıkarılırsa bilgi.
      await _dokun(tester, elle);
      expect(
        _elleFormda(find.text(m.bilesen_teams_ad_alani(2))),
        findsOneWidget,
      );
      await _dokun(tester, find.byTooltip(m.bilesen_teams_takim_cikar(2)));
      await _dokun(tester, find.byTooltip(m.bilesen_teams_takim_cikar(1)));
      expect(
        _elleFormda(find.text(m.bilesen_teams_hepsi_kalkar)),
        findsOneWidget,
      );
      await _dokun(tester, _elleFormda(find.text(m.bilesen_teams_takim_ekle)));
      expect(
        _elleFormda(find.text(m.bilesen_teams_ad_alani(1))),
        findsOneWidget,
      );
    });

    testWidgets('az katılımcıda sunucunun hatası gösterilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        takimlar: (_) => takimlarJson(duzenleyebilir: true),
        yanitlar: {
          'POST $takimKurmaYolu': (_) =>
              const ApiProblem(type: ProblemType.teamsTooFew, status: 409),
        },
      );
      await _detayiAc(tester, tasima);
      final kur = _bolumde(find.text(m.bilesen_teams_kur));
      await _gorunurYap(tester, kur);
      // Takım yokken rastgele kurma onay istemez.
      await _dokun(tester, kur);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tasima.giden('POST', takimKurmaYolu), hasLength(1));
      expect(find.text(m.hata_teams_too_few), findsOneWidget);
    });

    testWidgets('elle kurmada sunucu reddederse form açık kalır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        takimlar: (_) =>
            takimlarJson(takimlar: _takimlar(), duzenleyebilir: true),
        yanitlar: {
          'PUT $takimYolu': (_) => const ApiProblem(
            type: ProblemType.teamsNotParticipant,
            status: 409,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final elle = _bolumde(find.text(m.bilesen_teams_elle_duzenle));
      await _gorunurYap(tester, elle);
      await _dokun(tester, elle);
      await _dokun(tester, _elleFormda(find.text(m.etkinlik_kaydet)));
      expect(tasima.giden('PUT', takimYolu), hasLength(1));
      expect(find.byType(TakimElleFormu), findsOneWidget);
      expect(_elleFormda(find.byType(HataSatiri)), findsOneWidget);
      expect(
        _elleFormda(find.text(m.hata_teams_not_participant)),
        findsOneWidget,
      );
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        takimlar: (_) {
          if (okundu) return takimlarJson(takimlar: _takimlar());
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(m.etkinlik_tekrar_dene));
      await _gorunurYap(tester, tekrar);
      expect(tekrar, findsOneWidget);
      await _dokun(tester, tekrar);
      expect(_bolumde(find.text('Kartallar')), findsOneWidget);
    });
  });
}
