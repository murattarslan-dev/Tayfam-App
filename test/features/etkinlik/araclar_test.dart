import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

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
