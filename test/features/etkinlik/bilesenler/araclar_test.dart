import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/arac_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/araclar_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/araclar/araclar_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_bileseni.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _bilesen =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}';
const String _rotaYolu = '$_bilesen/route';
const String _araclarYolu = '$_bilesen/vehicles';
const String _aracimYolu = '$_bilesen/vehicles/mine';
const String _aracYolu = '$_bilesen/vehicles/{vehicle_id}';
const String _istegimYolu =
    '$_bilesen/vehicles/{vehicle_id}/seat-requests/mine';
const String _istekYolu =
    '$_bilesen/vehicles/{vehicle_id}/seat-requests/{user_id}';
const String _onayYolu = '$_istekYolu/approval';

const String _aracId = '7f6e5d4c-3b2a-4f1e-8d0c-9b8a7f6e5d4c';
const String _yolcuId = '8a7f6e5d-4c3b-4a2f-9e1d-0c9b8a7f6e5d';

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  RotaBileseni(),
  AraclarBileseni(),
];

/// Organizatör "Ayşe", katılımcı "Mert", koltuk isteyen "Deniz".
Map<String, Object?> _profil(TayfaIstegi i, String ben) {
  final id = i.yolParametreleri['user_id']!;
  final ad = switch (id) {
    organizatorId => 'Ayşe',
    katilimciId => 'Mert',
    _ => 'Deniz',
  };
  return profilJson(id, ad, ben: id == ben);
}

/// Örnek `EventVehicle` JSON'u.
Map<String, Object?> _aracJson({
  String sahip = organizatorId,
  int koltuk = 2,
  List<String> yolcular = const [],
  List<String> bekleyenler = const [],
  String? plaka,
}) => {
  'id': _aracId,
  'user_id': sahip,
  'make': 'Anadol',
  'model': 'A1',
  'model_year': 1972,
  'color': 'Turuncu',
  'plate': ?plaka,
  'seats': koltuk,
  'rider_user_ids': yolcular,
  'pending_user_ids': bekleyenler,
};

/// Örnek `EventVehicles` JSON'u.
Map<String, Object?> _araclarJson(
  List<Map<String, Object?>> araclar, {
  bool katilabilir = true,
  bool yonetebilir = false,
}) => {
  'vehicles': araclar,
  'plate_enabled': true,
  'seats_enabled': true,
  'caller_can_participate': katilabilir,
  'caller_can_manage': yonetebilir,
};

/// Konvoy (katalog fikstüründe `vehicles` bileşeni olan tür); oturumdaki
/// kullanıcı [ben].
SahteTayfaTasima _tasima(
  Map<String, TayfaYaniti> yanitlar, {
  String ben = katilimciId,
  String? cevap = 'going',
}) {
  final t = etkinlikTasimasi({
    'GET $etkinlikYolu': (_) => etkinlikJson(
      tur: 'convoy',
      cevap: cevap,
      baslangic: yakinBaslangic,
    ),
    'GET $_rotaYolu': (_) => {
      'points': const <Object?>[],
      'caller_can_edit': false,
    },
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

String _bosKoltuk(int sayi) => '$sayi boş koltuk';

void main() {
  test('katalog fikstüründe araçlar bileşenini kullanan tür var', () {
    expect(
      turBilesenleri(testTuru('convoy')).map((b) => b.kind),
      contains('vehicles'),
    );
  });

  group('araç formu', () {
    test('yalnızca marka zorunlu; boş alanlar gönderilmez', () {
      final sonuc = aracIstegi(marka: ' Anadol ', buYil: 2026);
      expect(sonuc.hatalar, isEmpty);
      expect(sonuc.istek!.toJson(), {'make': 'Anadol'});
    });

    test('tüm alanlar; plaka ve koltuk yalnızca parametre açıksa', () {
      final sonuc = aracIstegi(
        marka: 'Anadol',
        model: 'A1',
        yil: '1972',
        renk: 'Turuncu',
        plaka: '34 AB 1972',
        koltuk: '3',
        plakaAcik: true,
        koltukAcik: true,
        buYil: 2026,
      );
      expect(sonuc.istek!.toJson(), {
        'make': 'Anadol',
        'model': 'A1',
        'model_year': 1972,
        'color': 'Turuncu',
        'plate': '34 AB 1972',
        'seats': 3,
      });
      final kapali = aracIstegi(
        marka: 'Anadol',
        plaka: '34 AB 1972',
        koltuk: '3',
        buYil: 2026,
      );
      expect(kapali.istek!.toJson(), {'make': 'Anadol'});
    });

    test('hatalar: marka, yıl, plaka ve koltuk', () {
      expect(aracIstegi(marka: '  ', buYil: 2026).hatalar, {AracHatasi.marka});
      expect(aracIstegi(marka: 'A' * 41, buYil: 2026).hatalar, {
        AracHatasi.marka,
      });
      for (final yil in ['1899', '2028', 'yetmiş']) {
        expect(aracIstegi(marka: 'Anadol', yil: yil, buYil: 2026).hatalar, {
          AracHatasi.yil,
        }, reason: yil);
      }
      expect(
        aracIstegi(marka: 'Anadol', yil: '2027', buYil: 2026).hatalar,
        isEmpty,
        reason: 'gelecek yıl olabilir',
      );
      for (final plaka in ['3', '34  AB 12', '34-AB-12', 'A' * 17]) {
        final sonuc = aracIstegi(
          marka: 'Anadol',
          plaka: plaka,
          plakaAcik: true,
          buYil: 2026,
        );
        expect(sonuc.hatalar, {AracHatasi.plaka}, reason: plaka);
      }
      for (final koltuk in ['-1', '9', 'iki']) {
        final sonuc = aracIstegi(
          marka: 'Anadol',
          koltuk: koltuk,
          koltukAcik: true,
          buYil: 2026,
        );
        expect(sonuc.hatalar, {AracHatasi.koltuk}, reason: koltuk);
      }
    });
  });

  test('boş koltuk: yazılan koltuktan onaylanmış yolcular düşer', () {
    EventVehicle arac(int koltuk, int yolcu) => EventVehicle.fromJson(
      _aracJson(koltuk: koltuk, yolcular: List.filled(yolcu, _yolcuId)),
    );
    expect(bosKoltuk(arac(3, 1)), 2);
    expect(bosKoltuk(arac(1, 1)), 0);
    expect(bosKoltuk(arac(0, 2)), 0);
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('katılımcı: koltuk ister, istek onay bekler '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var istendi = false;
        final tasima = _tasima(ben: _yolcuId, {
          'GET $_araclarYolu': (_) => _araclarJson([
            _aracJson(plaka: '34 AB 1972'),
          ]),
          'PUT $_istegimYolu': (_) {
            istendi = true;
            return _araclarJson([
              _aracJson(plaka: '34 AB 1972', bekleyenler: [_yolcuId]),
            ]);
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);

        final iste = find.text(arbMetni('bilesen_vehicles_koltuk_iste'));
        await _gorunurYap(tester, iste);
        expect(find.text('Anadol A1'), findsOneWidget);
        expect(find.text('1972, Turuncu'), findsOneWidget);
        expect(find.text('Plaka: 34 AB 1972'), findsOneWidget);
        expect(find.text(_bosKoltuk(2)), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_vehicles_ekle')),
          findsOneWidget,
          reason: 'aracı olmayan katılımcı aracını ekleyebilir',
        );
        expect(tester.takeException(), isNull);

        await _dokun(tester, iste);
        expect(istendi, isTrue);
        final istek = tasima.giden('PUT', _istegimYolu).single;
        expect(istek.yolParametreleri['component_key'], 'vehicles');
        expect(istek.yolParametreleri['vehicle_id'], _aracId);
        expect(
          find.text(arbMetni('bilesen_vehicles_istek_gonderildi')),
          findsOneWidget,
        );
        await _gorunurYap(
          tester,
          find.text(arbMetni('bilesen_vehicles_bekliyor')),
        );
        expect(
          find.byTooltip(arbMetni('bilesen_vehicles_geri_cek')),
          findsOneWidget,
        );
        expect(
          find.text(arbMetni('bilesen_vehicles_koltuk_iste')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('araç sahibi: bekleyen isteği onaylar '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima({
          'GET $_araclarYolu': (_) => _araclarJson([
            _aracJson(sahip: katilimciId, koltuk: 3, bekleyenler: [_yolcuId]),
          ]),
          'PUT $_onayYolu': (_) => _araclarJson([
            _aracJson(sahip: katilimciId, koltuk: 3, yolcular: [_yolcuId]),
          ]),
        });
        await _detayiAc(tester, tasima, themeMode: tema);

        final onayla = find.byTooltip(arbMetni('bilesen_vehicles_onayla'));
        await _gorunurYap(tester, onayla);
        expect(find.text('Deniz'), findsOneWidget);
        expect(
          find.text(arbMetni('bilesen_vehicles_bekliyor')),
          findsOneWidget,
        );
        expect(
          find.byTooltip(arbMetni('bilesen_vehicles_degistir')),
          findsOneWidget,
        );
        expect(
          find.text(arbMetni('bilesen_vehicles_koltuk_iste')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);

        await _dokun(tester, onayla);
        expect(tasima.giden('PUT', _onayYolu).single.yolParametreleri, {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'vehicles',
          'vehicle_id': _aracId,
          'user_id': _yolcuId,
        });
        await _gorunurYap(tester, find.text(_bosKoltuk(2)));
        expect(find.text(arbMetni('bilesen_vehicles_bekliyor')), findsNothing);
        expect(
          find.byTooltip(arbMetni('bilesen_vehicles_yolcu_cikar')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('aracını ekler: koltuk ve plaka formu '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        var eklendi = false;
        final tasima = _tasima({
          'GET $_araclarYolu': (_) => _araclarJson([
            if (eklendi) _aracJson(sahip: katilimciId, koltuk: 3),
          ]),
          'PUT $_aracimYolu': (_) {
            eklendi = true;
            return _araclarJson([_aracJson(sahip: katilimciId, koltuk: 3)]);
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);
        await _gorunurYap(tester, find.text(arbMetni('bilesen_vehicles_yok')));

        await _dokun(tester, find.text(arbMetni('bilesen_vehicles_ekle')));
        expect(find.byType(AracFormu), findsOneWidget);
        expect(
          find.text(arbMetni('etkinlik_arac_gizlilik_notu')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
        expect(find.text(arbMetni('etkinlik_arac_marka_hata')), findsOneWidget);
        expect(tasima.giden('PUT', _aracimYolu), isEmpty);

        await tester.enterText(find.byType(TextField).first, 'Anadol');
        await tester.enterText(
          find.widgetWithText(
            TextField,
            arbMetni('bilesen_vehicles_koltuk_alani'),
          ),
          '3',
        );
        await _dokun(tester, find.text(arbMetni('etkinlik_ekle')));
        expect(tasima.giden('PUT', _aracimYolu).single.govde, {
          'make': 'Anadol',
          'seats': 3,
        });
        expect(find.byType(AracFormu), findsNothing);
        await _gorunurYap(tester, find.text('Anadol A1'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('üye ("Geliyorum" değil): bilgi metni, düğme yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(ben: _yolcuId, cevap: null, {
        'GET $_araclarYolu': (_) =>
            _araclarJson([_aracJson()], katilabilir: false),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(
        tester,
        find.text(arbMetni('bilesen_vehicles_ekle_bilgi')),
      );
      expect(find.text('Anadol A1'), findsOneWidget);
      expect(find.textContaining('Plaka'), findsNothing);
      expect(find.text(arbMetni('bilesen_vehicles_koltuk_iste')), findsNothing);
      expect(find.text(arbMetni('bilesen_vehicles_ekle')), findsNothing);
      expect(find.byTooltip(arbMetni('bilesen_vehicles_cikar')), findsNothing);
    });

    testWidgets('yönetici başkasının aracını çıkarır', (tester) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $_araclarYolu': (_) =>
            _araclarJson([_aracJson()], yonetebilir: true),
        'DELETE $_aracYolu': (_) => _araclarJson([], yonetebilir: true),
      });
      await _detayiAc(tester, tasima);
      final cikar = find.byTooltip(arbMetni('bilesen_vehicles_cikar'));
      await _gorunurYap(tester, cikar);
      await _dokun(tester, cikar);
      await _dokun(tester, find.text(arbMetni('etkinlik_cikar')));
      expect(tasima.giden('DELETE', _aracYolu).single.yolParametreleri, {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
        'component_key': 'vehicles',
        'vehicle_id': _aracId,
      });
      await _gorunurYap(tester, find.text(arbMetni('bilesen_vehicles_yok')));
    });

    testWidgets('koltuk dolduysa hata bildirilir, liste yeniden okunur', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima(ben: _yolcuId, {
        'GET $_araclarYolu': (_) => _araclarJson([_aracJson()]),
        'PUT $_istegimYolu': (_) =>
            const ApiProblem(status: 409, type: ProblemType.vehicleFull),
      });
      await _detayiAc(tester, tasima);
      final iste = find.text(arbMetni('bilesen_vehicles_koltuk_iste'));
      await _gorunurYap(tester, iste);
      expect(tasima.giden('GET', _araclarYolu), hasLength(1));

      await _dokun(tester, iste);
      expect(find.text(arbMetni('hata_vehicle_full')), findsOneWidget);
      expect(tasima.giden('GET', _araclarYolu), hasLength(2));
    });

    testWidgets('okunamazsa hata; "Tekrar dene" ile gelir', (tester) async {
      ekranBoyutu(tester);
      var bagli = false;
      final tasima = _tasima({
        'GET $_araclarYolu': (_) =>
            bagli ? _araclarJson([_aracJson()]) : const ApiOffline(),
      });
      await _detayiAc(tester, tasima);
      expect(find.byType(AracKarti), findsNothing);

      bagli = true;
      final tekrar = find.descendant(
        of: find.byType(AraclarBolumu),
        matching: find.text(arbMetni('etkinlik_tekrar_dene')),
      );
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(find.byType(AracKarti), findsOneWidget);
    });
  });
}
