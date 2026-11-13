import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/anket/presentation/anket_ekrani.dart';
import 'package:tayfam/features/anket/presentation/anket_karti.dart';
import 'package:tayfam/features/anket/presentation/anket_sonuclari.dart';
import 'package:tayfam/features/anket/presentation/anketler_ekrani.dart';
import 'package:tayfam/shell/kayitlar.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _anketiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  String anketId = anketId1,
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  AnketEkrani(tayfaId: ornekTayfaId, anketId: anketId),
  themeMode: themeMode,
  tayfa: anketOverridelari(tasima),
);

Future<void> _listeyiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  String? etkinlikId,
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  AnketlerEkrani(tayfaId: ornekTayfaId, etkinlikId: etkinlikId),
  themeMode: themeMode,
  tayfa: anketOverridelari(tasima),
);

SahteTayfaTasima _tekAnket(
  Map<String, Object?> anket, {
  String rol = 'member',
  Map<String, TayfaYaniti>? yanitlar,
}) => anketTasimasi({
  'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(rol: rol)),
  'GET $anketYolu': yanit(anket),
  ...?yanitlar,
});

/// [hedef]'i görünür yapıp dokunur.
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// [alan]'ı görünür yapıp [metin]'i yazar (büyük yazıda alanlar ekranın
/// altında kalabilir).
Future<void> _yaz(WidgetTester tester, Finder alan, String metin) async {
  await tester.ensureVisible(alan);
  await tester.pumpAndSettle();
  await tester.enterText(alan, metin);
}

final Finder _islemMenusu = find.byTooltip(arbMetni('anket_islemler'));

/// Menüde kapatma yok, yalnızca "Şikâyet et" var (başkasının anketi).
Future<void> _yalnizcaSikayet(WidgetTester tester) async {
  await tester.tap(_islemMenusu);
  await tester.pumpAndSettle();
  expect(find.text(arbMetni('anket_kapat')), findsNothing);
  expect(find.text(arbMetni('sikayet_et')), findsOneWidget);
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
}

final Finder _seninOyun = find.text(arbMetni('anket_senin_oyun'));
final Finder _esikNotu = find.textContaining('5 oydan sonra görünür');
final Finder _ipucu = find.textContaining(arbMetni('anket_oy_verenler_ipucu'));
final Finder _secenekKutusu = find.byType(OySecenegi);
final Finder _sonucSecenegi = find.byType(AnketSonucSecenegi);
final Finder _oyuGonder = find.text('Oyu gönder');

void main() {
  group('gizli anket (kesin kural 7)', () {
    testWidgets('eşiğin altında sayı, yüzde ve çubuk yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(
          anketId1,
          gizli: true,
          oyVeren: 3,
          oylar: [2, 1, 0],
          kendi: [secenekA],
        ),
        yanitlar: {
          'GET $oyVerenlerYolu': yanit({'voters': <Object?>[]}),
        },
      );
      await _anketiAc(tester, tasima);

      expect(_sonucSecenegi, findsNothing);
      expect(_esikNotu, findsOneWidget);
      expect(find.textContaining('3 kişi oy verdi.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('2 oy'), findsNothing);
      expect(find.text('1 oy'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(find.text('1'), findsNothing);
      expect(
        find.textContaining(arbMetni('anket_gizli_kutu_baslik')),
        findsOneWidget,
      );
      expect(
        find.textContaining(arbMetni('anket_gizli_aciklama')),
        findsOneWidget,
      );
      // Kendi oyu yalnızca kendisine, yalnızca kendi seçeneğinin satırında.
      expect(_seninOyun, findsOneWidget);
      expect(
        tester.getCenter(_seninOyun).dy,
        greaterThan(tester.getTopLeft(find.text('Moda sahili')).dy),
      );
      expect(
        tester.getCenter(_seninOyun).dy,
        lessThan(tester.getTopLeft(find.text('Belgrad ormanı')).dy),
      );
      // Seçenekler dokunulmaz; oy verenler istenmez.
      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tasima.giden('GET', oyVerenlerYolu), isEmpty);
      expect(_ipucu, findsNothing);
    });

    testWidgets('eşiğin bir altında (4 oy) da sonuç yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _anketiAc(
        tester,
        _tekAnket(
          anketJson(
            anketId1,
            gizli: true,
            coklu: true,
            oyVeren: 4,
            oylar: [4, 3, 1],
            kendi: [secenekA],
          ),
        ),
      );
      expect(_sonucSecenegi, findsNothing);
      expect(_esikNotu, findsOneWidget);
      expect(find.textContaining('4 kişi oy verdi.'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // Çoklu seçim yüzde notu da yalnızca sayılar görünürken.
      expect(find.text(arbMetni('anket_coklu_yuzde_notu')), findsNothing);
    });

    testWidgets('eşikte sayılar görünür, oy verenler yine istenmez', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(
          anketId1,
          gizli: true,
          oyVeren: 5,
          oylar: [3, 2, 0],
          kendi: [secenekB],
        ),
        yanitlar: {
          'GET $oyVerenlerYolu': yanit({'voters': <Object?>[]}),
        },
      );
      await _anketiAc(tester, tasima);

      expect(_sonucSecenegi, findsNWidgets(3));
      expect(_esikNotu, findsNothing);
      expect(_seninOyun, findsOneWidget);
      expect(find.text('%60'), findsOneWidget);
      expect(find.text('%40'), findsOneWidget);
      final onde = tester
          .widgetList<AnketSonucSecenegi>(_sonucSecenegi)
          .where((c) => c.onde);
      expect(onde.single.secenek.text, 'Moda sahili');
      final kendi = tester
          .widgetList<AnketSonucSecenegi>(_sonucSecenegi)
          .where((c) => c.kendi);
      expect(kendi.single.secenek.text, 'Belgrad ormanı');

      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tasima.giden('GET', oyVerenlerYolu), isEmpty);
      expect(_ipucu, findsNothing);
    });

    testWidgets('yöneticiye de oy verenler gösterilmiyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1, gizli: true, oyVeren: 8, oylar: [5, 3, 0]),
        rol: 'admin',
        yanitlar: {
          'GET $oyVerenlerYolu': yanit({'voters': <Object?>[]}),
        },
      );
      await _anketiAc(tester, tasima);
      await _dokun(tester, find.text(arbMetni('anket_sonuclari_gor')));

      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tasima.giden('GET', oyVerenlerYolu), isEmpty);
    });
  });

  group('açık anket', () {
    testWidgets('seçeneğe dokununca oy verenler listeleniyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1, oyVeren: 2, oylar: [1, 1, 0], kendi: [secenekA]),
        yanitlar: {
          'GET $oyVerenlerYolu': yanit({
            'voters': [
              {'user_id': digerId, 'voted_at': '2026-11-10T11:00:00Z'},
              {'user_id': benimId, 'voted_at': '2026-11-10T11:05:00Z'},
            ],
          }),
        },
      );
      await _anketiAc(tester, tasima);

      expect(_sonucSecenegi, findsNWidgets(3));
      expect(_ipucu, findsOneWidget);
      expect(find.textContaining('2 kişi oy verdi.'), findsOneWidget);
      expect(_seninOyun, findsOneWidget);
      // Yüzde oy veren kişi sayısına göre; seçenek başına oy sayısı.
      expect(find.text('%50'), findsNWidgets(2));
      expect(find.text('%0'), findsOneWidget);
      expect(find.text('1 oy'), findsNWidgets(2));
      expect(find.text('Oy yok'), findsOneWidget);
      expect(find.text('Açan: Ayşe Yılmaz'), findsOneWidget);

      await tester.tap(find.text('Belgrad ormanı'));
      await tester.pumpAndSettle();

      final istek = tasima.giden('GET', oyVerenlerYolu).single;
      expect(istek.yolParametreleri['option_id'], secenekB);
      final sayfa = find.byType(BottomSheet);
      expect(
        find.descendant(of: sayfa, matching: find.text('Belgrad ormanı')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sayfa, matching: find.text('1 kişi oy verdi')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sayfa, matching: find.text('Ayşe Yılmaz')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sayfa, matching: find.text('Ben Üye (sen)')),
        findsOneWidget,
      );
    });

    testWidgets('oyu olmayan seçenek dokunulmuyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1, oyVeren: 1, oylar: [1, 0, 0], kendi: [secenekA]),
      );
      await _anketiAc(tester, tasima);
      await tester.tap(find.text('Şile feneri'));
      await tester.pumpAndSettle();
      expect(tasima.giden('GET', oyVerenlerYolu), isEmpty);
    });
  });

  group('oy verme', () {
    testWidgets('tek seçimli ankette oy veriliyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1),
        yanitlar: {
          'PUT $oyYolu': yanit(
            anketJson(
              anketId1,
              oyVeren: 1,
              oylar: [0, 1, 0],
              kendi: [secenekB],
            ),
          ),
        },
      );
      await _anketiAc(tester, tasima);

      expect(_secenekKutusu, findsNWidgets(3));
      expect(find.text(arbMetni('anket_tek_secim')), findsOneWidget);
      expect(find.text(arbMetni('anket_elle_kapanana_kadar')), findsOneWidget);
      expect(find.text('Henüz oy yok · Açan: Ayşe Yılmaz'), findsOneWidget);
      // Tek seçimde düğmede sayı yok; seçim yokken düğme devre dışı.
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: _oyuGonder,
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Belgrad ormanı'));
      await tester.pumpAndSettle();
      final secili = tester
          .widgetList<OySecenegi>(_secenekKutusu)
          .where((s) => s.secili);
      expect(secili.single.metin, 'Belgrad ormanı');
      expect(_oyuGonder, findsOneWidget);
      // Tek seçimde başka seçenek öncekinin yerini alır.
      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Belgrad ormanı'));
      await tester.pumpAndSettle();
      await _dokun(tester, _oyuGonder);

      expect(tasima.giden('PUT', oyYolu).single.govde, {
        'option_ids': [secenekB],
      });
      expect(find.text(arbMetni('anket_oy_kaydedildi')), findsOneWidget);
      expect(_sonucSecenegi, findsNWidgets(3));
      expect(_seninOyun, findsOneWidget);
      expect(_oyuGonder, findsNothing);
    });

    testWidgets('çok seçimli ankette kutular', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1, coklu: true),
        yanitlar: {
          'PUT $oyYolu': yanit(
            anketJson(
              anketId1,
              coklu: true,
              oyVeren: 1,
              oylar: [1, 0, 1],
              kendi: [secenekA, secenekC],
            ),
          ),
        },
      );
      await _anketiAc(tester, tasima);

      expect(_secenekKutusu, findsNWidgets(3));
      expect(find.text(arbMetni('anket_coklu_secim')), findsOneWidget);
      await tester.tap(find.text('Şile feneri'));
      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      // Düğmede seçilen sayısı yazar.
      await _dokun(tester, find.text('Oyu gönder (2 seçenek)'));

      expect(tasima.giden('PUT', oyYolu).single.govde, {
        'option_ids': [secenekA, secenekC],
      });
      expect(_seninOyun, findsNWidgets(2));
      expect(find.text('%100'), findsNWidgets(2));
      expect(find.text(arbMetni('anket_coklu_yuzde_notu')), findsOneWidget);
    });

    testWidgets('oy reddedilirse hata bildiriliyor, seçim kalıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1),
        yanitlar: {
          'PUT $oyYolu': yanit(
            const ApiProblem(type: ProblemType.pollClosed, status: 409),
          ),
        },
      );
      await _anketiAc(tester, tasima);
      await tester.tap(find.text('Moda sahili'));
      await tester.pumpAndSettle();
      await _dokun(tester, _oyuGonder);

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_poll_closed')),
        ),
        findsOneWidget,
      );
      expect(_secenekKutusu, findsNWidgets(3));
      final secili = tester
          .widgetList<OySecenegi>(_secenekKutusu)
          .where((s) => s.secili);
      expect(secili.single.metin, 'Moda sahili');
    });

    testWidgets('oy değiştirme ve geri çekme', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = _tekAnket(
        anketJson(anketId1, oyVeren: 1, oylar: [1, 0, 0], kendi: [secenekA]),
        yanitlar: {'DELETE $oyYolu': yanit(anketJson(anketId1))},
      );
      await _anketiAc(tester, tasima);

      await _dokun(tester, find.text(arbMetni('anket_oyu_degistir')));
      expect(_secenekKutusu, findsNWidgets(3));
      // Değiştirirken mevcut oy seçili gelir.
      final secili = tester
          .widgetList<OySecenegi>(_secenekKutusu)
          .where((s) => s.secili);
      expect(secili.single.metin, 'Moda sahili');
      await _dokun(tester, find.text(arbMetni('anket_vazgec')));
      expect(_sonucSecenegi, findsNWidgets(3));

      await _dokun(tester, find.text(arbMetni('anket_oyu_geri_cek')));
      expect(tasima.giden('DELETE', oyYolu), hasLength(1));
      expect(find.text(arbMetni('anket_oy_geri_cekildi')), findsOneWidget);
      expect(_secenekKutusu, findsNWidgets(3));
      expect(_seninOyun, findsNothing);
    });

    testWidgets('oy vermeden sonuçlara geçip geri dönülüyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _anketiAc(
        tester,
        _tekAnket(anketJson(anketId1, oyVeren: 3, oylar: [2, 1, 0])),
      );
      await _dokun(tester, find.text(arbMetni('anket_sonuclari_gor')));
      expect(_sonucSecenegi, findsNWidgets(3));
      expect(_oyuGonder, findsNothing);
      expect(find.text(arbMetni('anket_oyu_degistir')), findsNothing);
      await _dokun(tester, find.text(arbMetni('anket_oy_vermeye_don')));
      expect(_secenekKutusu, findsNWidgets(3));
    });

    testWidgets('kapanmış ankette oy düğmesi yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _anketiAc(
        tester,
        _tekAnket(
          anketJson(anketId1, kapali: true, oyVeren: 2, oylar: [2, 0, 0]),
        ),
      );
      expect(find.text(arbMetni('anket_kapandi')), findsOneWidget);
      expect(_oyuGonder, findsNothing);
      expect(find.text(arbMetni('anket_oyu_degistir')), findsNothing);
      expect(_sonucSecenegi, findsNWidgets(3));
      await _yalnizcaSikayet(tester);
    });
  });

  group('kapatma', () {
    testWidgets('üyeye (açan değil) yalnızca şikâyet', (tester) async {
      ekranBoyutu(tester);
      await _anketiAc(tester, _tekAnket(anketJson(anketId1)));
      await _yalnizcaSikayet(tester);
    });

    testWidgets('anketi açana menü var', (tester) async {
      ekranBoyutu(tester);
      await _anketiAc(tester, _tekAnket(anketJson(anketId1, acan: benimId)));
      expect(_islemMenusu, findsOneWidget);
    });

    testWidgets('yönetici onayla kapatıyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tekAnket(
        anketJson(anketId1),
        rol: 'moderator',
        yanitlar: {
          'POST $kapatmaYolu': yanit(anketJson(anketId1, kapali: true)),
        },
      );
      await _anketiAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('anket_kapat')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('anket_kapat_onay_baslik')), findsOneWidget);
      await tester.tap(find.text(arbMetni('anket_vazgec')));
      await tester.pumpAndSettle();
      expect(tasima.giden('POST', kapatmaYolu), isEmpty);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('anket_kapat')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('anket_kapat')),
        ),
      );
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', kapatmaYolu), hasLength(1));
      expect(find.text(arbMetni('anket_kapatildi')), findsOneWidget);
      expect(find.text(arbMetni('anket_kapandi')), findsOneWidget);
      await _yalnizcaSikayet(tester);
    });
  });

  group('anket ekranı', () {
    testWidgets('biçimsiz kimlikte istek gitmiyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = anketTasimasi();
      await _anketiAc(tester, tasima, anketId: 'gecersiz');
      expect(find.text(arbMetni('hata_poll_not_found')), findsOneWidget);
      expect(tasima.giden('GET', anketYolu), isEmpty);
    });

    testWidgets('bulunamayan anket HataSatiri ile', (tester) async {
      ekranBoyutu(tester);
      await _anketiAc(
        tester,
        anketTasimasi({
          'GET $anketYolu': yanit(
            const ApiProblem(type: ProblemType.pollNotFound, status: 404),
          ),
        }),
      );
      expect(find.byType(HataSatiri), findsOneWidget);
      expect(find.text(arbMetni('hata_poll_not_found')), findsOneWidget);
    });

    testWidgets('etkinliğe bağlı ankette etkinlik bağlantısı', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _anketiAc(
        tester,
        _tekAnket(anketJson(anketId1, etkinlik: anketEtkinlikId)),
      );
      expect(find.text(arbMetni('anket_etkinlige_git')), findsOneWidget);
    });
  });

  group('liste', () {
    testWidgets('açık ve kapanmış anketler kartlarla', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _listeyiAc(
        tester,
        anketTasimasi({
          'GET $anketlerYolu': yanit(
            anketListesiJson([
              anketJson(
                anketId1,
                soru: 'Açık soru',
                kendi: [secenekA],
                oyVeren: 4,
                kapanis: '2026-11-20T12:00:00Z',
              ),
              anketJson(anketId2, soru: 'Kapalı soru', kapali: true),
              anketJson(anketId3, soru: 'Gizli soru', gizli: true, oyVeren: 3),
            ]),
          ),
        }),
      );
      expect(find.byType(AnketKarti), findsNWidgets(3));
      // "Açık" bölüm başlığı ve iki açık anketin çipi.
      expect(find.text(arbMetni('anket_bolum_acik')), findsNWidgets(3));
      expect(find.text(arbMetni('anket_bolum_kapanan')), findsOneWidget);
      expect(find.text(arbMetni('anket_kapandi')), findsOneWidget);
      expect(find.text(arbMetni('anket_oy_verdin')), findsOneWidget);
      expect(find.text(arbMetni('anket_ac')), findsOneWidget);
      // Kartta oy sayısı ve kapanış ya da "Gizli anket"; seçenek sayısı yok.
      expect(find.textContaining('4 kişi oy verdi · '), findsOneWidget);
      expect(find.textContaining('kapanır'), findsOneWidget);
      expect(find.text('3 kişi oy verdi · Gizli anket'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      // Kapanan bölüm açık anketlerin altında.
      final kapananBasligi = tester.getTopLeft(
        find.text(arbMetni('anket_bolum_kapanan')),
      );
      expect(
        kapananBasligi.dy,
        greaterThan(tester.getTopLeft(find.text('Gizli soru')).dy),
      );
      expect(
        kapananBasligi.dy,
        lessThan(tester.getTopLeft(find.text('Kapalı soru')).dy),
      );
    });

    testWidgets('boş liste ve etkinlik süzgeci', (tester) async {
      ekranBoyutu(tester);
      final tasima = anketTasimasi();
      await _listeyiAc(tester, tasima, etkinlikId: anketEtkinlikId);
      expect(find.text(arbMetni('anket_etkinlik_liste_bos')), findsOneWidget);
      expect(
        tasima.giden('GET', anketlerYolu).single.sorgu['event_id'],
        anketEtkinlikId,
      );
    });

    testWidgets('ilk sayfa okunamazsa HataSatiri', (tester) async {
      ekranBoyutu(tester);
      await _listeyiAc(
        tester,
        anketTasimasi({
          'GET $anketlerYolu': yanit(
            const ApiProblem(type: ProblemType.moduleDisabled, status: 403),
          ),
        }),
      );
      expect(find.text(arbMetni('hata_module_disabled')), findsOneWidget);
    });
  });

  group('form', () {
    Future<void> formuAc(WidgetTester tester, SahteTayfaTasima tasima) async {
      await _listeyiAc(tester, tasima);
      await tester.tap(find.text(arbMetni('anket_ac')));
      await tester.pumpAndSettle();
    }

    testWidgets('boş soruda istek gitmiyor, hatalar görünüyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = anketTasimasi();
      await formuAc(tester, tasima);
      await _dokun(tester, find.text(arbMetni('anket_form_gonder')));
      expect(find.text(arbMetni('anket_form_soru_hatasi')), findsOneWidget);
      expect(
        find.text(arbMetni('anket_form_secenek_hatasi')),
        findsNWidgets(2),
      );
      expect(tasima.giden('POST', anketlerYolu), isEmpty);
    });

    testWidgets('seçenek ekleniyor ve kaldırılıyor', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      await formuAc(tester, anketTasimasi());
      final kaldir = find.byTooltip(arbMetni('anket_form_secenek_kaldir'));
      expect(kaldir, findsNothing);
      await _dokun(tester, find.text(arbMetni('anket_form_secenek_ekle')));
      expect(find.text('Seçenek 3'), findsOneWidget);
      expect(kaldir, findsNWidgets(3));
      await _dokun(tester, kaldir.first);
      expect(find.text('Seçenek 3'), findsNothing);
    });

    testWidgets('anket açılınca form kapanıyor, liste güncel', (tester) async {
      ekranBoyutu(tester, yukseklik: 1400);
      final tasima = anketTasimasi({
        'POST $anketlerYolu': yanit(anketJson(anketId3, soru: 'Nereye?')),
      });
      await formuAc(tester, tasima);

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(0), 'Nereye?');
      await tester.enterText(alanlar.at(1), 'Moda');
      await tester.enterText(alanlar.at(2), 'Şile');
      await _dokun(tester, find.text(arbMetni('anket_form_gizli')));
      await _dokun(tester, find.text(arbMetni('anket_form_gonder')));

      expect(tasima.giden('POST', anketlerYolu).single.govde, {
        'question': 'Nereye?',
        'options': ['Moda', 'Şile'],
        'anonymous': true,
        'multiple_choice': false,
        'client_request_id': anketIstekId,
      });
      expect(find.text(arbMetni('anket_form_baslik')), findsNothing);
      expect(find.text(arbMetni('anket_acildi')), findsOneWidget);
      expect(find.text('Nereye?'), findsOneWidget);
    });
  });

  group('ana sayfa bölümü ve etkinlik bağlantısı', () {
    testWidgets('yalnızca açık anketler', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await widgetAc(
        tester,
        const Scaffold(body: AnketBolumu(tayfaId: ornekTayfaId)),
        tayfa: anketOverridelari(
          anketTasimasi({
            'GET $anketlerYolu': yanit(
              anketListesiJson([
                anketJson(anketId1, soru: 'Açık soru'),
                anketJson(anketId2, soru: 'Kapalı soru', kapali: true),
              ]),
            ),
          }),
        ),
      );
      expect(find.text(arbMetni('anket_ana_baslik')), findsOneWidget);
      expect(find.text('Açık soru'), findsOneWidget);
      expect(find.text('Kapalı soru'), findsNothing);
    });

    testWidgets('açık anket yoksa yalnızca boş durum', (tester) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const Scaffold(body: AnketBolumu(tayfaId: ornekTayfaId)),
        tayfa: anketOverridelari(anketTasimasi()),
      );
      expect(find.text(arbMetni('anket_ana_bos')), findsOneWidget);
      // "Anket aç" ana sayfanın "Oluştur" sayfasında (2026-11-13).
      expect(find.text(arbMetni('anket_ac')), findsNothing);
    });

    test('kayıtta sıra: etkinlikler, duyurular, anketler', () {
      final anahtarlar = [for (final m in tayfaModulKaydi) m.sunucuAnahtari];
      expect(anahtarlar.indexOf('polls'), greaterThan(-1));
      expect(
        anahtarlar.indexOf('polls'),
        greaterThan(anahtarlar.indexOf('announcements')),
      );
      expect(
        anahtarlar.indexOf('announcements'),
        greaterThan(anahtarlar.indexOf('events')),
      );
      final qa = anahtarlar.indexOf('qa');
      if (qa >= 0) expect(qa, greaterThan(anahtarlar.indexOf('polls')));
    });

    for (final (polls, beklenen) in [
      (true, findsOneWidget),
      (false, findsNothing),
    ]) {
      testWidgets('etkinlik bağlantısı (polls: $polls)', (tester) async {
        ekranBoyutu(tester);
        final gorunum = modulluGorunum();
        ((gorunum['tayfa']! as Map<String, Object?>)['modules']!
                as Map<String, Object?>)['polls'] =
            polls;
        await widgetAc(
          tester,
          const Scaffold(
            body: EtkinlikAnketleriBaglantisi(
              tayfaId: ornekTayfaId,
              etkinlikId: anketEtkinlikId,
            ),
          ),
          tayfa: anketOverridelari(
            anketTasimasi({'GET /v1/tayfas/{tayfa_id}': yanit(gorunum)}),
          ),
        );
        expect(find.text(arbMetni('anket_etkinlik_liste_baslik')), beklenen);
      });
    }
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} temada 2× yazıda 320 dp taşmıyor', () {
      testWidgets('liste', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          anketTasimasi({
            'GET $anketlerYolu': yanit(
              anketListesiJson([
                anketJson(
                  anketId1,
                  soru: 'Pazar sabahı hangi sahilde buluşalım arkadaşlar?',
                  gizli: true,
                  kendi: [secenekA],
                  oyVeren: 3,
                  kapanis: '2026-11-20T18:00:00Z',
                ),
                anketJson(anketId2, kapali: true),
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

      testWidgets('oy verme', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _anketiAc(
          tester,
          _tekAnket(
            anketJson(anketId1, coklu: true, kapanis: '2026-11-20T18:00:00Z'),
            rol: 'admin',
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        expect(_oyuGonder, findsOneWidget);
        await tester.dragUntilVisible(
          find.text(arbMetni('anket_sonuclari_gor')),
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('gizli sonuçlar (eşik altı ve üstü)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _anketiAc(
          tester,
          _tekAnket(
            anketJson(
              anketId1,
              gizli: true,
              oyVeren: 2,
              oylar: [2, 0, 0],
              kendi: [secenekA],
            ),
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await tester.dragUntilVisible(
          _esikNotu,
          find.byType(ListView),
          const Offset(0, -300),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('açık sonuçlar ve oy verenler', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _anketiAc(
          tester,
          _tekAnket(
            anketJson(
              anketId1,
              oyVeren: 7,
              oylar: [4, 3, 0],
              kendi: [secenekA],
              etkinlik: anketEtkinlikId,
            ),
            yanitlar: {
              'GET $oyVerenlerYolu': yanit({
                'voters': [
                  {'user_id': digerId, 'voted_at': '2026-11-10T11:00:00Z'},
                ],
                'next_page_token': 'opak-1',
              }),
            },
          ),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await _dokun(tester, find.text('Belgrad ormanı'));
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Belgrad ormanı'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('form ve hata', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          anketTasimasi({'POST $anketlerYolu': yanit(const ApiOffline())}),
          etkinlikId: anketEtkinlikId,
          themeMode: mod,
        );
        await tester.tap(find.text(arbMetni('anket_ac')));
        await tester.pumpAndSettle();
        final alanlar = find.byType(TextField);
        await _yaz(tester, alanlar.at(0), 'Çok uzun bir anket sorusu');
        await _yaz(tester, alanlar.at(1), 'Moda');
        await _yaz(tester, alanlar.at(2), 'Şile');
        // Odaktaki alan kendini yeniden görünür yapmasın.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await _dokun(tester, find.text(arbMetni('anket_form_gonder')));
        expect(find.byType(HataSatiri), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
