import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/core/medya/medya_onbellegi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kutlama/kutlama_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/oylama_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/oylama_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/oylama/secenek_formu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

/// Katalog fikstüründeki fotoğraf yarışması: albüm kaynaklı oylama ve
/// oylama kaynaklı kutlama.
const String _tur = 'photo_contest';

const List<EtkinlikBileseni> _kayit = [
  OylamaBileseni(),
  TemelBilesen('celebration'),
];

const List<EtkinlikBileseni> _kutlamaKaydi = [
  OylamaBileseni(),
  KutlamaBileseni(),
];

const String _secenek1 = '0c1d2e3f-4a5b-4c6d-8e7f-90a1b2c3d4e5';
const String _secenek2 = '1d2e3f4a-5b6c-4d7e-9f80-a1b2c3d4e5f6';
const String _yukleme1 = '2e3f4a5b-6c7d-4e8f-a091-b2c3d4e5f607';
const String _yukleme2 = '3f4a5b6c-7d8e-4f90-b1a2-c3d4e5f60718';

List<Map<String, Object?>> _serbest({int oy1 = 0, int oy2 = 0}) => [
  oylamaSecenegiJson(_secenek1, etiket: 'Göl kenarı', oy: oy1, kazanan: true),
  oylamaSecenegiJson(_secenek2, etiket: 'Orman yolu', oy: oy2),
];

/// Başlamış bir fotoğraf yarışması; oylama ucu [oylama]'dır. Oturumdaki
/// kullanıcı [ben] (organizatör "Ayşe", katılımcı "Mert").
SahteTayfaTasima _tasima({
  required TayfaYaniti oylama,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = katilimciId,
  String? cevap = 'going',
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: _tur,
      cevap: cevap,
      baslangic: gecmisBaslangic,
      sure: const Duration(hours: 3),
    ),
    'GET $oylamaYolu': oylama,
    ...yanitlar,
  });
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(ben);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  List<EtkinlikBileseni> kayit = _kayit,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, bilesenler: kayit),
    overrides: [
      // Albüm küçük resimleri: link yok, yer tutucu çizilir; gerçek ağ yok.
      medyaLinkIsteyiciProvider.overrideWithValue(
        (idler) async => const <MediaUrls>[],
      ),
    ],
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

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(OylamaBolumu), matching: bulucu);

Finder _formda(Finder bulucu) =>
    find.descendant(of: find.byType(OylamaSecenekFormu), matching: bulucu);

Finder _pencerede(Finder bulucu) =>
    find.descendant(of: find.byType(AlertDialog), matching: bulucu);

/// [metin]'i içeren seçenek satırının birleşik ekran okuyucu düğümü.
Finder _satirAnlami(String metin) => find.descendant(
  of: find.ancestor(
    of: find.text(metin),
    matching: find.byType(OylamaSecenegiSatiri),
  ),
  matching: find.byType(MergeSemantics),
);

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe oylama bileşenini kullanan türler var', () {
    final album = turBilesenleri(testTuru(_tur))
        .where((b) => b.kind == 'vote')
        .single;
    expect(bilesenAnahtari(album), 'vote');
    expect(BilesenParametreleri(album.params).metin('source'), 'album');
    final kutlama = turBilesenleri(testTuru(_tur))
        .where((b) => b.kind == 'celebration')
        .single;
    expect(BilesenParametreleri(kutlama.params).metin('source'), 'vote');
    final serbest = turBilesenleri(testTuru('ornek_bilesenler'))
        .where((b) => b.kind == 'vote')
        .single;
    expect(BilesenParametreleri(serbest.params).metin('source'), 'free');
  });

  group('yardımcılar', () {
    test('etiket kırpılır, iç boşluklar teke iner; sınırlar', () {
      expect(oylamaEtiketi('  Göl   kenarı \n'), 'Göl kenarı');
      expect(oylamaEtiketi('   '), isNull);
      expect(oylamaEtiketi('a' * oylamaEtiketiEnCok), hasLength(100));
      expect(oylamaEtiketi('a' * (oylamaEtiketiEnCok + 1)), isNull);
    });

    test('kendi seçeneği ve seçenek ekleme sınırı', () {
      final kendi = EventVoteOption.fromJson(
        oylamaSecenegiJson(_secenek1, kisi: katilimciId, yukleme: _yukleme1),
      );
      expect(oylamaKendiSecenegim(kendi, katilimciId), isTrue);
      expect(oylamaKendiSecenegim(kendi, organizatorId), isFalse);
      expect(oylamaKendiSecenegim(kendi, null), isFalse);
      final serbest = EventVoteOption.fromJson(
        oylamaSecenegiJson(_secenek2, etiket: 'Göl kenarı'),
      );
      expect(oylamaKendiSecenegim(serbest, katilimciId), isFalse);

      EventVote oylama({required String kaynak, int enCok = 20}) =>
          EventVote.fromJson(
            oylamaJson(
              kaynak: kaynak,
              secenekler: _serbest(),
              duzenleyebilir: true,
              enCok: enCok,
            ),
          );
      expect(oylamaSecenekEklenebilir(oylama(kaynak: 'free')), isTrue);
      expect(oylamaSecenekEklenebilir(oylama(kaynak: 'free', enCok: 2)), isFalse);
      expect(oylamaSecenekEklenebilir(oylama(kaynak: 'album')), isFalse);
    });

    test('tanınmayan kaynak', () {
      final oylama = EventVote.fromJson(oylamaJson(kaynak: 'route_stops'));
      expect(oylamaKaynagiTanindi(oylama), isFalse);
      expect(
        oylamaKaynagiTanindi(EventVote.fromJson(oylamaJson())),
        isTrue,
      );
    });
  });

  group('açık oylama', () {
    for (final tema in _temalar) {
      testWidgets('katılımcı oy verir ve geri alır; sayılar gizli, yalnızca '
          'oy veren sayısı görünür (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        final tasima = _tasima(
          oylama: (_) => oylamaJson(
            secenekler: _serbest(oy1: 3, oy2: 1),
            oyVeren: 4,
            oyVerebilir: true,
          ),
          yanitlar: {
            'PUT $oylamaYolu': (_) => oylamaJson(
              secenekler: _serbest(),
              oyVeren: 5,
              oyum: _secenek2,
              oyVerebilir: true,
            ),
            'DELETE $oylamaYolu': (_) => oylamaJson(
              secenekler: _serbest(),
              oyVeren: 4,
              oyVerebilir: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final orman = _bolumde(find.text('Orman yolu'));
        await _gorunurYap(tester, orman);
        expect(_bolumde(find.text(m.bilesen_vote_oy_veren(4))), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_vote_sonuc_gizli)),
          findsOneWidget,
        );
        // Açıkken seçenek başına sayı ve kazanan gösterilmez.
        expect(_bolumde(find.text(m.bilesen_vote_oy_sayisi(0))), findsNothing);
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_kazanan)),
          findsNothing,
        );
        expect(
          tester.getSemantics(_satirAnlami('Orman yolu')),
          isSemantics(isChecked: false, isInMutuallyExclusiveGroup: true),
        );

        await _dokun(tester, orman);
        final istek = tasima.giden('PUT', oylamaYolu).single;
        expect(istek.govde, {'option_id': _secenek2});
        expect(istek.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'vote',
        });
        expect(_bolumde(find.text(m.bilesen_vote_oy_veren(5))), findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_oyun)),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(_satirAnlami('Orman yolu')),
          isSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
        );

        // Seçili seçeneğe yeniden dokunmak istek göndermez.
        await _dokun(tester, _bolumde(find.text('Orman yolu')));
        expect(tasima.giden('PUT', oylamaYolu), hasLength(1));

        await _dokun(tester, _bolumde(find.text(m.bilesen_vote_geri_al)));
        expect(tasima.giden('DELETE', oylamaYolu), hasLength(1));
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_oyun)),
          findsNothing,
        );
        expect(_bolumde(find.text(m.bilesen_vote_geri_al)), findsNothing);
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    testWidgets('sunucu hatası kısa bildirimle gösterilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        oylama: (_) => oylamaJson(secenekler: _serbest(), oyVerebilir: true),
        yanitlar: {
          'PUT $oylamaYolu': (_) =>
              const ApiProblem(type: ProblemType.voteClosed, status: 409),
        },
      );
      await _detayiAc(tester, tasima);
      final gol = _bolumde(find.text('Göl kenarı'));
      await _gorunurYap(tester, gol);
      await _dokun(tester, gol);
      expect(find.text(m.hata_vote_closed), findsOneWidget);
      // Bayatlamış oylama yeniden okunur.
      expect(tasima.giden('GET', oylamaYolu).length, greaterThan(1));
    });

    testWidgets('gelmeyen üye seçemez; nedeni yazılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        cevap: null,
        oylama: (_) => oylamaJson(secenekler: _serbest(), oyVeren: 2),
      );
      await _detayiAc(tester, tasima);
      final bilgi = _bolumde(find.text(m.bilesen_vote_katil));
      await _gorunurYap(tester, bilgi);
      expect(bilgi, findsOneWidget);
      await _dokun(tester, _bolumde(find.text('Göl kenarı')));
      expect(tasima.giden('PUT', oylamaYolu), isEmpty);
    });

    testWidgets('tanınmayan kaynakta "güncelle" yazılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        oylama: (_) => oylamaJson(kaynak: 'gelecek_kaynak'),
      );
      await _detayiAc(tester, tasima);
      final guncelle = _bolumde(find.text(m.bilesen_vote_guncelle));
      await _gorunurYap(tester, guncelle);
      expect(guncelle, findsOneWidget);
      expect(_bolumde(find.byType(OylamaSecenegiSatiri)), findsNothing);
    });
  });

  group('kaynaklar', () {
    for (final tema in _temalar) {
      testWidgets('albüm: küçük resim, yükleyen; kendi fotoğrafı seçilemez '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          oylama: (_) => oylamaJson(
            kaynak: 'album',
            secenekler: [
              oylamaSecenegiJson(
                _yukleme1,
                yukleme: _yukleme1,
                kisi: organizatorId,
              ),
              oylamaSecenegiJson(
                _yukleme2,
                yukleme: _yukleme2,
                kisi: katilimciId,
              ),
            ],
            oyVerebilir: true,
          ),
        );
        await _detayiAc(tester, tasima, themeMode: tema);
        final ikinci = _bolumde(find.text(m.bilesen_vote_fotograf(2)));
        await _gorunurYap(tester, ikinci);
        expect(_bolumde(find.byType(MedyaGorseli)), findsNWidgets(2));
        expect(
          _bolumde(find.text(m.bilesen_vote_yukleyen('Ayşe'))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_sen)),
          findsOneWidget,
        );
        await _dokun(tester, ikinci);
        expect(tasima.giden('PUT', oylamaYolu), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('araç: araç kartı ve sahibi, plaka yok '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          oylama: (_) => oylamaJson(
            kaynak: 'vehicles',
            secenekler: [
              oylamaSecenegiJson(
                _secenek1,
                kisi: organizatorId,
                arac: {
                  'make': 'Ford',
                  'model': 'Mustang',
                  'model_year': 1967,
                  'color': 'Kırmızı',
                },
              ),
            ],
          ),
        );
        await _detayiAc(tester, tasima, themeMode: tema);
        final arac = _bolumde(find.text('Ford Mustang'));
        await _gorunurYap(tester, arac);
        expect(
          _bolumde(
            find.text('1967, Kırmızı · ${m.bilesen_vote_sahibi('Ayşe')}'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('katılımcı: seçenek kişinin adıdır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        oylama: (_) => oylamaJson(
          kaynak: 'participants',
          secenekler: [oylamaSecenegiJson(organizatorId, kisi: organizatorId)],
        ),
      );
      await _detayiAc(tester, tasima);
      final kisi = _bolumde(find.text('Ayşe'));
      await _gorunurYap(tester, kisi);
      expect(kisi, findsOneWidget);
    });

    testWidgets('boş kaynakta kaynağa göre metin', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(oylama: (_) => oylamaJson(kaynak: 'album'));
      await _detayiAc(tester, tasima);
      final bos = _bolumde(find.text(m.bilesen_vote_bos_album));
      await _gorunurYap(tester, bos);
      expect(bos, findsOneWidget);
    });
  });

  group('kapalı oylama', () {
    for (final tema in _temalar) {
      testWidgets('sayılar ve kazanan görünür, seçim yok '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          oylama: (_) => oylamaJson(
            secenekler: _serbest(oy1: 3, oy2: 1),
            oyVeren: 4,
            oyum: _secenek2,
            kapali: true,
          ),
        );
        await _detayiAc(tester, tasima, themeMode: tema);
        final kazanan = _bolumde(find.textContaining(m.bilesen_vote_kazanan));
        await _gorunurYap(tester, kazanan);
        expect(kazanan, findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_kapandi)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_vote_oy_sayisi(3))), findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_vote_oy_sayisi(1))), findsOneWidget);
        expect(
          _bolumde(find.text(m.bilesen_vote_sonuc_gizli)),
          findsNothing,
        );
        // Kendi oyun işaretli kalır; geri alınamaz.
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_oyun)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_vote_geri_al)), findsNothing);
        await _dokun(tester, _bolumde(find.text('Göl kenarı')));
        expect(tasima.giden('PUT', oylamaYolu), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('organizatör', () {
    for (final tema in _temalar) {
      testWidgets('seçenek ekler (sunucu hatası formda kalır), kaldırır ve '
          'oylamayı kapatır (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var ilk = true;
        final tasima = _tasima(
          ben: organizatorId,
          oylama: (_) => oylamaJson(
            secenekler: [_serbest().first],
            duzenleyebilir: true,
            kapatabilir: true,
          ),
          yanitlar: {
            'POST $oylamaSecenekleriYolu': (_) {
              if (ilk) {
                ilk = false;
                return const ApiProblem(
                  type: ProblemType.voteOptionExists,
                  status: 409,
                );
              }
              return oylamaJson(
                secenekler: _serbest(),
                duzenleyebilir: true,
                kapatabilir: true,
              );
            },
            'DELETE $oylamaSecenegiYolu': (_) => oylamaJson(
              secenekler: [_serbest().last],
              duzenleyebilir: true,
              kapatabilir: true,
            ),
            'POST $oylamaKapatYolu': (_) => oylamaJson(
              secenekler: [_serbest().last],
              kapali: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final ekle = _bolumde(find.text(m.bilesen_vote_secenek_ekle));
        await _gorunurYap(tester, ekle);
        await _dokun(tester, ekle);
        expect(find.byType(OylamaSecenekFormu), findsOneWidget);
        final onay = _formda(find.text(m.bilesen_vote_ekle));
        await _dokun(tester, onay);
        expect(
          _formda(find.text(m.bilesen_vote_secenek_hata(oylamaEtiketiEnCok))),
          findsOneWidget,
        );
        expect(tasima.giden('POST', oylamaSecenekleriYolu), isEmpty);

        await tester.enterText(
          _formda(find.byType(TextField)),
          '  Orman   yolu ',
        );
        await _dokun(tester, onay);
        expect(_formda(find.text(m.hata_vote_option_exists)), findsOneWidget);
        await _dokun(tester, onay);
        final eklemeler = tasima.giden('POST', oylamaSecenekleriYolu);
        expect(eklemeler, hasLength(2));
        expect(eklemeler.last.govde, {'label': 'Orman yolu'});
        expect(find.byType(OylamaSecenekFormu), findsNothing);
        expect(_bolumde(find.text('Orman yolu')), findsOneWidget);

        // Kaldırma onay ister; vazgeçince istek gitmez.
        final kaldir = _bolumde(find.byTooltip(m.bilesen_vote_kaldir)).first;
        await _dokun(tester, kaldir);
        expect(
          _pencerede(find.text(m.bilesen_vote_kaldir_aciklama)),
          findsOneWidget,
        );
        await _dokun(tester, _pencerede(find.text(m.etkinlik_vazgec)));
        expect(tasima.giden('DELETE', oylamaSecenegiYolu), isEmpty);
        await _dokun(
          tester,
          _bolumde(find.byTooltip(m.bilesen_vote_kaldir)).first,
        );
        await _dokun(tester, _pencerede(find.text(m.bilesen_vote_kaldir)));
        expect(
          tasima
              .giden('DELETE', oylamaSecenegiYolu)
              .single
              .yolParametreleri['option_id'],
          _secenek1,
        );
        expect(_bolumde(find.text('Göl kenarı')), findsNothing);

        final kapat = _bolumde(find.text(m.bilesen_vote_kapat));
        await _gorunurYap(tester, kapat);
        await _dokun(tester, kapat);
        expect(
          _pencerede(find.text(m.bilesen_vote_kapat_aciklama)),
          findsOneWidget,
        );
        await _dokun(tester, _pencerede(find.text(m.bilesen_vote_kapat)));
        expect(tasima.giden('POST', oylamaKapatYolu), hasLength(1));
        expect(
          _bolumde(find.textContaining(m.bilesen_vote_kapandi)),
          findsOneWidget,
        );
        expect(_bolumde(find.text(m.bilesen_vote_kapat)), findsNothing);
        expect(_bolumde(find.text(m.bilesen_vote_secenek_ekle)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sınır dolunca ekleme düğmesi yerine sınır yazılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        oylama: (_) => oylamaJson(
          secenekler: _serbest(),
          duzenleyebilir: true,
          enCok: 2,
        ),
      );
      await _detayiAc(tester, tasima);
      final sinir = _bolumde(find.text(m.bilesen_vote_secenek_sinir(2)));
      await _gorunurYap(tester, sinir);
      expect(sinir, findsOneWidget);
      expect(_bolumde(find.text(m.bilesen_vote_secenek_ekle)), findsNothing);
    });

    testWidgets('serbest olmayan kaynakta seçenek düzenlenmez', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        ben: organizatorId,
        oylama: (_) => oylamaJson(
          kaynak: 'album',
          secenekler: [
            oylamaSecenegiJson(_yukleme1, yukleme: _yukleme1, kisi: katilimciId),
          ],
          kapatabilir: true,
        ),
      );
      await _detayiAc(tester, tasima);
      final kapat = _bolumde(find.text(m.bilesen_vote_kapat));
      await _gorunurYap(tester, kapat);
      expect(_bolumde(find.text(m.bilesen_vote_secenek_ekle)), findsNothing);
      expect(_bolumde(find.byTooltip(m.bilesen_vote_kaldir)), findsNothing);
    });
  });

  group('kutlama', () {
    for (final tema in _temalar) {
      testWidgets('oylama kazananı: serbest seçenekte etiket, araçta araç ve '
          'sahibi (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(
          oylama: (_) => oylamaJson(
            secenekler: [
              ..._serbest(oy1: 2, oy2: 2),
              oylamaSecenegiJson(
                _yukleme1,
                kisi: organizatorId,
                arac: {'make': 'Ford', 'model': 'Mustang'},
                oy: 2,
                kazanan: true,
              ),
            ],
            oyVeren: 6,
            kapali: true,
          ),
          yanitlar: {
            'GET $kutlamaYolu': (_) => kutlamaJson(
              kaynak: 'vote',
              kaynakTuru: 'vote',
              kazananlar: [
                kutlamaKazananiJson(secenek: _secenek1),
                kutlamaKazananiJson(secenek: _yukleme1, kisi: organizatorId),
              ],
              ilanEdildi: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema, kayit: _kutlamaKaydi);
        final kart = find.descendant(
          of: find.byType(KutlamaBolumu),
          matching: find.byType(KutlamaKarti),
        );
        await _gorunurYap(tester, kart);
        expect(
          find.descendant(of: kart, matching: find.text('Göl kenarı')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: kart,
            matching: find.text(m.bilesen_vote_sahipli('Ford Mustang', 'Ayşe')),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
