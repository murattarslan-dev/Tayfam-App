import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/features/sohbet/presentation/kanal_ekrani.dart';
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
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final ortam = SohbetOrtami(
          rol: 'admin',
          kanallar: [
            kanalJson(kanalId1, ad: 'genel', okunmamis: 3),
            kanalJson(kanalId2, ad: 'yönetim', yonetim: true, okunmamis: 100),
          ],
        );
        await _ac(tester, const SohbetEkrani(), ortam, tema: tema);
        expect(find.text(arbMetni('sohbet_sekme_kanallar')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_sekme_birebir')), findsOneWidget);
        expect(find.text('genel'), findsOneWidget);
        expect(find.text('yönetim'), findsOneWidget);
        expect(find.text(arbMetni('sohbet_kanal_yonetim')), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(find.text(arbMetni('gezinme_rozet_cok')), findsOneWidget);
        expect(find.text(arbMetni('sohbet_kanal_ac')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('üye "Kanal aç" görmez; arşivli kanal etiketli', (tester) async {
    final ortam = SohbetOrtami(
      kanallar: [kanalJson(kanalId1), kanalJson(kanalId2, arsiv: true)],
    );
    await _ac(tester, const SohbetEkrani(), ortam);
    expect(find.text(arbMetni('sohbet_kanal_ac')), findsNothing);
    expect(find.text(arbMetni('sohbet_kanal_arsivde')), findsOneWidget);
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
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      final ortam = SohbetOrtami(
        kanallar: [kanalJson(kanalId1, ad: 'genel', yavas: 30)],
        mesajlar: [
          mesajJson(mesajId3, metin: 'benden', yazar: benimId),
          mesajJson(mesajId2, metin: 'selam tayfa'),
          mesajJson(mesajId1, silindi: true),
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
    ortam.tasima.yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] =
        (_) => const ApiProblem(type: ProblemType.muted, status: 403);
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
    expect(find.text(arbMetni('sohbet_form_yonetim')), findsOneWidget);
    expect(find.text(arbMetni('sohbet_arsivle')), findsOneWidget);
  });
}
