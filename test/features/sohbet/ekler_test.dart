import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/medya/fotograf_secici.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/realtime/realtime.dart' show KanalRef;
import 'package:tayfam/core/medya/jpeg.dart';
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';
import 'package:tayfam/core/sohbet/sohbet_ekleri.dart';
import 'package:tayfam/features/sohbet/application/kanal_akisi_notifier.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ekrani.dart';

import '../../core/medya/sahteler.dart';
import '../../yardimcilar.dart';
import '../etkinlik/sahteler.dart' show SahteKonumServisi;
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const KanalRef _kanal1 = (tayfaId: ornekTayfaId, kanalId: kanalId1);
const String _mesajYolu =
    '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages';
const String _fotografId = '7d0e8c4a-5b6f-4a1e-9c3d-2f1a0b9e8d7c';

HazirGoruntu _goruntu() => HazirGoruntu(
  tam: ornekJpeg(),
  onizleme: ornekJpeg(),
  tamOlcu: const JpegOlculeri(1600, 1200),
  onizlemeOlcu: const JpegOlculeri(400, 300),
);

/// Sohbet ortamına medya (yükleme, link, depo), harita (karo yok) ve konum
/// sahteleri eklenir; gerçek ağ yok.
List<Override> _overridelar(
  SohbetOrtami o, {
  List<http.Request>? depo,
  KonumServisi? konum,
  FotografSecici? secici,
  GoruntuKodlayici? kodlayici,
}) => [
  ...o.overridelar,
  ...medyaOverridelari(
    tasima: o.tasima,
    secici: secici,
    kodlayici: kodlayici,
    depo: sahteDepo(depo ?? []),
    linkIsteyici: (idler) async => [
      for (final id in idler) MediaUrls.fromJson(medyaLinkiJson(id)),
    ],
  ),
  karoSaglayiciProvider.overrideWithValue(() => null),
  konumServisiProvider.overrideWithValue(konum ?? SahteKonumServisi()),
];

void _yuklemeYanitlari(SohbetOrtami o) {
  o.tasima.yanitlar['POST /v1/uploads'] = (istek) {
    final varyantlar =
        (istek.govde! as Map<String, Object?>)['variants']! as List<Object?>;
    int boyut(int i) =>
        (varyantlar[i]! as Map<String, Object?>)['size_bytes']! as int;
    return yuklemeAcildiJson(
      id: _fotografId,
      onizlemeBoyutu: boyut(0),
      tamBoyutu: boyut(1),
    );
  };
  o.tasima.yanitlar['POST /v1/uploads/{upload_id}/complete'] = (_) => {
    'upload': yuklemeJson(id: _fotografId),
  };
}

Map<String, Object?> _fotografMesaji(String id, {String yazar = digerId}) => {
  ...mesajJson(id, yazar: yazar, metin: null),
  'kind': 'photo',
  'photo_upload_id': _fotografId,
};

Map<String, Object?> _yerMesaji(String id, {Object? enlem = 40.7}) => {
  ...mesajJson(id, metin: null),
  'kind': 'place',
  'place': {'latitude': enlem, 'longitude': 30.26, 'name': 'Göl otoparkı'},
};

void main() {
  group('gönderim (ADR-0026 §1)', () {
    test('fotoğraf: chat_photo olarak bir kez yüklenir, mesaj photo türünde; '
        'tekrarda yeniden yüklenmez', () async {
      final o = SohbetOrtami();
      _yuklemeYanitlari(o);
      var deneme = 0;
      o.tasima.yanitlar['POST $_mesajYolu'] = (_) {
        deneme++;
        if (deneme == 1) return const ApiOffline();
        return _fotografMesaji(mesajId3, yazar: benimId);
      };
      final depo = <http.Request>[];
      final kap = ProviderContainer.test(
        overrides: _overridelar(o, depo: depo),
      );
      kap.listen(kanalAkisiProvider(_kanal1), (_, _) {});
      await kap.read(kanalAkisiProvider(_kanal1).future);
      kap.read(kanalAkisiProvider(_kanal1).notifier).fotografGonder(_goruntu());
      await pumpEventQueue();
      kap.read(cevrimdisiKuyrukProvider.notifier).simdiDene();
      await pumpEventQueue();

      final ac = o.tasima.giden('POST', '/v1/uploads');
      expect(ac, hasLength(1));
      final yukleme = ac.single.govde! as Map<String, Object?>;
      expect(yukleme['purpose'], 'chat_photo');
      expect(yukleme['tayfa_id'], ornekTayfaId);
      expect(depo, hasLength(2));
      final mesajlar = o.tasima.giden('POST', _mesajYolu);
      expect(mesajlar, hasLength(2));
      for (final m in mesajlar) {
        expect(m.govde, {
          'kind': 'photo',
          'photo_upload_id': _fotografId,
          'client_request_id': sahteIstekKimligi,
        });
      }
      expect(kap.read(cevrimdisiKuyrukProvider), isEmpty);
    });

    test('yer: place türünde; geçersiz yer kuyruğa girmez', () async {
      final o = SohbetOrtami();
      o.tasima.yanitlar['POST $_mesajYolu'] = (_) => _yerMesaji(mesajId3);
      final kap = ProviderContainer.test(overrides: _overridelar(o));
      kap.listen(kanalAkisiProvider(_kanal1), (_, _) {});
      await kap.read(kanalAkisiProvider(_kanal1).future);
      final n = kap.read(kanalAkisiProvider(_kanal1).notifier);
      expect(n.yerGonder(const PaylasilanYer(enlem: 91, boylam: 0)), isFalse);
      expect(
        n.yerGonder(
          const PaylasilanYer(enlem: 40.7, boylam: 30.26, ad: 'Otopark'),
        ),
        isTrue,
      );
      await pumpEventQueue();
      expect(o.tasima.giden('POST', _mesajYolu).single.govde, {
        'kind': 'place',
        'place': {'latitude': 40.7, 'longitude': 30.26, 'name': 'Otopark'},
        'client_request_id': sahteIstekKimligi,
      });
    });

    test('bağlantı açıkken yer send çerçevesiyle gider', () async {
      final o = SohbetOrtami();
      final kap = ProviderContainer.test(overrides: _overridelar(o));
      kap.listen(kanalAkisiProvider(_kanal1), (_, _) {});
      await kap.read(kanalAkisiProvider(_kanal1).future);
      final soket = await o.baglan();
      kap
          .read(kanalAkisiProvider(_kanal1).notifier)
          .yerGonder(const PaylasilanYer(enlem: 1, boylam: 2));
      await pumpEventQueue();
      final cerceve = soket.tur('send').single['data']! as Map;
      expect(cerceve['kind'], 'place');
      expect(cerceve['place'], {'latitude': 1.0, 'longitude': 2.0});
      expect(cerceve.containsKey('body'), isFalse);
    });
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('kanal ekranı: fotoğraf, yer ve tanınmayan tür; 2× yazı '
        '(${tema.name})', (tester) async {
      ekranBoyutu(tester, genislik: 360, yukseklik: 1400);
      ikiKatYazi(tester);
      final o = SohbetOrtami(
        mesajlar: [
          {...mesajJson(mesajId3, metin: null), 'kind': 'video'},
          _yerMesaji(mesajId2),
          _fotografMesaji(mesajId1),
        ],
      );
      await widgetAc(
        tester,
        const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
        themeMode: tema,
        tayfa: _overridelar(o),
      );
      await tester.pumpAndSettle();
      expect(find.text('Göl otoparkı'), findsOneWidget);
      expect(find.byType(OsmHarita), findsOneWidget);
      expect(find.byType(KanalFotografi), findsOneWidget);
      expect(
        find.text(arbMetni('sohbet_mesaj_gosterilemiyor')),
        findsOneWidget,
      );
      expect(find.byTooltip(arbMetni('sohbet_ek_ekle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('aralık dışı yer gösterilmez (sunucudan gelen veri girdidir)', (
    tester,
  ) async {
    final o = SohbetOrtami(mesajlar: [_yerMesaji(mesajId2, enlem: 123.0)]);
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(o),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OsmHarita), findsNothing);
    expect(find.text(arbMetni('sohbet_mesaj_gosterilemiyor')), findsOneWidget);
  });

  testWidgets('fotoğrafa dokununca tam ekran; yer kartına dokununca harita', (
    tester,
  ) async {
    ekranBoyutu(tester, genislik: 390, yukseklik: 1400);
    final o = SohbetOrtami(
      mesajlar: [_yerMesaji(mesajId2), _fotografMesaji(mesajId1)],
    );
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(o),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(KanalFotografi));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Göl otoparkı'));
    await tester.pumpAndSettle();
    expect(find.byType(OsmHarita), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('⊕ → Yer paylaş: konum izni yalnızca "Bulunduğum yer"e '
      'basınca; nokta görülüp onaylanınca gönderilir', (tester) async {
    ekranBoyutu(tester, genislik: 390, yukseklik: 1000);
    final konum = SahteKonumServisi();
    final o = SohbetOrtami();
    o.tasima.yanitlar['POST $_mesajYolu'] = (_) => _yerMesaji(mesajId3);
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(o, konum: konum),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(arbMetni('sohbet_ek_ekle')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('sohbet_ek_galeri')), findsOneWidget);
    await tester.tap(find.text(arbMetni('sohbet_ek_yer')));
    await tester.pumpAndSettle();
    // Seçici açıldı; konum henüz istenmedi.
    expect(find.text(arbMetni('harita_bulundugum_yer')), findsOneWidget);
    expect(konum.okuma, 0);
    await tester.tap(find.text(arbMetni('harita_bulundugum_yer')));
    await tester.pumpAndSettle();
    expect(konum.okuma, 1);
    await tester.tap(find.text(arbMetni('sohbet_yer_sec')));
    await tester.pumpAndSettle();
    // Onay sayfası: harita önizlemesi ve ad; henüz gönderilmedi.
    expect(find.text(arbMetni('sohbet_yer_gonder_baslik')), findsOneWidget);
    expect(o.tasima.giden('POST', _mesajYolu), isEmpty);
    await tester.enterText(find.byType(TextField).last, '  Kamp yeri ');
    await tester.tap(find.text(arbMetni('sohbet_gonder')).last);
    await tester.pumpAndSettle();
    final govde =
        o.tasima.giden('POST', _mesajYolu).single.govde!
            as Map<String, Object?>;
    expect(govde['kind'], 'place');
    expect(govde['place'], {
      'latitude': 40.600123,
      'longitude': 31.280456,
      'name': 'Kamp yeri',
    });
  });

  testWidgets('yer onayında vazgeçilirse hiçbir şey gönderilmez', (
    tester,
  ) async {
    ekranBoyutu(tester, genislik: 390, yukseklik: 1000);
    final o = SohbetOrtami();
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(o),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(arbMetni('sohbet_ek_ekle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_ek_yer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('harita_bulundugum_yer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_yer_sec')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_vazgec')));
    await tester.pumpAndSettle();
    expect(o.tasima.giden('POST', _mesajYolu), isEmpty);
  });

  testWidgets('konum izni verilmezse seçici metinle söyler ve elle çalışır', (
    tester,
  ) async {
    ekranBoyutu(tester, genislik: 390, yukseklik: 1000);
    ikiKatYazi(tester);
    final konum = SahteKonumServisi(const KonumIzniYok(kalici: true));
    final o = SohbetOrtami();
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(o, konum: konum),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(arbMetni('sohbet_ek_ekle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_ek_yer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('harita_bulundugum_yer')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('harita_konum_izni_yok')), findsOneWidget);
    await tester.tap(find.text(arbMetni('harita_ayarlari_ac')));
    expect(konum.uygulamaAyarlari, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('⊕ → galeri: fotoğraf hazırlanır, onaylanınca kuyruğa girer', (
    tester,
  ) async {
    ekranBoyutu(tester, genislik: 390, yukseklik: 1000);
    final o = SohbetOrtami();
    _yuklemeYanitlari(o);
    o.tasima.yanitlar['POST $_mesajYolu'] = (_) =>
        _fotografMesaji(mesajId3, yazar: benimId);
    final k = ornekJpeg();
    await widgetAc(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      tayfa: _overridelar(
        o,
        secici: SahteSecici([k]),
        kodlayici: SahteKodlayici(
          kaynak: k,
          kaynakOlcusu: const JpegOlculeri(4032, 3024),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(arbMetni('sohbet_ek_ekle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_ek_galeri')));
    await tester.pumpAndSettle();
    expect(
      find.text(arbMetni('sohbet_fotograf_gonder_baslik')),
      findsOneWidget,
    );
    expect(
      find.text(arbMetni('sohbet_fotograf_gizlilik_kanal')),
      findsOneWidget,
    );
    expect(o.tasima.giden('POST', '/v1/uploads'), isEmpty);
    await tester.tap(find.text(arbMetni('sohbet_gonder')));
    await tester.pumpAndSettle();
    expect(o.tasima.giden('POST', '/v1/uploads'), hasLength(1));
    expect(
      (o.tasima.giden('POST', _mesajYolu).single.govde!
          as Map<String, Object?>)['kind'],
      'photo',
    );
  });
}
