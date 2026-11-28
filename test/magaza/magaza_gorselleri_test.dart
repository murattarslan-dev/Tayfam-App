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

import '../features/tayfa/sahteler.dart' show SahteTayfaTasima;
import '../yardimcilar.dart';
import 'cerceve.dart';
import 'demo_verisi.dart';
import 'png.dart';

/// Bir mağaza görseli: dosya adı, üst başlık ve ekranı hazırlayan adımlar.
final class MagazaEkrani {
  const MagazaEkrani({
    required this.ad,
    required this.baslik,
    required this.hazirla,
    this.durumCubuguAcik = false,
    this.durumCubuguZemini = false,
  });

  /// Dosya adı (sıra numarasıyla birlikte).
  final String ad;

  /// Platform sahibinin onayladığı üst başlık (`tayfam/12-magaza-ve-yayin.md`
  /// §5).
  final String baslik;

  /// Uygulama açıldıktan sonra ekrana gitme ve kaydırma.
  final Future<void> Function(WidgetTester tester, MagazaHedefi hedef) hazirla;

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
Future<void> _basaKaydir(
  WidgetTester tester,
  MagazaHedefi hedef,
  Finder bulucu,
) async {
  final hizalama = (hedef.ustBosluk + 8) / hedef.ekran.height;
  await Scrollable.ensureVisible(
    tester.element(bulucu.first),
    alignment: hizalama,
  );
  await tester.pumpAndSettle();
}

final List<MagazaEkrani> magazaEkranlari = [
  MagazaEkrani(
    ad: '01-tayfa-ana-sayfa',
    baslik: 'Kulübün tek bir yerde',
    durumCubuguAcik: true,
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.tayfa(egeId));
    },
  ),
  MagazaEkrani(
    ad: '02-konvoy-detayi',
    baslik: 'Rota, buluşma noktası, katılan araçlar',
    durumCubuguZemini: true,
    hazirla: (tester, hedef) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.etkinlik(egeId, konvoyId));
      await _basaKaydir(
        tester,
        hedef,
        find.text(arbMetni('etkinlik_yer_baslik')),
      );
    },
  ),
  MagazaEkrani(
    ad: '03-kamp-malzeme-listesi',
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
    baslik: 'Kararı tayfa versin',
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.anket(egeId, rotaAnketiId));
    },
  ),
  MagazaEkrani(
    ad: '05-soru-cevap-aramasi',
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
  MagazaEkrani(
    ad: '06-sohbet-kanallari',
    baslik: 'Kanallar ve şifreli birebir mesaj',
    hazirla: (tester, _) async {
      await _tayfaSec(tester, egeId);
      await _git(tester, Adresler.sohbet);
    },
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
          await uygulamayiAc(
            tester,
            tayfa: demoOverridelari(tasima),
            bildirim: demoBildirimOverridelari(tasima),
            birebir: demoBirebirOverridelari(tasima),
            gozlemciler: [_HataGozlemcisi(hatalar)],
            sarmala: (uygulama) => RepaintBoundary(
              key: anahtar,
              child: MagazaCercevesi(
                hedef: hedef,
                baslik: ekran.baslik,
                durumCubuguAcik: ekran.durumCubuguAcik,
                durumCubuguZemini: ekran.durumCubuguZemini,
                uygulama: uygulama,
              ),
            ),
          );
          await ekran.hazirla(tester, hedef);
          await tester.pumpAndSettle();

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
