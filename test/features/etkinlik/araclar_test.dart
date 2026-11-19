import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _avId = '2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f';
const String _digerAvId = '3d4e5f6a-7b8c-4d9e-8f0a-2b3c4d5e6f7a';

/// Oturumdaki kullanıcı [katilimciId]'dir ("Mert"); organizatör "Ayşe".
Map<String, Object?> _profil(TayfaIstegi i) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(
    id,
    id == katilimciId ? 'Mert' : 'Ayşe',
    ben: id == katilimciId,
  );
}

/// Detay ekranını [etkinlik] JSON'uyla açar; [katilimcilar] ise
/// Katılımcılar ekranını.
Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  KonumServisi? konum,
  bool katilimcilar = false,
}) async {
  tasima.yanitlar['GET $profilYolu'] = _profil;
  tasima.yanitlar['GET $hesapYolu'] = (_) => hesapJson(katilimciId);
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, konum: konum),
  );
  yonlendiriciyiAl(tester).go(
    katilimcilar
        ? Adresler.etkinlikKatilimcilari(ornekTayfaId, ornekEtkinlikId)
        : Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
  );
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

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await _gorunurYap(tester, bulucu);
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

/// Kaydırılabilir bir bölümdeki öğeyi görünür yapıp dokunur.
Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  // Odaktaki metin alanı imleci görünür tutmak için kaydırmayı geri
  // almasın (alttan sayfadaki formlar).
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final ekran = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (!(Offset.zero & ekran).contains(tester.getCenter(bulucu))) {
    await tester.ensureVisible(bulucu);
    await tester.pumpAndSettle();
  }
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

/// [ad]'a dokununca [kimlik]in kişi profili açılır (#185).
Future<void> _profilAcilir(
  WidgetTester tester,
  Finder ad,
  String kimlik,
) async {
  await _gorunurYap(tester, ad);
  await tester.tap(ad);
  // Kişi profili yüklenirken dönen gösterge durmaz; yalnızca geçiş.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(uygulamadaKisiProfili(kimlik), findsOneWidget);
}

void main() {
  group('kişi profili (#185)', () {
    testWidgets('detayda organizatör satırı', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(tester, etkinlikTasimasi());
      await _profilAcilir(tester, find.text('Ayşe'), organizatorId);
    });

    testWidgets('katılımcılar ekranında satır', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(tester, etkinlikTasimasi(), katilimcilar: true);
      await _profilAcilir(tester, find.text('Mert'), katilimciId);
    });
  });

  group('varış bildirimi', () {
    for (final tema in _temalar) {
      testWidgets('"Geldim": izin reddi ve ayarlar (${tema.name})', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final konum = SahteKonumServisi(const KonumIzniYok(kalici: true));
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) =>
              etkinlikJson(cevap: 'going', baslangic: yakinBaslangic),
        });
        await _detayiAc(tester, tasima, themeMode: tema, konum: konum);

        final geldim = find.text(arbMetni('etkinlik_varis_geldim'));
        await _gorunurYap(tester, geldim);
        expect(
          find.text(arbMetni('etkinlik_varis_konum_notu')),
          findsOneWidget,
        );
        expect(konum.okuma, 0, reason: 'izin düğmeye basmadan istenmez');

        await tester.tap(geldim);
        await tester.pumpAndSettle();
        expect(konum.okuma, 1);
        expect(
          find.text(arbMetni('etkinlik_konum_izni_baslik')),
          findsOneWidget,
        );
        expect(tasima.giden('POST', varisYolu), isEmpty);

        await tester.tap(find.text(arbMetni('etkinlik_ayarlara_git')));
        await tester.pumpAndSettle();
        expect(konum.uygulamaAyarlari, 1);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('"Geldim": konum gövdede, katılım doğrulanır', (tester) async {
      ekranBoyutu(tester);
      var bildirildi = false;
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          cevap: 'going',
          baslangic: yakinBaslangic,
          katilim: bildirildi ? 'attended' : null,
        ),
        'POST $varisYolu': (_) {
          bildirildi = true;
          return {'attendance': 'attended', 'method': 'location'};
        },
      });
      await _detayiAc(tester, tasima);

      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_varis_geldim')));

      expect(tasima.giden('POST', varisYolu).single.govde, {
        'location': {'lat': sahteKonum.lat, 'lng': sahteKonum.lng},
      });
      expect(find.text(arbMetni('etkinlik_varis_basarili')), findsOneWidget);
      expect(
        find.text(arbMetni('etkinlik_katilim_dogrulandi')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('etkinlik_varis_geldim')), findsNothing);
    });

    testWidgets('çevrimiçi: "Katıldım", konum istenmez', (tester) async {
      ekranBoyutu(tester);
      final konum = SahteKonumServisi();
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          mod: 'online',
          cevap: 'going',
          baslangic: yakinBaslangic,
        ),
        'POST $varisYolu': (_) => {
          'attendance': 'attended',
          'method': 'online',
        },
      });
      await _detayiAc(tester, tasima, konum: konum);

      expect(find.text(arbMetni('etkinlik_varis_geldim')), findsNothing);
      expect(find.text(arbMetni('etkinlik_varis_konum_notu')), findsNothing);
      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_varis_katildim')),
      );
      expect(konum.okuma, 0);
      expect(tasima.giden('POST', varisYolu).single.govde, isEmpty);
    });

    testWidgets('pencere kapalıyken ya da "Belki"de düğme yok', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(cevap: 'going'),
        }),
      );
      expect(find.text(arbMetni('etkinlik_varis_geldim')), findsNothing);
      expect(find.text(arbMetni('etkinlik_varis_soru')), findsNothing);
    });
  });

  group('av günlüğü', () {
    Map<String, Object?> avlar() => {
      'catches': [
        {
          'id': _avId,
          'user_id': katilimciId,
          'species': 'Levrek',
          'length_cm': 42.5,
          'visibility': 'self',
          'location': {'lat': 40.61, 'lng': 31.29},
          'created_at': '2026-11-09T12:00:00Z',
        },
        {
          'id': _digerAvId,
          'user_id': organizatorId,
          'species': 'Çipura',
          'length_cm': 30,
          'visibility': 'self',
          'created_at': '2026-11-09T13:00:00Z',
        },
      ],
    };

    for (final tema in _temalar) {
      testWidgets('liste, mera gizliliği ve ekleme (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final baglanti = SahteBaglantiAcici();
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            tur: 'fishing',
            cevap: 'going',
            katilim: 'attended',
            baslangic: gecmisBaslangic,
            sure: const Duration(hours: 3),
          ),
          'GET $avlarYolu': (_) => avlar(),
          'POST $avlarYolu': (_) => {
            'id': '5f6a7b8c-9d0e-4f1a-8b2c-4d5e6f7a8b9c',
            'user_id': katilimciId,
            'species': 'Lüfer',
            'length_cm': 28.5,
            'visibility': 'self',
            'created_at': '2026-11-11T09:00:00Z',
          },
        });
        tasima.yanitlar['GET $profilYolu'] = _profil;
        tasima.yanitlar['GET $hesapYolu'] = (_) => hesapJson(katilimciId);
        await uygulamayiAc(
          tester,
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: tasima, baglanti: baglanti),
        );
        yonlendiriciyiAl(tester)
            .go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
        await tester.pumpAndSettle();

        await _gorunurYap(tester, find.text('Çipura, 30 cm'));
        expect(find.text('Levrek, 42,5 cm'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_av_yeri_sende')), findsOneWidget);
        // Yalnızca sunucunun yerini döndürdüğü av için harita bağlantısı.
        expect(find.text(arbMetni('etkinlik_av_yeri_ac')), findsOneWidget);
        // Üye yalnızca kendi avını çıkarabilir.
        expect(find.byTooltip(arbMetni('etkinlik_av_cikar')), findsOneWidget);

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_av_yeri_ac')));
        expect(baglanti.noktalar, [(40.61, 31.29)]);

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_av_ekle')));
        await tester.enterText(find.byType(TextField).at(0), 'Lüfer');
        await tester.enterText(find.byType(TextField).at(1), '28,5');
        // Alttan sayfa; varsayılan görünürlük "Yalnızca ben", yer seçilmedi.
        expect(
          find.text(arbMetni('etkinlik_av_gizlilik_notu')),
          findsOneWidget,
        );
        await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
        expect(tasima.giden('POST', avlarYolu).single.govde, {
          'species': 'Lüfer',
          'length_cm': 28.5,
          'client_request_id': sahteEtkinlikIstekKimligi,
        });
        await _gorunurYap(tester, find.text('Lüfer, 28,5 cm'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('avı kaydedenin adı kişi profilini açar (#185)', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            tur: 'fishing',
            cevap: 'going',
            katilim: 'attended',
            baslangic: gecmisBaslangic,
            sure: const Duration(hours: 3),
          ),
          'GET $avlarYolu': (_) => avlar(),
        }),
      );
      await _profilAcilir(tester, find.text('Mert'), katilimciId);
    });

    testWidgets('katılım doğrulanmadıysa ekleme yerine bilgi', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'fishing'),
        }),
      );
      await _gorunurYap(tester, find.text(arbMetni('etkinlik_av_ekle_bilgi')));
      expect(find.text(arbMetni('etkinlik_av_ekle')), findsNothing);
      expect(find.text(arbMetni('etkinlik_av_yok')), findsOneWidget);
    });
  });

  group('ekleme formları alttan sayfa (#187)', () {
    final formlar = <String, (Map<String, Object?> Function(), String)>{
      'av': (
        () => etkinlikJson(
          tur: 'fishing',
          cevap: 'going',
          katilim: 'attended',
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
        ),
        'etkinlik_av_ekle',
      ),
    };
    for (final tema in _temalar) {
      for (final MapEntry(key: ad, value: (etkinlik, dugme))
          in formlar.entries) {
        testWidgets('$ad formu ${tema.name}, 2× yazı, 320 dp, klavye açık: '
            'taşmıyor; altta Vazgeç + Ekle', (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _detayiAc(
            tester,
            etkinlikTasimasi({'GET $etkinlikYolu': (_) => etkinlik()}),
            themeMode: tema,
          );
          await _gorunurDokun(tester, find.text(arbMetni(dugme)).first);
          expect(find.byType(BottomSheet), findsOneWidget);
          tester.view.viewInsets = const FakeViewPadding(bottom: 900);
          addTearDown(tester.view.resetViewInsets);
          await tester.enterText(find.byType(TextField).first, 'Uzun bir ad');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Sayfa klavyenin üstüne kayar.
          expect(
            tester.getBottomLeft(find.byType(SingleChildScrollView).last).dy,
            lessThanOrEqualTo(640 - 300 + 1),
          );
          final vazgec = find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text(arbMetni('etkinlik_vazgec')),
          );
          expect(vazgec, findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.text(arbMetni('etkinlik_ekle')),
            ),
            findsOneWidget,
          );
          await _dokun(tester, vazgec);
          expect(find.byType(BottomSheet), findsNothing);
        });
      }
    }
  });

  group('organizatör düzeltmesi', () {
    for (final tema in _temalar) {
      testWidgets('bitişten sonra katılım eklenir (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            yonetebilir: true,
            baslangic: gecmisBaslangic,
            sure: const Duration(hours: 3),
          ),
          'GET $katilimcilarYolu': (_) =>
              katilimcilarJson([organizatorId, katilimciId]),
          'PUT $duzeltmeYolu': (_) => null,
        });
        await _detayiAc(tester, tasima, themeMode: tema, katilimcilar: true);
        final menu = find.byTooltip(arbMetni('etkinlik_duzeltme'));
        expect(find.text(arbMetni('etkinlik_duzeltme_bilgi')), findsOneWidget);
        // Liste kartı büyük yazıda ekranın altında kalır; kaydırınca kurulur.
        await _gorunurYap(tester, menu);
        // Kendi satırında (Mert) menü yok.
        expect(menu, findsOneWidget);

        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text(arbMetni('etkinlik_duzeltme_ekle')));
        await tester.pumpAndSettle();
        expect(tasima.giden('PUT', duzeltmeYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'user_id': organizatorId,
        });
        expect(find.text(arbMetni('etkinlik_duzeltme_tamam')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('katılımı kaldırmak onay ister', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          yonetebilir: true,
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
        ),
        'GET $katilimcilarYolu': (_) => {
          'attendees': [
            {
              'user_id': organizatorId,
              'status': 'going',
              'attendance': 'attended',
              'updated_at': '2026-11-09T10:00:00Z',
            },
          ],
        },
        'DELETE $duzeltmeYolu': (_) => null,
      });
      await _detayiAc(tester, tasima, katilimcilar: true);
      final menu = find.byTooltip(arbMetni('etkinlik_duzeltme'));
      await _gorunurYap(tester, find.text(arbMetni('etkinlik_duzeltme_bilgi')));
      await tester.ensureVisible(menu);
      await tester.pumpAndSettle();
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('etkinlik_duzeltme_kaldir')));
      await tester.pumpAndSettle();
      expect(
        find.text(arbMetni('etkinlik_duzeltme_kaldir_onay')),
        findsOneWidget,
      );
      expect(tasima.giden('DELETE', duzeltmeYolu), isEmpty);

      await tester.tap(find.text(arbMetni('etkinlik_duzeltme_kaldir')).last);
      await tester.pumpAndSettle();
      expect(tasima.giden('DELETE', duzeltmeYolu), hasLength(1));
    });

    testWidgets('etkinlik bitmeden ya da üyeye menü yok', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(yonetebilir: true),
        }),
        katilimcilar: true,
      );
      await _gorunurYap(tester, find.text('Mert'));
      expect(find.byTooltip(arbMetni('etkinlik_duzeltme')), findsNothing);
      expect(find.text(arbMetni('etkinlik_duzeltme_bilgi')), findsNothing);
    });
  });
}
