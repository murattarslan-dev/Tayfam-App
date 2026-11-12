import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_ekrani.dart';
import 'package:tayfam/features/duyuru/presentation/duyuru_karti.dart';
import 'package:tayfam/features/duyuru/presentation/duyurular_ekrani.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _listeyiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  const DuyurularEkrani(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: modulOverridelari(tasima),
);

Future<void> _duyuruyuAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  String duyuruId = duyuruId1,
  ThemeMode themeMode = ThemeMode.light,
}) => widgetAc(
  tester,
  DuyuruEkrani(tayfaId: ornekTayfaId, duyuruId: duyuruId),
  themeMode: themeMode,
  tayfa: modulOverridelari(tasima),
  overrides: [
    sikayetDeposuProvider.overrideWithValue(SikayetDeposu(tasima)),
    profilOkuyucuProvider.overrideWithValue(
      (id) async => const KullaniciAdi('Kişi'),
    ),
    kendiKimligiOkuyucuProvider.overrideWithValue(() async => _benimId),
  ],
);

/// Oturumdaki kullanıcı (duyuruların yazarı değil).
const String _benimId = '00000000-0000-4000-8000-0000000000aa';
const String _sikayetlerYolu = '/v1/tayfas/{tayfa_id}/reports';

SahteTayfaTasima _rolle(String rol, [Map<String, TayfaYaniti>? yanitlar]) =>
    modulTasimasi({
      'GET /v1/tayfas/{tayfa_id}': yanit(modulluGorunum(rol: rol)),
      ...?yanitlar,
    });

const String _uzunGovde =
    'Pazar sabahı Moda sahilinde buluşuyoruz. **Kalın değil** '
    '<b>etiket değil</b> https://ornek.invalid bağlantı değil. '
    'Herkes kendi kahvaltısını getirsin; çay bizden. Yağmur yağarsa '
    'buluşma bir hafta ertelenir ve burada duyurulur.';

/// [hedef]'i görünür yapıp dokunur (formun düğmesi büyük yazıda ekranın
/// altında kalabilir).
Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
}

final Finder _islemMenusu = find.byTooltip(arbMetni('duyuru_islemler'));

void main() {
  group('liste', () {
    testWidgets('duyurular sıralı; sabit olanda etiket', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      await _listeyiAc(
        tester,
        modulTasimasi({
          'GET $duyurularYolu': yanit(
            duyuruListesiJson([
              duyuruJson(duyuruId1, baslik: 'Sabit duyuru', sabit: true),
              duyuruJson(duyuruId2, baslik: 'Sıradan duyuru'),
            ]),
          ),
        }),
      );

      expect(find.byType(DuyuruKarti), findsNWidgets(2));
      expect(find.text(arbMetni('duyuru_sabit')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sabit duyuru')).dy,
        lessThan(tester.getTopLeft(find.text('Sıradan duyuru')).dy),
      );
    });

    testWidgets('üyeye "Duyuru yaz" yok, boş durum var', (tester) async {
      ekranBoyutu(tester);
      await _listeyiAc(tester, _rolle('member'));
      expect(find.text(arbMetni('duyuru_yaz')), findsNothing);
      expect(find.text(arbMetni('tayfa_ana_duyurular_bos')), findsOneWidget);
    });

    testWidgets('moderatöre "Duyuru yaz" var', (tester) async {
      ekranBoyutu(tester);
      await _listeyiAc(tester, _rolle('moderator'));
      expect(find.text(arbMetni('duyuru_yaz')), findsOneWidget);
    });

    testWidgets('sayfalama: "Daha fazla göster" sonraki sayfayı ekliyor', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = modulTasimasi({
        'GET $duyurularYolu': (i) => switch (i.sorgu['page_token']) {
          null => duyuruListesiJson([
            duyuruJson(duyuruId1, baslik: 'Birinci sayfa'),
          ], sonraki: 'opak-1'),
          _ => duyuruListesiJson([
            duyuruJson(
              duyuruId2,
              baslik: 'İkinci sayfa',
              zaman: '2026-11-01T10:00:00Z',
            ),
          ]),
        },
      });
      await _listeyiAc(tester, tasima);
      expect(find.text('İkinci sayfa'), findsNothing);

      await tester.tap(find.text(arbMetni('tayfa_ana_daha_fazla')));
      await tester.pumpAndSettle();

      expect(find.text('Birinci sayfa'), findsOneWidget);
      expect(find.text('İkinci sayfa'), findsOneWidget);
      expect(find.text(arbMetni('tayfa_ana_daha_fazla')), findsNothing);
      final istekler = tasima.giden('GET', duyurularYolu);
      expect(istekler.map((i) => i.sorgu['page_token']), [null, 'opak-1']);
    });

    testWidgets('sonraki sayfa okunamazsa HataSatiri ve tekrar dene', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = modulTasimasi({
        'GET $duyurularYolu': (i) => switch (i.sorgu['page_token']) {
          null => duyuruListesiJson([
            duyuruJson(duyuruId1, baslik: 'Birinci sayfa'),
          ], sonraki: 'opak-1'),
          _ => const ApiOffline(),
        },
      });
      await _listeyiAc(tester, tasima);

      await tester.tap(find.text(arbMetni('tayfa_ana_daha_fazla')));
      await tester.pumpAndSettle();

      expect(find.byType(HataSatiri), findsOneWidget);
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      expect(find.text('Birinci sayfa'), findsOneWidget);

      tasima.yanitlar['GET $duyurularYolu'] = yanit(
        duyuruListesiJson([duyuruJson(duyuruId2, baslik: 'İkinci sayfa')]),
      );
      await tester.tap(find.text(arbMetni('tayfa_ana_tekrar_dene')));
      await tester.pumpAndSettle();
      expect(find.byType(HataSatiri), findsNothing);
      expect(find.text('İkinci sayfa'), findsOneWidget);
    });

    testWidgets('ilk sayfa okunamazsa HataSatiri', (tester) async {
      ekranBoyutu(tester);
      await _listeyiAc(
        tester,
        modulTasimasi({
          'GET $duyurularYolu': yanit(
            const ApiProblem(type: ProblemType.moduleDisabled, status: 403),
          ),
        }),
      );

      expect(find.byType(HataSatiri), findsOneWidget);
      expect(find.text(arbMetni('hata_module_disabled')), findsOneWidget);
      expect(find.text(arbMetni('tayfa_ana_tekrar_dene')), findsOneWidget);
    });

    testWidgets('yenileme başarısızsa liste kalıyor, hata bildiriliyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = modulTasimasi({
        'GET $duyurularYolu': yanit(
          duyuruListesiJson([duyuruJson(duyuruId1, baslik: 'Eldeki')]),
        ),
      });
      await _listeyiAc(tester, tasima);
      tasima.yanitlar['GET $duyurularYolu'] = yanit(const ApiOffline());

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Eldeki'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_baglanti_yok')),
        ),
        findsOneWidget,
      );
    });
  });

  group('duyuru ekranı', () {
    testWidgets('gövde düz metin olarak gösteriliyor', (tester) async {
      ekranBoyutu(tester);
      await _duyuruyuAc(
        tester,
        modulTasimasi({
          'GET $duyuruYolu': yanit(
            duyuruJson(duyuruId1, baslik: 'Pazar', govde: _uzunGovde),
          ),
        }),
      );

      expect(find.text('Pazar'), findsOneWidget);
      // Markdown, HTML ve bağlantı yorumlanmaz; metin olduğu gibi.
      final govde = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(govde.data, _uzunGovde);
      expect(govde.textSpan, isNull);
    });

    testWidgets('biçimsiz kimlikte istek gitmiyor, bulunamadı', (tester) async {
      ekranBoyutu(tester);
      final tasima = modulTasimasi();
      await _duyuruyuAc(tester, tasima, duyuruId: 'gecersiz-kimlik');

      expect(
        find.text(arbMetni('hata_announcement_not_found')),
        findsOneWidget,
      );
      expect(tasima.giden('GET', duyuruYolu), isEmpty);
    });

    testWidgets('bulunamayan duyuru HataSatiri ile', (tester) async {
      ekranBoyutu(tester);
      await _duyuruyuAc(
        tester,
        modulTasimasi({
          'GET $duyuruYolu': yanit(
            const ApiProblem(
              type: ProblemType.announcementNotFound,
              status: 404,
            ),
          ),
        }),
      );

      expect(find.byType(HataSatiri), findsOneWidget);
      expect(
        find.text(arbMetni('hata_announcement_not_found')),
        findsOneWidget,
      );
    });

    testWidgets('üyeye yönetim işlemi yok; yalnızca şikâyet', (tester) async {
      ekranBoyutu(tester);
      await _duyuruyuAc(
        tester,
        _rolle('member', {'GET $duyuruYolu': yanit(duyuruJson(duyuruId1))}),
      );

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('duyuru_sil')), findsNothing);
      expect(find.text(arbMetni('duyuru_duzenle')), findsNothing);
      expect(find.text(arbMetni('sikayet_et')), findsOneWidget);
    });

    testWidgets('kendi duyurusunu şikâyet edemez; üyeye menü yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _duyuruyuAc(
        tester,
        _rolle('member', {
          'GET $duyuruYolu': yanit(duyuruJson(duyuruId1, yazar: _benimId)),
        }),
      );

      expect(_islemMenusu, findsNothing);
    });

    testWidgets('üye şikâyet eder: gerekçe seçilir, POST gider', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _rolle('member', {
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1)),
        'POST $_sikayetlerYolu': yanit({
          'id': '9a8b7c6d-0000-4000-8000-000000000001',
          'tayfa_id': ornekTayfaId,
          'target_type': 'announcement',
          'target_id': duyuruId1,
          'reason': 'spam',
          'status': 'open',
          'created_at': '2026-11-11T10:00:00Z',
        }),
      });
      await _duyuruyuAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('sikayet_et')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('sikayet_soru_duyuru')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('sikayet_gerekce_spam')));
      await tester.pumpAndSettle();
      await _dokun(tester, find.text(arbMetni('sikayet_gonder')));
      await tester.pumpAndSettle();

      final giden = tasima.giden('POST', _sikayetlerYolu);
      expect(giden, hasLength(1));
      expect(giden.single.govde, {
        'target_type': 'announcement',
        'target_id': duyuruId1,
        'reason': 'spam',
      });
      expect(find.text(arbMetni('sikayet_iletildi')), findsOneWidget);
    });

    testWidgets('yönetici siler: onay sorulur, sonra DELETE', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin', {
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1)),
        'DELETE $duyuruYolu': yanit(null),
      });
      await _duyuruyuAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('duyuru_sil')));
      await tester.pumpAndSettle();

      // Vazgeçince istek gitmez.
      expect(find.text(arbMetni('duyuru_sil_onay_baslik')), findsOneWidget);
      await tester.tap(find.text(arbMetni('duyuru_vazgec')));
      await tester.pumpAndSettle();
      expect(tasima.giden('DELETE', duyuruYolu), isEmpty);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('duyuru_sil')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('duyuru_sil')),
        ),
      );
      await tester.pumpAndSettle();

      final istek = tasima.giden('DELETE', duyuruYolu).single;
      expect(istek.yolParametreleri['announcement_id'], duyuruId1);
      expect(find.text(arbMetni('duyuru_silindi')), findsOneWidget);
    });

    testWidgets('sabitleme reddedilirse hata bildiriliyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('moderator', {
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1)),
        'PUT $sabitlemeYolu': yanit(
          const ApiProblem(type: ProblemType.permissionDenied, status: 403),
        ),
      });
      await _duyuruyuAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('duyuru_sabitlemeyi_kaldir')), findsNothing);
      await tester.tap(find.text(arbMetni('duyuru_sabitle')));
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', sabitlemeYolu), hasLength(1));
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(arbMetni('hata_permission_denied')),
        ),
        findsOneWidget,
      );
      expect(find.text(arbMetni('duyuru_sabit')), findsNothing);
    });

    testWidgets('sabitlenince etiket görünüyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin', {
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1)),
        'PUT $sabitlemeYolu': yanit(duyuruJson(duyuruId1, sabit: true)),
      });
      await _duyuruyuAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('duyuru_sabitle')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('duyuru_sabit')), findsOneWidget);
      expect(find.text(arbMetni('duyuru_sabitlendi')), findsOneWidget);
    });

    testWidgets('düzenle formu mevcut değerlerle açıyor ve kaydediyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin', {
        'GET $duyuruYolu': yanit(duyuruJson(duyuruId1, baslik: 'Eski')),
        'PATCH $duyuruYolu': yanit(duyuruJson(duyuruId1, baslik: 'Yeni')),
      });
      await _duyuruyuAc(tester, tasima);

      await tester.tap(_islemMenusu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('duyuru_duzenle')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('duyuru_form_duzenle')), findsOneWidget);
      final baslik = find.widgetWithText(TextField, 'Eski');
      expect(baslik, findsOneWidget);
      await tester.enterText(baslik, 'Yeni');
      await _dokun(tester, find.text(arbMetni('duyuru_form_kaydet')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('duyuru_form_duzenle')), findsNothing);
      expect(tasima.giden('PATCH', duyuruYolu).single.govde, {'title': 'Yeni'});
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text(arbMetni('duyuru_kaydedildi')), findsOneWidget);
    });
  });

  group('form', () {
    Future<void> formuAc(WidgetTester tester, SahteTayfaTasima tasima) async {
      await _listeyiAc(tester, tasima);
      await tester.tap(find.text(arbMetni('duyuru_yaz')));
      await tester.pumpAndSettle();
    }

    Finder alan(String anahtar) =>
        find.widgetWithText(TextField, arbMetni(anahtar));

    testWidgets('boş başlıkta istek gitmiyor, hata görünüyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin');
      await formuAc(tester, tasima);

      await _dokun(tester, find.text(arbMetni('duyuru_form_yayinla')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('duyuru_form_baslik_hatasi')), findsOneWidget);
      expect(tasima.giden('POST', duyurularYolu), isEmpty);
    });

    testWidgets('bağlantı yoksa form açık, girilenler duruyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin', {
        'POST $duyurularYolu': yanit(const ApiOffline()),
      });
      await formuAc(tester, tasima);

      await tester.enterText(alan('duyuru_form_baslik_etiketi'), 'Toplantı');
      await tester.enterText(alan('duyuru_form_govde_etiketi'), 'Saat 9');
      await _dokun(tester, find.text(arbMetni('duyuru_form_yayinla')));
      await tester.pumpAndSettle();

      expect(find.byType(HataSatiri), findsOneWidget);
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);
      expect(find.text('Toplantı'), findsOneWidget);
      expect(find.text(arbMetni('duyuru_form_yeni')), findsOneWidget);
    });

    testWidgets('yayınlanınca form kapanıyor, duyuru listede', (tester) async {
      ekranBoyutu(tester);
      final tasima = _rolle('admin', {
        'POST $duyurularYolu': yanit(
          duyuruJson(duyuruId3, baslik: 'Toplantı', govde: 'Saat 9'),
        ),
      });
      await formuAc(tester, tasima);

      await tester.enterText(alan('duyuru_form_baslik_etiketi'), 'Toplantı');
      await tester.enterText(alan('duyuru_form_govde_etiketi'), 'Saat 9');
      await _dokun(tester, find.text(arbMetni('duyuru_form_yayinla')));
      await tester.pumpAndSettle();

      final istek = tasima.giden('POST', duyurularYolu).single;
      expect(istek.govde, {
        'title': 'Toplantı',
        'body': 'Saat 9',
        'client_request_id': sahteIstekKimligi,
      });
      expect(find.text(arbMetni('duyuru_form_yeni')), findsNothing);
      expect(find.text(arbMetni('duyuru_yayinlandi')), findsOneWidget);
      expect(find.byType(DuyuruKarti), findsOneWidget);
      expect(find.text('Toplantı'), findsOneWidget);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} temada 2× yazıda 320 dp taşmıyor', () {
      testWidgets('liste', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          _rolle('admin', {
            'GET $duyurularYolu': yanit(
              duyuruListesiJson([
                duyuruJson(
                  duyuruId1,
                  baslik: 'Çok uzun başlıklı sabitlenmiş bir duyuru',
                  govde: _uzunGovde,
                  sabit: true,
                ),
                duyuruJson(duyuruId2, govde: _uzunGovde),
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

      testWidgets('duyuru ve menü', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _duyuruyuAc(
          tester,
          _rolle('admin', {
            'GET $duyuruYolu': yanit(
              duyuruJson(
                duyuruId1,
                baslik: 'Çok uzun başlıklı sabitlenmiş bir duyuru',
                govde: _uzunGovde,
                sabit: true,
              ),
            ),
          }),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(_islemMenusu);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('form ve hata', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _listeyiAc(
          tester,
          _rolle('admin', {'POST $duyurularYolu': yanit(const ApiOffline())}),
          themeMode: mod,
        );
        await tester.tap(find.text(arbMetni('duyuru_yaz')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'Çok uzun başlıklı bir duyuru',
        );
        await _dokun(tester, find.text(arbMetni('duyuru_form_yayinla')));
        await tester.pumpAndSettle();
        expect(find.byType(HataSatiri), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
