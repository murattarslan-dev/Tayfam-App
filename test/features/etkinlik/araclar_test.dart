import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/data/konum_servisi.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';
import 'package:tayfam/features/etkinlik/presentation/rota_secici_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _aracId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';
const String _digerAracId = '8a7f6e5d-4c3b-4a2f-9e1d-0c9b8a7f6e5d';
const String _malzemeId = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';
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

/// Detay ekranını [etkinlik] JSON'uyla açar.
Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  KonumServisi? konum,
}) async {
  tasima.yanitlar['GET $profilYolu'] = _profil;
  tasima.yanitlar['GET $hesapYolu'] = (_) => hesapJson(katilimciId);
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(tasima: tasima, konum: konum),
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

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await _gorunurYap(tester, bulucu);
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

/// Kaydırılabilir bir bölümdeki öğeyi görünür yapıp dokunur.
Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

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
      expect(find.text(arbMetni('etkinlik_varis_baslik')), findsNothing);
    });
  });

  group('konvoy', () {
    Map<String, Object?> konvoy({List<Map<String, Object?>>? araclar}) =>
        etkinlikJson(
          tur: 'convoy',
          cevap: 'going',
          baslangic: yakinBaslangic,
          ayrinti: {
            'route': [
              {'lat': 40.6, 'lng': 31.28},
              {'lat': 40.7, 'lng': 31.4},
            ],
            'vehicles':
                araclar ??
                [
                  {
                    'id': _aracId,
                    'user_id': katilimciId,
                    'make': 'Anadol',
                    'model': 'A1',
                    'model_year': 1972,
                    'color': 'Turuncu',
                    'plate': '34 AB 1972',
                  },
                  {
                    'id': _digerAracId,
                    'user_id': organizatorId,
                    'make': 'Murat',
                    'model': '124',
                  },
                ],
          },
        );

    for (final tema in _temalar) {
      testWidgets('liste: kendi aracında değiştir ve çıkar (${tema.name})', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _detayiAc(
          tester,
          etkinlikTasimasi({'GET $etkinlikYolu': (_) => konvoy()}),
          themeMode: tema,
        );
        await _gorunurYap(tester, find.text('Murat 124'));
        expect(find.text('Anadol A1'), findsOneWidget);
        expect(find.text('1972, Turuncu'), findsOneWidget);
        expect(
          find.byTooltip(arbMetni('etkinlik_konvoy_arac_cikar')),
          findsOneWidget,
        );
        expect(
          find.byTooltip(arbMetni('etkinlik_konvoy_arac_degistir')),
          findsOneWidget,
        );
        expect(find.text(arbMetni('etkinlik_konvoy_arac_ekle')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('aracını ekler: plaka isteğe bağlı', (tester) async {
      ekranBoyutu(tester);
      const arac = {'id': _aracId, 'user_id': katilimciId, 'make': 'Anadol'};
      var eklendi = false;
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => konvoy(araclar: [if (eklendi) arac]),
        'POST $araclarYolu': (_) {
          eklendi = true;
          return arac;
        },
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(
        tester,
        find.text(arbMetni('etkinlik_konvoy_arac_yok')),
      );

      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_konvoy_arac_ekle')),
      );
      expect(find.text(arbMetni('etkinlik_arac_plaka_notu')), findsOneWidget);
      await tester.tap(find.text(arbMetni('etkinlik_kaydet')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_arac_marka_hata')), findsOneWidget);
      expect(tasima.giden('POST', araclarYolu), isEmpty);

      await tester.enterText(find.byType(TextField).first, 'Anadol');
      await tester.tap(find.text(arbMetni('etkinlik_kaydet')));
      await tester.pumpAndSettle();
      expect(tasima.giden('POST', araclarYolu).single.govde, {
        'make': 'Anadol',
      });
      expect(find.text('Anadol'), findsOneWidget);
    });

    testWidgets('yönetici başkasının aracını çıkarır', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => {...konvoy(), 'caller_can_manage': true},
        'DELETE $aracYolu': (_) => null,
      });
      await _detayiAc(tester, tasima);
      final cikar = find.byTooltip(arbMetni('etkinlik_konvoy_arac_cikar'));
      await _gorunurYap(tester, find.text('Murat 124'));
      await tester.ensureVisible(cikar.last);
      await tester.pumpAndSettle();
      expect(cikar, findsNWidgets(2));

      await tester.tap(cikar.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('etkinlik_cikar')));
      await tester.pumpAndSettle();
      expect(tasima.giden('DELETE', aracYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
        'vehicle_id': _digerAracId,
      });
    });
  });

  group('kamp', () {
    const ocak = {
      'id': _malzemeId,
      'name': 'Ocak',
      'quantity': 2,
      'assigned_user_id': organizatorId,
    };
    const cadir = {
      'id': '4e5f6a7b-8c9d-4e0f-8a1b-3c4d5e6f7a8b',
      'name': 'Çadır',
      'quantity': 1,
    };

    Map<String, Object?> kamp({
      bool yonetebilir = false,
      List<Map<String, Object?>> malzemeler = const [ocak],
    }) => etkinlikJson(
      yonetebilir: yonetebilir,
      ayrinti: {'site_name': 'Göl kenarı', 'items': malzemeler},
    );

    for (final tema in _temalar) {
      testWidgets('yönetici ekler ve çıkarır (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var malzemeler = [ocak];
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) =>
              kamp(yonetebilir: true, malzemeler: malzemeler),
          'POST $malzemelerYolu': (_) {
            malzemeler = [...malzemeler, cadir];
            return cadir;
          },
          'DELETE $malzemeYolu': (i) {
            final id = i.yolParametreleri['item_id'];
            malzemeler = [
              for (final m in malzemeler)
                if (m['id'] != id) m,
            ];
            return null;
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);
        await _gorunurYap(tester, find.text('Ocak'));
        expect(find.text('2 adet'), findsOneWidget);

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_kamp_malzeme_ekle')),
        );
        await tester.enterText(find.byType(TextField).first, 'Çadır');
        await tester.tap(find.text(arbMetni('etkinlik_ekle')));
        await tester.pumpAndSettle();
        expect(tasima.giden('POST', malzemelerYolu).single.govde, {
          'name': 'Çadır',
        });
        await _gorunurYap(tester, find.text('Çadır'));

        final cikar = find.byTooltip(arbMetni('etkinlik_kamp_malzeme_cikar'));
        await _gorunurYap(tester, cikar.first);
        await tester.tap(cikar.first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(arbMetni('etkinlik_cikar')));
        await tester.pumpAndSettle();
        expect(tasima.giden('DELETE', malzemeYolu), hasLength(1));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('üye listeyi görür; ekleme ve çıkarma yok', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({'GET $etkinlikYolu': (_) => kamp()}),
      );
      await _gorunurYap(tester, find.text('Ocak'));
      expect(find.text(arbMetni('etkinlik_kamp_malzeme_ekle')), findsNothing);
      expect(
        find.byTooltip(arbMetni('etkinlik_kamp_malzeme_cikar')),
        findsNothing,
      );
    });
  });

  group('yürüyüş', () {
    for (final tema in _temalar) {
      testWidgets('"Çıktım" sonra "Döndüm" (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            tur: 'hike',
            cevap: 'going',
            baslangic: yakinBaslangic,
            ayrinti: {'difficulty': 3},
          ),
          'POST $cikisYolu': (_) => {'started_at': '2026-11-11T09:05:00Z'},
          'POST $donusYolu': (_) => {
            'started_at': '2026-11-11T09:05:00Z',
            'returned_at': '2026-11-11T15:40:00Z',
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);
        expect(
          find.text(arbMetni('etkinlik_varis_geldim')),
          findsNothing,
          reason: 'yürüyüşte katılım "Çıktım" ile',
        );

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_yuruyus_ciktim')),
        );
        expect(tasima.giden('POST', cikisYolu).single.govde, isEmpty);
        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_yuruyus_dondum')),
        );
        expect(tasima.giden('POST', donusYolu), hasLength(1));
        expect(find.text(arbMetni('etkinlik_yuruyus_dondum')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cevap "Belki" ise "Çıktım" yok', (tester) async {
      ekranBoyutu(tester);
      await _detayiAc(
        tester,
        etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            tur: 'hike',
            cevap: 'maybe',
            baslangic: yakinBaslangic,
          ),
        }),
      );
      await _gorunurYap(
        tester,
        find.text(arbMetni('etkinlik_yuruyus_yoklama')),
      );
      expect(find.text(arbMetni('etkinlik_yuruyus_ciktim')), findsNothing);
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
        await tester.tap(find.text(arbMetni('etkinlik_ekle')));
        await tester.pumpAndSettle();
        expect(tasima.giden('POST', avlarYolu).single.govde, {
          'species': 'Lüfer',
          'length_cm': 28.5,
          'client_request_id': sahteEtkinlikIstekKimligi,
        });
        await _gorunurYap(tester, find.text('Lüfer, 28,5 cm'));
        expect(tester.takeException(), isNull);
      });
    }

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
        await _detayiAc(tester, tasima, themeMode: tema);
        final menu = find.byTooltip(arbMetni('etkinlik_duzeltme'));
        await _gorunurYap(
          tester,
          find.text(arbMetni('etkinlik_duzeltme_bilgi')),
        );
        await tester.ensureVisible(menu);
        await tester.pumpAndSettle();
        expect(find.text(arbMetni('etkinlik_duzeltme_bilgi')), findsOneWidget);
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
      await _detayiAc(tester, tasima);
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
      );
      await _gorunurYap(tester, find.text('Mert'));
      expect(find.byTooltip(arbMetni('etkinlik_duzeltme')), findsNothing);
    });
  });

  group('rota seçici', () {
    for (final tema in _temalar) {
      testWidgets('nokta ekleme, silme ve kaydetme (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final sonuclar = <List<LatLng>?>[];
        await widgetAc(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => sonuclar.add(
                    await rotaSeciciAc(
                      context,
                      baslangic: const [LatLng(lat: 40.6, lng: 31.28)],
                    ),
                  ),
                  child: Text(arbMetni('etkinlik_rota_ciz')),
                ),
              ),
            ),
          ),
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: etkinlikTasimasi()),
        );
        await tester.tap(find.text(arbMetni('etkinlik_rota_ciz')));
        await tester.pumpAndSettle();
        expect(find.byType(RotaSeciciEkrani), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_rota_hata')), findsOneWidget);
        expect(_dugme(tester, arbMetni('etkinlik_rota_kaydet')), isNull);

        tester.widget<OsmHarita>(find.byType(OsmHarita)).onTap!(
          const LatLng(lat: 40.7, lng: 31.4),
        );
        await tester.pumpAndSettle();
        expect(find.text(arbMetni('etkinlik_rota_hata')), findsNothing);
        expect(
          tester.widget<OsmHarita>(find.byType(OsmHarita)).rota,
          hasLength(2),
        );

        final sil = find.text(arbMetni('etkinlik_rota_son_noktayi_sil'));
        await _dokun(tester, sil);
        await _dokun(tester, sil);
        expect(find.text(arbMetni('etkinlik_rota_yok')), findsOneWidget);

        await _dokun(tester, find.text(arbMetni('etkinlik_rota_kaydet')));
        expect(sonuclar.single, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
