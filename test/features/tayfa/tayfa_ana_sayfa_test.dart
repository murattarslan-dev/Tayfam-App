import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tema_baglami.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

final Finder _tayfaAdiDugmesi = find
    .descendant(
      of: find.byType(TayfaUstBolumu),
      matching: find.byType(TextButton),
    )
    .first;

/// `GET /v1/tayfas/{tayfa_id}` yanıtı verilen tayfa override'ları.
List<Override> _gorunum(
  Object? Function(TayfaIstegi istek) yanit, {
  SahtePaylasici? paylasici,
}) => tayfaOverridelari(
  tasima: SahteTayfaTasima({'GET /v1/tayfas/{tayfa_id}': yanit}),
  paylasici: paylasici,
);

Future<void> _ac(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override>? tayfa,
  List<Override> overrides = const [],
}) => widgetAc(
  tester,
  const TayfaAnaSayfa(tayfaId: ornekTayfaId),
  themeMode: themeMode,
  tayfa: tayfa,
  overrides: overrides,
);

void main() {
  testWidgets('tayfa sunucudan tazeleniyor: ad ve üye sayısı', (tester) async {
    ekranBoyutu(tester);
    await _ac(
      tester,
      tayfa: _gorunum((_) => gorunumJson(ornekTayfaId, uyeSayisi: 142)),
    );

    expect(find.text('Klasikçiler'), findsOneWidget);
    expect(find.text('142 üye'), findsOneWidget);
    expect(find.text(arbMetni('tayfa_ana_sayfa_bos')), findsOneWidget);
    // Kod yalnızca yöneticiye döner; dönmediyse paylaşım düğmesi yok.
    expect(find.text(arbMetni('tayfa_kodu_paylas')), findsNothing);
  });

  testWidgets('ad bilinmiyorken genel başlık gösteriliyor', (tester) async {
    ekranBoyutu(tester);
    await _ac(tester, tayfa: _gorunum((_) => const ApiOffline()));

    expect(find.text(arbMetni('tayfa_adi_bilinmiyor')), findsOneWidget);
  });

  group('durum şeridi', () {
    final durumlar = <String, Map<String, Object?>>{
      'tayfa_durum_uyari': gorunumJson(ornekTayfaId, durum: 'warned'),
      'tayfa_durum_arsiv': gorunumJson(ornekTayfaId, durum: 'archived'),
      'tayfa_durum_askida': gorunumJson(
        ornekTayfaId,
        askida: '2026-11-01T09:00:00Z',
      ),
    };
    for (final MapEntry(key: anahtar, value: yanit) in durumlar.entries) {
      testWidgets(anahtar, (tester) async {
        ekranBoyutu(tester);
        await _ac(tester, tayfa: _gorunum((_) => yanit));

        expect(find.byType(TayfaDurumSeridi), findsOneWidget);
        expect(find.text(arbMetni(anahtar)), findsOneWidget);
      });
    }

    testWidgets('silinme zamanı yerel saatle', (tester) async {
      ekranBoyutu(tester);
      final zaman = DateTime.utc(2026, 12, 1, 9);
      await _ac(
        tester,
        tayfa: _gorunum(
          (_) => gorunumJson(ornekTayfaId, silinme: zaman.toIso8601String()),
        ),
      );

      final yerel = zaman.toLocal();
      final saat =
          '${yerel.hour.toString().padLeft(2, '0')}:'
          '${yerel.minute.toString().padLeft(2, '0')}';
      final seritMetni = tester
          .widget<Text>(
            find.descendant(
              of: find.byType(TayfaDurumSeridi),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(seritMetni, contains('${yerel.year}'));
      expect(seritMetni, contains(saat));
    });

    testWidgets('olağan tayfada şerit yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester);

      expect(find.byType(TayfaDurumSeridi), findsNothing);
    });
  });

  group('kod paylaşımı (ADR-0014 §5)', () {
    testWidgets('kod dönünce paylaş ve kopyala görünüyor', (tester) async {
      ekranBoyutu(tester);
      final paylasici = SahtePaylasici();
      await _ac(
        tester,
        tayfa: _gorunum(
          (_) => gorunumJson(ornekTayfaId, rol: 'admin', kod: sahteKod),
          paylasici: paylasici,
        ),
      );

      final ust = find.byType(TayfaUstBolumu);
      await tester.tap(
        find.descendant(
          of: ust,
          matching: find.text(arbMetni('tayfa_kodu_paylas')),
        ),
      );
      await tester.pump();
      expect(paylasici.paylasilan, hasLength(1));
      expect(paylasici.paylasilan.single, contains('Klasikçiler'));
      expect(paylasici.paylasilan.single, contains(sahteKod));
      expect(paylasici.paylasilan.single, contains('https://tayfam.app'));

      await tester.tap(
        find.descendant(
          of: ust,
          matching: find.text(arbMetni('tayfa_kodu_kopyala')),
        ),
      );
      await tester.pump();
      expect(paylasici.kopyalanan, [sahteKod]);
      expect(find.text(arbMetni('tayfa_kod_kopyalandi')), findsOneWidget);
    });

    testWidgets('davet kısayolu yeni tayfada görünüyor ve kapanıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        tayfa: _gorunum(
          (_) => gorunumJson(ornekTayfaId, rol: 'admin', kod: sahteKod),
        ),
      );
      expect(find.byType(DavetKisayolu), findsNothing);

      tester
          .container()
          .read(davetKisayoluProvider.notifier)
          .goster(ornekTayfaId);
      await tester.pumpAndSettle();

      expect(find.byType(DavetKisayolu), findsOneWidget);
      expect(find.text(arbMetni('tayfa_davet_baslik')), findsOneWidget);
      expect(find.text('Tayfa kodu: $sahteKod'), findsOneWidget);

      await tester.tap(find.byTooltip(arbMetni('tayfa_davet_kapat')));
      await tester.pumpAndSettle();
      expect(find.byType(DavetKisayolu), findsNothing);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    final r = mod == ThemeMode.dark ? TayfamColors.koyu : TayfamColors.acik;

    testWidgets('${mod.name}: üst bölüm brand zemin, beyaz ad', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, themeMode: mod);

      // Mor yüzey ortak bileşenle çizilir; iki temada da brand (§2a).
      expect(
        find.descendant(
          of: find.byType(TayfaUstBolumu),
          matching: find.byType(MarkaYuzeyi),
        ),
        findsOneWidget,
      );
      final zemin = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(TayfaUstBolumu),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(zemin.color, r.markaYuzey);

      final ad = tester.widget<RichText>(
        find.descendant(
          of: find.text('Klasikçiler'),
          matching: find.byType(RichText),
        ),
      );
      expect(ad.text.style?.color, r.markaYuzeyUstu);
    });

    testWidgets('${mod.name}: tayfa adında mango odak çerçevesi', (
      tester,
    ) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic;
      });
      ekranBoyutu(tester);
      await _ac(tester, themeMode: mod);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final cerceve = find.descendant(
        of: find.byType(TayfaUstBolumu),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is OdakBoyaci,
        ),
      );
      expect(cerceve, findsOneWidget);
      final boya = tester.widget<CustomPaint>(cerceve);
      final boyaci = boya.foregroundPainter! as OdakBoyaci;
      // Mor yüzeyde iki temada da mango (ADR-0004 Notlar, 2026-11-10).
      expect(boyaci.renk, r.mango);
      expect(boyaci.kalinlik, 3);
    });

    testWidgets('${mod.name}: panel mor yüzeyin odak rengini almıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(tester, themeMode: mod);

      await tester.tap(_tayfaAdiDugmesi);
      await tester.pumpAndSettle();

      final panel = tester.element(find.byType(TayfaDegistirmePaneli));
      expect(panel.renkler.odak, r.odak);
    });
  }

  testWidgets('tayfa adına dokununca değiştirme paneli açılıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await _ac(tester);

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();

    expect(find.byType(TayfaDegistirmePaneli), findsOneWidget);
    expect(find.text(arbMetni('tayfa_tayfalarim')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_tayfalarim_bos')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_kodla_katil')), findsOneWidget);
    expect(find.text(arbMetni('tayfa_olustur')), findsOneWidget);
  });

  testWidgets('paneldeki "Tayfa kodum var" katılım sayfasını açıyor', (
    tester,
  ) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('tayfa_kodla_katil')));
    await tester.pumpAndSettle();

    expect(find.byType(TayfaDegistirmePaneli), findsNothing);
    // Katılım alttan açılan bir sayfadır.
    expect(find.text(arbMetni('katilim_baslik')), findsOneWidget);

    // Geri dönünce tayfanın ana sayfası yerinde.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(arbMetni('katilim_baslik')), findsNothing);
    expect(find.byType(TayfaAnaSayfa), findsOneWidget);
  });

  testWidgets('paneldeki "Tayfa oluştur" sihirbazı açıyor', (tester) async {
    ekranBoyutu(tester);
    await uygulamayiAc(tester);
    tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
    await tester.pumpAndSettle();

    await tester.tap(_tayfaAdiDugmesi);
    await tester.pumpAndSettle();
    await tester.tap(find.text(arbMetni('tayfa_olustur')));
    await tester.pumpAndSettle();

    expect(find.byType(OlusturmaEkrani), findsOneWidget);
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('${mod.name} temada 2× yazıda sayfa ve panel taşmıyor', (
      tester,
    ) async {
      ekranBoyutu(tester, genislik: 320);
      ikiKatYazi(tester);
      await _ac(
        tester,
        themeMode: mod,
        tayfa: _gorunum(
          (_) => gorunumJson(
            ornekTayfaId,
            ad: 'Çok uzun adlı bir klasik otomobil tayfası',
            rol: 'admin',
            kod: sahteKod,
            silinme: '2026-12-01T09:00:00Z',
            uyeSayisi: 1250,
          ),
        ),
      );
      tester
          .container()
          .read(davetKisayoluProvider.notifier)
          .goster(ornekTayfaId);
      await tester.pumpAndSettle();
      expect(find.byType(TayfaDurumSeridi), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Üst bölüm içerikle birlikte kayar; kısayola kaydırılarak ulaşılır.
      await tester.dragUntilVisible(
        find.byType(DavetKisayolu),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.byType(DavetKisayolu), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.dragUntilVisible(
        find.byType(TayfaUstBolumu),
        find.byType(ListView),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      await tester.tap(_tayfaAdiDugmesi);
      await tester.pumpAndSettle();
      expect(find.byType(TayfaDegistirmePaneli), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
