import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/tema/tema.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_ekrani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_uyarici.dart';

import '../../../core/katalog/sahte_katalog.dart';
import '../../../core/zaman_sahteleri.dart';
import '../../../yardimcilar.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const KronometreTanimi _geriSayim = KronometreTanimi(
  mod: KronometreModu.geriSayim,
  onAyarlar: [60, 90],
);

const KronometreTanimi _satranc = KronometreTanimi(
  mod: KronometreModu.satrancSaati,
  onAyarlar: [300],
);

/// Süre dolunca yapılan uyarıları ve ekran kilidi isteklerini sayar.
final class _SahteUyarici implements KronometreUyarici {
  int uyari = 0;
  final List<bool> ekran = [];

  @override
  Future<void> uyar() async {
    uyari++;
  }

  @override
  Future<void> ekraniAcikTut({required bool acik}) async {
    ekran.add(acik);
  }
}

/// Elle ilerletilen saat, sahte zamanlayıcı ve sahte uyarıcı.
final class _Saat {
  DateTime simdi = DateTime.utc(2026, 11, 20, 12);
  final SahteZamanlayici zaman = SahteZamanlayici();
  final _SahteUyarici uyarici = _SahteUyarici();

  void ilerle(Duration sure) => simdi = simdi.add(sure);

  /// Saati ilerletir ve kurulan zamanlayıcıları çalıştırır.
  void ilerleVeCalistir(Duration sure) {
    ilerle(sure);
    zaman.calistir();
  }

  List<Override> get overrides => [
    simdiProvider.overrideWithValue(() => simdi),
    zamanlayiciProvider.overrideWithValue(zaman.kur),
    kronometreUyariciProvider.overrideWithValue(uyarici),
  ];
}

/// Bellekteki kronometre (ekran olmadan).
final class _Kurulum {
  _Kurulum(KronometreModu mod, {Duration sure = const Duration(minutes: 1)})
    : ayar = (mod: mod, ilkSure: sure) {
    c = ProviderContainer(overrides: saat.overrides);
    addTearDown(c.dispose);
    c.listen(kronometreProvider(ayar), (_, _) {});
  }

  final _Saat saat = _Saat();
  final KronometreAyari ayar;
  late final ProviderContainer c;

  KronometreDurumu get d => c.read(kronometreProvider(ayar));
  KronometreNotifier get n => c.read(kronometreProvider(ayar).notifier);
}

Finder _rakam(String metin) => find.descendant(
  of: find.byKey(const ValueKey('kronometre-rakamlar')),
  matching: find.text(metin),
);

Finder _tarafta(int taraf, String metin) => find.descendant(
  of: find.byKey(ValueKey('kronometre-taraf-$taraf')),
  matching: find.text(metin),
);

Future<void> _dokun(WidgetTester tester, Finder bulucu) async {
  await tester.ensureVisible(bulucu);
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

void main() {
  group('tanım', () {
    test('mod ve ön ayarlar okunur; geçersiz ön ayar atlanır', () {
      final t = KronometreTanimi.oku(
        const BilesenParametreleri({
          'mode': 'chess_clock',
          'presets': [0, 60, 60, 90, 86401, 'x'],
        }),
      );
      expect(t.mod, KronometreModu.satrancSaati);
      expect(t.onAyarlar, [60, 90]);
      expect(t.ilkSure, const Duration(seconds: 60));
    });

    test('mod yoksa ya da tanınmıyorsa geri sayım; ön ayar yoksa 5 dk', () {
      final yok = KronometreTanimi.oku(const BilesenParametreleri(null));
      expect(yok.mod, KronometreModu.geriSayim);
      expect(yok.ilkSure, kronometreVarsayilanSure);
      final bilinmeyen = KronometreTanimi.oku(
        const BilesenParametreleri({'mode': 'sync'}),
      );
      expect(bilinmeyen.mod, KronometreModu.geriSayim);
    });

    test('organizatörün seçimi okunur', () {
      final t = KronometreTanimi.oku(
        const BilesenParametreleri(
          {
            'mode': {
              'organizer_choice': ['countdown', 'stopwatch'],
              'default': 'countdown',
            },
          },
          {'mode': 'stopwatch'},
        ),
      );
      expect(t.mod, KronometreModu.ileriSayim);
    });

    test('katalog fikstüründeki kelime tahmin oyunu', () {
      final bilesen = turBilesenleri(testTuru('word_guess')).single;
      expect(bilesen.kind, 'timer');
      final t = KronometreTanimi.oku(BilesenParametreleri(bilesen.params));
      expect(t.mod, KronometreModu.geriSayim);
      expect(t.onAyarlar, [60, 90, 120]);
    });
  });

  group('elle süre', () {
    test('okunan biçimler', () {
      expect(kronometreSuresiniOku('90'), const Duration(seconds: 90));
      expect(kronometreSuresiniOku(' 1:30 '), const Duration(seconds: 90));
      expect(
        kronometreSuresiniOku('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
      expect(kronometreSuresiniOku('24:00:00'), const Duration(hours: 24));
    });

    test('okunamayanlar', () {
      for (final metin in [
        '',
        '0',
        '0:00',
        '1:60',
        '1::0',
        'a',
        '1:2:3:4',
        '24:00:01',
        '123456',
      ]) {
        expect(kronometreSuresiniOku(metin), isNull, reason: metin);
      }
    });
  });

  group('geri sayım (sahte saat)', () {
    test('süre başlangıç anından hesaplanır, saniye yukarı yuvarlanır', () {
      final k = _Kurulum(KronometreModu.geriSayim);
      expect(k.d.gosterilenSaniye(), 60);
      expect(k.d.baslatildi, isFalse);
      k.n.baslat();
      expect(k.d.calisiyor, isTrue);
      expect(k.d.sonrakiDegisim, const Duration(seconds: 1));
      k.saat.ilerleVeCalistir(const Duration(milliseconds: 29500));
      expect(k.d.gosterilenSaniye(), 31);
      expect(k.d.sonrakiDegisim, const Duration(milliseconds: 500));
      // Zamanlayıcı hiç çalışmasa da (ekran kapalı, arka plan) değer
      // saatten doğru hesaplanır.
      k.saat.ilerle(const Duration(seconds: 20));
      k.n.yenile();
      expect(k.d.gosterilenSaniye(), 11);
    });

    test('süre dolunca bir kez uyarır ve durur', () {
      final k = _Kurulum(KronometreModu.geriSayim);
      k.n.baslat();
      k.saat.ilerleVeCalistir(const Duration(seconds: 59));
      expect(k.d.bitti, isFalse);
      expect(k.saat.uyarici.uyari, 0);
      k.saat.ilerleVeCalistir(const Duration(seconds: 1));
      expect(k.d.bitti, isTrue);
      expect(k.d.calisiyor, isFalse);
      expect(k.d.gosterilenSaniye(), 0);
      expect(k.saat.uyarici.uyari, 1);
      expect(k.saat.zaman.etkin, isEmpty);
      k.saat.ilerle(const Duration(seconds: 5));
      k.n
        ..yenile()
        ..baslat();
      expect(k.saat.uyarici.uyari, 1);
      expect(k.d.calisiyor, isFalse);
    });

    test('arka plandayken dolan süre öne gelince bir kez uyarır', () {
      final k = _Kurulum(KronometreModu.geriSayim);
      k.n.baslat();
      k.saat.ilerle(const Duration(minutes: 10));
      k.n.yenile();
      expect(k.d.bitti, isTrue);
      expect(k.d.kalan(), Duration.zero);
      expect(k.saat.uyarici.uyari, 1);
    });

    test('duraklat, sürdür ve sıfırla; süre yalnızca başlamadan seçilir', () {
      final k = _Kurulum(KronometreModu.geriSayim);
      k.n.sureSec(const Duration(seconds: 90));
      expect(k.d.gosterilenSaniye(), 90);
      k.n.baslat();
      k.saat.ilerleVeCalistir(const Duration(seconds: 10));
      k.n.duraklat();
      expect(k.d.duraklatildi, isTrue);
      expect(k.saat.zaman.etkin, isEmpty);
      k.saat.ilerle(const Duration(minutes: 5));
      expect(k.d.gosterilenSaniye(), 80);
      k.n.sureSec(const Duration(seconds: 30));
      expect(k.d.sure, const Duration(seconds: 90));
      k.n.baslat();
      k.saat.ilerleVeCalistir(const Duration(seconds: 5));
      expect(k.d.gosterilenSaniye(), 75);
      k.n.sifirla();
      expect(k.d.baslatildi, isFalse);
      expect(k.d.gosterilenSaniye(), 90);
      expect(k.saat.zaman.etkin, isEmpty);
    });

    test('sınır dışındaki süre seçilmez', () {
      final k = _Kurulum(KronometreModu.geriSayim);
      k.n
        ..sureSec(Duration.zero)
        ..sureSec(const Duration(seconds: kronometreSureEnCok + 1));
      expect(k.d.sure, const Duration(minutes: 1));
    });
  });

  group('ileri sayım (sahte saat)', () {
    test('geçen süre aşağı yuvarlanır; duraklatınca saymaz; bitmez', () {
      final k = _Kurulum(KronometreModu.ileriSayim);
      expect(k.d.gosterilenSaniye(), 0);
      k.n.baslat();
      k.saat.ilerleVeCalistir(const Duration(milliseconds: 5400));
      expect(k.d.gosterilenSaniye(), 5);
      expect(k.d.sonrakiDegisim, const Duration(milliseconds: 600));
      k.n.duraklat();
      k.saat.ilerle(const Duration(minutes: 3));
      expect(k.d.gosterilenSaniye(), 5);
      k.n.baslat();
      k.saat.ilerleVeCalistir(const Duration(hours: 2));
      expect(k.d.gosterilenSaniye(), 2 * 3600 + 5);
      expect(k.d.bitti, isFalse);
      expect(k.saat.uyarici.uyari, 0);
    });
  });

  group('satranç saati (sahte saat)', () {
    test('dokunan oyuncunun saati durur, rakibinki işler', () {
      final k = _Kurulum(
        KronometreModu.satrancSaati,
        sure: const Duration(minutes: 5),
      );
      expect(k.d.sayaclar, hasLength(2));
      // Alttaki oyuncu başlatır: üstteki oyuncunun saati işler.
      k.n.hamle(1);
      expect(k.d.sira, 0);
      k.saat.ilerleVeCalistir(const Duration(seconds: 10));
      // Sırası olmayan oyuncunun dokunuşu yok sayılır.
      k.n.hamle(1);
      expect(k.d.sira, 0);
      k.n.hamle(0);
      expect(k.d.sira, 1);
      k.saat.ilerleVeCalistir(const Duration(seconds: 3));
      expect(k.d.gosterilenSaniye(0), 290);
      expect(k.d.gosterilenSaniye(1), 297);
      // Duraklatılmış saatte dokunuş yok sayılır; sürdürünce sıra korunur.
      k.n.duraklat();
      k.n.hamle(1);
      expect(k.d.sira, 1);
      k.saat.ilerle(const Duration(minutes: 1));
      k.n.baslat();
      expect(k.d.sira, 1);
      expect(k.d.gosterilenSaniye(1), 297);
    });

    test('süresi dolan oyuncu bulunur ve bir kez uyarılır', () {
      final k = _Kurulum(
        KronometreModu.satrancSaati,
        sure: const Duration(seconds: 30),
      );
      k.n.hamle(0);
      k.saat.ilerleVeCalistir(const Duration(seconds: 30));
      expect(k.d.bitti, isTrue);
      expect(k.d.bitenTaraf, 1);
      expect(k.d.gosterilenSaniye(0), 30);
      expect(k.saat.uyarici.uyari, 1);
      k.n.hamle(1);
      expect(k.d.calisiyor, isFalse);
      k.n.sifirla();
      expect(k.d.bitti, isFalse);
      expect(k.d.sira, isNull);
      expect(k.d.gosterilenSaniye(1), 30);
    });
  });

  group('ekran', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name}: geri sayım (2× yazı, 320 dp) ön ayar, '
          'başlat, süre dolunca duyuru', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final s = _Saat();
        final semantik = tester.ensureSemantics();
        await widgetAc(
          tester,
          const KronometreEkrani(baslik: 'Kelime tahmin', tanim: _geriSayim),
          themeMode: tema,
          overrides: s.overrides,
        );
        expect(s.uyarici.ekran, [true]);
        expect(_rakam('1:00'), findsOneWidget);
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('kronometre-rakamlar')),
          ),
          containsSemantics(label: 'Kalan süre: 1 dakika', isLiveRegion: false),
        );

        await _dokun(tester, find.widgetWithText(ChoiceChip, '1:30'));
        expect(_rakam('1:30'), findsOneWidget);

        await _dokun(tester, find.text('Başlat'));
        expect(find.text('Duraklat'), findsOneWidget);
        expect(find.byType(ChoiceChip), findsNothing);
        s.ilerleVeCalistir(const Duration(milliseconds: 500));
        await tester.pump();
        expect(_rakam('1:30'), findsOneWidget);
        s.ilerleVeCalistir(const Duration(milliseconds: 500));
        await tester.pump();
        expect(_rakam('1:29'), findsOneWidget);
        expect(find.text('Süre doldu.'), findsNothing);

        s.ilerleVeCalistir(const Duration(seconds: 89));
        await tester.pump();
        expect(_rakam('0:00'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Süre doldu.')),
          containsSemantics(label: 'Süre doldu.', isLiveRegion: true),
        );
        expect(s.uyarici.uyari, 1);
        expect(find.text('Başlat'), findsNothing);
        expect(find.text('Sıfırla'), findsOneWidget);

        await _dokun(tester, find.text('Sıfırla'));
        expect(_rakam('1:30'), findsOneWidget);
        expect(find.text('Süre doldu.'), findsNothing);

        // Ekrandan çıkınca ekran kilidi bırakılır.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(s.uyarici.ekran, [true, false]);
        semantik.dispose();
      });

      testWidgets('${tema.name}: satranç saati (2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final s = _Saat();
        final semantik = tester.ensureSemantics();
        await widgetAc(
          tester,
          const KronometreEkrani(baslik: 'Satranç', tanim: _satranc),
          themeMode: tema,
          overrides: s.overrides,
        );
        expect(_tarafta(0, '5:00'), findsOneWidget);
        expect(_tarafta(1, '5:00'), findsOneWidget);
        expect(
          find.text('Hamleni bitirince kendi tarafına dokun.'),
          findsNWidgets(2),
        );
        // Üstteki alan ters döner.
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('kronometre-taraf-0')),
            matching: find.byType(RotatedBox),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('kronometre-taraf-1')));
        await tester.pump();
        expect(_tarafta(0, 'Sıra sende'), findsOneWidget);
        s.ilerleVeCalistir(const Duration(seconds: 2));
        await tester.pump();
        expect(_tarafta(0, '4:58'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('kronometre-taraf-0'))),
          containsSemantics(
            label: 'Üstteki oyuncu, kalan süre 4 dakika 58 saniye',
            value: 'Sıra sende',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            hasTapAction: true,
          ),
        );

        // Sırası olmayan alana dokunmak bir şey değiştirmez.
        await tester.tap(find.byKey(const ValueKey('kronometre-taraf-1')));
        await tester.pump();
        expect(_tarafta(0, 'Sıra sende'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('kronometre-taraf-0')));
        await tester.pump();
        expect(_tarafta(1, 'Sıra sende'), findsOneWidget);
        await tester.pumpAndSettle();
        semantik.dispose();
      });
    }

    testWidgets('elle süre: geçersizse hata, geçerliyse seçilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final s = _Saat();
      await widgetAc(
        tester,
        const KronometreEkrani(baslik: 'Kelime tahmin', tanim: _geriSayim),
        overrides: s.overrides,
      );
      await _dokun(tester, find.text('Süreyi elle gir'));
      final alan = find.byKey(const ValueKey('kronometre-sure'));
      await tester.enterText(alan, '1:75');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Süreyi 1:30 ya da 90 gibi yaz; 1 saniye ile 24 saat arasında olsun.',
        ),
        findsOneWidget,
      );
      await tester.enterText(alan, '2:15');
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(alan, findsNothing);
      expect(_rakam('2:15'), findsOneWidget);
      final cip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '2:15'),
      );
      expect(cip.selected, isTrue);
    });

    group('hareket', () {
      Future<Duration> gecisSuresi(WidgetTester tester) async {
        ekranBoyutu(tester);
        await widgetAc(
          tester,
          const KronometreEkrani(baslik: 'Satranç', tanim: _satranc),
          overrides: _Saat().overrides,
        );
        return tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byKey(const ValueKey('kronometre-taraf-1')),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .duration;
      }

      testWidgets('sıra geçişi kısa bir renk geçişidir', (tester) async {
        expect(await gecisSuresi(tester), TayfamMotion.kisa);
      });

      testWidgets('"hareketi azalt" açıkken geçiş yok', (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        expect(await gecisSuresi(tester), Duration.zero);
      });
    });
  });

  group('bileşen', () {
    for (final tema in _temalar) {
      testWidgets('${tema.name}: detaydaki giriş kartı kronometreyi tam '
          'ekran açar (2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final bilesen = turBilesenleri(testTuru('word_guess')).single;
        final bolum = const KronometreBileseni().detayBolumu(
          BilesenBaglami(tanim: bilesen, rol: BilesenRolu.uye),
        )!;
        await widgetAc(
          tester,
          Scaffold(body: SingleChildScrollView(child: bolum)),
          themeMode: tema,
          overrides: _Saat().overrides,
        );
        expect(find.text('Kronometre'), findsOneWidget);
        expect(find.text('Geri sayım'), findsOneWidget);
        await _dokun(tester, find.byKey(const ValueKey('kronometre-giris')));
        expect(find.byType(KronometreEkrani), findsOneWidget);
        expect(_rakam('1:00'), findsOneWidget);
      });
    }

    testWidgets('organizatöre bırakılan mod sihirbazda seçilir', (
      tester,
    ) async {
      final bilesen = turBilesenleri(testTuru('ornek_bilesenler'))
          .firstWhere((b) => b.kind == 'timer');
      (String, String)? secilen;
      final form = const KronometreBileseni().formBolumu(
        BilesenBaglami(
          tanim: bilesen,
          rol: BilesenRolu.organizator,
          secimler: const {'mode': 'countdown'},
          form: BilesenFormu(onSecim: (p, d) => secilen = (p, d)),
        ),
      )!;
      await widgetAc(tester, Scaffold(body: form));
      expect(find.text('Kronometre nasıl çalışsın?'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Geri sayım'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'İleri sayım'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Satranç saati'));
      await tester.pump();
      expect(secilen, ('mode', 'chess_clock'));
    });
  });
}
