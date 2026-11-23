import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/liste_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/liste_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/liste/madde_formu.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _maddeYolu = '$listeYolu/{item_id}';
const String _atamaYolu = '$_maddeYolu/assignee';

const String _ocakId = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';
const String _cadirId = '2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f';
const String _digerId = '8a7f6e5d-4c3b-4a2f-9e1d-0c9b8a7f6e5d';

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  ListeBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert", diğer üye "Deniz".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  final ad = switch (id) {
    organizatorId => 'Ayşe',
    katilimciId => 'Mert',
    _ => 'Deniz',
  };
  return profilJson(id, ad, ben: id == ben);
}

Map<String, Object?> _madde(
  String id,
  String ad, {
  int adet = 1,
  String? ustlenen,
}) => {'id': id, 'name': ad, 'quantity': adet, 'assigned_user_id': ?ustlenen};

Map<String, Object?> get _ocak => _madde(_ocakId, 'Ocak', adet: 2);
Map<String, Object?> get _cadir => _madde(_cadirId, 'Çadır');

/// Kamp (katalog fikstüründe `gear` anahtarlı `checklist` bileşeni olan
/// tür); oturumdaki kullanıcı [ben].
SahteTayfaTasima _tasima(
  Map<String, TayfaYaniti> yanitlar, {
  String ben = katilimciId,
  String? cevap = 'going',
  DateTime? baslangic,
  bool yonetebilir = false,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      cevap: cevap,
      baslangic: baslangic ?? yakinBaslangic,
      yonetebilir: yonetebilir,
    ),
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
    find.descendant(of: find.byType(MaddeFormu), matching: bulucu);

/// [etiket]li düğmenin `onPressed`'i.
VoidCallback? _dugme(WidgetTester tester, String etiket) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(etiket),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    )
    .onPressed;

void main() {
  test('katalog fikstüründe liste bileşenini kullanan tür var', () {
    expect(
      turBilesenleri(testTuru('camp')).map((b) => b.kind),
      contains('checklist'),
    );
  });

  group('madde formu', () {
    test('ad zorunlu; adet boşsa gönderilmez', () {
      expect(maddeIstegi(ad: ' Çadır ').istek!.toJson(), {'name': 'Çadır'});
      expect(maddeIstegi(ad: 'Ocak', adet: '2').istek!.toJson(), {
        'name': 'Ocak',
        'quantity': 2,
      });
      expect(maddeIstegi(ad: '').hatalar, {MaddeHatasi.ad});
      expect(maddeIstegi(ad: 'A' * 61).hatalar, {MaddeHatasi.ad});
    });

    test('adet 1–999; adet kapalıysa gönderilmez', () {
      for (final adet in ['0', '1000', 'iki']) {
        expect(maddeIstegi(ad: 'Ocak', adet: adet).hatalar, {
          MaddeHatasi.adet,
        }, reason: adet);
      }
      expect(maddeIstegi(ad: 'Ocak', adet: '999').istek!.quantity, 999);
      expect(
        maddeIstegi(ad: 'Ocak', adet: '5', adetAcik: false).istek!.toJson(),
        {'name': 'Ocak'},
      );
    });

    test('üstlenen assigned_user_id olur; "Henüz kimse"de alan yok', () {
      expect(
        maddeIstegi(
          ad: 'Ocak',
          adet: '1',
          ustlenen: katilimciId,
        ).istek!.toJson(),
        {'name': 'Ocak', 'quantity': 1, 'assigned_user_id': katilimciId},
      );
      expect(
        maddeIstegi(ad: 'Ocak').istek!.toJson().containsKey('assigned_user_id'),
        isFalse,
      );
    });
  });

  test('tanınmayan etiket "item" gibi gösterilir', () {
    Checklist liste(String etiket) =>
        Checklist.fromJson(kontrolListesiJson(etiket: etiket));
    expect(listeEtiketi(liste('duty')), 'duty');
    expect(listeEtiketi(liste('gelecekte')), 'item');
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('katılımcı boştaki malzemeyi üstlenir, sonra vazgeçer '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        String? ustlenen;
        Map<String, Object?> liste() => kontrolListesiJson(
          maddeler: [
            _madde(_ocakId, 'Ocak', adet: 2, ustlenen: organizatorId),
            _madde(_cadirId, 'Çadır', ustlenen: ustlenen),
          ],
          ustlenebilir: true,
        );
        final tasima = _tasima({
          'GET $listeYolu': (_) => liste(),
          'PUT $_atamaYolu': (i) {
            final govde = i.govde! as Map<String, Object?>;
            ustlenen = govde['assigned_user_id'] as String?;
            return liste();
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);

        final ustlen = find.text('Ben getiririm');
        await _gorunurYap(tester, ustlen);
        expect(find.text('Malzeme listesi'), findsOneWidget);
        expect(find.text('1/2 üstlenildi'), findsOneWidget);
        expect(find.text('2 adet'), findsOneWidget);
        expect(find.text('Getirecek:'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_checklist_kimse_ustlenmedi')),
          findsOneWidget,
        );
        expect(find.text('Malzeme ekle'), findsNothing);
        expect(
          find.byTooltip(arbMetni('bilesen_checklist_cikar')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        await _dokun(tester, ustlen);
        final alma = tasima.giden('PUT', _atamaYolu).single;
        expect(alma.yolParametreleri['component_key'], 'gear');
        expect(alma.yolParametreleri['item_id'], _cadirId);
        expect(alma.govde, {'assigned_user_id': katilimciId});
        await _gorunurYap(tester, find.text('Getirecek: Sen'));
        expect(find.text('2/2 üstlenildi'), findsOneWidget);

        final vazgec = find.text(arbMetni('bilesen_checklist_vazgec'));
        await _dokun(tester, vazgec);
        expect(tasima.giden('PUT', _atamaYolu).last.govde, isEmpty);
        await _gorunurYap(tester, ustlen);
        expect(tester.takeException(), isNull);
      });

      testWidgets('yönetici madde ekler: "Kim getirecek?: Ben" '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima(ben: organizatorId, yonetebilir: true, {
          'GET $listeYolu': (_) => kontrolListesiJson(yonetebilir: true),
          'POST $listeYolu': (_) => kontrolListesiJson(
            maddeler: [_madde(_ocakId, 'Tüp', ustlenen: organizatorId)],
            yonetebilir: true,
          ),
        });
        await _detayiAc(tester, tasima, themeMode: tema);
        await _gorunurYap(tester, find.text(arbMetni('bilesen_checklist_yok')));

        await _dokun(tester, find.text('Malzeme ekle'));
        expect(find.byType(MaddeFormu), findsOneWidget);
        expect(_formda(find.text('Kim getirecek?')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
        final adHatasi = arbMetni('bilesen_checklist_ad_hata')
            .replaceAll('{enCok}', '60');
        expect(find.text(adHatasi), findsOneWidget);
        expect(tasima.giden('POST', listeYolu), isEmpty);

        await tester.enterText(find.byType(TextField).first, 'Tüp');
        await _dokun(
          tester,
          _formda(find.text(arbMetni('bilesen_checklist_kim_ben'))),
        );
        await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
        final ekleme = tasima.giden('POST', listeYolu).single;
        expect(ekleme.yolParametreleri['component_key'], 'gear');
        expect(ekleme.govde, {
          'name': 'Tüp',
          'quantity': 1,
          'assigned_user_id': organizatorId,
        });
        expect(find.byType(MaddeFormu), findsNothing);
        await _gorunurYap(tester, find.text('Tüp'));
        expect(find.text('Getirecek: Sen'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('event-not-going formda gösterilir; form açık kalır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(ben: organizatorId, yonetebilir: true, {
        'GET $listeYolu': (_) => kontrolListesiJson(yonetebilir: true),
        'POST $listeYolu': (_) =>
            const ApiProblem(type: ProblemType.eventNotGoing, status: 409),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(tester, find.text('Malzeme ekle'));
      await _dokun(tester, find.text('Malzeme ekle'));
      await tester.enterText(find.byType(TextField).first, 'Tüp');
      await _dokun(
        tester,
        _formda(find.text(arbMetni('bilesen_checklist_kim_ben'))),
      );
      await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
      expect(tasima.giden('POST', listeYolu), hasLength(1));
      expect(
        _formda(find.text(arbMetni('hata_event_not_going'))),
        findsOneWidget,
      );
      expect(find.byType(MaddeFormu), findsOneWidget);
    });

    testWidgets('"Kişi seç" gelenlerden seçer; kişisiz eklenmez', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tasima(ben: organizatorId, yonetebilir: true, {
        'GET $listeYolu': (_) => kontrolListesiJson(yonetebilir: true),
        'GET $katilimcilarYolu': (_) => katilimcilarJson([katilimciId]),
        'POST $listeYolu': (_) => kontrolListesiJson(
          maddeler: [_madde(_cadirId, 'Çadır', ustlenen: katilimciId)],
          yonetebilir: true,
        ),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(tester, find.text('Malzeme ekle'));
      await _dokun(tester, find.text('Malzeme ekle'));
      await tester.enterText(find.byType(TextField).first, 'Çadır');
      await _dokun(
        tester,
        _formda(find.text(arbMetni('bilesen_checklist_kim_kisi'))),
      );
      expect(
        tasima.giden('GET', katilimcilarYolu).last.sorgu['status'],
        'going',
      );
      await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
      expect(
        find.text(arbMetni('bilesen_checklist_kisi_sec_hata')),
        findsOneWidget,
      );
      expect(tasima.giden('POST', listeYolu), isEmpty);

      await _dokun(tester, find.byType(RadioListTile<String>).first);
      await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
      expect(tasima.giden('POST', listeYolu).single.govde, {
        'name': 'Çadır',
        'quantity': 1,
        'assigned_user_id': katilimciId,
      });
    });

    testWidgets('yönetici başkasının atamasını kaldırır ve maddeyi çıkarır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var maddeler = [_madde(_ocakId, 'Ocak', ustlenen: katilimciId), _cadir];
      Map<String, Object?> liste() =>
          kontrolListesiJson(maddeler: maddeler, yonetebilir: true);
      final tasima = _tasima(ben: organizatorId, yonetebilir: true, {
        'GET $listeYolu': (_) => liste(),
        'PUT $_atamaYolu': (_) {
          maddeler = [_madde(_ocakId, 'Ocak'), _cadir];
          return liste();
        },
        'DELETE $_maddeYolu': (i) {
          maddeler = [
            for (final m in maddeler)
              if (m['id'] != i.yolParametreleri['item_id']) m,
          ];
          return liste();
        },
      });
      await _detayiAc(tester, tasima);
      final kaldir = find.byTooltip(
        arbMetni('bilesen_checklist_atamayi_kaldir'),
      );
      await _gorunurYap(tester, kaldir);
      await _dokun(tester, kaldir);
      await _dokun(
        tester,
        find.text(arbMetni('bilesen_checklist_atamayi_kaldir')),
      );
      final atama = tasima.giden('PUT', _atamaYolu).single;
      expect(atama.yolParametreleri['item_id'], _ocakId);
      expect(atama.govde, isEmpty);
      expect(kaldir, findsNothing);

      final cikar = find.byTooltip(arbMetni('bilesen_checklist_cikar'));
      expect(cikar, findsNWidgets(2));
      await _dokun(tester, cikar.last);
      await _dokun(tester, find.text(arbMetni('etkinlik_cikar')));
      expect(tasima.giden('DELETE', _maddeYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
        'component_key': 'gear',
        'item_id': _cadirId,
      });
      expect(find.text('Çadır'), findsNothing);
      expect(find.text('Ocak'), findsOneWidget);
    });

    testWidgets('event-item-taken: kısa bildirim, liste yeniden okunur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var alindi = false;
      final tasima = _tasima({
        'GET $listeYolu': (_) => kontrolListesiJson(
          maddeler: [
            if (alindi)
              _madde(_cadirId, 'Çadır', ustlenen: _digerId)
            else
              _cadir,
          ],
          ustlenebilir: true,
        ),
        'PUT $_atamaYolu': (_) {
          alindi = true;
          return const ApiProblem(
            type: ProblemType.eventItemTaken,
            status: 409,
          );
        },
      });
      await _detayiAc(tester, tasima);
      final ustlen = find.text('Ben getiririm');
      await _gorunurYap(tester, ustlen);
      expect(tasima.giden('GET', listeYolu), hasLength(1));
      await _dokun(tester, ustlen);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_event_item_taken')),
        ),
        findsOneWidget,
      );
      expect(tasima.giden('GET', listeYolu), hasLength(2));
      expect(ustlen, findsNothing);
      await _gorunurYap(tester, find.text('Deniz'));
    });

    testWidgets('düğme gizlenmese de sunucu hatası gösterilir; düğme '
        'yeniden kullanılabilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $listeYolu': (_) => kontrolListesiJson(
          maddeler: [_madde(_ocakId, 'Ocak', ustlenen: katilimciId)],
          ustlenebilir: true,
        ),
        'PUT $_atamaYolu': (_) =>
            const ApiProblem(type: ProblemType.permissionDenied, status: 403),
      });
      await _detayiAc(tester, tasima);
      final vazgec = find.text(arbMetni('bilesen_checklist_vazgec'));
      await _gorunurYap(tester, vazgec);
      await _dokun(tester, vazgec);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_permission_denied')),
        ),
        findsOneWidget,
      );
      expect(_dugme(tester, arbMetni('bilesen_checklist_vazgec')), isNotNull);
    });

    testWidgets('üye ("Geliyorum" değil): bilgi metni, düğme yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(ben: _digerId, cevap: null, {
        'GET $listeYolu': (_) => kontrolListesiJson(maddeler: [_ocak]),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(
        tester,
        find.text(arbMetni('bilesen_checklist_ustlen_bilgi')),
      );
      expect(find.text('Ocak'), findsOneWidget);
      expect(find.text('Ben getiririm'), findsNothing);
      expect(find.text('Malzeme ekle'), findsNothing);
    });

    testWidgets('etkinlik bitince liste kapanır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(baslangic: gecmisBaslangic, {
        'GET $listeYolu': (_) => kontrolListesiJson(maddeler: [_cadir]),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(
        tester,
        find.text(arbMetni('bilesen_checklist_kapandi')),
      );
      expect(find.text('Ben getiririm'), findsNothing);
    });

    testWidgets('görev listesi, adet ve atama kapalı: yalnızca adlar', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(ben: organizatorId, yonetebilir: true, {
        'GET $listeYolu': (_) => kontrolListesiJson(
          maddeler: [_ocak],
          etiket: 'task',
          atama: false,
          adet: false,
          yonetebilir: true,
        ),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(tester, find.text('Görev ekle'));
      expect(find.text('Ocak'), findsOneWidget);
      expect(find.text('2 adet'), findsNothing);
      expect(
        find.text(arbMetni('bilesen_checklist_kimse_ustlenmedi')),
        findsNothing,
      );
      expect(find.textContaining('üstlenildi'), findsNothing);
      await _dokun(tester, find.text('Görev ekle'));
      expect(_formda(find.text('Görev')), findsOneWidget);
      expect(
        _formda(find.text(arbMetni('bilesen_checklist_adet_etiketi'))),
        findsNothing,
      );
      expect(_formda(find.text('Kim üstlenecek?')), findsNothing);
    });

    testWidgets('okunamazsa hata; "Tekrar dene" ile gelir', (tester) async {
      ekranBoyutu(tester);
      var bagli = false;
      final tasima = _tasima({
        'GET $listeYolu': (_) =>
            bagli ? kontrolListesiJson(maddeler: [_cadir]) : const ApiOffline(),
      });
      await _detayiAc(tester, tasima);
      expect(find.byType(MaddeSatiri), findsNothing);

      bagli = true;
      final tekrar = find.descendant(
        of: find.byType(ListeBolumu),
        matching: find.text(arbMetni('etkinlik_tekrar_dene')),
      );
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(find.byType(MaddeSatiri), findsOneWidget);
    });
  });
}
