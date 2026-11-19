import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/rota/rota_secici_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../yardimcilar.dart';
import '../../tayfa/sahteler.dart';
import '../sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _rotaYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}/route';

const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  RotaBileseni(),
];

const List<Map<String, Object?>> _ikiNokta = [
  {'lat': 40.6, 'lng': 31.28},
  {'lat': 40.7, 'lng': 31.4},
];

/// Örnek `EventRoute` JSON'u.
Map<String, Object?> _rotaJson({
  List<Map<String, Object?>> noktalar = const [],
  bool duzenlenebilir = false,
}) => {
  'points': noktalar,
  if (noktalar.isNotEmpty) 'updated_at': '2026-11-10T10:00:00Z',
  'caller_can_edit': duzenlenebilir,
};

String _noktalar(int sayi) =>
    arbMetni('bilesen_route_noktalari').replaceAll('{sayi}', '$sayi');

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

/// Konvoy (katalog fikstüründe `route` bileşeni olan tür).
SahteTayfaTasima _tasima(Map<String, TayfaYaniti> yanitlar) =>
    etkinlikTasimasi({
      'GET $etkinlikYolu': (_) => etkinlikJson(
        tur: 'convoy',
        cevap: 'going',
        ayrinti: {'vehicles': const <Object?>[]},
      ),
      ...yanitlar,
    });

Future<void> _gorunurYap(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

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
  test('katalog fikstüründe rota bileşenini kullanan tür var', () {
    expect(
      turBilesenleri(testTuru('convoy')).map((b) => b.kind),
      contains('route'),
    );
  });

  test('rota boş ya da 2–500 nokta', () {
    const a = LatLng(lat: 40.1, lng: 29.1);
    const b = LatLng(lat: 40.2, lng: 29.2);
    expect(rotaHatali(const []), isFalse);
    expect(rotaHatali(const [a]), isTrue);
    expect(rotaHatali(const [a, b]), isFalse);
    expect(rotaHatali(List.filled(rotaEnCokNokta, a)), isFalse);
    expect(rotaHatali(List.filled(rotaEnCokNokta + 1, a)), isTrue);
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('üye: önizleme ve nokta sayısı, düzenleme yok '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima({
          'GET $_rotaYolu': (_) => _rotaJson(noktalar: _ikiNokta),
        });
        await _detayiAc(tester, tasima, themeMode: tema);
        expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);

        await _gorunurYap(tester, find.text(_noktalar(2)));
        expect(find.byType(RotaKarti), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RotaKarti),
            matching: find.byType(OsmHarita),
          ),
          findsOneWidget,
        );
        expect(find.text(arbMetni('bilesen_route_duzenle')), findsNothing);
        expect(find.text(arbMetni('bilesen_route_ciz')), findsNothing);
        final istek = tasima.giden('GET', _rotaYolu).single;
        expect(istek.yolParametreleri['component_key'], 'route');
        expect(tester.takeException(), isNull);
      });

      testWidgets('organizatör: rota çizer ve kaydeder '
          '(${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = _tasima({
          'GET $_rotaYolu': (_) => _rotaJson(duzenlenebilir: true),
          // Yanıt: yazılan noktalar.
          'PUT $_rotaYolu': (i) => {
            ...i.govde! as Map<String, Object?>,
            'caller_can_edit': true,
          },
        });
        await _detayiAc(tester, tasima, themeMode: tema);

        await _gorunurYap(tester, find.text(arbMetni('bilesen_route_ciz')));
        expect(find.text(arbMetni('bilesen_route_yok')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(RotaKarti),
            matching: find.byType(OsmHarita),
          ),
          findsNothing,
        );
        await _dokun(tester, find.text(arbMetni('bilesen_route_ciz')));
        expect(find.byType(RotaSeciciEkrani), findsOneWidget);
        expect(tester.takeException(), isNull);

        final harita = find.descendant(
          of: find.byType(RotaSeciciEkrani),
          matching: find.byType(OsmHarita),
        );
        tester.widget<OsmHarita>(harita).onTap!(
          const LatLng(lat: 40.6, lng: 31.28),
        );
        await tester.pumpAndSettle();
        tester.widget<OsmHarita>(harita).onTap!(
          const LatLng(lat: 40.7, lng: 31.4),
        );
        await tester.pumpAndSettle();
        await _dokun(tester, find.text(arbMetni('bilesen_route_kaydet')));

        expect(find.byType(RotaSeciciEkrani), findsNothing);
        final govde =
            tasima.giden('PUT', _rotaYolu).single.govde!
                as Map<String, Object?>;
        expect(govde, {'points': _ikiNokta});
        await _gorunurYap(tester, find.text(_noktalar(2)));
        expect(find.text(arbMetni('bilesen_route_duzenle')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kaydedilemezse hata bildirilir, rota değişmez', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _tasima({
        'GET $_rotaYolu': (_) =>
            _rotaJson(noktalar: _ikiNokta, duzenlenebilir: true),
        'PUT $_rotaYolu': (_) => const ApiOffline(),
      });
      await _detayiAc(tester, tasima);
      await _gorunurYap(tester, find.text(arbMetni('bilesen_route_duzenle')));
      await _dokun(tester, find.text(arbMetni('bilesen_route_duzenle')));
      // Temizle + kaydet: boş rota rotayı kaldırır.
      await _dokun(tester, find.text(arbMetni('bilesen_route_temizle')));
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('bilesen_route_temizle')),
        ),
      );
      await _dokun(tester, find.text(arbMetni('bilesen_route_kaydet')));

      expect(tasima.giden('PUT', _rotaYolu).single.govde, {
        'points': const <Object?>[],
      });
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_noktalar(2)), findsOneWidget);
    });

    testWidgets('okunamazsa hata; "Tekrar dene" ile gelir', (tester) async {
      ekranBoyutu(tester);
      var bagli = false;
      final tasima = _tasima({
        'GET $_rotaYolu': (_) =>
            bagli ? _rotaJson(noktalar: _ikiNokta) : const ApiOffline(),
      });
      await _detayiAc(tester, tasima);
      expect(find.byType(RotaKarti), findsNothing);

      bagli = true;
      final tekrar = find.descendant(
        of: find.byType(RotaBolumu),
        matching: find.text(arbMetni('etkinlik_tekrar_dene')),
      );
      await _gorunurYap(tester, tekrar);
      await _dokun(tester, tekrar);
      expect(find.byType(RotaKarti), findsOneWidget);
      expect(find.text(_noktalar(2)), findsOneWidget);
    });
  });

  group('rota çizme ekranı', () {
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
                  child: Text(arbMetni('bilesen_route_ciz')),
                ),
              ),
            ),
          ),
          themeMode: tema,
          tayfa: etkinlikOverridelari(tasima: etkinlikTasimasi()),
        );
        await tester.tap(find.text(arbMetni('bilesen_route_ciz')));
        await tester.pumpAndSettle();
        expect(find.byType(RotaSeciciEkrani), findsOneWidget);
        expect(find.text(arbMetni('bilesen_route_hata')), findsOneWidget);
        expect(_dugme(tester, arbMetni('bilesen_route_kaydet')), isNull);

        tester.widget<OsmHarita>(find.byType(OsmHarita)).onTap!(
          const LatLng(lat: 40.7, lng: 31.4),
        );
        await tester.pumpAndSettle();
        expect(find.text(arbMetni('bilesen_route_hata')), findsNothing);
        expect(
          tester.widget<OsmHarita>(find.byType(OsmHarita)).rota,
          hasLength(2),
        );

        final sil = find.text(arbMetni('bilesen_route_son_noktayi_sil'));
        await _dokun(tester, sil);
        await _dokun(tester, sil);
        expect(find.text(arbMetni('bilesen_route_yok')), findsOneWidget);

        await _dokun(tester, find.text(arbMetni('bilesen_route_kaydet')));
        expect(sonuclar.single, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
