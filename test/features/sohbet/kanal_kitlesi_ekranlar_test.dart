import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ekrani.dart';
import 'package:tayfam/features/sohbet/presentation/katilimcilar_ekrani.dart';
import 'package:tayfam/features/sohbet/sohbet.dart';

import '../../yardimcilar.dart';
import '../etkinlik/sahteler.dart'
    show etkinlikJson, ornekEtkinlik, ornekEtkinlikId;
import 'sahteler.dart';

/// Sabit saat: 15 Kasım 2026 10:00 (cihazın saat diliminde).
final DateTime _simdi = DateTime(2026, 11, 15, 10);

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SohbetOrtami ortam, {
  ThemeMode tema = ThemeMode.light,
}) async {
  await widgetAc(tester, ekran, themeMode: tema, tayfa: ortam.overridelar);
  await tester.pumpAndSettle();
}

Map<String, Object?> _seciliKanal({String acan = benimId}) => kanalJson(
  kanalId1,
  ad: 'parça-alımı',
  gorunurluk: 'selected',
  kisiSayisi: 3,
  acan: acan,
);

Map<String, Object?> _etkinlikKanali({
  DateTime? arsivZamani,
  bool arsiv = false,
}) => kanalJson(
  kanalId2,
  ad: 'boğaz-sabah-turu',
  gorunurluk: 'event',
  etkinlik: ornekEtkinlikId,
  kisiSayisi: 24,
  acan: benimId,
  arsiv: arsiv,
  arsivZamani: arsivZamani,
);

void main() {
  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    group('kanal kitlesi (${tema.name}, 2×, 320 dp)', () {
      testWidgets('listede etkinlik ve seçili kişi etiketleri, kişi sayısı', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          kanallar: [_etkinlikKanali(), _seciliKanal()],
        );
        await _ac(tester, const SohbetEkrani(), ortam, tema: tema);
        expect(find.text(arbMetni('sohbet_kanal_etkinlik')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_kanal_secili')), findsOneWidget);
        expect(find.text('24 kişi'), findsOneWidget);
        expect(find.text('3 kişi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('katılımcılar: kanalı açan "Kişi ekle" ve "Çıkar" görür', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          kanallar: [_seciliKanal()],
          katilimcilar: [benimId, digerId, ucuncuId],
        );
        await _ac(
          tester,
          const KatilimcilarEkrani(
            kanal: (tayfaId: ornekTayfaId, kanalId: kanalId1),
          ),
          ortam,
          tema: tema,
        );
        expect(find.text(arbMetni('sohbet_kisi_ekle')), findsOneWidget);
        // Kanalı açan kendini çıkaramaz: iki kişi, iki "Çıkar".
        expect(find.text(arbMetni('sohbet_katilimci_cikar')), findsNWidgets(2));
        expect(find.text('Ben (sen)'), findsOneWidget);
        expect(find.text(arbMetni('sohbet_katilimci_acan')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_katilimcilar_not')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('etkinlik kanalı: kapanış bandı ve kitle alt başlığı', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1200);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          simdi: _simdi,
          kanallar: [_etkinlikKanali(arsivZamani: DateTime(2026, 11, 20, 9))],
        );
        await _ac(
          tester,
          const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId2),
          ortam,
          tema: tema,
        );
        expect(find.text('Kanal 5 gün sonra kapanacak'), findsOneWidget);
        expect(find.textContaining('20 Kasım'), findsOneWidget);
        expect(find.text('Etkinlik kanalı · 24 kişi'), findsOneWidget);
        expect(find.byTooltip(arbMetni('sohbet_gonder')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('katılımcılar: kanalı açmayan (yönetim de) eylem görmez', (
    tester,
  ) async {
    final ortam = SohbetOrtami(
      rol: 'admin',
      kanallar: [_seciliKanal(acan: digerId)],
      katilimcilar: [benimId, digerId],
    );
    await _ac(
      tester,
      const KatilimcilarEkrani(
        kanal: (tayfaId: ornekTayfaId, kanalId: kanalId1),
      ),
      ortam,
    );
    expect(find.text('Ayşe'), findsOneWidget);
    expect(find.text(arbMetni('sohbet_kisi_ekle')), findsNothing);
    expect(find.text(arbMetni('sohbet_katilimci_cikar')), findsNothing);
    expect(find.text(arbMetni('sohbet_katilimcilar_not')), findsNothing);
  });

  testWidgets('katılımcılar: etkinlik kanalı salt okunur', (tester) async {
    final ortam = SohbetOrtami(
      kanallar: [_etkinlikKanali()],
      katilimcilar: [benimId, digerId],
    );
    await _ac(
      tester,
      const KatilimcilarEkrani(
        kanal: (tayfaId: ornekTayfaId, kanalId: kanalId2),
      ),
      ortam,
    );
    expect(
      find.text(arbMetni('sohbet_katilimcilar_etkinlik_bilgi')),
      findsOneWidget,
    );
    expect(find.text(arbMetni('sohbet_kisi_ekle')), findsNothing);
    expect(find.text(arbMetni('sohbet_katilimci_cikar')), findsNothing);
  });

  testWidgets('kanalı açan kişiyi çıkarır', (tester) async {
    final ortam = SohbetOrtami(
      kanallar: [_seciliKanal()],
      katilimcilar: [benimId, digerId],
    );
    ortam.tasima.yanitlar['DELETE $kanalKisisiYolu'] = (_) => null;
    ortam.tasima.yanitlar['GET $kanalYolu'] = (_) => _seciliKanal();
    await _ac(
      tester,
      const KatilimcilarEkrani(
        kanal: (tayfaId: ornekTayfaId, kanalId: kanalId1),
      ),
      ortam,
    );
    await tester.tap(find.text(arbMetni('sohbet_katilimci_cikar')));
    await tester.pumpAndSettle();
    expect(
      ortam.tasima.giden('DELETE', kanalKisisiYolu).single.yolParametreleri,
      containsPair('user_id', digerId),
    );
    expect(find.text('Ayşe'), findsNothing);
  });

  testWidgets('arşivlenmiş etkinlik kanalında bant yok, arşiv bilgisi var', (
    tester,
  ) async {
    final ortam = SohbetOrtami(
      simdi: _simdi,
      kanallar: [
        _etkinlikKanali(arsiv: true, arsivZamani: DateTime(2026, 11, 10)),
      ],
    );
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId2),
      ortam,
    );
    expect(find.text(arbMetni('sohbet_kanal_alt_arsiv')), findsOneWidget);
    expect(find.text(arbMetni('sohbet_arsiv_bilgi')), findsOneWidget);
    expect(find.textContaining('kapanacak'), findsNothing);
  });

  testWidgets('etkinlik bitmeden bant yok', (tester) async {
    final ortam = SohbetOrtami(
      simdi: _simdi,
      kanallar: [_etkinlikKanali(arsivZamani: DateTime(2026, 11, 30))],
    );
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId2),
      ortam,
    );
    expect(find.textContaining('kapanacak'), findsNothing);
  });

  testWidgets('yeni kanal: seçili kişilerle açılır', (tester) async {
    ekranBoyutu(tester, yukseklik: 1400);
    final ortam = SohbetOrtami(rol: 'admin', kanallar: const []);
    ortam.tasima.yanitlar['POST $kanallarYolu'] = (_) => _seciliKanal();
    await _ac(tester, const SohbetEkrani(), ortam);
    await tester.tap(find.text(arbMetni('sohbet_kanal_ac')));
    await tester.pumpAndSettle();
    for (final anahtar in [
      'sohbet_kitle_herkes',
      'sohbet_kitle_yonetim',
      'sohbet_kitle_etkinlik',
      'sohbet_kitle_secili',
    ]) {
      expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
    }
    await tester.enterText(find.byType(TextField), 'parça-alımı');
    await tester.tap(find.text(arbMetni('sohbet_kitle_secili')));
    await tester.pumpAndSettle();
    // Kişi seçici kendiliğinden açılır; kanalı açan (sen) seçili ve pasif.
    expect(find.text(arbMetni('sohbet_kisi_bilgi')), findsOneWidget);
    expect(find.text('Ben (sen)'), findsOneWidget);
    await tester.tap(find.text('Ayşe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 kişiyle devam et'));
    await tester.pumpAndSettle();
    expect(find.text('1 kişi seçildi'), findsOneWidget);
    final ac = find.text(arbMetni('sohbet_form_olustur'));
    await tester.ensureVisible(ac);
    await tester.pumpAndSettle();
    await tester.tap(ac);
    await tester.pumpAndSettle();
    expect(ortam.tasima.giden('POST', kanallarYolu).single.govde, {
      'name': 'parça-alımı',
      'visibility': 'selected',
      'slow_mode_seconds': 0,
      'member_user_ids': [digerId],
    });
  });

  testWidgets('yeni kanal: etkinlik seçilir, ad etkinlikten önerilir', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1400);
    final ortam = SohbetOrtami(
      rol: 'admin',
      kanallar: const [],
      etkinlikler: [etkinlikJson(baslik: 'Boğaz sabah turu', gelen: 24)],
    );
    ortam.tasima.yanitlar['POST $kanallarYolu'] = (_) => _etkinlikKanali();
    await _ac(tester, const SohbetEkrani(), ortam);
    await tester.tap(find.text(arbMetni('sohbet_kanal_ac')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_kitle_etkinlik')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('sohbet_etkinlik_nasil')), findsOneWidget);
    await tester.tap(find.text('Boğaz sabah turu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('sohbet_etkinlik_devam')));
    await tester.pumpAndSettle();
    expect(find.text('Boğaz sabah turu'), findsOneWidget);
    expect(find.text('boğaz-sabah-turu'), findsOneWidget);
    final ac = find.text(arbMetni('sohbet_form_olustur'));
    await tester.ensureVisible(ac);
    await tester.pumpAndSettle();
    await tester.tap(ac);
    await tester.pumpAndSettle();
    expect(ortam.tasima.giden('POST', kanallarYolu).single.govde, {
      'name': 'boğaz-sabah-turu',
      'visibility': 'event',
      'slow_mode_seconds': 0,
      'event_id': ornekEtkinlikId,
    });
  });

  group('etkinlik detayındaki sohbet bölümü', () {
    Widget bolum(Event etkinlik) => Scaffold(
      body: ListView(
        children: [
          EtkinlikSohbeti(etkinlik: etkinlik, baslik: const Text('başlık')),
        ],
      ),
    );

    for (final tema in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('kanal varsa kart, kişi sayısı ve okunmamış '
          '(${tema.name}, 2×)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          kanallar: [
            kanalJson(
              kanalId2,
              gorunurluk: 'event',
              etkinlik: ornekEtkinlikId,
              kisiSayisi: 24,
              okunmamis: 4,
            ),
          ],
        );
        await _ac(tester, bolum(ornekEtkinlik()), ortam, tema: tema);
        expect(find.text('başlık'), findsOneWidget);
        expect(find.text(arbMetni('sohbet_etkinlik_sohbeti')), findsOneWidget);
        expect(
          find.text('24 kişi · gelenler kendiliğinden girer'),
          findsOneWidget,
        );
        expect(find.byType(SayiRozeti), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('kanal yoksa organizatör açar; görmediğin kanal varsa '
        'hata gösterilir ve liste yenilenir', (tester) async {
      final ortam = SohbetOrtami(kanallar: const [], simdi: _simdi);
      ortam.tasima.yanitlar['POST $kanallarYolu'] = (_) =>
          const ApiProblem(type: ProblemType.eventChannelExists, status: 409);
      await _ac(tester, bolum(ornekEtkinlik(yonetebilir: true)), ortam);
      expect(find.text('başlık'), findsOneWidget);
      expect(
        find.text(arbMetni('sohbet_etkinlik_sohbeti_soru')),
        findsOneWidget,
      );
      await tester.tap(find.text(arbMetni('sohbet_etkinlik_sohbeti_ac')));
      await tester.pumpAndSettle();
      // Ad etkinlik başlığından: "Göl kampı" → "göl-kampı".
      expect(ortam.tasima.giden('POST', kanallarYolu).single.govde, {
        'name': 'göl-kampı',
        'visibility': 'event',
        'slow_mode_seconds': 0,
        'event_id': ornekEtkinlikId,
      });
      expect(find.text(arbMetni('hata_event_channel_exists')), findsOneWidget);
      expect(ortam.tasima.giden('GET', kanallarYolu), hasLength(2));
    });

    testWidgets('kanal yoksa ve yönetemiyorsan bölüm hiç görünmez', (
      tester,
    ) async {
      final ortam = SohbetOrtami(kanallar: const [], simdi: _simdi);
      await _ac(tester, bolum(ornekEtkinlik()), ortam);
      expect(find.text('başlık'), findsNothing);
      expect(find.text(arbMetni('sohbet_etkinlik_sohbeti_ac')), findsNothing);
    });

    testWidgets('bitişinin üzerinden 7 gün geçtiyse açma kartı yok', (
      tester,
    ) async {
      final ortam = SohbetOrtami(
        kanallar: const [],
        simdi: DateTime.utc(2026, 12, 1),
      );
      await _ac(tester, bolum(ornekEtkinlik(yonetebilir: true)), ortam);
      expect(find.text(arbMetni('sohbet_etkinlik_sohbeti_ac')), findsNothing);
    });
  });
}
