import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/kullanici/kimlik_avatari.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ekrani.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_formu.dart';
import 'package:tayfam/features/sohbet/sohbet.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SohbetOrtami ortam, {
  ThemeMode tema = ThemeMode.light,
}) async {
  await widgetAc(tester, ekran, themeMode: tema, tayfa: ortam.overridelar);
  await tester.pumpAndSettle();
}

void main() {
  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    group('Sohbet sekmesi (${tema.name})', () {
      testWidgets('kanallar, etiketler ve okunmamış rozeti; 2× yazı, 320 dp', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1600);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          rol: 'admin',
          kanallar: [
            kanalJson(kanalId1, ad: 'genel', okunmamis: 3),
            kanalJson(kanalId2, ad: 'yönetim', yonetim: true, okunmamis: 100),
          ],
        );
        await _ac(tester, const SohbetEkrani(), ortam, tema: tema);
        // Parça seçicide ve bölüm başlığında.
        expect(find.text(arbMetni('sohbet_sekme_kanallar')), findsNWidgets(2));
        expect(find.text(arbMetni('sohbet_sekme_birebir')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_tayfa_satiri')), findsOneWidget);
        expect(find.text('genel'), findsOneWidget);
        expect(find.text('yönetim'), findsOneWidget);
        expect(find.text(arbMetni('sohbet_kanal_yonetim')), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        // Yönetim kanalının rozeti ve Kanallar parçasının toplamı (103).
        expect(find.text(arbMetni('gezinme_rozet_cok')), findsNWidgets(2));
        expect(find.text(arbMetni('sohbet_kanal_ac')), findsOneWidget);
        // Son mesaj önizlemesi yok; yalnızca sayı.
        expect(find.byType(SohbetBalonu), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('kanal ekranı: gruplama, gün ayırıcı ve işlemler sayfası '
          '(${tema.name}, 2×)', (tester) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 1200);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          rol: 'admin',
          kanallar: [kanalJson(kanalId1, ad: 'genel')],
          mesajlar: [
            mesajJson(mesajId3, metin: 'ikinci', zaman: '2026-11-11T10:01:00Z'),
            mesajJson(
              mesajId2,
              metin: 'birinci',
              zaman: '2026-11-11T10:00:00Z',
            ),
            mesajJson(mesajId1, metin: 'dünden', zaman: '2026-11-10T09:00:00Z'),
          ],
        );
        await _ac(
          tester,
          const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
          ortam,
          tema: tema,
        );
        // İki gün, iki ayırıcı; aynı yazarın aynı gündeki iki mesajı tek
        // grup: ad grubun başında (iki grup, iki ad), avatar grubun sonunda.
        expect(find.byType(GunAyirici), findsNWidgets(2));
        expect(find.text('Ayşe'), findsNWidgets(2));
        expect(find.byType(KimlikAvatari), findsNWidgets(2));
        expect(tester.takeException(), isNull);

        await tester.longPress(find.text('ikinci'));
        await tester.pumpAndSettle();
        expect(find.text(arbMetni('sohbet_mesaj_islemleri')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_mesaji_sil')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('üye "Kanal aç" görmez; arşivdekiler açılır bölümde', (
    tester,
  ) async {
    ekranBoyutu(tester, yukseklik: 1000);
    final ortam = SohbetOrtami(
      kanallar: [
        kanalJson(kanalId1),
        kanalJson(kanalId2, ad: 'eski-konvoy', arsiv: true),
      ],
    );
    await _ac(tester, const SohbetEkrani(), ortam);
    expect(find.text(arbMetni('sohbet_kanal_ac')), findsNothing);
    expect(find.text('eski-konvoy'), findsNothing);
    final arsiv = find.textContaining('(1)');
    expect(arsiv, findsOneWidget);
    await tester.tap(arsiv);
    await tester.pumpAndSettle();
    expect(find.text('eski-konvoy'), findsOneWidget);
  });

  testWidgets('üye başkasının mesajına uzun basınca işlem sayfası açılmaz', (
    tester,
  ) async {
    final ortam = SohbetOrtami(mesajlar: [mesajJson(mesajId2, metin: 'selam')]);
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      ortam,
    );
    await tester.longPress(find.text('selam'));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('sohbet_mesaj_islemleri')), findsNothing);
  });

  testWidgets('yavaş modda gönderdikten sonra düğme geri sayıma döner', (
    tester,
  ) async {
    final ortam = SohbetOrtami(kanallar: [kanalJson(kanalId1, yavas: 30)]);
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      ortam,
    );
    expect(find.byTooltip(arbMetni('sohbet_gonder')), findsOneWidget);
    ortam
        .tasima
        .yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] = (
      _,
    ) => mesajJson(mesajId3, metin: 'merhaba', yazar: benimId);
    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.tap(find.byTooltip(arbMetni('sohbet_gonder')));
    await tester.pump();
    expect(find.byTooltip(arbMetni('sohbet_gonder')), findsNothing);
    expect(find.textContaining(' sn'), findsWidgets);
    // Ekran kapanınca sayaç durur (bekleyen zamanlayıcı kalmaz).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('okunmamışı yalnızca Birebir parçasında olan sekme Birebir '
      'açılır', (tester) async {
    final ortam = SohbetOrtami();
    await widgetAc(
      tester,
      const SohbetEkrani(),
      tayfa: [
        ...ortam.overridelar,
        birebirOkunmamisYuvasiProvider.overrideWithValue(2),
        birebirBolumuProvider.overrideWithValue(
          (context) => const Text('birebir-yuvasi'),
        ),
      ],
    );
    expect(find.text('birebir-yuvasi'), findsOneWidget);
  });

  testWidgets('iki parçada da okunmamış varsa Kanallar açılır', (tester) async {
    final ortam = SohbetOrtami(kanallar: [kanalJson(kanalId1, okunmamis: 2)]);
    await widgetAc(
      tester,
      const SohbetEkrani(),
      tayfa: [
        ...ortam.overridelar,
        birebirOkunmamisYuvasiProvider.overrideWithValue(2),
        birebirBolumuProvider.overrideWithValue(
          (context) => const Text('birebir-yuvasi'),
        ),
      ],
    );
    expect(find.text('birebir-yuvasi'), findsNothing);
    expect(find.text('genel'), findsOneWidget);
  });

  testWidgets('aktif tayfa yoksa bilgi metni', (tester) async {
    final ortam = SohbetOrtami(aktifTayfaVar: false);
    await _ac(tester, const SohbetEkrani(), ortam);
    expect(find.text(arbMetni('sohbet_tayfa_yok')), findsOneWidget);
  });

  testWidgets('kanal yoksa boş durum', (tester) async {
    final ortam = SohbetOrtami(kanallar: const []);
    await _ac(tester, const SohbetEkrani(), ortam);
    expect(find.text(arbMetni('sohbet_kanallar_bos')), findsOneWidget);
  });

  testWidgets('Birebir bölümü yuvası doldurulmadıysa bilgi metni', (
    tester,
  ) async {
    final ortam = SohbetOrtami();
    await _ac(tester, const SohbetEkrani(), ortam);
    await tester.tap(find.text(arbMetni('sohbet_sekme_birebir')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('sohbet_birebir_yakinda')), findsOneWidget);
  });

  testWidgets('Birebir bölümü kayıtla doldurulur', (tester) async {
    final ortam = SohbetOrtami();
    await widgetAc(
      tester,
      const SohbetEkrani(),
      tayfa: [
        ...ortam.overridelar,
        birebirBolumuProvider.overrideWithValue(
          (context) => const Text('birebir-yuvasi'),
        ),
      ],
    );
    await tester.tap(find.text(arbMetni('sohbet_sekme_birebir')));
    await tester.pumpAndSettle();
    expect(find.text('birebir-yuvasi'), findsOneWidget);
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('kanal ekranı: mesajlar, silinen, yavaş mod (${tema.name})', (
      tester,
    ) async {
      // 2× yazıda üç balon ve şeritler sığsın diye uzun ekran.
      ekranBoyutu(tester, genislik: 320, yukseklik: 1800);
      ikiKatYazi(tester);
      final ortam = SohbetOrtami(
        kanallar: [kanalJson(kanalId1, ad: 'genel', yavas: 30)],
        mesajlar: [
          mesajJson(mesajId1, silindi: true, zaman: '2026-11-11T10:03:00Z'),
          mesajJson(
            mesajId3,
            metin: 'benden',
            yazar: benimId,
            zaman: '2026-11-11T10:02:00Z',
          ),
          mesajJson(mesajId2, metin: 'selam tayfa'),
        ],
      );
      await _ac(
        tester,
        const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
        ortam,
        tema: tema,
      );
      expect(find.text('genel'), findsOneWidget);
      expect(find.text('selam tayfa'), findsOneWidget);
      expect(find.text('benden'), findsOneWidget);
      expect(find.text(arbMetni('sohbet_mesaj_silindi')), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byType(GunAyirici), findsOneWidget);
      expect(find.byTooltip(arbMetni('sohbet_gonder')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('arşivli kanalda yazma alanı yok', (tester) async {
    final ortam = SohbetOrtami(kanallar: [kanalJson(kanalId1, arsiv: true)]);
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      ortam,
    );
    expect(find.text(arbMetni('sohbet_arsiv_bilgi')), findsOneWidget);
    expect(find.byTooltip(arbMetni('sohbet_gonder')), findsNothing);
  });

  testWidgets('boş kanal; gönderilemeyen mesajda tekrar dene ve sil', (
    tester,
  ) async {
    final ortam = SohbetOrtami();
    ortam
        .tasima
        .yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] = (
      _,
    ) => const ApiProblem(type: ProblemType.muted, status: 403);
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      ortam,
    );
    expect(find.text(arbMetni('sohbet_kanal_bos')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'merhaba tayfa');
    await tester.tap(find.byTooltip(arbMetni('sohbet_gonder')));
    await tester.pumpAndSettle();
    expect(find.text('merhaba tayfa'), findsOneWidget);
    expect(find.text(arbMetni('sohbet_mesaj_gonderilemedi')), findsOneWidget);
    await tester.tap(find.text(arbMetni('sohbet_mesaj_sil')));
    await tester.pumpAndSettle();
    expect(find.text('merhaba tayfa'), findsNothing);
    final kap = ProviderScope.containerOf(
      tester.element(find.byType(KanalEkrani)),
    );
    expect(kap.read(cevrimdisiKuyrukProvider), isEmpty);
  });

  testWidgets('yönetim kanal formunu açar', (tester) async {
    final ortam = SohbetOrtami(rol: 'admin');
    await _ac(
      tester,
      const KanalEkrani(tayfaId: ornekTayfaId, kanalId: kanalId1),
      ortam,
    );
    await tester.tap(find.byTooltip(arbMetni('sohbet_kanal_ayarlari')));
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('sohbet_form_duzenle')), findsOneWidget);
    // Düzenlemede yalnızca bütün tayfa ile yönetim arasında geçilir.
    expect(find.text(arbMetni('sohbet_kitle_herkes')), findsOneWidget);
    expect(find.text(arbMetni('sohbet_kitle_yonetim')), findsOneWidget);
    expect(find.text(arbMetni('sohbet_kitle_etkinlik')), findsNothing);
    expect(find.text(arbMetni('sohbet_kitle_secili')), findsNothing);
    expect(find.text(arbMetni('sohbet_form_yavas_aciklama')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(yavasModSecenekleri.length));
    expect(find.text(arbMetni('sohbet_arsivle')), findsOneWidget);
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('yeni kanal formu taşmıyor (${tema.name}, 2×)', (tester) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final ortam = SohbetOrtami(rol: 'admin');
      await _ac(tester, const SohbetEkrani(), ortam, tema: tema);
      final kanalAc = find.text(arbMetni('sohbet_kanal_ac'));
      await tester.ensureVisible(kanalAc);
      await tester.pumpAndSettle();
      await tester.tap(kanalAc);
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('sohbet_form_yeni')), findsOneWidget);
      expect(find.text(arbMetni('sohbet_form_olustur')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
