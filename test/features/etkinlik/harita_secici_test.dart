import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/features/etkinlik/presentation/harita_secici_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

const YerSonucu _abant = YerSonucu(
  ad: 'Abant Gölü, Bolu, Türkiye',
  enlem: 40.6012,
  boylam: 31.2834,
  il: 'Bolu',
  ilce: 'Merkez',
);

/// 1×1 saydam PNG; ağsız karo.
final Uint8List _seffafPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Ağa gitmeyen karo sağlayıcı.
class _BosKaroSaglayici extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_seffafPng);
}

/// Her aramada hata veren arayıcı.
class _HataliArayici implements YerArayici {
  @override
  Future<List<YerSonucu>> ara(String metin) async =>
      throw const YerAramaHatasi();
}

/// Seçiciyi bir düğmeyle açan sayfa; sonucu [sonuclar]'a ekler.
class _Acici extends StatelessWidget {
  const _Acici(this.sonuclar);

  final List<HaritaSecimSonucu?> sonuclar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async =>
              sonuclar.add(await haritaSeciciAc(context)),
          child: const Text('ac'),
        ),
      ),
    );
  }
}

void main() {
  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('yazarken arama yok; "Ara" ile tek istek (${tema.name})', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final arayici = SahteYerArayici(const [_abant]);
      final sonuclar = <HaritaSecimSonucu?>[];
      await widgetAc(
        tester,
        _Acici(sonuclar),
        themeMode: tema,
        tayfa: etkinlikOverridelari(
          tasima: etkinlikTasimasi(),
          arayici: arayici,
        ),
      );
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();
      expect(find.byType(HaritaSeciciEkrani), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_harita_atif')), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_harita_ipucu')), findsOneWidget);

      final secButonu = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(arbMetni('etkinlik_harita_sec')),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(secButonu.onPressed, isNull, reason: 'nokta yokken seçilemez');

      await tester.enterText(find.byType(TextField), 'Aba');
      await tester.pump(const Duration(seconds: 2));
      await tester.enterText(find.byType(TextField), 'Abant');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(arayici.aramalar, isEmpty);

      await tester.tap(find.text(arbMetni('etkinlik_harita_ara')));
      await tester.pumpAndSettle();
      expect(arayici.aramalar, ['Abant']);

      await tester.tap(find.text(_abant.ad));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_harita_atif')), findsOneWidget);

      await tester.tap(find.text(arbMetni('etkinlik_harita_sec')));
      await tester.pumpAndSettle();
      expect(find.byType(HaritaSeciciEkrani), findsNothing);
      final sonuc = sonuclar.single!;
      expect(sonuc.nokta, const LatLng(lat: 40.6012, lng: 31.2834));
      expect(sonuc.oneri, _abant);
    });
  }

  testWidgets('sonuç yoksa metin gösterilir', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const HaritaSeciciEkrani(),
      tayfa: etkinlikOverridelari(
        tasima: etkinlikTasimasi(),
        arayici: SahteYerArayici(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Yokyer');
    await tester.tap(find.text(arbMetni('etkinlik_harita_ara')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('etkinlik_harita_sonuc_yok')), findsOneWidget);
  });

  testWidgets('arama başarısızsa hata satırı gösterilir', (tester) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const HaritaSeciciEkrani(),
      tayfa: etkinlikOverridelari(
        tasima: etkinlikTasimasi(),
        arayici: _HataliArayici(),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Abant');
    await tester.tap(find.text(arbMetni('etkinlik_harita_ara')));
    await tester.pumpAndSettle();
    expect(
      find.text(arbMetni('etkinlik_harita_arama_hatasi')),
      findsOneWidget,
    );
  });

  testWidgets('karolar: OSM adresi ve uygulamayı tanıtan User-Agent', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await widgetAc(
      tester,
      const Scaffold(
        body: OsmHarita(
          merkez: LatLng(lat: 39, lng: 35),
          yakinlik: 5,
        ),
      ),
      tayfa: etkinlikOverridelari(
        tasima: etkinlikTasimasi(),
        karolar: _BosKaroSaglayici.new,
      ),
    );
    final katman = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(katman.urlTemplate, osmKaroAdresi);
    expect(
      katman.tileProvider.headers['User-Agent'],
      'flutter_map ($haritaPaketAdi)',
    );
    expect(find.text(arbMetni('etkinlik_harita_atif')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
