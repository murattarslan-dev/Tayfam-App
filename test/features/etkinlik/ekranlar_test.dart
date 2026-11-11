import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlikler_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/iptal_diyalogu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

String _yol(WidgetTester tester) =>
    yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path;

/// Uygulamayı açıp [adres]'e gider.
Future<void> _git(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  String adres, {
  ThemeMode themeMode = ThemeMode.light,
  SahteTakvimPaylasici? takvim,
  SahteBaglantiAcici? baglanti,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(
      tasima: tasima,
      takvim: takvim,
      baglanti: baglanti,
    ),
  );
  yonlendiriciyiAl(tester).go(adres);
  await tester.pumpAndSettle();
}

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

/// İlk metin alanına yazar.
Future<void> _yaz(WidgetTester tester, String metin) async {
  final alan = find.byType(TextField).first;
  await tester.ensureVisible(alan);
  await tester.pumpAndSettle();
  await tester.enterText(alan, metin);
  await tester.pumpAndSettle();
}

void main() {
  group('etkinlik listesi', () {
    for (final tema in _temalar) {
      testWidgets('kartlar, iptal etiketi ve sayfalama (${tema.name})', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET $etkinliklerYolu': (i) => i.sorgu['page_token'] == null
              ? etkinlikListesiJson([
                  etkinlikJson(cevap: 'going', kontenjan: 20, gelen: 8),
                ], sonraki: 'sonraki-sayfa')
              : etkinlikListesiJson([
                  etkinlikJson(
                    id: ikinciEtkinlikId,
                    tur: 'gaming',
                    mod: 'online',
                    baslik: 'Oyun gecesi',
                    iptal: true,
                  ),
                ]),
        });
        await _git(
          tester,
          tasima,
          Adresler.etkinlikler(ornekTayfaId),
          themeMode: tema,
        );

        expect(find.byType(EtkinliklerEkrani), findsOneWidget);
        expect(find.text('Göl kampı'), findsOneWidget);
        expect(find.text('Abant Gölü'), findsOneWidget);
        expect(find.text('8 / 20 kişi geliyor'), findsOneWidget);
        expect(find.text('Cevabın: Geliyorum'), findsOneWidget);
        expect(
          find.text(arbMetni('etkinlik_ac')),
          findsNothing,
          reason: 'üye, tayfada üyeler etkinlik açamıyor',
        );

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_daha_fazla')),
        );
        final sayfalar = tasima.giden('GET', etkinliklerYolu);
        expect(sayfalar, hasLength(2));
        expect(sayfalar[0].sorgu, {'page_size': '20'});
        expect(sayfalar[1].sorgu, {
          'page_size': '20',
          'page_token': 'sonraki-sayfa',
        });
        await tester.scrollUntilVisible(
          find.text('Oyun gecesi'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(arbMetni('etkinlik_iptal_edildi')), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_cevrimici')), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_daha_fazla')), findsNothing);
      });
    }

    testWidgets('yöneticiye "Etkinlik aç"; boş durum; karta dokununca detay', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var bos = true;
      final tasima = etkinlikTasimasi({
        'GET /v1/tayfas/{tayfa_id}': (_) =>
            gorunumJson(ornekTayfaId, rol: 'admin'),
        'GET $etkinliklerYolu': (_) =>
            etkinlikListesiJson(bos ? const [] : [etkinlikJson()]),
      });
      await _git(tester, tasima, Adresler.etkinlikler(ornekTayfaId));

      expect(find.text(arbMetni('etkinlik_liste_bos')), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_ac')), findsOneWidget);

      bos = false;
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('Göl kampı'), findsOneWidget);

      await tester.tap(find.text('Göl kampı'));
      await tester.pumpAndSettle();
      expect(
        _yol(tester),
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
    });
  });

  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('bölümler (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(
            kontenjan: 3,
            yonetebilir: true,
            seri: ikinciEtkinlikId,
            ayrinti: {'site_name': 'Göl kenarı', 'has_water': true},
          ),
        });
        await _git(
          tester,
          tasima,
          Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
          themeMode: tema,
        );

        expect(find.text('Göl kampı'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_seri_notu')), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_kontenjan_dolu')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Göl kenarı'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Ayşe'), findsOneWidget);
        expect(find.text('Abant Gölü'), findsOneWidget);
        expect(find.text('Merkez, Bolu'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_harita_atif')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Mert'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          tasima.giden('GET', katilimcilarYolu).first.sorgu['status'],
          'going',
        );
      });
    }

    testWidgets('katılım: Geliyorum seçilir, sayı ve sekme güncellenir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var okuma = 0;
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => okuma++ == 0
            ? etkinlikJson()
            : etkinlikJson(cevap: 'going', gelen: 4),
        'PUT $katilimYolu': (_) => {'status': 'going'},
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.text('Geliyor: 3 · Belki: 1'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(ChoiceChip, arbMetni('etkinlik_cevap_going')),
      );
      await tester.pumpAndSettle();

      expect(tasima.giden('PUT', katilimYolu).single.govde, {
        'status': 'going',
      });
      final cip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, arbMetni('etkinlik_cevap_going')),
      );
      expect(cip.selected, isTrue);
      expect(find.text('Geliyor: 4 · Belki: 1'), findsOneWidget);
      expect(
        tasima.giden('GET', katilimcilarYolu).length,
        greaterThanOrEqualTo(2),
        reason: 'katılımcılar yeniden okunur',
      );
    });

    testWidgets('bekleme listesindeyken bilgi gösterilir', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) =>
            etkinlikJson(kontenjan: 3, cevap: 'waitlist', bekleyen: 1),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(
        find.text(arbMetni('etkinlik_bekleme_listesindesin')),
        findsOneWidget,
      );
      final cip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, arbMetni('etkinlik_cevap_going')),
      );
      expect(cip.selected, isTrue);
    });

    testWidgets('takvime ekle ve harita uygulaması', (tester) async {
      ekranBoyutu(tester);
      final takvim = SahteTakvimPaylasici();
      final baglanti = SahteBaglantiAcici();
      final tasima = etkinlikTasimasi({
        'GET $takvimYolu': (_) => 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
        takvim: takvim,
        baglanti: baglanti,
      );

      await tester.tap(find.byTooltip(arbMetni('etkinlik_takvime_ekle')));
      await tester.pumpAndSettle();
      expect(takvim.paylasilan, hasLength(1));

      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_haritada_ac')),
      );
      expect(baglanti.noktalar, [(40.6, 31.28)]);
    });

    testWidgets('çevrimiçi etkinlik: bağlantı açılır', (tester) async {
      ekranBoyutu(tester);
      final baglanti = SahteBaglantiAcici();
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(mod: 'online'),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
        baglanti: baglanti,
      );
      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_baglantiyi_ac')),
      );
      expect(baglanti.adresler, [Uri.parse('https://ornek.tayfam.app/oda')]);
    });

    testWidgets('iptal: gerekçe zorunlu, istek gider, etiket görünür', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(yonetebilir: true),
        'POST $iptalYolu': (_) => etkinlikJson(iptal: true),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );

      await tester.tap(find.byTooltip(arbMetni('etkinlik_islemler')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('etkinlik_iptal_et')));
      await tester.pumpAndSettle();
      expect(find.byType(IptalDiyalogu), findsOneWidget);

      final onay = find.descendant(
        of: find.byType(IptalDiyalogu),
        matching: find.text(arbMetni('etkinlik_iptal_onayla')),
      );
      await tester.tap(onay);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_iptal_gerekce_hata')), findsOneWidget);
      expect(tasima.giden('POST', iptalYolu), isEmpty);

      await tester.enterText(find.byType(TextField), 'Hava kötü');
      await tester.tap(onay);
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', iptalYolu).single.govde, {
        'reason': 'Hava kötü',
      });
      expect(find.text(arbMetni('etkinlik_iptal_edildi')), findsOneWidget);
      expect(find.text('İptal gerekçesi: Hava kötü'), findsOneWidget);
      expect(find.byTooltip(arbMetni('etkinlik_islemler')), findsNothing);
    });

    testWidgets('biçimi bozuk kimlikle istek gitmez', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi();
      await _git(tester, tasima, Adresler.etkinlik(ornekTayfaId, 'bozuk'));
      expect(find.text(arbMetni('hata_event_not_found')), findsOneWidget);
      expect(tasima.giden('GET', etkinlikYolu), isEmpty);
    });
  });

  group('sihirbaz', () {
    for (final tema in _temalar) {
      testWidgets('dört adım (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi();
        await _git(
          tester,
          tasima,
          Adresler.etkinlikOlustur(ornekTayfaId),
          themeMode: tema,
        );
        expect(find.byType(EtkinlikSihirbaziEkrani), findsOneWidget);
        expect(find.text('Adım 1 / 4'), findsOneWidget);

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_turu_hike')));
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 2 / 4'), findsOneWidget);

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text(arbMetni('etkinlik_baslik_hata')), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_baslangic_yok')), findsOneWidget);

        await _yaz(tester, 'Kaçkar');
        tester
            .container()
            .read(
              etkinlikSihirbaziProvider((
                tayfaId: ornekTayfaId,
                duzenlenen: null,
              )).notifier,
            )
            .baslangicAyarla(ornekBaslangic);
        await tester.pumpAndSettle();
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 3 / 4'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_nokta_sec')), findsOneWidget);

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_mod_cevrimici')),
        );
        await _yaz(tester, 'https://ornek.tayfam.app/oda');
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 4 / 4'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_mesafe_etiketi')), findsOneWidget);

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_tekrar_haftalik')),
        );
        expect(
          find.text(arbMetni('etkinlik_tekrar_aralik_haftalik')),
          findsOneWidget,
        );
      });
    }

    testWidgets('gönderince etkinliğin detayı açılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(tur: 'general'),
      });
      await _git(tester, tasima, Adresler.etkinlikOlustur(ornekTayfaId));
      final n = tester.container().read(
        etkinlikSihirbaziProvider((
          tayfaId: ornekTayfaId,
          duzenlenen: null,
        )).notifier,
      );
      n
        ..turSec(EventType.general)
        ..ileri()
        ..baslikAyarla('Buluşma')
        ..baslangicAyarla(ornekBaslangic)
        ..ileri()
        ..noktaSec(
          const LatLng(lat: 40.6, lng: 31.28),
          il: 'Bolu',
          ilce: 'Merkez',
        )
        ..ileri();
      await tester.pumpAndSettle();
      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_olustur_gonder')),
      );

      final govde =
          tasima.giden('POST', etkinliklerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['client_request_id'], sahteEtkinlikIstekKimligi);
      expect(govde['type'], 'general');
      expect(
        _yol(tester),
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
    });

    testWidgets('düzenleme: seri notu, tür adımı yok', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) =>
            etkinlikJson(yonetebilir: true, seri: ikinciEtkinlikId),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlikDuzenle(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.text(arbMetni('etkinlik_duzenle_baslik')), findsOneWidget);
      expect(find.text('Adım 1 / 3'), findsOneWidget);
      expect(
        find.text(arbMetni('etkinlik_seri_duzenleme_notu')),
        findsOneWidget,
      );
      expect(find.text('Göl kampı'), findsOneWidget);
    });
  });
}
