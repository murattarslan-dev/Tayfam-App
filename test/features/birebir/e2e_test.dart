import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/features/birebir/application/birebir_gonderici.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';

import '../../core/e2e/sahte_e2e_istemcisi.dart';
import '../../core/e2e/sahte_e2e_sunucu.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

/// E2E cihaz durumu sabit (ağ ve kayıt yok).
class _SabitCihaz extends E2eCihazNotifier {
  _SabitCihaz(this._durum);

  final E2eCihazBilgisi _durum;

  @override
  E2eCihazBilgisi build() => _durum;
}

/// Bellekteki içerik sabit bir durumla başlar.
class _SabitIcerik extends BirebirIcerikNotifier {
  _SabitIcerik(this._ilk);

  final BirebirIcerikDurumu _ilk;

  @override
  BirebirIcerikDurumu build() => _ilk;
}

const String _sifreliGelen = '4d5e6f70-0000-4000-8000-0000000000e1';
const String _sifreliOkunamayan = '4d5e6f70-0000-4000-8000-0000000000e2';

Map<String, Object?> _mesaj(
  String id, {
  required String gonderen,
  required String zaman,
}) => mesajJson(id, gonderen: gonderen, zaman: zaman);

SahteTayfaTasima _tasima() => birebirTasimasi({
  'GET $konusmaYolu': (_) => konusmaJson(konusmaId1),
  'GET $mesajlarYolu': (_) => mesajListesiJson([
    _mesaj(
      _sifreliOkunamayan,
      gonderen: karsiId,
      zaman: '2026-11-10T12:00:00Z',
    ),
    _mesaj(_sifreliGelen, gonderen: karsiId, zaman: '2026-11-10T11:00:00Z'),
  ]),
});

final BirebirIcerikDurumu _icerik = BirebirIcerikDurumu(
  mesajlar: {
    _sifreliGelen: CozulmusBirebirMesaj(
      mesajId: _sifreliGelen,
      konusmaId: konusmaId1,
      gonderenKullaniciId: karsiId,
      metin: 'Şifreli selam',
      olusturma: DateTime.utc(2026, 11, 10, 11),
      kaynak: CozulmusMesajKaynagi.zarf,
    ),
  },
  konusmaSatirlari: {
    konusmaId1: [
      E2eSistemSatiri(
        kimlik: 'zarf:1',
        tur: E2eSatirTuru.mesajCozulemedi,
        zaman: DateTime.utc(2026, 11, 10, 11, 30),
      ),
    ],
  },
  kullaniciSatirlari: {
    karsiId: [
      E2eSistemSatiri(
        kimlik: 'olay:1',
        tur: E2eSatirTuru.guvenlikKoduDegisti,
        zaman: DateTime.utc(2026, 11, 10, 10, 30),
      ),
    ],
  },
  genelSatirlar: [
    E2eSistemSatiri(
      kimlik: 'kendi:1',
      tur: E2eSatirTuru.yeniKendiCihazi,
      zaman: DateTime.utc(2026, 11, 10, 12, 30),
    ),
  ],
);

List<Override> _e2eOverridelari(
  SahteTayfaTasima tasima, {
  bool e2e = true,
  E2eCihazBilgisi cihaz = const E2eCihazBilgisi(
    durum: E2eCihazDurumu.hazirlaniyor,
  ),
  BirebirIcerikDurumu? icerik,
}) => [
  ...birebirEkranOverridelari(tasima, e2e: e2e),
  e2eCihazProvider.overrideWith(() => _SabitCihaz(cihaz)),
  birebirIcerikProvider.overrideWith(() => _SabitIcerik(icerik ?? _icerik)),
];

const E2eCihazBilgisi _hazir = E2eCihazBilgisi(durum: E2eCihazDurumu.hazir);

void main() {
  group('konuşma (mobil, E2E)', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('çözülmüş içerik ve sistem satırları ($tema, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester, yukseklik: 2400);
        ikiKatYazi(tester);
        await widgetAc(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          themeMode: tema,
          tayfa: _e2eOverridelari(_tasima()),
        );
        expect(find.text('Şifreli selam'), findsOneWidget);
        expect(find.text(arbMetni('e2e_mesaj_okunamiyor')), findsOneWidget);
        expect(find.text(arbMetni('e2e_mesaj_cozulemedi')), findsOneWidget);
        expect(
          find.text(arbMetni('e2e_guvenlik_kodu_degisti')),
          findsOneWidget,
        );
        expect(find.text(arbMetni('e2e_yeni_kendi_cihazi')), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cihaz sınırı: uyarı ve oturumlar düğmesi', (tester) async {
      ekranBoyutu(tester, yukseklik: 1000);
      ikiKatYazi(tester);
      await widgetAc(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        themeMode: ThemeMode.dark,
        tayfa: _e2eOverridelari(
          birebirTasimasi(),
          cihaz: const E2eCihazBilgisi(durum: E2eCihazDurumu.sinirDolu),
        ),
      );
      expect(find.text(arbMetni('e2e_cihaz_siniri_baslik')), findsOneWidget);
      expect(find.text(arbMetni('e2e_oturumlari_ac')), findsOneWidget);
      expect(find.text(arbMetni('e2e_tekrar_dene')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('kayıt hatası: tekrar dene', (tester) async {
      ekranBoyutu(tester);
      await widgetAc(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        tayfa: _e2eOverridelari(
          birebirTasimasi(),
          cihaz: const E2eCihazBilgisi(durum: E2eCihazDurumu.hata),
        ),
      );
      expect(find.text(arbMetni('e2e_hazirlanamadi')), findsOneWidget);
      expect(find.text(arbMetni('e2e_oturumlari_ac')), findsNothing);
    });
  });

  group('web geliştirme derlemesi', () {
    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('şifreli konuşmada yalnızca mobil boş durumu ($tema, 2×)', (
        tester,
      ) async {
        ekranBoyutu(tester, yukseklik: 2400);
        ikiKatYazi(tester);
        await widgetAc(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          themeMode: tema,
          tayfa: _e2eOverridelari(
            _tasima(),
            e2e: false,
            icerik: const BirebirIcerikDurumu(),
          ),
        );
        expect(find.text(arbMetni('e2e_yalnizca_mobil')), findsOneWidget);
        expect(find.text(arbMetni('e2e_sifreli_mesaj')), findsNWidgets(2));
        expect(find.byType(TextField), findsNothing);
        // Web'de E2E satırları yok.
        expect(find.text(arbMetni('e2e_mesaj_cozulemedi')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('gönderim', () {
    test('mobilde birebir gönderici şifreli, REST ile gönderir', () async {
      final sunucu = SahteE2eSunucu();
      final ben = SahteE2eIstemcisi(sunucu, benId);
      final karsi = SahteE2eIstemcisi(sunucu, karsiId, tohum: 40);
      await ben.hazirla();
      await karsi.hazirla();
      final kap = ProviderContainer.test(
        overrides: [
          ...birebirEkranOverridelari(
            birebirTasimasi(),
            e2e: true,
            sahteGonderim: false,
          ),
          e2eCihazProvider.overrideWith(() => _SabitCihaz(_hazir)),
          e2eDeposuProvider.overrideWithValue(ben.depo),
          e2eGondericiProvider.overrideWithValue(ben.gonderici),
        ],
      );
      final sonuc = await kap
          .read(birebirGondericiProvider)
          .gonder(
            aliciId: karsiId,
            metin: 'Şifreli merhaba',
            istekKimligi: '9c000000-0000-4000-8000-000000000001',
          );
      expect(sonuc.konusma.id, sonuc.mesaj.conversationId);
      final icerik = kap.read(birebirIcerikProvider).mesajlar[sonuc.mesaj.id];
      expect(icerik?.metin, 'Şifreli merhaba');
      await karsi.cek();
      expect(karsi.alinanlar.single.metin, 'Şifreli merhaba');
      // Düz metin hiçbir istekte yok.
      for (final i in sunucu.istekler) {
        expect('${i.govde}', isNot(contains('Şifreli merhaba')));
      }
    });

    test('E2E yoksa gönderim düz yola düşmüyor, hata veriyor', () async {
      // Web geliştirme derlemesi ve iOS köprüsü yazılana kadar iOS: cihaz
      // kaydı yok; mesaj ne REST'ten ne WebSocket'ten düz gider.
      final tasima = birebirTasimasi();
      final kap = ProviderContainer.test(
        overrides: birebirEkranOverridelari(tasima, sahteGonderim: false),
      );
      await expectLater(
        kap
            .read(birebirGondericiProvider)
            .gonder(
              aliciId: karsiId,
              metin: 'Düz gitmemeli',
              istekKimligi: '9c000000-0000-4000-8000-000000000002',
            ),
        throwsA(
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.e2eDeviceNotRegistered,
          ),
        ),
      );
      expect(tasima.giden('POST', gonderYolu), isEmpty);
    });
  });
}
