// Mağaza ekran görüntüleri (T-22 Google Play, T-11 App Store).
//
// Uygulamanın gerçek ekranlarını demo verisiyle ([demoTasimasi]) çizer,
// marka morunda bir zemine, başlığın altına ve telefon çerçevesinin içine
// yerleştirir ([MagazaCercevesi]). Cihaz ve ağ kullanılmaz.
//
// Her `flutter test`te ekranlar çizilir ve tanımsız istek ya da provider
// hatası olmadığı denetlenir. PNG yalnızca `MAGAZA_CIKTI` ortam değişkeni
// verilince yazılır:
//
//   TZ=Europe/Istanbul MAGAZA_CIKTI=build/magaza \
//     flutter test test/magaza/magaza_gorselleri_test.dart
//
// Çıktı: `$MAGAZA_CIKTI/play/0N-<ad>.png` (1080 × 1920) ve
// `$MAGAZA_CIKTI/ios/0N-<ad>.png` (1320 × 2868); saydamlık kanalı yok.
// CI'da `.github/workflows/magaza-gorselleri.yml` üretir ve artifact olarak
// yükler.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';

import '../features/tayfa/sahteler.dart' show SahteTayfaTasima;
import '../yardimcilar.dart';
import 'cerceve.dart';
import 'demo_verisi.dart';
import 'png.dart';
import 'tanitim.dart';

/// Bir mağaza görseli: dosya adı, üst başlık ve ekranı hazırlayan adımlar.
final class MagazaEkrani {
  const MagazaEkrani({
    required this.ad,
    required this.baslik,
    this.hazirla,
    this.tanitim,
    this.gorunmeli = const [],
    this.durumCubuguAcik = false,
    this.durumCubuguZemini = false,
  });

  /// Telefon ekranında tamamen görünmesi gereken metinler (parçası yeter).
  final List<String> gorunmeli;

  /// Dosya adı (sıra numarasıyla birlikte).
  final String ad;

  /// Platform sahibinin onayladığı üst başlık (`tayfam/12-magaza-ve-yayin.md`
  /// §5).
  final String baslik;

  /// Uygulama açıldıktan sonra ekrana gitme ve kaydırma.
  final Future<void> Function(WidgetTester tester, MagazaHedefi hedef)? hazirla;

  /// Verilirse gerçek ekran yerine bu tanıtım illüstrasyonu çizilir
  /// (platform sahibi, 2026-11-28: 02 ve 06).
  final Widget? tanitim;

  final bool durumCubuguAcik;
  final bool durumCubuguZemini;
}

Future<void> _git(WidgetTester tester, String adres) async {
  yonlendiriciyiAl(tester).go(adres);
  await tester.pumpAndSettle();
}

Future<void> _tayfaSec(WidgetTester tester, String tayfaId) async {
  tester.container().read(aktifTayfaIdProvider.notifier).sec(tayfaId);
  await tester.pumpAndSettle();
}

/// [bulucu]'yu ekranın üstüne (durum çubuğunun hemen altına) kaydırır.
/// Konumlar tuval birimindedir; telefon ekranı [FittedBox] ile ölçeklendiği
/// için kaydırma miktarı ekran birimine çevrilir.
Future<void> _basaKaydir(
  WidgetTester tester,
  MagazaHedefi hedef,
  Finder bulucu,
) async {
  final ekranAlani = tester.getRect(find.byKey(icerikAlaniAnahtari));
  final olcek = ekranAlani.height / hedef.ekran.height;
  final ust = tester.getRect(bulucu.first).top;
  final konum = Scrollable.of(tester.element(bulucu.first)).position;
  final kayma = (ust - ekranAlani.top) / olcek - hedef.ustBosluk - 8;
  konum.jumpTo(
    (konum.pixels + kayma).clamp(konum.minScrollExtent, konum.maxScrollExtent),
  );
  await tester.pumpAndSettle();
}

final List<MagazaEkrani> magazaEkranlari = [
  MagazaEkrani(
    ad: '01-tayfa-ana-sayfa',
    gorunmeli: ['Ege Klasikleri Demo', 'Bozdağ sonbahar konvoyu'],
    baslik: 'Kulübün tek bir yerde',
    durumCubuguAcik: true,
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.tayfa(egeId));
    },
  ),
  // Tanıtım görseli: gerçek ekranda rota, buluşma noktası ve araçlar
  // aynı anda sığmıyordu, harita karoları da çizilmiyordu.
  const MagazaEkrani(
    ad: '02-konvoy-rotasi',
    baslik: 'Rota, buluşma noktası, katılan araçlar',
    tanitim: RotaTanitimi(),
    gorunmeli: ['Buluşma noktası', 'Varış', 'Konvoy · 5 araç'],
  ),
  MagazaEkrani(
    ad: '03-kamp-malzeme-listesi',
    gorunmeli: [
      'Malzeme listesi',
      'Çadır (4 kişilik)',
      'Kahvaltılık',
      'Fener ve yedek pil',
    ],
    baslik: 'Kim ne getiriyor, belli olsun',
    durumCubuguZemini: true,
    hazirla: (tester, hedef) async {
      await _tayfaSec(tester, kazdagiId);
      await _git(tester, Adresler.etkinlik(kazdagiId, kampId));
      await _basaKaydir(tester, hedef, find.text('Malzeme listesi'));
    },
  ),
  MagazaEkrani(
    ad: '04-anket',
    gorunmeli: [
      'Bir sonraki konvoy rotası nereye olsun?',
      'Şirince',
      'Kozak Yaylası',
    ],
    baslik: 'Kararı tayfa versin',
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.anket(egeId, rotaAnketiId));
    },
  ),
  MagazaEkrani(
    ad: '05-soru-cevap-aramasi',
    gorunmeli: [
      'Çift gövdeli karbüratör ayarını kim yapıyor?',
      'Weber karbüratör için conta takımı nereden bulunur?',
      'Soğuk sabahlarda karbüratörlü motor zor çalışıyor',
    ],
    baslik: 'Sorulan soru kaybolmasın',
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.sorular(egeId));
      await tester.enterText(find.byType(TextField).first, 'karbüratör');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
    },
  ),
  // Tanıtım görseli: kanal listesinde önizleme yok, demo setinde birebir
  // mesaj yok; şifreli birebir mesaj gerçek ekranda gösterilemiyordu.
  const MagazaEkrani(
    ad: '06-sohbet',
    baslik: 'Kanallar ve şifreli birebir mesaj',
    tanitim: SohbetTanitimi(),
    gorunmeli: [
      '#genel',
      '#bakım-onarım',
      'Cumartesi kaçta çıkıyoruz?',
      'Birebir mesajlar uçtan uca şifreli',
    ],
  ),
];

/// Provider hatalarını toplar (yalnızca demo verisi; hata ayıklama için).
final class _HataGozlemcisi extends ProviderObserver {
  _HataGozlemcisi(this.hatalar);

  final List<String> hatalar;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    hatalar.add('${context.provider.name ?? context.provider}: $error');
  }
}

Future<List<int>> _pngAl(
  WidgetTester tester,
  GlobalKey anahtar,
  MagazaHedefi hedef,
) async {
  final sinir =
      anahtar.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final resim = await sinir.toImage(pixelRatio: hedef.oran);
    final genislik = resim.width;
    final yukseklik = resim.height;
    final veri = await resim.toByteData(format: ui.ImageByteFormat.rawRgba);
    resim.dispose();
    return rgbPngKodla(veri!.buffer.asUint8List(), genislik, yukseklik);
  });
  return png!;
}

void main() {
  final cikti = Platform.environment['MAGAZA_CIKTI'];

  setUpAll(uygulamaFontlariniYukle);

  test('App Store: görsellerin yarısından fazlası uygulamayı kullanımda '
      'gösterir (tanıtım görseli yarıdan az)', () {
    final tanitim = magazaEkranlari.where((e) => e.tanitim != null).length;
    expect(tanitim * 2, lessThan(magazaEkranlari.length));
    expect(magazaEkranlari.map((e) => e.ad.substring(0, 2)), [
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
    ]);
  });

  test('gömülü font yüklendi', () {
    // Test fontunda (Ahem) her karakter puntosu kadar geniştir: "9:41"
    // 17 pt'de 68 px olurdu.
    final olcu = TextPainter(
      text: const TextSpan(
        text: '9:41',
        style: TextStyle(fontFamily: TayfamTypography.aile, fontSize: 17),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(olcu.width, lessThan(17 * 3));
    olcu.dispose();
  });

  for (final hedef in MagazaHedefi.values) {
    for (final ekran in magazaEkranlari) {
      testWidgets(
        '${hedef.klasor}: ${ekran.ad}',
        (tester) async {
          tester.view
            ..physicalSize = hedef.cikti
            ..devicePixelRatio = hedef.oran;
          addTearDown(tester.view.reset);
          WidgetsApp.debugAllowBannerOverride = false;
          addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);

          final SahteTayfaTasima tasima = demoTasimasi();
          final hatalar = <String>[];
          final anahtar = GlobalKey();
          Widget cerceve({Widget? uygulama}) => RepaintBoundary(
            key: anahtar,
            child: MagazaCercevesi(
              hedef: hedef,
              baslik: ekran.baslik,
              durumCubuguAcik: ekran.durumCubuguAcik,
              durumCubuguZemini: ekran.durumCubuguZemini,
              uygulama: uygulama,
              tanitim: ekran.tanitim,
            ),
          );
          if (ekran.tanitim != null) {
            await tester.pumpWidget(cerceve());
            await tester.pumpAndSettle();
          } else {
            await uygulamayiAc(
              tester,
              tayfa: demoOverridelari(tasima),
              bildirim: demoBildirimOverridelari(tasima),
              birebir: demoBirebirOverridelari(tasima),
              gozlemciler: [_HataGozlemcisi(hatalar)],
              sarmala: (uygulama) => cerceve(uygulama: uygulama),
            );
            await ekran.hazirla!(tester, hedef);
            await tester.pumpAndSettle();
          }

          // Ekranın asıl içeriği telefonda görünüyor mu. Konumlar log'a
          // yazılır: düzeni görüntüyü açmadan izlemek için.
          final ekranAlani = tester.getRect(find.byKey(icerikAlaniAnahtari));
          final gorunmeyen = <String>[];
          for (final metin in ekran.gorunmeli) {
            final alanlar = [
              for (final e in find.textContaining(metin).evaluate())
                tester.getRect(find.byElementPredicate((x) => x == e)),
            ];
            final icerde = alanlar.where(
              (a) => a.top >= ekranAlani.top && a.bottom <= ekranAlani.bottom,
            );
            for (final alan in alanlar) {
              final ust = (alan.top - ekranAlani.top) / ekranAlani.height;
              debugPrint(
                '[${hedef.klasor}/${ekran.ad}] "$metin": '
                '${(ust * 100).round()}%',
              );
            }
            if (icerde.isEmpty) gorunmeyen.add(metin);
          }

          // Ekrandaki bütün metinler yukarıdan aşağıya (yalnızca demo
          // verisi): görüntüyü açmadan düzeni okumak için.
          if (cikti != null) {
            final satirlar = <(double, String)>[];
            for (final e in find.byType(RichText).evaluate()) {
              final kutu = e.renderObject;
              if (kutu is! RenderBox || !kutu.hasSize) continue;
              final alan = kutu.localToGlobal(Offset.zero) & kutu.size;
              if (!alan.overlaps(ekranAlani)) continue;
              final metin = (e.widget as RichText).text.toPlainText();
              satirlar.add((
                (alan.top - ekranAlani.top) / ekranAlani.height * 100,
                metin.replaceAll('\n', ' '),
              ));
            }
            satirlar.sort((a, b) => a.$1.compareTo(b.$1));
            for (final (ust, metin) in satirlar) {
              debugPrint(
                '[${hedef.klasor}/${ekran.ad}] '
                '${ust.toStringAsFixed(0).padLeft(4)}% $metin',
              );
            }
          }

          if (ekran.tanitim is RotaTanitimi) {
            final alan = tester.getSize(find.byKey(icerikAlaniAnahtari));
            for (final MapEntry(key: ad, value: n) in RotaYerlesimi(
              alan,
            ).noktalar.entries) {
              debugPrint(
                '[${hedef.klasor}/${ekran.ad}] çizim "$ad": '
                'x ${(n.dx * 100).round()}%, y ${(n.dy * 100).round()}%',
              );
            }
          }

          final tanimsiz = tanimsizIstekler(tasima);
          for (final satir in [...tanimsiz, ...hatalar]) {
            debugPrint('[${hedef.klasor}/${ekran.ad}] $satir');
          }

          final png = await _pngAl(tester, anahtar, hedef);
          final baslik = pngBasligi(png);
          expect(baslik.genislik, hedef.cikti.width.toInt());
          expect(baslik.yukseklik, hedef.cikti.height.toInt());
          expect(baslik.renkTuru, 2, reason: 'RGB, saydamlık kanalı yok');
          if (cikti != null) {
            final dosya = File('$cikti/${hedef.klasor}/${ekran.ad}.png');
            await tester.runAsync(() async {
              await dosya.parent.create(recursive: true);
              await dosya.writeAsBytes(png);
            });
            debugPrint('${dosya.path}: ${png.length} bayt');
          }

          expect(gorunmeyen, isEmpty, reason: 'görünmeyen içerik');
          expect(tanimsiz, isEmpty, reason: 'tanımsız istek');
          expect(hatalar, isEmpty, reason: 'provider hatası');
        },
        variant: TargetPlatformVariant.only(
          hedef == MagazaHedefi.ios
              ? TargetPlatform.iOS
              : TargetPlatform.android,
        ),
      );
    }
  }
}
