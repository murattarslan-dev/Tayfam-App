import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/soru_cevap/application/soru_listesi_notifier.dart';
import 'package:tayfam/features/soru_cevap/presentation/cevap_karti.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_bolumu.dart';
import 'package:tayfam/features/soru_cevap/presentation/soru_ekrani.dart';
import 'package:tayfam/features/soru_cevap/presentation/sorular_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _listeyiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  const SorularEkrani(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: soruOverridelari(tasima),
);

Future<void> _soruyuAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  String soruId = soruId1,
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  SoruEkrani(tayfaId: ornekTayfaId, soruId: soruId),
  themeMode: themeMode,
  tayfa: soruOverridelari(tasima),
);

Future<void> _bolumuAc(WidgetTester tester, SahteTayfaTasima tasima) =>
    widgetAc(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: SoruBolumu(tayfaId: ornekTayfaId)),
      ),
      tayfa: soruOverridelari(tasima),
    );

/// [hedef]'i görünür yapıp dokunur.
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

Finder _alan(String anahtar) =>
    find.widgetWithText(TextField, arbMetni(anahtar));

final Finder _soruMenusu = find.byTooltip(arbMetni('soru_islemler'));
final Finder _cevapMenusu = find.byTooltip(arbMetni('soru_cevap_islemler'));

const String _uzunGovde =
    'Dört kişilik, hafif ve **çabuk kurulan** bir çadır arıyoruz. '
    '<b>Etiket değil</b> https://ornek.invalid bağlantı değil. Yağmurda '
    'su almayan, rüzgârda dayanıklı bir şey olursa çok iyi olur.';

/// Biri oturumdaki kullanıcının (2 oy), biri başkasının cevabı.
SahteTayfaTasima _detayTasimasi({
  String rol = 'member',
  String? soruYazari = digerId,
  Map<String, TayfaYaniti>? ek,
}) => soruTasimasi({
  'GET /v1/tayfas/{tayfa_id}': yanit(rolluGorunum(rol: rol)),
  'GET $soruYolu': yanit(
    soruJson(
      soruId1,
      yazar: soruYazari,
      cevapSayisi: 2,
      etiketler: [etiketJson(etiketId1, 'kamp')],
    ),
  ),
  'GET $cevaplarYolu': yanit(
    cevapListesiJson([
      cevapJson(cevapId1, yazar: benimId, oy: 2, govde: 'Kendi cevabım'),
      cevapJson(cevapId2, govde: 'Başkasının cevabı'),
    ]),
  ),
  ...?ek,
});

void main() {
  group('liste', () {
    testWidgets('sorular kartlarla; etiket ve cevap sayısı görünüyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _listeyiAc(
        tester,
        soruTasimasi({
          'GET $sorularYolu': yanit(
            soruListesiJson([
              soruJson(
                soruId1,
                baslik: 'Hangi çadırı alalım?',
                etiketler: [etiketJson(etiketId1, 'kamp')],
                cevapSayisi: 3,
              ),
              soruJson(soruId2, baslik: 'Göl kenarında balık var mı?'),
            ]),
          ),
        }),
      );

      expect(find.byType(SoruSatiri), findsNWidgets(2));
      expect(find.text('Hangi çadırı alalım?'), findsOneWidget);
      // Satırda etiketler, cevap sayısı ve zaman; yazar yok (tasarım:
      // Sorular).
      expect(find.text('kamp'), findsOneWidget);
      expect(find.textContaining('3 cevap · '), findsOneWidget);
      expect(find.textContaining('Henüz cevap yok · '), findsOneWidget);
      expect(find.text(digerAdi), findsNothing);
    });

    testWidgets('boş tayfada boş durum ve "Soru sor"', (tester) async {
      ekranBoyutu(tester);
      await _listeyiAc(tester, soruTasimasi());
      expect(find.text(arbMetni('soru_bos')), findsOneWidget);
      expect(find.text(arbMetni('soru_sor')), findsOneWidget);
    });

    testWidgets('arama yazmayı bırakınca sunucuda yapılıyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = soruTasimasi({
        'GET $sorularYolu': (i) => switch (i.sorgu['q']) {
          null => soruListesiJson([soruJson(soruId1, baslik: 'Tüm sorular')]),
          _ => soruListesiJson([]),
        },
      });
      await _listeyiAc(tester, tasima);

      await tester.enterText(_alan('soru_arama_etiketi'), 'IŞIK');
      await tester.pump(soruAramasiGecikmesi ~/ 2);
      // Gecikme dolmadan istek gitmez.
      expect(tasima.giden('GET', sorularYolu), hasLength(1));
      await tester.pump(soruAramasiGecikmesi);
      await tester.pumpAndSettle();

      final istekler = tasima.giden('GET', sorularYolu);
      expect(istekler.last.sorgu['q'], 'IŞIK');
      expect(find.text(arbMetni('soru_arama_bos')), findsOneWidget);

      await tester.tap(find.byTooltip(arbMetni('soru_arama_temizle')));
      await tester.pumpAndSettle();
      expect(find.text('Tüm sorular'), findsOneWidget);
    });

    testWidgets('etiket çipi süzüyor, ikinci dokunuşta kalkıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = soruTasimasi({
        'GET $etiketlerYolu': yanit({
          'tags': [
            etiketJson(etiketId1, 'kamp', sayi: 3),
            etiketJson(etiketId2, 'balık', sayi: 1),
          ],
        }),
      });
      await _listeyiAc(tester, tasima);

      ChoiceChip cip(String metin) =>
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, metin));
      expect(cip(arbMetni('soru_etiket_tumu')).selected, isTrue);

      await tester.tap(find.widgetWithText(ChoiceChip, 'balık'));
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', sorularYolu).last.sorgu['tag_id'], etiketId2);
      expect(cip('balık').selected, isTrue);
      expect(cip(arbMetni('soru_etiket_tumu')).selected, isFalse);

      await tester.tap(find.widgetWithText(ChoiceChip, 'balık'));
      await tester.pumpAndSettle();
      // Süzgeçsiz liste bellekte değilse yeniden okunur; tag_id gitmez.
      expect(
        tasima.giden('GET', sorularYolu).last.sorgu.containsKey('tag_id'),
        isFalse,
      );

      // "Tümü" seçili etiketi kaldırır.
      await tester.tap(find.widgetWithText(ChoiceChip, 'kamp'));
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', sorularYolu).last.sorgu['tag_id'], etiketId1);
      await tester.tap(
        find.widgetWithText(ChoiceChip, arbMetni('soru_etiket_tumu')),
      );
      await tester.pumpAndSettle();
      expect(cip(arbMetni('soru_etiket_tumu')).selected, isTrue);
      expect(cip('kamp').selected, isFalse);
    });

    testWidgets('ilk sayfa okunamazsa HataSatiri ve tekrar dene', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = soruTasimasi({
        'GET $sorularYolu': yanit(
          const ApiProblem(type: ProblemType.moduleDisabled, status: 403),
        ),
      });
      await _listeyiAc(tester, tasima);
      expect(find.text(arbMetni('hata_module_disabled')), findsOneWidget);

      tasima.yanitlar['GET $sorularYolu'] = yanit(
        soruListesiJson([soruJson(soruId1, baslik: 'Geldi')]),
      );
      await tester.tap(find.text(arbMetni('tayfa_ana_tekrar_dene')));
      await tester.pumpAndSettle();
      expect(find.text('Geldi'), findsOneWidget);
    });
  });

  group('ana sayfa bölümü', () {
    testWidgets('en son iki soru kısa satırla gösteriliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _bolumuAc(
        tester,
        soruTasimasi({
          'GET $sorularYolu': yanit(
            soruListesiJson([
              soruJson(soruId1, baslik: 'Birinci soru burada'),
              soruJson(soruId2, baslik: 'İkinci soru burada'),
              soruJson(soruId3, baslik: 'Üçüncü soru burada'),
              soruJson(soruId4, baslik: 'Dördüncü soru burada'),
            ]),
          ),
        }),
      );
      expect(find.text(arbMetni('soru_bolum_baslik')), findsOneWidget);
      expect(find.byType(SoruSatiri), findsNWidgets(2));
      expect(find.text('Üçüncü soru burada'), findsNothing);
      expect(find.text('Dördüncü soru burada'), findsNothing);
      expect(find.text(arbMetni('soru_sor')), findsNothing);
    });

    testWidgets('boşken yalnızca boş durum', (tester) async {
      ekranBoyutu(tester);
      await _bolumuAc(tester, soruTasimasi());
      expect(find.text(arbMetni('soru_bos')), findsOneWidget);
      // "Soru sor" ana sayfanın "Oluştur" sayfasında (2026-11-13).
      expect(find.text(arbMetni('soru_sor')), findsNothing);
    });
  });

  group('soru ekranı', () {
    testWidgets('soru düz metin; cevaplar ve faydalı sayaçları', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _soruyuAc(
        tester,
        _detayTasimasi(
          ek: {'GET $soruYolu': yanit(soruJson(soruId1, govde: _uzunGovde))},
        ),
      );

      final govde = tester.widget<SelectableText>(
        find.byType(SelectableText).first,
      );
      expect(govde.data, _uzunGovde);
      expect(find.byType(CevapKarti), findsNWidgets(2));
      expect(find.byType(FaydaliDugmesi), findsNWidgets(2));
      expect(find.text(arbMetni('soru_cevap_siralama')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Kendi cevabım')).dy,
        lessThan(tester.getTopLeft(find.text('Başkasının cevabı')).dy),
      );
      // "Cevap yaz" altta sabit.
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(arbMetni('soru_cevap_yaz')),
        ),
        findsNothing,
      );
      expect(find.text(arbMetni('soru_cevap_yaz')), findsOneWidget);
    });

    testWidgets('"En faydalı" yalnızca oy almış ilk cevapta', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _soruyuAc(tester, _detayTasimasi());
      final etiket = find.text(arbMetni('soru_en_faydali'));
      expect(etiket, findsOneWidget);
      expect(
        find.descendant(of: find.byType(CevapKarti).first, matching: etiket),
        findsOneWidget,
      );
    });

    testWidgets('ilk cevabın oyu yoksa "En faydalı" yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _soruyuAc(
        tester,
        _detayTasimasi(
          ek: {
            'GET $cevaplarYolu': yanit(
              cevapListesiJson([
                cevapJson(cevapId1, govde: 'Birinci'),
                cevapJson(cevapId2, govde: 'İkinci'),
              ]),
            ),
          },
        ),
      );
      expect(find.byType(CevapKarti), findsNWidgets(2));
      expect(find.text(arbMetni('soru_en_faydali')), findsNothing);
    });

    testWidgets('başkasının cevabına oy veriliyor, kendi cevabına değil', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        ek: {
          'PUT $oyYolu': yanit(
            cevapJson(
              cevapId2,
              govde: 'Başkasının cevabı',
              oy: 1,
              oyladim: true,
            ),
          ),
        },
      );
      await _soruyuAc(tester, tasima);

      final kendi = tester.widget<FaydaliDugmesi>(
        find.byType(FaydaliDugmesi).at(0),
      );
      expect(kendi.onPressed, isNull);
      expect(find.text('Faydalı · 2'), findsOneWidget);

      await _dokun(tester, find.byType(FaydaliDugmesi).at(1));
      final istek = tasima.giden('PUT', oyYolu).single;
      expect(istek.yolParametreleri['answer_id'], cevapId2);
      final sonra = tester.widget<FaydaliDugmesi>(
        find.byType(FaydaliDugmesi).at(1),
      );
      expect(sonra.isaretli, isTrue);
      expect(sonra.sayi, 1);
      expect(find.text('Faydalı · 1'), findsOneWidget);
    });

    testWidgets('oy reddedilirse hata bildiriliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        ek: {
          'PUT $oyYolu': yanit(
            const ApiProblem(type: ProblemType.ownAnswerVote, status: 403),
          ),
        },
      );
      await _soruyuAc(tester, tasima);
      await _dokun(tester, find.byType(FaydaliDugmesi).at(1));
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_own_answer_vote')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('üye: başkasının sorusunda yalnızca şikâyet', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _soruyuAc(tester, _detayTasimasi());
      expect(_cevapMenusu, findsNWidgets(2));

      await tester.tap(_soruMenusu);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_sil')), findsNothing);
      expect(find.text(arbMetni('soru_duzenle')), findsNothing);
      expect(find.text(arbMetni('sikayet_et')), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // Kendi cevabında şikâyet yok; başkasınınkinde yalnızca şikâyet.
      await tester.tap(_cevapMenusu.first);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_sil')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_et')), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      await tester.tap(_cevapMenusu.last);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_sil')), findsNothing);
      expect(find.text(arbMetni('sikayet_et')), findsOneWidget);
    });

    testWidgets('moderatör başkasının sorusunu siler: gizleme açıklaması', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        rol: 'moderator',
        ek: {'DELETE $soruYolu': yanit(null)},
      );
      await _soruyuAc(tester, tasima);
      expect(_cevapMenusu, findsNWidgets(2));

      await tester.tap(_soruMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('soru_sil')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_sil_onay_yonetim')), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('soru_sil')),
        ),
      );
      await tester.pumpAndSettle();
      final istek = tasima.giden('DELETE', soruYolu).single;
      expect(istek.yolParametreleri['question_id'], soruId1);
      expect(find.text(arbMetni('soru_silindi')), findsOneWidget);
    });

    testWidgets('yazar kendi sorusunu silerken kalıcı silme açıklaması', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(soruYazari: benimId);
      await _soruyuAc(tester, tasima);

      await tester.tap(_soruMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('soru_sil')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_sil_onay_kendi')), findsOneWidget);

      await tester.tap(find.text(arbMetni('soru_vazgec')));
      await tester.pumpAndSettle();
      expect(tasima.giden('DELETE', soruYolu), isEmpty);
    });

    testWidgets('kendi cevabını siliyor; sayı azalıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(ek: {'DELETE $cevapYolu': yanit(null)});
      await _soruyuAc(tester, tasima);
      expect(find.text('2 cevap'), findsOneWidget);

      await tester.tap(_cevapMenusu.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('soru_sil')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_cevap_sil_onay_kendi')), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('soru_sil')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tasima.giden('DELETE', cevapYolu).single.yolParametreleri['answer_id'],
        cevapId1,
      );
      expect(find.text('Kendi cevabım'), findsNothing);
      expect(find.text('1 cevap'), findsOneWidget);
      expect(find.text(arbMetni('soru_cevap_silindi')), findsOneWidget);
    });

    testWidgets('biçimsiz kimlikte istek gitmiyor, bulunamadı', (tester) async {
      ekranBoyutu(tester);
      final tasima = soruTasimasi();
      await _soruyuAc(tester, tasima, soruId: 'gecersiz');
      expect(find.text(arbMetni('hata_question_not_found')), findsOneWidget);
      expect(tasima.giden('GET', soruYolu), isEmpty);
    });

    testWidgets('silinmiş kullanıcının sorusu', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      await _soruyuAc(
        tester,
        _detayTasimasi(
          ek: {'GET $soruYolu': yanit(soruJson(soruId1, yazar: null))},
        ),
      );
      expect(find.text(arbMetni('kullanici_silinmis')), findsOneWidget);
    });
  });

  group('formlar', () {
    testWidgets('cevap yazılıyor; listeye ve sayıya yansıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        ek: {
          'POST $cevaplarYolu': yanit(
            cevapJson(cevapId3, yazar: benimId, govde: 'Yeni cevap'),
          ),
        },
      );
      await _soruyuAc(tester, tasima);

      await _dokun(tester, find.text(arbMetni('soru_cevap_yaz')));
      expect(find.text(arbMetni('soru_cevap_form_yeni')), findsWidgets);

      await _dokun(tester, find.text(arbMetni('soru_cevap_form_gonder')));
      expect(
        find.text(arbMetni('soru_cevap_form_govde_hatasi')),
        findsOneWidget,
      );
      expect(tasima.giden('POST', cevaplarYolu), isEmpty);

      await tester.enterText(
        _alan('soru_cevap_form_govde_etiketi'),
        'Yeni cevap',
      );
      await _dokun(tester, find.text(arbMetni('soru_cevap_form_gonder')));

      expect(tasima.giden('POST', cevaplarYolu).single.govde, {
        'body': 'Yeni cevap',
        'client_request_id': sahteIstekKimligi,
      });
      expect(find.text('Yeni cevap'), findsOneWidget);
      expect(find.text('3 cevap'), findsOneWidget);
      expect(find.text(arbMetni('soru_cevap_gonderildi')), findsOneWidget);
    });

    testWidgets('soru soruluyor: başlık doğrulanıyor, etiket ekleniyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = soruTasimasi({
        'GET $etiketlerYolu': yanit({
          'tags': [etiketJson(etiketId1, 'Işıklandırma')],
        }),
        'POST $sorularYolu': yanit(
          soruJson(soruId1, baslik: 'Kamp için hangi çadırı alalım?'),
        ),
      });
      await _listeyiAc(tester, tasima);
      await _dokun(tester, find.text(arbMetni('soru_sor')));
      expect(find.text(arbMetni('soru_form_yeni')), findsWidgets);

      await tester.enterText(_alan('soru_form_baslik_etiketi'), 'Kısa');
      await _dokun(tester, find.text(arbMetni('soru_form_gonder')));
      expect(find.text(arbMetni('soru_form_baslik_hatasi')), findsOneWidget);
      expect(tasima.giden('POST', sorularYolu), isEmpty);

      await tester.enterText(
        _alan('soru_form_baslik_etiketi'),
        'Kamp için hangi çadırı alalım?',
      );
      // Var olan etiket Türkçe harfle öneriliyor.
      await tester.enterText(_alan('soru_form_etiket_etiketi'), 'IŞIK');
      await tester.pumpAndSettle();
      await _dokun(tester, find.widgetWithText(ActionChip, 'Işıklandırma'));
      expect(find.widgetWithText(InputChip, 'Işıklandırma'), findsOneWidget);
      // Eklenmemiş yazılı etiket gönderimde eklenir.
      await tester.enterText(_alan('soru_form_etiket_etiketi'), ' çadır ');
      await _dokun(tester, find.text(arbMetni('soru_form_gonder')));

      expect(tasima.giden('POST', sorularYolu).single.govde, {
        'title': 'Kamp için hangi çadırı alalım?',
        'tags': ['Işıklandırma', 'çadır'],
        'client_request_id': sahteIstekKimligi,
      });
      expect(_alan('soru_form_baslik_etiketi'), findsNothing);
      expect(find.text(arbMetni('soru_soruldu')), findsOneWidget);
      expect(find.text('Kamp için hangi çadırı alalım?'), findsOneWidget);
    });

    testWidgets('soru düzenleniyor; yalnızca değişen alan gidiyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        soruYazari: benimId,
        ek: {
          'PATCH $soruYolu': yanit(
            soruJson(
              soruId1,
              yazar: benimId,
              baslik: 'Hangi çadır daha iyi olur?',
            ),
          ),
        },
      );
      await _soruyuAc(tester, tasima);
      await tester.tap(_soruMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('soru_duzenle')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('soru_form_duzenle')), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Kamp için hangi çadırı alalım?'),
        'Hangi çadır daha iyi olur?',
      );
      await _dokun(tester, find.text(arbMetni('soru_form_kaydet')));

      expect(tasima.giden('PATCH', soruYolu).single.govde, {
        'title': 'Hangi çadır daha iyi olur?',
      });
      expect(find.text('Hangi çadır daha iyi olur?'), findsOneWidget);
      expect(find.text(arbMetni('soru_kaydedildi')), findsOneWidget);
    });

    testWidgets('bağlantı yoksa cevap formu açık kalıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = _detayTasimasi(
        ek: {'POST $cevaplarYolu': yanit(const ApiOffline())},
      );
      await _soruyuAc(tester, tasima);
      await _dokun(tester, find.text(arbMetni('soru_cevap_yaz')));
      await tester.enterText(
        _alan('soru_cevap_form_govde_etiketi'),
        'Taslak cevap',
      );
      await _dokun(tester, find.text(arbMetni('soru_cevap_form_gonder')));
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      expect(find.text('Taslak cevap'), findsOneWidget);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} temada 2× yazıda 320 dp taşmıyor', () {
      testWidgets('liste, arama ve etiketler', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          soruTasimasi({
            'GET $etiketlerYolu': yanit({
              'tags': [
                etiketJson(etiketId1, 'kamp ateşi ve ekipman'),
                etiketJson(etiketId2, 'balık'),
              ],
            }),
            'GET $sorularYolu': yanit(
              soruListesiJson([
                soruJson(
                  soruId1,
                  baslik: 'Çok uzun başlıklı bir kamp sorusu burada duruyor',
                  govde: _uzunGovde,
                  cevapSayisi: 12,
                  etiketler: [
                    etiketJson(etiketId1, 'kamp ateşi ve ekipman'),
                    etiketJson(etiketId2, 'balık'),
                  ],
                ),
              ], sonraki: 'opak-1'),
            ),
          }),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(
          find.text(arbMetni('tayfa_ana_daha_fazla')),
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('soru, cevaplar ve menü', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _soruyuAc(
          tester,
          _detayTasimasi(
            rol: 'admin',
            ek: {
              'GET $soruYolu': yanit(
                soruJson(
                  soruId1,
                  baslik: 'Çok uzun başlıklı bir kamp sorusu burada duruyor',
                  govde: _uzunGovde,
                  cevapSayisi: 2,
                  etiketler: [etiketJson(etiketId1, 'kamp ateşi ve ekipman')],
                ),
              ),
            },
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(
          find.text('Başkasının cevabı'),
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(_soruMenusu);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('soru formu ve hatalar', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          soruTasimasi({'POST $sorularYolu': yanit(const ApiOffline())}),
          themeMode: mod,
        );
        await _dokun(tester, find.text(arbMetni('soru_sor')));
        await tester.enterText(
          find.byType(TextField).first,
          'Çok uzun başlıklı bir kamp sorusu',
        );
        await tester.enterText(
          _alan('soru_form_etiket_etiketi'),
          'kamp ateşi ve ekipman',
        );
        await _dokun(tester, find.text(arbMetni('soru_form_etiket_ekle')));
        await _dokun(tester, find.text(arbMetni('soru_form_gonder')));
        expect(find.byType(HataSatiri), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cevap formu', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _soruyuAc(tester, _detayTasimasi(), themeMode: mod);
        // "Cevap yaz" altta sabit; kaydırmadan görünür.
        await _dokun(tester, find.text(arbMetni('soru_cevap_yaz')));
        expect(find.text(arbMetni('soru_baslik')), findsOneWidget);
        await _dokun(tester, find.text(arbMetni('soru_cevap_form_gonder')));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
