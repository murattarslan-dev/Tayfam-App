import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlikler_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/iptal_diyalogu.dart';
import 'package:tayfam/features/etkinlik/presentation/katilimcilar_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/tekrar_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

/// Liste gruplama testindeki ek etkinlik kimlikleri.
const String _ucuncuEtkinlikId = '7c6b5a49-3827-4165-a4b3-c2d1e0f9a8b7';
const String _dorduncuEtkinlikId = '8d7c6b5a-4938-4276-b5c4-d3e2f1a0b9c8';

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

/// Seçili (dolu, işaretli) katılım düğmesi: "Geliyorum".
Finder _seciliKatilim() => find.ancestor(
  of: find.text(arbMetni('etkinlik_cevap_going')),
  matching: find.byType(FilledButton),
);

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
    testWidgets('yöneticiye "Etkinlik aç"; karta dokununca detay', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final tasima = etkinlikTasimasi({
        'GET /v1/tayfas/{tayfa_id}': (_) =>
            gorunumJson(ornekTayfaId, rol: 'admin'),
      });
      await _git(tester, tasima, Adresler.etkinlikler(ornekTayfaId));

      expect(find.byType(EtkinliklerEkrani), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text(arbMetni('etkinlik_listesi_ac')), findsOneWidget);

      await _gorunurDokun(tester, find.text('Göl kampı'));
      expect(_yol(tester), Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
    });

    testWidgets('üyeye "Etkinlik aç" yok; sihirbaz adresiyle açılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _git(
        tester,
        etkinlikTasimasi(),
        Adresler.etkinlikler(ornekTayfaId),
      );
      expect(find.text(arbMetni('etkinlik_listesi_ac')), findsNothing);

      yonlendiriciyiAl(tester).go(Adresler.etkinlikOlustur(ornekTayfaId));
      await tester.pumpAndSettle();
      expect(find.byType(EtkinlikSihirbaziEkrani), findsOneWidget);
    });
  });

  group('etkinlik listesi grupları (2026-11-13 tasarım)', () {
    testWidgets('bu hafta, gelecek hafta, aylar; iptal ve cevap', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2400);
      // sabitSimdi: 11 Kasım 2026 Çarşamba; hafta 9–15 Kasım.
      final tasima = etkinlikTasimasi({
        'GET $etkinliklerYolu': (_) => etkinlikListesiJson([
          etkinlikJson(
            baslik: 'Cumartesi turu',
            baslangic: DateTime(2026, 11, 14, 10).toUtc(),
            sure: const Duration(hours: 3),
            cevap: 'going',
          ),
          etkinlikJson(
            id: ikinciEtkinlikId,
            baslik: 'Pazar maçı',
            baslangic: DateTime(2026, 11, 22, 10).toUtc(),
            sure: const Duration(hours: 2),
            iptal: true,
          ),
          etkinlikJson(
            id: _ucuncuEtkinlikId,
            baslik: 'Kış kampı',
            baslangic: DateTime(2026, 12, 5, 10).toUtc(),
          ),
          etkinlikJson(
            id: _dorduncuEtkinlikId,
            baslik: 'Yılbaşı sonrası',
            baslangic: DateTime(2027, 1, 9, 10).toUtc(),
          ),
        ]),
      });
      await _git(tester, tasima, Adresler.etkinlikler(ornekTayfaId));

      expect(find.text(arbMetni('etkinlik_listesi_baslik')), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_listesi_bu_hafta')), findsOneWidget);
      expect(
        find.text(arbMetni('etkinlik_listesi_gelecek_hafta')),
        findsOneWidget,
      );
      expect(find.text('Aralık'), findsOneWidget);
      expect(find.text('Ocak 2027'), findsOneWidget);
      expect(find.byType(ListeKarti), findsNWidgets(4));

      // Cevap ya da "Cevap ver"; iptal edilende etiket ve üstü çizili.
      expect(find.text(arbMetni('etkinlik_cevap_going')), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_cevap_ver')), findsNWidgets(2));
      expect(find.text(arbMetni('etkinlik_karti_iptal')), findsOneWidget);
      final iptal = tester.widget<Text>(find.text('Pazar maçı'));
      expect(iptal.style?.decoration, TextDecoration.lineThrough);
      final olagan = tester.widget<Text>(find.text('Kış kampı'));
      expect(olagan.style?.decoration, isNot(TextDecoration.lineThrough));
    });

    for (final tema in _temalar) {
      testWidgets('yönetici, 2× yazı, 320 dp taşmaz (${tema.name})', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET /v1/tayfas/{tayfa_id}': (_) =>
              gorunumJson(ornekTayfaId, rol: 'admin'),
          'GET $etkinliklerYolu': (_) => etkinlikListesiJson([
            etkinlikJson(cevap: 'maybe'),
            etkinlikJson(
              id: ikinciEtkinlikId,
              baslangic: DateTime(2026, 12, 5, 10).toUtc(),
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
        expect(tester.takeException(), isNull);
        expect(find.text(arbMetni('etkinlik_listesi_ac')), findsOneWidget);
      });
    }

    testWidgets('boşken mevcut boş metni', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinliklerYolu': (_) => etkinlikListesiJson(const []),
      });
      await _git(tester, tasima, Adresler.etkinlikler(ornekTayfaId));
      expect(find.text(arbMetni('tayfa_ana_etkinlikler_bos')), findsOneWidget);
      expect(find.byType(BolumEtiketi), findsNothing);
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

        for (final metin in [
          'Göl kampı',
          '3 gün sonra',
          'Merkez, Bolu',
          arbMetni('etkinlik_organizator'),
          'Ayşe',
          '3/3 kişi geliyor · 1 belki',
          arbMetni('etkinlik_kontenjan_dolu'),
          arbMetni('etkinlik_harita_atif'),
          'Göl kenarı',
          '3 kişi geliyor',
          arbMetni('etkinlik_seri_notu'),
        ]) {
          await tester.scrollUntilVisible(
            find.text(metin),
            100,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text(metin), findsOneWidget, reason: metin);
        }
        // Yer adı özet kartında ve harita kartında.
        expect(find.text('Abant Gölü'), findsNWidgets(2));
        // Katılımcı listesi detayda değil; özet ilk sayfadan avatar alır.
        expect(find.text('Mert'), findsNothing);
        expect(
          tasima.giden('GET', katilimcilarYolu).first.sorgu['status'],
          'going',
        );
        expect(tester.takeException(), isNull);
      });
    }

    for (final tema in _temalar) {
      testWidgets('katılımcılar ekranı (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(belki: 2, bekleyen: 1),
          'GET $katilimcilarYolu': (i) => i.sorgu['status'] == 'maybe'
              ? katilimcilarJson([organizatorId], durum: 'maybe')
              : katilimcilarJson([katilimciId]),
        });
        await _git(
          tester,
          tasima,
          Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
          themeMode: tema,
        );
        await _gorunurDokun(tester, find.text('3 kişi geliyor'));
        expect(
          _yol(tester),
          Adresler.etkinlikKatilimcilari(ornekTayfaId, ornekEtkinlikId),
        );
        expect(find.byType(KatilimcilarEkrani), findsOneWidget);
        expect(find.text('Geliyor 3'), findsOneWidget);
        expect(find.text('Belki 2'), findsOneWidget);
        expect(find.text('Mert'), findsOneWidget);

        await tester.tap(find.text('Belki 2'));
        await tester.pumpAndSettle();
        expect(find.text('Ayşe'), findsOneWidget);
        expect(
          tasima.giden('GET', katilimcilarYolu).last.sorgu['status'],
          'maybe',
        );
        // Bitmemiş etkinlikte düzeltme yok.
        expect(find.text(arbMetni('etkinlik_duzeltme_bilgi')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('iptal edilen etkinlik: üst bölüm, gerekçe, cevap yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(iptal: true),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.text(arbMetni('etkinlik_karti_iptal')), findsOneWidget);
      expect(find.text('3 gün sonra'), findsNothing);
      expect(
        find.text(arbMetni('etkinlik_iptal_edildi_baslik')),
        findsOneWidget,
      );
      expect(find.text('İptal gerekçesi: Hava kötü'), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_katilim_kapali')), findsOneWidget);
      expect(find.text(arbMetni('etkinlik_cevap_going')), findsNothing);
    });

    testWidgets('katılım: Geliyorum seçilir, sayılar güncellenir', (
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
      expect(find.text('3 kişi geliyor · 1 belki'), findsOneWidget);
      expect(_seciliKatilim(), findsNothing);

      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_cevap_going')));

      expect(tasima.giden('PUT', katilimYolu).single.govde, {
        'status': 'going',
      });
      expect(_seciliKatilim(), findsOneWidget);
      expect(find.text('4 kişi geliyor · 1 belki'), findsOneWidget);
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
      expect(find.text(arbMetni('etkinlik_rozet_bekleme')), findsOneWidget);
      expect(_seciliKatilim(), findsOneWidget);
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

      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_haritada_ac')));
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
      expect(find.text(arbMetni('etkinlik_duzenle')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_et')), findsNothing);
      await tester.tap(find.text(arbMetni('etkinlik_iptal_baslik')));
      await tester.pumpAndSettle();
      expect(find.byType(IptalDiyalogu), findsOneWidget);

      final onay = find.descendant(
        of: find.byType(IptalDiyalogu),
        matching: find.text(arbMetni('etkinlik_iptal_onayla')),
      );
      await tester.tap(onay);
      await tester.pumpAndSettle();
      expect(
        find.text(arbMetni('etkinlik_iptal_gerekce_hata')),
        findsOneWidget,
      );
      expect(tasima.giden('POST', iptalYolu), isEmpty);

      await tester.enterText(find.byType(TextField), 'Hava kötü');
      await tester.tap(onay);
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', iptalYolu).single.govde, {
        'reason': 'Hava kötü',
      });
      expect(find.text(arbMetni('etkinlik_karti_iptal')), findsOneWidget);
      expect(find.text('İptal gerekçesi: Hava kötü'), findsOneWidget);
      // İptal edilen etkinlikte yönetim işlemi kalmaz; şikâyet kalır.
      await tester.tap(find.byTooltip(arbMetni('etkinlik_islemler')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_iptal_baslik')), findsNothing);
      expect(find.text(arbMetni('sikayet_et')), findsOneWidget);
    });

    testWidgets('üye etkinliği şikâyet eder: sahte etkinlik gerekçesi', (
      tester,
    ) async {
      ekranBoyutu(tester);
      const sikayetlerYolu = '/v1/tayfas/{tayfa_id}/reports';
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(),
        'POST $sikayetlerYolu': (_) => {
          'id': '9a8b7c6d-0000-4000-8000-000000000002',
          'tayfa_id': ornekTayfaId,
          'target_type': 'event',
          'target_id': ornekEtkinlikId,
          'reason': 'fake_event',
          'status': 'open',
          'created_at': '2026-11-11T10:00:00Z',
        },
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );

      await tester.tap(find.byTooltip(arbMetni('etkinlik_islemler')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_iptal_baslik')), findsNothing);
      await tester.tap(find.text(arbMetni('sikayet_et')));
      await tester.pumpAndSettle();
      const gerekce = 'sikayet_gerekce_sahte_etkinlik';
      for (final metin in [gerekce, 'sikayet_gonder']) {
        final hedef = find.text(arbMetni(metin));
        await tester.ensureVisible(hedef);
        await tester.pumpAndSettle();
        await tester.tap(hedef);
        await tester.pumpAndSettle();
      }

      expect(tasima.giden('POST', sikayetlerYolu).single.govde, {
        'target_type': 'event',
        'target_id': ornekEtkinlikId,
        'reason': 'fake_event',
      });
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
      testWidgets('beş adım (${tema.name}, 2× yazı, 320 dp)', (tester) async {
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
        expect(find.text('Adım 1 / 5'), findsOneWidget);
        expect(
          find.text(arbMetni('etkinlik_tur_aciklama_hike')),
          findsOneWidget,
        );

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_turu_hike')));
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 2 / 5'), findsOneWidget);

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
        expect(find.text('Adım 3 / 5'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_nokta_sec')), findsOneWidget);

        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_mod_cevrimici')),
        );
        await _yaz(tester, 'https://ornek.tayfam.app/oda');
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 4 / 5'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_mesafe_etiketi')), findsOneWidget);

        // Tekrar ayrı ekranda; "Tamam" 4. adıma döner.
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_tekrar_yok')));
        expect(find.byType(TekrarEkrani), findsOneWidget);
        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_tekrar_haftalik')),
        );
        expect(
          find.text(arbMetni('etkinlik_tekrar_aralik_haftalik')),
          findsWidgets,
        );
        // Özet kutusu listenin sonunda.
        await tester.scrollUntilVisible(
          find.textContaining('bitiş yok'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('bitiş yok'), findsOneWidget);
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_tamam')));
        expect(find.byType(TekrarEkrani), findsNothing);
        expect(find.text(arbMetni('etkinlik_tekrar_haftalik')), findsOneWidget);

        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 5 / 5'), findsOneWidget);
        expect(find.text(arbMetni('etkinlik_onizleme_baslik')), findsOneWidget);
        expect(find.text('Kaçkar'), findsOneWidget);

        // "Değiştir" ilgili adıma götürür, "İleri" önizlemeye döner.
        await _gorunurDokun(
          tester,
          find.text(arbMetni('etkinlik_degistir')).at(1),
        );
        expect(find.text('Adım 3 / 5'), findsOneWidget);
        await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
        expect(find.text('Adım 5 / 5'), findsOneWidget);
        expect(tasima.giden('POST', etkinliklerYolu), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kapatırken girilen varsa onay sorulur', (tester) async {
      ekranBoyutu(tester);
      await _git(
        tester,
        etkinlikTasimasi(),
        Adresler.etkinlikOlustur(ornekTayfaId),
      );
      final kapat = find.byIcon(Icons.close);
      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_turu_camp')));
      await tester.tap(kapat);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_vazgec_baslik')), findsOneWidget);

      await tester.tap(find.text(arbMetni('etkinlik_vazgec_devam')));
      await tester.pumpAndSettle();
      expect(find.byType(EtkinlikSihirbaziEkrani), findsOneWidget);

      await tester.tap(kapat);
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('etkinlik_vazgec')));
      await tester.pumpAndSettle();
      expect(find.byType(EtkinlikSihirbaziEkrani), findsNothing);
    });

    testWidgets('gönderince etkinliğin detayı açılır', (tester) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(tur: 'general'),
      });
      await _git(tester, tasima, Adresler.etkinlikOlustur(ornekTayfaId));
      final n = tester.container().read(
        etkinlikSihirbaziProvider((tayfaId: ornekTayfaId, duzenlenen: null))
            .notifier,
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
        ..ileri()
        ..ileri();
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_onizleme_baslik')), findsOneWidget);
      await _gorunurDokun(
        tester,
        find.text(arbMetni('etkinlik_olustur_gonder')),
      );

      final govde =
          tasima.giden('POST', etkinliklerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['client_request_id'], sahteEtkinlikIstekKimligi);
      expect(govde['type'], 'general');
      expect(_yol(tester), Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
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
      expect(find.text('Adım 1 / 4'), findsOneWidget);
      expect(
        find.text(arbMetni('etkinlik_seri_duzenleme_notu')),
        findsOneWidget,
      );
      expect(find.text('Göl kampı'), findsOneWidget);
    });
  });
}
