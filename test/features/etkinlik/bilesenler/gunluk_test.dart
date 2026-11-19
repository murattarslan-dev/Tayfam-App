import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/gunluk_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/gunluk/kayit_formu.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _levrekId = '1b2c3d4e-5f6a-4b7c-8d9e-0f1a2b3c4d5e';
const String _cipuraId = '2c3d4e5f-6a7b-4c8d-9e0f-1a2b3c4d5e6f';
const String _yeniId = '5f6a7b8c-9d0e-4f1a-8b2c-4d5e6f7a8b9c';

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  GunlukBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  return profilJson(
    id,
    id == organizatorId ? 'Ayşe' : 'Mert',
    ben: id == ben,
  );
}

/// Mert'in konumlu, kendi görebildiği av kaydı.
Map<String, Object?> get _levrek => {
  'id': _levrekId,
  'user_id': katilimciId,
  'values': {'species': 'Levrek', 'count': 2, 'weight': 1.5},
  'location': {'lat': 40.61, 'lng': 31.29},
  'location_visibility': 'self',
  'created_at': '2026-11-09T12:00:00Z',
  'caller_can_remove': true,
};

/// Ayşe'nin konumu gizli kaydı.
Map<String, Object?> get _cipura => {
  'id': _cipuraId,
  'user_id': organizatorId,
  'values': {'species': 'Çipura', 'length_cm': 30},
  'created_at': '2026-11-09T13:00:00Z',
  'caller_can_remove': false,
};

/// Balıkçılık (katalog fikstüründe `catches` anahtarlı `log` bileşeni olan
/// tür); oturumdaki kullanıcı Mert, katılımı doğrulanmış.
SahteTayfaTasima _tasima(
  Map<String, TayfaYaniti> yanitlar, {
  String? katilim = 'attended',
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: 'fishing',
      cevap: 'going',
      katilim: katilim,
      baslangic: gecmisBaslangic,
      sure: const Duration(hours: 3),
    ),
    ...yanitlar,
  });
  t.yanitlar['GET $profilYolu'] = (i) => _profil(i, katilimciId);
  t.yanitlar['GET $hesapYolu'] = (_) => hesapJson(katilimciId);
  return t;
}

Future<void> _detayiAc(
  WidgetTester tester,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  SahteBaglantiAcici? baglanti,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(
      tasima: tasima,
      baglanti: baglanti,
      bilesenler: _kayit,
    ),
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
    find.descendant(of: find.byType(KayitFormu), matching: bulucu);

/// Fikstürdeki balıkçılık günlüğünün alanları.
List<CatalogField> _avAlanlari() => gunlukAlanlari(
  BilesenParametreleri(
    turBilesenleri(
      testTuru('fishing'),
    ).singleWhere((b) => b.kind == 'log').params,
  ),
);

void main() {
  test('katalog fikstüründe günlük bileşenini kullanan tür var', () {
    final gunluk = turBilesenleri(
      testTuru('fishing'),
    ).singleWhere((b) => b.kind == 'log');
    expect(bilesenAnahtari(gunluk), 'catches');
    expect(_avAlanlari().map((a) => a.key), [
      'species',
      'count',
      'weight',
      'length_cm',
    ]);
  });

  test('alanlar tanımdan; bozuk, geçersiz ve tekrar eden atlanır', () {
    final alanlar = gunlukAlanlari(
      const BilesenParametreleri({
        'fields': [
          {
            'key': 'species',
            'kind': 'text',
            'labels': {'tr': 'Tür'},
          },
          {'key': 'eksik_tur', 'labels': <String, Object?>{}},
          {
            'key': 'Buyuk',
            'kind': 'text',
            'labels': {'tr': 'X'},
          },
          {
            'key': 'species',
            'kind': 'integer',
            'labels': {'tr': 'Y'},
          },
          'metin',
        ],
      }),
    );
    expect(alanlar.map((a) => (a.key, a.kind)), [('species', 'text')]);
    expect(gunlukAlanlari(const BilesenParametreleri(null)), isEmpty);
  });

  group('kayıt isteği', () {
    test('değerler tanıma göre; yer seçilmeden yer ve görünürlük gitmez', () {
      final sonuc = gunlukIstegi(
        alanlar: _avAlanlari(),
        degerler: {'species': ' Levrek ', 'count': '2', 'weight': '1,5'},
        gorunurluk: LogLocationVisibility.tayfa,
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek!.toJson(), {
        'values': {'species': 'Levrek', 'count': 2, 'weight': 1.5},
        'client_request_id': sahteEtkinlikIstekKimligi,
      });
    });

    test('yer seçildiyse görünürlüğüyle ve fotoğrafla gider', () {
      final sonuc = gunlukIstegi(
        alanlar: _avAlanlari(),
        degerler: {'species': 'Levrek'},
        yer: const LatLng(lat: 40.1, lng: 29.1),
        gorunurluk: LogLocationVisibility.participants,
        fotograf: _yeniId,
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek!.toJson(), {
        'values': {'species': 'Levrek'},
        'location': {'lat': 40.1, 'lng': 29.1},
        'location_visibility': 'participants',
        'photo_upload_id': _yeniId,
        'client_request_id': sahteEtkinlikIstekKimligi,
      });
    });

    test('zorunlu alan ve aralık hataları alana göre döner', () {
      final sonuc = gunlukIstegi(
        alanlar: _avAlanlari(),
        degerler: {'count': '0', 'weight': '1,234'},
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek, isNull);
      expect(sonuc.alanHatalari, {
        'species': AlanHatasi.zorunlu,
        'count': AlanHatasi.aralik,
        'weight': AlanHatasi.basamak,
      });
    });

    test('zorunlu alanı olmayan günlükte de kayıt boş olamaz', () {
      final alanlar = [
        CatalogField.fromJson({
          'key': 'note',
          'kind': 'text',
          'labels': {'tr': 'Not'},
        }),
      ];
      final sonuc = gunlukIstegi(
        alanlar: alanlar,
        degerler: const {},
        istekKimligi: sahteEtkinlikIstekKimligi,
      );
      expect(sonuc.istek, isNull);
      expect(sonuc.hatalar, {GunlukHatasi.bos});
    });
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('kayıtlar, konum gizliliği ve ekleme '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final baglanti = SahteBaglantiAcici();
        final tasima = _tasima({
          'GET $gunlukYolu': (_) =>
              gunlukJson(kayitlar: [_levrek, _cipura], ekleyebilir: true),
          'POST $gunlukYolu': (_) => {
            'id': _yeniId,
            'user_id': katilimciId,
            'values': {'species': 'Lüfer'},
            'created_at': '2026-11-11T09:00:00Z',
            'caller_can_remove': true,
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema, baglanti: baglanti);

        await _gorunurYap(tester, find.text('Çipura'));
        expect(tasima.giden('GET', gunlukYolu).first.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'catches',
        });
        expect(find.text('Av günlüğü'), findsOneWidget);
        expect(find.text('Levrek'), findsOneWidget);
        expect(find.text('Adet: 2 adet · Ağırlık: 1,5 kg'), findsOneWidget);
        expect(find.text('Boy (cm): 30'), findsOneWidget);
        expect(find.text(arbMetni('bilesen_log_yeri_sende')), findsOneWidget);
        // Yalnızca sunucunun yerini döndürdüğü kayıtta harita bağlantısı;
        // yalnızca `caller_can_remove` kayıtta çıkarma düğmesi.
        expect(find.text(arbMetni('bilesen_log_yeri_ac')), findsOneWidget);
        expect(find.byTooltip(arbMetni('bilesen_log_cikar')), findsOneWidget);

        await _dokun(tester, find.text(arbMetni('bilesen_log_yeri_ac')));
        expect(baglanti.noktalar, [(40.61, 31.29)]);

        await _dokun(tester, find.text(arbMetni('bilesen_log_ekle')));
        expect(find.byType(KayitFormu), findsOneWidget);
        // Tek alan çizici: tür (zorunlu), adet, ağırlık, boy.
        expect(_formda(find.byType(TextField)), findsNWidgets(4));
        // Konum açık; varsayılan görünürlük, yer seçilmeden gösterilmez.
        expect(
          _formda(find.text(arbMetni('bilesen_log_yer_sec'))),
          findsOneWidget,
        );
        expect(
          _formda(find.text(arbMetni('bilesen_log_gizlilik_notu'))),
          findsOneWidget,
        );
        await _dokun(tester, _formda(find.text(arbMetni('etkinlik_ekle'))));
        expect(tasima.giden('POST', gunlukYolu), isEmpty);
        expect(find.byType(KayitFormu), findsOneWidget);

        await tester.enterText(_formda(find.byType(TextField)).first, 'Lüfer');
        await _dokun(tester, _formda(find.text(arbMetni('etkinlik_ekle'))));
        expect(tasima.giden('POST', gunlukYolu).single.govde, {
          'values': {'species': 'Lüfer'},
          'client_request_id': sahteEtkinlikIstekKimligi,
        });
        expect(find.byType(KayitFormu), findsNothing);
        await _gorunurYap(tester, find.text('Lüfer'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('katılım doğrulanmadıysa ekleme yerine bilgi', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima(const {}, katilim: null);
      await _detayiAc(tester, tasima);
      await _gorunurYap(tester, find.text(arbMetni('bilesen_log_ekle_bilgi')));
      expect(find.text(arbMetni('bilesen_log_ekle')), findsNothing);
      expect(find.text(arbMetni('bilesen_log_yok')), findsOneWidget);
    });

    testWidgets('kendi kaydını onayla çıkarır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $gunlukYolu': (_) => gunlukJson(kayitlar: [_levrek, _cipura]),
        'DELETE $gunlukKaydiYolu': (_) => null,
      });
      await _detayiAc(tester, tasima);
      final cikar = find.byTooltip(arbMetni('bilesen_log_cikar'));
      await _gorunurYap(tester, cikar);
      await _dokun(tester, cikar);
      expect(find.text(arbMetni('bilesen_log_cikar_onay')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('etkinlik_cikar')));
      expect(tasima.giden('DELETE', gunlukKaydiYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
        'component_key': 'catches',
        'entry_id': _levrekId,
      });
      expect(find.text('Levrek'), findsNothing);
      expect(find.text('Çipura'), findsOneWidget);
    });

    testWidgets('donmuş günlükte hata gösterilir, günlük yeniden okunur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $gunlukYolu': (_) => gunlukJson(kayitlar: [_levrek]),
        'DELETE $gunlukKaydiYolu': (_) => const ApiProblem(
          type: ProblemType.componentFrozen,
          status: 409,
        ),
      });
      await _detayiAc(tester, tasima);
      final cikar = find.byTooltip(arbMetni('bilesen_log_cikar'));
      await _gorunurYap(tester, cikar);
      expect(tasima.giden('GET', gunlukYolu), hasLength(1));
      await _dokun(tester, cikar);
      await _dokun(tester, find.text(arbMetni('etkinlik_cikar')));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tasima.giden('GET', gunlukYolu), hasLength(2));
      expect(find.text('Levrek'), findsOneWidget);
    });

    testWidgets('okunamazsa hata ve "Tekrar dene"', (tester) async {
      ekranBoyutu(tester);
      var okundu = false;
      final tasima = _tasima({
        'GET $gunlukYolu': (_) {
          if (okundu) return gunlukJson(kayitlar: [_cipura]);
          okundu = true;
          return const ApiOffline();
        },
      });
      await _detayiAc(tester, tasima);
      final tekrar = find.descendant(
        of: find.byType(GunlukBolumu),
        matching: find.text(arbMetni('etkinlik_tekrar_dene')),
      );
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(find.text('Çipura'), findsOneWidget);
    });
  });

  group('kayıt formu alttan sayfa', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name}, 2× yazı, 320 dp, klavye açık: taşmıyor; '
          'altta Vazgeç + Ekle', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _detayiAc(
          tester,
          _tasima({'GET $gunlukYolu': (_) => gunlukJson(ekleyebilir: true)}),
          themeMode: tema,
        );
        final ekle = find.text(arbMetni('bilesen_log_ekle'));
        await _gorunurYap(tester, ekle);
        await _dokun(tester, ekle);
        expect(find.byType(BottomSheet), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 900);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(find.byType(TextField).first, 'Uzun bir ad');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
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
  });
}
