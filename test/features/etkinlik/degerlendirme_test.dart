import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/degerlendirme/degerlendirme_deposu.dart';
import 'package:tayfam/core/degerlendirme/magaza_degerlendirmesi.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/etkinlik/application/degerlendirme_istegi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/etkinlik/presentation/degerlendirme_firsati.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';

import '../../yardimcilar.dart';
import 'sahteler.dart';

/// Bitmiş (iki gün önce başlamış, üç saat sürmüş) etkinlik.
Event _bitmis({String? cevap = 'going', bool iptal = false}) => Event.fromJson(
  etkinlikJson(
    baslangic: gecmisBaslangic,
    sure: const Duration(hours: 3),
    cevap: cevap,
    iptal: iptal,
  ),
);

/// Bitmemiş (yaklaşan) etkinlik.
Event _yaklasan({String? cevap = 'going'}) =>
    Event.fromJson(etkinlikJson(cevap: cevap));

/// Sayfanın yerini tutan metin.
const String _sayfa = 'sayfa';

/// Bekleme süresinden biraz fazlası.
const Duration _bekle = Duration(seconds: 3);

ProviderContainer _kap(
  DegerlendirmeDeposu depo,
  MagazaDegerlendirmesi magaza, [
  List<Override> ek = const [],
]) {
  final kap = ProviderContainer(
    overrides: [
      degerlendirmeDeposuProvider.overrideWithValue(depo),
      magazaDegerlendirmesiProvider.overrideWithValue(magaza),
      etkinlikSaatiProvider.overrideWithValue(() => sabitSimdi),
      ...ek,
    ],
  );
  addTearDown(kap.dispose);
  return kap;
}

List<Override> _overridelar(
  DegerlendirmeDeposu depo,
  MagazaDegerlendirmesi magaza,
) => [
  degerlendirmeDeposuProvider.overrideWithValue(depo),
  magazaDegerlendirmesiProvider.overrideWithValue(magaza),
  etkinlikSaatiProvider.overrideWithValue(() => sabitSimdi),
];

void main() {
  group('tetik koşulu', () {
    test('"Geliyorum" denmiş ve bitmiş etkinlik tamamlanmıştır', () {
      expect(etkinlikTamamlandi(_bitmis(), sabitSimdi), isTrue);
    });

    test('bitiş anında tamamlanmış sayılır', () {
      final etkinlik = _bitmis();
      expect(etkinlikTamamlandi(etkinlik, etkinlik.endsAt), isTrue);
      expect(
        etkinlikTamamlandi(
          etkinlik,
          etkinlik.endsAt.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
    });

    test('bitmemiş etkinlik tamamlanmamıştır', () {
      expect(etkinlikTamamlandi(_yaklasan(), sabitSimdi), isFalse);
    });

    test('cevabı "Geliyorum" olmayan etkinlik sayılmaz', () {
      for (final cevap in [null, 'maybe', 'not_going', 'waitlist']) {
        expect(
          etkinlikTamamlandi(_bitmis(cevap: cevap), sabitSimdi),
          isFalse,
          reason: '$cevap',
        );
      }
    });

    test('iptal edilen etkinlik sayılmaz', () {
      expect(etkinlikTamamlandi(_bitmis(iptal: true), sabitSimdi), isFalse);
    });

    test('doğrulanmış katılım aranmaz; organizatör de sayılır', () {
      final organizator = Event.fromJson(
        etkinlikJson(
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
          cevap: 'going',
          yonetebilir: true,
        ),
      );
      expect(organizator.callerAttendance, isNull);
      expect(etkinlikTamamlandi(organizator, sabitSimdi), isTrue);
    });
  });

  group('DegerlendirmeNotifier', () {
    test('tamamlanmış etkinlik yoksa aday değildir', () async {
      final magaza = SahteMagazaDegerlendirmesi();
      final kap = _kap(BellekDegerlendirmeDeposu(), magaza);
      final notifier = kap.read(degerlendirmeProvider.notifier);

      expect(
        await notifier.adayMi([_yaklasan(), _bitmis(cevap: 'maybe')]),
        isFalse,
      );
      expect(await notifier.adayMi(const []), isFalse);
    });

    test('bir kez: bayrak yazılır, ikinci kez istenmez', () async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi();
      final kap = _kap(depo, magaza);
      final notifier = kap.read(degerlendirmeProvider.notifier);

      expect(await notifier.adayMi([_yaklasan(), _bitmis()]), isTrue);
      await notifier.iste();
      expect(magaza.istek, 1);
      expect(depo.istendi, isTrue);

      expect(await notifier.adayMi([_bitmis()]), isFalse);
      await notifier.iste();
      expect(magaza.istek, 1);
    });

    test('bayrak varsa (uygulama yeniden açıldı) istenmez', () async {
      final depo = BellekDegerlendirmeDeposu(true);
      final magaza = SahteMagazaDegerlendirmesi();
      final kap = _kap(depo, magaza);

      expect(
        await kap.read(degerlendirmeProvider.notifier).adayMi([_bitmis()]),
        isFalse,
      );
      expect(kap.read(degerlendirmeProvider), isTrue);
      expect(magaza.istek, 0);
    });

    test('bayrak oturum kapanınca silinmez', () async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi();
      final kap = _kap(depo, magaza, [
        oturumDurumuProvider.overrideWith(
          () => SabitOturumDurumu(OturumDurumu.acik),
        ),
      ]);
      final notifier = kap.read(degerlendirmeProvider.notifier);
      await notifier.iste();

      kap.read(oturumDurumuProvider.notifier).ayarla(OturumDurumu.girisYok);
      await Future<void>.delayed(Duration.zero);

      expect(depo.istendi, isTrue);
      expect(kap.read(degerlendirmeProvider), isTrue);

      // Aynı cihazda başka bir oturum (yeni süreç): bayrak hâlâ orada.
      final yeni = _kap(depo, magaza);
      expect(
        await yeni.read(degerlendirmeProvider.notifier).adayMi([_bitmis()]),
        isFalse,
      );
      expect(magaza.istek, 1);
    });

    test('mağaza kullanılamıyorsa sessizce hiçbir şey yapılmaz', () async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi(kullanilabilir: false);
      final kap = _kap(depo, magaza);

      expect(
        await kap.read(degerlendirmeProvider.notifier).adayMi([_bitmis()]),
        isFalse,
      );
      expect(magaza.istek, 0);
      expect(depo.istendi, isFalse);
    });

    test('depo hatası sessizce yok sayılır', () async {
      final magaza = SahteMagazaDegerlendirmesi();
      final kap = _kap(_BozukDepo(), magaza);
      final notifier = kap.read(degerlendirmeProvider.notifier);

      expect(await notifier.adayMi([_bitmis()]), isFalse);
      await notifier.iste();
      expect(magaza.istek, 0);
    });
  });

  group('DegerlendirmeFirsati', () {
    testWidgets('bitmiş etkinlikte kısa gecikmeyle bir kez ister', (
      tester,
    ) async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi();
      await widgetAc(
        tester,
        Scaffold(
          body: DegerlendirmeFirsati(
            etkinlikler: [_bitmis()],
            child: const Text(_sayfa),
          ),
        ),
        overrides: _overridelar(depo, magaza),
      );

      await tester.pump(const Duration(seconds: 1));
      expect(magaza.istek, 0);
      await tester.pump(_bekle);
      expect(magaza.istek, 1);
      expect(depo.istendi, isTrue);

      await tester.pump(_bekle);
      expect(magaza.istek, 1);
    });

    testWidgets('bitmemiş etkinlikte istemez', (tester) async {
      final magaza = SahteMagazaDegerlendirmesi();
      await widgetAc(
        tester,
        Scaffold(
          body: DegerlendirmeFirsati(
            etkinlikler: [_yaklasan()],
            child: const Text(_sayfa),
          ),
        ),
        overrides: _overridelar(BellekDegerlendirmeDeposu(), magaza),
      );

      await tester.pump(_bekle);
      expect(magaza.istek, 0);
    });

    testWidgets('mağaza kullanılamıyorsa istemez', (tester) async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi(kullanilabilir: false);
      await widgetAc(
        tester,
        Scaffold(
          body: DegerlendirmeFirsati(
            etkinlikler: [_bitmis()],
            child: const Text(_sayfa),
          ),
        ),
        overrides: _overridelar(depo, magaza),
      );

      await tester.pump(_bekle);
      expect(magaza.istek, 0);
      expect(depo.istendi, isFalse);
    });

    testWidgets('üstte form açıkken istemez; form kapanınca ister', (
      tester,
    ) async {
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi();
      await widgetAc(
        tester,
        Scaffold(
          body: DegerlendirmeFirsati(
            etkinlikler: [_bitmis()],
            child: const Text(_sayfa),
          ),
        ),
        overrides: _overridelar(depo, magaza),
      );

      final gezinme = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        gezinme.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: TextField()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_bekle);
      expect(magaza.istek, 0);
      expect(depo.istendi, isFalse);

      gezinme.pop();
      await tester.pumpAndSettle();
      await tester.pump(_bekle);
      expect(magaza.istek, 1);
    });

    testWidgets('kökte diyalog açıkken istemez', (tester) async {
      final magaza = SahteMagazaDegerlendirmesi();
      await widgetAc(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: DegerlendirmeFirsati(
                etkinlikler: [_bitmis()],
                child: const Text(_sayfa),
              ),
            ),
          ),
        ),
        overrides: _overridelar(BellekDegerlendirmeDeposu(), magaza),
      );

      unawaited(
        showDialog<void>(
          context: tester.element(find.text(_sayfa)),
          builder: (_) => const AlertDialog(content: TextField()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(_bekle);
      expect(magaza.istek, 0);
    });
  });

  group('ekranlar', () {
    testWidgets('bitmiş etkinliğin detayında bir kez ister', (tester) async {
      ekranBoyutu(tester);
      final depo = BellekDegerlendirmeDeposu();
      final magaza = SahteMagazaDegerlendirmesi();
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          tur: 'fishing',
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
          cevap: 'going',
        ),
      });
      await uygulamayiAc(
        tester,
        tayfa: etkinlikOverridelari(
          tasima: tasima,
          degerlendirme: depo,
          magaza: magaza,
        ),
      );
      final yonlendirici = yonlendiriciyiAl(tester);
      final detay = Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId);
      yonlendirici.go(detay);
      await tester.pumpAndSettle();
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);

      await tester.pump(_bekle);
      expect(magaza.istek, 1);
      expect(depo.istendi, isTrue);

      yonlendirici.go(Adresler.etkinlikler(ornekTayfaId));
      await tester.pumpAndSettle();
      yonlendirici.go(detay);
      await tester.pumpAndSettle();
      await tester.pump(_bekle);
      expect(magaza.istek, 1);
    });

    testWidgets('detaydan düzenlemeye geçilirse istemez', (tester) async {
      ekranBoyutu(tester);
      final magaza = SahteMagazaDegerlendirmesi();
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(
          tur: 'fishing',
          baslangic: gecmisBaslangic,
          sure: const Duration(hours: 3),
          cevap: 'going',
          yonetebilir: true,
        ),
      });
      await uygulamayiAc(
        tester,
        tayfa: etkinlikOverridelari(tasima: tasima, magaza: magaza),
      );
      final yonlendirici = yonlendiriciyiAl(tester);
      yonlendirici.go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
      await tester.pump();
      await tester.pump();
      yonlendirici.go(Adresler.etkinlikDuzenle(ornekTayfaId, ornekEtkinlikId));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(_bekle);
      expect(magaza.istek, 0);
    });

    // Liste yalnızca bitmemiş etkinlikleri getirir; burada liste
    // okunduktan sonra biten bir etkinlik vardır.
    testWidgets('ana sayfa bölümünde de ister', (tester) async {
      final magaza = SahteMagazaDegerlendirmesi();
      final tasima = etkinlikTasimasi({
        'GET $etkinliklerYolu': (_) => etkinlikListesiJson([
          etkinlikJson(
            baslangic: gecmisBaslangic,
            sure: const Duration(hours: 3),
            cevap: 'going',
          ),
        ]),
      });
      await widgetAc(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: EtkinlikBolumu(tayfaId: ornekTayfaId),
          ),
        ),
        tayfa: etkinlikOverridelari(tasima: tasima, magaza: magaza),
      );

      await tester.pump(_bekle);
      expect(magaza.istek, 1);
    });
  });
}

/// Okunamayan güvenli depo.
final class _BozukDepo implements DegerlendirmeDeposu {
  @override
  Future<bool> istendiMi() async => throw Exception('depo');

  @override
  Future<void> isaretle() async => throw Exception('depo');
}
