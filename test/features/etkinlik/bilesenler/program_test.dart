import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/program/program_formu.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  ProgramBileseni(),
];

const String _madde1 = '01970000-0000-7000-8000-000000000101';
const String _madde2 = '01970000-0000-7000-8000-000000000102';
const String _madde3 = '01970000-0000-7000-8000-000000000103';

/// Sürmekte olan etkinlik: [sabitSimdi]'den bir saat önce başlamış, altı
/// saat sürer.
final DateTime _baslangic = sabitSimdi.subtract(const Duration(hours: 1));
const Duration _sure = Duration(hours: 6);

Map<String, Object?> _etkinlikJson({bool iptal = false}) => etkinlikJson(
  tur: 'auto_show',
  cevap: 'going',
  baslangic: _baslangic,
  sure: _sure,
  iptal: iptal,
);

Event get _etkinlik => Event.fromJson(_etkinlikJson());

/// İlki şu an süren (bitişi yok, sonraki madde iki saat sonra), ikincisi
/// bitişli iki madde.
List<Map<String, Object?>> _maddeler() => [
  programMaddesiJson(id: _madde1, baslangic: _baslangic),
  programMaddesiJson(
    id: _madde2,
    baslangic: _baslangic.add(const Duration(hours: 2)),
    bitis: _baslangic.add(const Duration(hours: 3)),
    baslik: 'Söyleşi',
    not: 'Ana salonda.',
  ),
];

EventScheduleItem _madde(Map<String, Object?> json) =>
    EventScheduleItem.fromJson(json);

/// Fuar / müze gezisi (katalog fikstüründe buluşma ve program bileşeni
/// var). [program] programın yanıtıdır.
SahteTayfaTasima _tasima({
  required TayfaYaniti program,
  Map<String, TayfaYaniti> yanitlar = const {},
  bool iptal = false,
}) => etkinlikTasimasi({
  'GET $etkinlikYolu': (_) => _etkinlikJson(iptal: iptal),
  'GET $programYolu': program,
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
    find.descendant(of: find.byType(ProgramFormu), matching: bulucu);

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(ProgramBolumu), matching: bulucu);

Finder get _baslikAlani => _formda(find.byType(TextField)).first;

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe program bileşenini kullanan tür var', () {
    final programlar = turBilesenleri(
      testTuru('auto_show'),
    ).where((b) => b.kind == 'schedule').toList();
    expect(programlar, hasLength(1));
    expect(bilesenAnahtari(programlar.single), 'schedule');
    expect(
      BilesenParametreleri(programlar.single.params).sayi('max_items'),
      30,
    );
  });

  group('madde formu', () {
    test('başlık, not ve saatler denetlenir; saatler UTC gider', () {
      final e = _etkinlik;
      final bas = e.startsAt.add(const Duration(minutes: 30));

      final bos = programIstegi(etkinlik: e, baslik: '  ', baslangic: bas);
      expect(bos.istek, isNull);
      expect(bos.hatalar, {ProgramHatasi.baslik});
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'a' * (programBasligiEnCok + 1),
          baslangic: bas,
        ).hatalar,
        {ProgramHatasi.baslik},
      );
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: bas,
          not: 'n' * (programNotuEnCok + 1),
        ).hatalar,
        {ProgramHatasi.not},
      );

      // Başlangıç: etkinlikten en çok bir gün önce, bitişten en çok bir gün
      // sonra.
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: e.startsAt.subtract(
            programPayi + const Duration(minutes: 1),
          ),
        ).hatalar,
        {ProgramHatasi.baslangic},
      );
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: e.startsAt.subtract(programPayi),
        ).hatalar,
        isEmpty,
      );
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: e.endsAt.add(programPayi + const Duration(minutes: 1)),
        ).hatalar,
        {ProgramHatasi.baslangic},
      );
      expect(
        programIstegi(etkinlik: e, baslik: 'Varış', baslangic: null).hatalar,
        {ProgramHatasi.baslangic},
      );

      // Bitiş başlangıçtan sonra, etkinliğin bitişinden en çok bir gün
      // sonra.
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: bas,
          bitis: bas,
        ).hatalar,
        {ProgramHatasi.bitis},
      );
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: bas,
          bitis: e.endsAt.add(programPayi + const Duration(minutes: 1)),
        ).hatalar,
        {ProgramHatasi.bitis},
      );

      final yerel = bas.toLocal();
      final gecerli = programIstegi(
        etkinlik: e,
        baslik: '  Öğle yemeği ',
        baslangic: yerel,
        bitis: yerel.add(const Duration(hours: 1)),
        not: '  ',
      );
      expect(gecerli.hatalar, isEmpty);
      expect(gecerli.istek!.toJson(), {
        'starts_at': bas.toUtc().toIso8601String(),
        'ends_at': bas.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'title': 'Öğle yemeği',
      });
      expect(
        programIstegi(
          etkinlik: e,
          baslik: 'Varış',
          baslangic: bas,
          not: ' Kapıda buluşuyoruz. ',
        ).istek!.note,
        'Kapıda buluşuyoruz.',
      );
    });

    test('yeni maddenin önerilen başlangıcı', () {
      final e = _etkinlik;
      EventSchedule program(List<Map<String, Object?>> maddeler) =>
          EventSchedule.fromJson(programJson(maddeler: maddeler));
      expect(programOnerilenBaslangic(program(const []), e), e.startsAt);
      final maddeler = _maddeler();
      expect(
        programOnerilenBaslangic(program(maddeler), e),
        _baslangic.add(const Duration(hours: 3)),
      );
      expect(
        programOnerilenBaslangic(program(maddeler.take(1).toList()), e),
        _baslangic,
      );
    });
  });

  group('süren madde (istemci hesabı)', () {
    final dort = _baslangic.add(const Duration(hours: 4));
    final program = EventSchedule.fromJson(
      programJson(
        maddeler: [
          ..._maddeler(),
          programMaddesiJson(id: _madde3, baslangic: dort, baslik: 'Kapanış'),
        ],
      ),
    );
    Set<String> suren(Duration sonra, {Event? etkinlik}) =>
        surenMaddeler(program, etkinlik ?? _etkinlik, _baslangic.add(sonra));

    test('bitişi olmayan madde sonrakine kadar, sonuncusu etkinlik bitene '
        'kadar sürer', () {
      expect(suren(const Duration(minutes: -1)), isEmpty);
      expect(suren(Duration.zero), {_madde1});
      expect(suren(const Duration(minutes: 119)), {_madde1});
      expect(suren(const Duration(hours: 2)), {_madde2});
      // İkinci madde 3. saatte biter; üçüncüsü 4. saatte başlar.
      expect(suren(const Duration(hours: 3, minutes: 30)), isEmpty);
      expect(suren(const Duration(hours: 5)), {_madde3});
      expect(suren(_sure), isEmpty);
    });

    test('aynı saatte başlayanlar birlikte sürer; iptalde madde sürmez', () {
      final ayni = EventSchedule.fromJson(
        programJson(
          maddeler: [
            programMaddesiJson(id: _madde1, baslangic: _baslangic),
            programMaddesiJson(id: _madde2, baslangic: _baslangic),
            programMaddesiJson(
              id: _madde3,
              baslangic: _baslangic.add(const Duration(hours: 1)),
            ),
          ],
        ),
      );
      expect(
        surenMaddeler(
          ayni,
          _etkinlik,
          _baslangic.add(const Duration(minutes: 10)),
        ),
        {_madde1, _madde2},
      );
      expect(
        suren(
          Duration.zero,
          etkinlik: Event.fromJson(_etkinlikJson(iptal: true)),
        ),
        isEmpty,
      );
    });
  });

  group('program bölümü', () {
    for (final tema in _temalar) {
      testWidgets('saatler cihazın saatinde, süren madde "Şimdi"; düzenleyen '
          'ekler, düzenler, çıkarır (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final yeni = programMaddesiJson(
          id: _madde3,
          baslangic: _baslangic.add(const Duration(hours: 3)),
          baslik: 'Öğle yemeği',
        );
        final tasima = _tasima(
          program: (_) =>
              programJson(maddeler: _maddeler(), duzenleyebilir: true),
          yanitlar: {
            'POST $programMaddeleriYolu': (_) => programJson(
              maddeler: [..._maddeler(), yeni],
              duzenleyebilir: true,
            ),
            'PUT $programMaddesiYolu': (_) => programJson(
              maddeler: [
                programMaddesiJson(
                  id: _madde1,
                  baslangic: _baslangic,
                  baslik: 'Kapıda buluşma',
                ),
                ..._maddeler().skip(1),
              ],
              duzenleyebilir: true,
            ),
            'DELETE $programMaddesiYolu': (_) => programJson(
              maddeler: _maddeler().skip(1).toList(),
              duzenleyebilir: true,
            ),
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final simdi = _bolumde(find.text(arbMetni('bilesen_schedule_simdi')));
        await _gorunurYap(tester, simdi);
        expect(simdi, findsOneWidget);
        expect(
          _bolumde(find.text(arbMetni('bilesen_schedule_ad'))),
          findsOneWidget,
        );
        expect(_bolumde(find.text('Varış')), findsOneWidget);
        expect(_bolumde(find.text('Söyleşi')), findsOneWidget);
        expect(_bolumde(find.text('Ana salonda.')), findsOneWidget);
        final maddeler = _maddeler();
        expect(
          _bolumde(find.text(programSaatMetni(m, _madde(maddeler.first)))),
          findsOneWidget,
        );
        expect(
          _bolumde(find.text(programSaatMetni(m, _madde(maddeler.last)))),
          findsOneWidget,
        );
        expect(
          programSaatMetni(m, _madde(maddeler.last)),
          m.etkinlik_zaman_araligi(
            etkinlikSaat(m, _baslangic.add(const Duration(hours: 2))),
            etkinlikSaat(m, _baslangic.add(const Duration(hours: 3))),
          ),
        );
        expect(find.text(m.bilesen_schedule_doluluk(2, 20)), findsOneWidget);
        expect(tasima.giden('GET', programYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'schedule',
        });

        // Ekle: başlangıç son maddenin bitişiyle önerilir.
        await _dokun(tester, find.text(arbMetni('bilesen_schedule_ekle')));
        expect(find.byType(ProgramFormu), findsOneWidget);
        expect(
          _formda(
            find.text(
              etkinlikTarihSaat(m, _baslangic.add(const Duration(hours: 3))),
            ),
          ),
          findsOneWidget,
        );
        expect(
          _formda(find.text(arbMetni('bilesen_schedule_bitis_yok'))),
          findsOneWidget,
        );
        await _dokun(tester, _formda(find.text(arbMetni('etkinlik_ekle'))));
        expect(tasima.giden('POST', programMaddeleriYolu), isEmpty);
        expect(
          _formda(find.text(m.bilesen_schedule_baslik_hata(120))),
          findsOneWidget,
        );
        await tester.enterText(_baslikAlani, ' Öğle yemeği ');
        await _dokun(tester, _formda(find.text(arbMetni('etkinlik_ekle'))));
        expect(tasima.giden('POST', programMaddeleriYolu).single.govde, {
          'starts_at': _baslangic
              .add(const Duration(hours: 3))
              .toUtc()
              .toIso8601String(),
          'title': 'Öğle yemeği',
        });
        expect(find.byType(ProgramFormu), findsNothing);
        expect(_bolumde(find.text('Öğle yemeği')), findsOneWidget);
        expect(find.text(m.bilesen_schedule_doluluk(3, 20)), findsOneWidget);

        // Düzenle: değerler maddeden dolar; bütün değerler gönderilir.
        await _dokun(
          tester,
          find.byTooltip(arbMetni('bilesen_schedule_duzenle')).first,
        );
        expect(find.byType(ProgramFormu), findsOneWidget);
        expect(
          tester.widget<TextField>(_baslikAlani).controller!.text,
          'Varış',
        );
        await tester.enterText(_baslikAlani, 'Kapıda buluşma');
        await _dokun(tester, _formda(find.text(arbMetni('etkinlik_kaydet'))));
        final duzenleme = tasima.giden('PUT', programMaddesiYolu).single;
        expect(duzenleme.yolParametreleri['item_id'], _madde1);
        expect(duzenleme.govde, {
          'starts_at': _baslangic.toUtc().toIso8601String(),
          'title': 'Kapıda buluşma',
        });
        expect(_bolumde(find.text('Kapıda buluşma')), findsOneWidget);

        // Çıkar: onaydan sonra.
        await _dokun(
          tester,
          find.byTooltip(arbMetni('bilesen_schedule_cikar')).first,
        );
        expect(
          find.text(arbMetni('bilesen_schedule_cikar_onay')),
          findsOneWidget,
        );
        await _dokun(tester, find.text(arbMetni('etkinlik_cikar')));
        expect(
          tasima
              .giden('DELETE', programMaddesiYolu)
              .single
              .yolParametreleri['item_id'],
          _madde1,
        );
        expect(_bolumde(find.text('Kapıda buluşma')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('üye yalnızca okur; boş program (${tema.name}, 2× yazı, '
          '320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(program: (_) => programJson());
        await _detayiAc(tester, tasima, themeMode: tema);

        final bos = find.text(arbMetni('bilesen_schedule_yok'));
        await _gorunurYap(tester, bos);
        expect(bos, findsOneWidget);
        expect(find.text(arbMetni('bilesen_schedule_ekle')), findsNothing);
        expect(find.text(m.bilesen_schedule_doluluk(0, 20)), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('üye düzenleyemez; program günlere ayrılır', (tester) async {
      ekranBoyutu(tester);
      final ertesiGun = _baslangic.add(const Duration(days: 1));
      final tasima = _tasima(
        program: (_) => programJson(
          maddeler: [
            ..._maddeler(),
            programMaddesiJson(
              id: _madde3,
              baslangic: ertesiGun,
              baslik: 'Dönüş',
            ),
          ],
        ),
      );
      await _detayiAc(tester, tasima);
      final donus = _bolumde(find.text('Dönüş'));
      await _gorunurYap(tester, donus);
      expect(
        _bolumde(find.text(etkinlikKisaGun(m, _baslangic))),
        findsOneWidget,
      );
      expect(_bolumde(find.text(etkinlikKisaGun(m, ertesiGun))), findsOneWidget);
      expect(
        find.byTooltip(arbMetni('bilesen_schedule_duzenle')),
        findsNothing,
      );
      expect(find.byTooltip(arbMetni('bilesen_schedule_cikar')), findsNothing);
      expect(find.text(arbMetni('bilesen_schedule_ekle')), findsNothing);
    });

    testWidgets('iptal edilen etkinlikte "Şimdi" yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        iptal: true,
        program: (_) => programJson(maddeler: _maddeler()),
      );
      await _detayiAc(tester, tasima);
      final varis = _bolumde(find.text('Varış'));
      await _gorunurYap(tester, varis);
      expect(
        _bolumde(find.text(arbMetni('bilesen_schedule_simdi'))),
        findsNothing,
      );
    });

    testWidgets('madde sınırında ekleme yerine bilgi', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        program: (_) => programJson(
          maddeler: _maddeler(),
          enCok: 2,
          duzenleyebilir: true,
        ),
      );
      await _detayiAc(tester, tasima);
      final dolu = find.text(m.bilesen_schedule_dolu(2));
      await _gorunurYap(tester, dolu);
      expect(dolu, findsOneWidget);
      expect(find.text(arbMetni('bilesen_schedule_ekle')), findsNothing);
    });

    testWidgets('sunucu reddederse form açık kalır, hata gösterilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        program: (_) => programJson(duzenleyebilir: true),
        yanitlar: {
          'POST $programMaddeleriYolu': (_) =>
              const ApiProblem(type: ProblemType.invalidRequest, status: 400),
        },
      );
      await _detayiAc(tester, tasima);
      final ekle = find.text(arbMetni('bilesen_schedule_ekle'));
      await _gorunurYap(tester, ekle);
      await _dokun(tester, ekle);
      // Boş programda başlangıç etkinliğin başlangıcıyla önerilir.
      expect(
        _formda(find.text(etkinlikTarihSaat(m, _baslangic))),
        findsOneWidget,
      );
      await tester.enterText(_baslikAlani, 'Varış');
      await _dokun(tester, _formda(find.text(arbMetni('etkinlik_ekle'))));
      expect(tasima.giden('POST', programMaddeleriYolu), hasLength(1));
      expect(find.byType(ProgramFormu), findsOneWidget);
      expect(_formda(find.byType(HataSatiri)), findsOneWidget);
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima(
        program: (_) {
          if (okundu) return programJson(maddeler: _maddeler());
          okundu = true;
          return const ApiOffline();
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(arbMetni('etkinlik_tekrar_dene')));
      await _gorunurYap(tester, tekrar);
      expect(tekrar, findsOneWidget);
      await _dokun(tester, tekrar);
      expect(_bolumde(find.text('Varış')), findsOneWidget);
    });
  });
}
