import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/soru_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/sorular_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sorular/sorular_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/etkinlik/presentation/arac_ortak.dart';
import 'package:tayfam/features/sikayet/application/moderasyon_kuyrugu.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_metinleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../core/realtime/sahte_soket.dart';
import '../../../core/zaman_sahteleri.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const List<EtkinlikBileseni> _kayit = [SorularBileseni()];

const String _soru1 = '0c1d2e3f-4051-4a62-8b73-9c84d5e6f701';
const String _soru2 = '1d2e3f40-5162-4b73-9c84-ad95e6f70812';
const String _soru3 = '2e3f4051-6273-4c84-ad95-be06f7081923';
const String _soru4 = '3f405162-7384-4d95-be06-cf1708192a34';

const SorularKimligi _kimlik = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
  anahtar: 'questions',
);

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Organizatör "Ayşe", katılımcı "Mert".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(id, id == organizatorId ? 'Ayşe' : 'Mert', ben: id == ben);
}

/// Söyleşi (katalog fikstüründe `talk`: anonim soruya izin veren soru
/// toplama) türünde, sürmekte olan bir etkinlik; soru ucu [sorular]'dır.
/// Oturumdaki kullanıcı [ben].
SahteTayfaTasima _tasima({
  required TayfaYaniti sorular,
  Map<String, TayfaYaniti> yanitlar = const {},
  String ben = katilimciId,
  String? cevap = 'going',
  DateTime? baslangic,
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: 'talk',
      cevap: cevap,
      baslangic: baslangic ?? sabitSimdi.subtract(const Duration(hours: 1)),
      sure: const Duration(hours: 3),
    ),
    'GET $sorularYolu': sorular,
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

Finder _bolumde(Finder bulucu) =>
    find.descendant(of: find.byType(SorularBolumu), matching: bulucu);

Finder _formda(Finder bulucu) =>
    find.descendant(of: find.byType(SoruFormu), matching: bulucu);

/// Bölümdeki "Soru sor" düğmesi.
Finder _sorDugmesi(AppLocalizations m) => _bolumde(
  find.byWidgetPredicate(
    (w) => w is AracDugmesi && w.etiket == m.bilesen_questions_sor,
  ),
);

Finder _menu(String soruId) =>
    find.byKey(ValueKey<String>('soru-islemler-$soruId'));

/// Üç soru: Ayşe'nin adlı sorusu ([ikinciOy]; [oyVerdim]), çağıranın kendi
/// sorusu (4 oy) ve başkasının anonim, cevaplandı sorusu (2 oy).
List<Map<String, Object?>> _ucSoru({int ikinciOy = 1, bool oyVerdim = true}) =>
    [
      soruJson(
        id: _soru2,
        metin: 'Kayıt paylaşılacak mı?',
        yazar: organizatorId,
        oy: ikinciOy,
        oyVerdim: oyVerdim,
      ),
      soruJson(
        id: _soru3,
        metin: 'Sunum dosyası nerede?',
        benim: true,
        oy: 4,
      ),
      soruJson(
        id: _soru1,
        metin: 'Soru-cevap kaç dakika?',
        anonim: true,
        oy: 2,
        cevaplandi: true,
      ),
    ];

void main() {
  final m = lookupAppLocalizations(const Locale('tr'));

  test('katalog fikstüründe soru toplama bileşenini kullanan tür var', () {
    final bilesen = turBilesenleri(testTuru('talk'))
        .where((b) => b.kind == 'questions')
        .single;
    expect(bilesenAnahtari(bilesen), 'questions');
    expect(BilesenParametreleri(bilesen.params).mantik('anonymous'), isTrue);
  });

  test('soru isteği: metin kırpılır, boşluklar teke iner, sınır denetlenir',
      () {
    const kimlik = '7b8c9d0e-1f20-4a31-8b42-5c6d7e8f9012';
    final istek = soruIstegi(
      metin: '  Rota\n\nne   kadar?  ',
      anonim: false,
      istekKimligi: kimlik,
    )!;
    expect(istek.toJson(), {
      'body': 'Rota ne kadar?',
      'client_request_id': kimlik,
    });
    expect(
      soruIstegi(metin: 'Soru', anonim: true, istekKimligi: kimlik)!.anonymous,
      isTrue,
    );
    expect(soruIstegi(metin: '  \n ', anonim: false, istekKimligi: kimlik),
        isNull);
    expect(
      soruIstegi(metin: 'a' * 500, anonim: false, istekKimligi: kimlik),
      isNotNull,
    );
    expect(
      soruIstegi(metin: 'a' * 501, anonim: false, istekKimligi: kimlik),
      isNull,
    );
    final liste = EventQuestionList.fromJson(sorularJson(sorular: _ucSoru()));
    expect(kendiSorularim(liste), 1);
  });

  test('anonim sorunun yazarı modelde yoktur; yazarı gizli şikâyette '
      'yaptırım seçilemez', () {
    final soru = EventQuestion.fromJson(
      soruJson(id: _soru1, anonim: true, yazar: katilimciId),
    );
    expect(soru.authorId, isNull);
    ModerationReport sikayet({String? konu}) => ModerationReport.fromJson({
      'id': _soru2,
      'tayfa_id': ornekTayfaId,
      'target_type': 'event_question',
      'target_id': _soru1,
      'subject_user_id': ?konu,
      'reason': 'spam',
      'priority': 'normal',
      'status': 'open',
      'created_at': '2026-11-10T09:00:00Z',
    });
    expect(yaptirimSecilebilir(sikayet()), isFalse);
    expect(yaptirimSecilebilir(sikayet(konu: katilimciId)), isTrue);
    expect(
      hedefTuruMetni(m, ReportTargetType.eventQuestion),
      m.bilesen_questions_sikayet_turu,
    );
    expect(
      sikayetSorusu(m, ReportTargetType.eventQuestion),
      m.bilesen_questions_sikayet_sorusu,
    );
  });

  group('katılımcı', () {
    for (final tema in _temalar) {
      testWidgets('sorular, anonim ve cevaplandı etiketi; oy verir ve soru '
          'sorar (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final anlam = tester.ensureSemantics();
        var oylandi = false;
        var soruldu = false;
        final tasima = _tasima(
          sorular: (_) => sorularJson(
            sorular: [
              if (soruldu)
                soruJson(id: _soru4, metin: 'Yeni soru', benim: true),
              ..._ucSoru(ikinciOy: oylandi ? 1 : 0, oyVerdim: oylandi),
            ],
            sorabilir: true,
          ),
          yanitlar: {
            'PUT $soruOyuYolu': (_) {
              oylandi = true;
              return null;
            },
            'POST $sorularYolu': (_) {
              soruldu = true;
              return soruJson(id: _soru4, metin: 'Yeni soru', benim: true);
            },
          },
        );
        await _detayiAc(tester, tasima, themeMode: tema);

        final ilk = _bolumde(find.text('Kayıt paylaşılacak mı?'));
        await _gorunurYap(tester, ilk);
        expect(ilk, findsOneWidget);
        expect(_bolumde(find.text(m.bilesen_questions_sayi(3))), findsOneWidget);
        // Adlı sorunun yazarı görünür; anonim sorunun yazarı yoktur.
        expect(_bolumde(find.text('Ayşe')), findsOneWidget);
        expect(
          _bolumde(find.textContaining(m.bilesen_questions_anonim)),
          findsOneWidget,
        );
        expect(_bolumde(find.text('Mert')), findsNothing);
        expect(
          _bolumde(find.text(m.bilesen_questions_sen_sordun)),
          findsOneWidget,
        );
        expect(
          _bolumde(find.textContaining(m.bilesen_questions_cevaplandi)),
          findsOneWidget,
        );
        // Oy sayısı ekran okuyucuda sözle okunur (yalnızca renk değil).
        expect(
          find.bySemanticsLabel(m.bilesen_questions_oy_anlam(2)),
          findsOneWidget,
        );
        final oy = find.bySemanticsLabel(m.bilesen_questions_oy_anlam(0));
        expect(oy, findsOneWidget);

        await _dokun(tester, oy);
        final oyIstegi = tasima.giden('PUT', soruOyuYolu).single;
        expect(oyIstegi.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'questions',
          'question_id': _soru2,
        });
        expect(
          find.bySemanticsLabel(m.bilesen_questions_oy_anlam_verdin(1)),
          findsOneWidget,
        );

        // Soru sor: boş metin gönderilmez; anonim seçilir.
        final sor = _sorDugmesi(m);
        await _gorunurYap(tester, sor);
        await _dokun(tester, sor);
        expect(find.byType(SoruFormu), findsOneWidget);
        final gonder = _formda(find.text(m.bilesen_questions_gonder));
        await _dokun(tester, gonder);
        expect(
          _formda(find.text(m.bilesen_questions_metin_hata(500))),
          findsOneWidget,
        );
        expect(tasima.giden('POST', sorularYolu), isEmpty);
        await tester.enterText(
          _formda(find.byType(TextField)),
          '  Yeni   soru ',
        );
        await _dokun(tester, _formda(find.byType(SwitchListTile)));
        await _dokun(tester, gonder);
        final istek = tasima.giden('POST', sorularYolu).single;
        final govde = istek.govde! as Map<String, Object?>;
        expect(govde['body'], 'Yeni soru');
        expect(govde['anonymous'], isTrue);
        expect(govde['client_request_id'], matches(_uuid));
        expect(find.byType(SoruFormu), findsNothing);
        expect(_bolumde(find.text('Yeni soru')), findsOneWidget);
        expect(tester.takeException(), isNull);
        anlam.dispose();
      });
    }

    testWidgets('sunucu hatası formda kalır; tekrar gönderimde aynı istek '
        'kimliği gider', (tester) async {
      ekranBoyutu(tester);
      var ilk = true;
      final tasima = _tasima(
        sorular: (_) => sorularJson(sorabilir: true),
        yanitlar: {
          'POST $sorularYolu': (_) {
            if (ilk) {
              ilk = false;
              return const ApiOffline();
            }
            return soruJson(id: _soru1, benim: true);
          },
        },
      );
      await _detayiAc(tester, tasima);
      final sor = _sorDugmesi(m);
      await _gorunurYap(tester, sor);
      expect(_bolumde(find.text(m.bilesen_questions_yok)), findsOneWidget);
      await _dokun(tester, sor);
      await tester.enterText(_formda(find.byType(TextField)), 'Ne zaman?');
      final gonder = _formda(find.text(m.bilesen_questions_gonder));
      await _dokun(tester, gonder);
      expect(find.byType(SoruFormu), findsOneWidget);
      await _dokun(tester, gonder);
      final istekler = tasima.giden('POST', sorularYolu);
      expect(istekler, hasLength(2));
      final kimlikler = {
        for (final i in istekler)
          (i.govde! as Map<String, Object?>)['client_request_id'],
      };
      expect(kimlikler, hasLength(1));
      expect(find.byType(SoruFormu), findsNothing);
    });

    testWidgets('kişi başı sınır dolunca "Soru sor" yerine bilgi', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        sorular: (_) => sorularJson(
          sorular: [soruJson(id: _soru1, benim: true)],
          sorabilir: true,
          enCok: 1,
        ),
      );
      await _detayiAc(tester, tasima);
      final bilgi = _bolumde(find.text(m.bilesen_questions_sinir(1)));
      await _gorunurYap(tester, bilgi);
      expect(bilgi, findsOneWidget);
      expect(
        _sorDugmesi(m),
        findsNothing,
      );
    });

    testWidgets('başkasının sorusunu şikâyet eder; kendi sorusunu kaldırır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var kaldirildi = false;
      final tasima = _tasima(
        sorular: (_) => sorularJson(
          sorular: [
            soruJson(id: _soru1, anonim: true),
            if (!kaldirildi)
              soruJson(
                id: _soru3,
                metin: 'Sunum dosyası nerede?',
                benim: true,
                kaldirabilir: true,
              ),
          ],
          sorabilir: true,
        ),
        yanitlar: {
          'DELETE $soruYolu': (_) {
            kaldirildi = true;
            return null;
          },
        },
      );
      await _detayiAc(tester, tasima);
      final kendi = _bolumde(find.text('Sunum dosyası nerede?'));
      await _gorunurYap(tester, kendi);

      // Kendi sorusunda şikâyet yok.
      await _dokun(tester, _menu(_soru3));
      expect(find.text(m.bilesen_questions_sikayet_et), findsNothing);
      await _dokun(tester, find.text(m.bilesen_questions_kaldir));
      expect(find.text(m.bilesen_questions_kaldir_onay), findsOneWidget);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(m.bilesen_questions_kaldir),
        ),
      );
      final silme = tasima.giden('DELETE', soruYolu).single;
      expect(silme.yolParametreleri['question_id'], _soru3);
      expect(kendi, findsNothing);

      // Anonim soruyu şikâyet: yazar istemcide hiç yoktur.
      await _dokun(tester, _menu(_soru1));
      expect(find.text(m.bilesen_questions_kaldir), findsNothing);
      await _dokun(tester, find.text(m.bilesen_questions_sikayet_et));
      expect(find.text(m.bilesen_questions_sikayet_sorusu), findsOneWidget);
    });

    testWidgets('soru kaldırılmışsa hata bildirilir ve liste yeniden okunur',
        (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(
        sorular: (_) => sorularJson(
          sorular: [soruJson(id: _soru2, yazar: organizatorId)],
          sorabilir: true,
        ),
        yanitlar: {
          'PUT $soruOyuYolu': (_) => const ApiProblem(
            type: ProblemType.eventItemNotFound,
            status: 404,
          ),
        },
      );
      await _detayiAc(tester, tasima);
      final soru = _bolumde(find.text('Rota ne kadar sürecek?'));
      await _gorunurYap(tester, soru);
      final once = tasima.giden('GET', sorularYolu).length;
      final anlam = tester.ensureSemantics();
      await _dokun(
        tester,
        find.bySemanticsLabel(m.bilesen_questions_oy_anlam(0)),
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tasima.giden('GET', sorularYolu).length, once + 1);
      anlam.dispose();
    });
  });

  group('üye ve organizatör', () {
    testWidgets('gelmeyen üye soru soramaz, oy veremez; bilgi görür', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final anlam = tester.ensureSemantics();
      final tasima = _tasima(
        cevap: null,
        baslangic: ornekBaslangic,
        sorular: (_) => sorularJson(
          sorular: [soruJson(id: _soru2, yazar: organizatorId, oy: 3)],
        ),
      );
      await _detayiAc(tester, tasima);
      final bilgi = _bolumde(find.text(m.bilesen_questions_katil_bilgi));
      await _gorunurYap(tester, bilgi);
      expect(bilgi, findsOneWidget);
      expect(
        _sorDugmesi(m),
        findsNothing,
      );
      final oy = find.bySemanticsLabel(m.bilesen_questions_oy_anlam(3));
      expect(oy, findsOneWidget);
      await tester.tap(oy, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tasima.giden('PUT', soruOyuYolu), isEmpty);
      anlam.dispose();
    });

    testWidgets('organizatör cevaplandı işaretler ve işareti kaldırır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var cevaplandi = false;
      final tasima = _tasima(
        ben: organizatorId,
        sorular: (_) => sorularJson(
          sorular: [
            soruJson(id: _soru1, anonim: true, cevaplandi: cevaplandi),
          ],
          sorabilir: true,
          isaretleyebilir: true,
        ),
        yanitlar: {
          'PUT $soruCevaplandiYolu': (_) {
            cevaplandi = true;
            return null;
          },
          'DELETE $soruCevaplandiYolu': (_) {
            cevaplandi = false;
            return null;
          },
        },
      );
      await _detayiAc(tester, tasima);
      final soru = _bolumde(find.text('Rota ne kadar sürecek?'));
      await _gorunurYap(tester, soru);
      // Anonim sorunun yazarı organizatöre de gösterilmez.
      expect(_bolumde(find.text('Mert')), findsNothing);
      expect(
        _bolumde(find.textContaining(m.bilesen_questions_cevaplandi)),
        findsNothing,
      );

      await _dokun(tester, _menu(_soru1));
      await _dokun(
        tester,
        find.text(m.bilesen_questions_cevaplandi_isaretle),
      );
      final isaret = tasima.giden('PUT', soruCevaplandiYolu).single;
      expect(isaret.yolParametreleri['question_id'], _soru1);
      expect(
        _bolumde(find.textContaining(m.bilesen_questions_cevaplandi)),
        findsOneWidget,
      );

      await _dokun(tester, _menu(_soru1));
      await _dokun(tester, find.text(m.bilesen_questions_isareti_kaldir));
      expect(tasima.giden('DELETE', soruCevaplandiYolu), hasLength(1));
      expect(
        _bolumde(find.textContaining(m.bilesen_questions_cevaplandi)),
        findsNothing,
      );
    });

    testWidgets('okunamazsa "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var ilk = true;
      final tasima = _tasima(
        sorular: (_) {
          if (ilk) {
            ilk = false;
            return const ApiOffline();
          }
          return sorularJson(sorular: [soruJson(id: _soru1)]);
        },
      );
      await _detayiAc(tester, tasima);
      final tekrar = _bolumde(find.text(arbMetni('etkinlik_tekrar_dene')));
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(_bolumde(find.text('Rota ne kadar sürecek?')), findsOneWidget);
    });
  });

  test('sorular canlı değişince yeniden okunur', () async {
    final tasima = etkinlikTasimasi({
      'GET $sorularYolu': (_) => sorularJson(),
    });
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
    int okuma() => tasima.giden('GET', sorularYolu).length;
    Future<void> bekle() async {
      await pumpEventQueue();
      await c.read(sorularProvider(_kimlik).future);
    }

    void degisti(String anahtar) =>
        soketler.single.cerceve('event.component_changed', {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': anahtar,
        });

    const etkinlik = (tayfaId: ornekTayfaId, etkinlikId: ornekEtkinlikId);
    final detay = c.listen(etkinlikDetayProvider(etkinlik), (_, _) {});
    await c.read(etkinlikDetayProvider(etkinlik).future);
    final durum = c.listen(sorularProvider(_kimlik), (_, _) {});
    await bekle();
    expect(okuma(), 1);

    realtime.baslat();
    await pumpEventQueue();
    await soketler.single.ac();
    await bekle();
    final once = okuma();
    expect(once, greaterThan(1));

    degisti('questions');
    await bekle();
    expect(okuma(), once + 1);

    // Başka bir bileşen soruları etkilemez.
    degisti('schedule');
    await bekle();
    expect(okuma(), once + 1);

    durum.close();
    detay.close();
  });
}
