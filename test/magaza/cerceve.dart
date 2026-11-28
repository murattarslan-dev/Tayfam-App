import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/bilesenler/tayfam_logo.dart';
import 'package:tayfam/core/tema/tayfam_colors.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/core/tema/tayfam_typography.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Mağaza görselinin hedefi: çıktı boyutu, telefon ekranının mantıksal
/// boyutu ve durum çubuğu ölçüleri.
enum MagazaHedefi {
  /// Google Play telefon: 1080 × 1920 (9:16). Ekran 412 × 915 dp.
  play(
    klasor: 'play',
    cikti: Size(1080, 1920),
    oran: 2,
    ekran: Size(412, 915),
    ustBosluk: 32,
    altBosluk: 20,
    kose: 36,
    baslikPuntosu: 36,
  ),

  /// App Store iPhone 6,9": 1320 × 2868. Ekran 390 × 844 pt.
  ios(
    klasor: 'ios',
    cikti: Size(1320, 2868),
    oran: 3,
    ekran: Size(390, 844),
    ustBosluk: 54,
    altBosluk: 30,
    kose: 52,
    baslikPuntosu: 34,
  );

  const MagazaHedefi({
    required this.klasor,
    required this.cikti,
    required this.oran,
    required this.ekran,
    required this.ustBosluk,
    required this.altBosluk,
    required this.kose,
    required this.baslikPuntosu,
  });

  /// Çıktı klasörünün adı.
  final String klasor;

  /// PNG'nin piksel boyutu.
  final Size cikti;

  /// Tuvalin mantıksal pikselinden PNG pikseline oran.
  final double oran;

  /// Telefon ekranının mantıksal boyutu (uygulama bu boyutta çizilir).
  final Size ekran;

  /// Durum çubuğu (üst güvenli alan) yüksekliği.
  final double ustBosluk;

  /// Alt güvenli alan (hareket çubuğu / ana ekran göstergesi).
  final double altBosluk;

  /// Ekranın köşe yarıçapı.
  final double kose;

  /// Üst başlığın puntosu (tuval biriminde).
  final double baslikPuntosu;

  /// Tuvalin mantıksal boyutu.
  Size get tuval => cikti / oran;

  bool get iosMu => this == MagazaHedefi.ios;
}

/// İçerik alanının anahtarı: telefon ekranı (uygulamanın çizildiği alan)
/// ya da tanıtım illüstrasyonu.
const Key icerikAlaniAnahtari = ValueKey('magaza-icerik-alani');

/// Mağaza görseli: marka morunda zemin, üstte logo ve kısa başlık, altında
/// telefon çerçevesi içinde uygulamanın gerçek ekranı ([uygulama]).
///
/// [uygulama] yerine [tanitim] verilirse telefon çerçevesi yoktur; aynı
/// alana marka paletiyle çizilmiş illüstrasyon gelir (02 ve 06, platform
/// sahibi 2026-11-28).
///
/// Uygulama, telefon ekranının boyutunda ([MagazaHedefi.ekran]) ve kendi
/// `MediaQuery`'siyle çizilir; çerçeve onu tuvale sığacak kadar ölçekler.
class MagazaCercevesi extends StatelessWidget {
  const MagazaCercevesi({
    super.key,
    required this.hedef,
    required this.baslik,
    this.uygulama,
    this.tanitim,
    this.durumCubuguAcik = false,
    this.durumCubuguZemini = false,
  });

  final MagazaHedefi hedef;

  /// Üstteki kısa başlık.
  final String baslik;

  /// Telefonun içindeki uygulama.
  final Widget? uygulama;

  /// Telefon çerçevesi yerine gösterilen tanıtım illüstrasyonu.
  final Widget? tanitim;

  /// Durum çubuğu yazısı beyaz mı (ekranın üstü mor olduğunda).
  final bool durumCubuguAcik;

  /// Durum çubuğunun arkası sayfa zemini mi (kaydırılmış ekranlarda içerik
  /// durum çubuğunun altında kalmasın diye).
  final bool durumCubuguZemini;

  @override
  Widget build(BuildContext context) {
    const r = TayfamColors.acik;
    final tuval = hedef.tuval;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: TayfamApp.yerelAyar,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: TayfamTheme.acik(),
      home: MediaQuery(
        data: MediaQueryData(size: tuval, devicePixelRatio: hedef.oran),
        child: ColoredBox(
          color: r.markaYuzey,
          child: SizedBox.fromSize(
            size: tuval,
            child: Column(
              children: [
                SizedBox(height: tuval.height * 0.045),
                TayfamLogo.yazili(boyut: 30, zemin: r.markaYuzey),
                SizedBox(height: tuval.height * 0.018),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tuval.width * 0.07),
                  child: Text(
                    baslik,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontFamily: TayfamTypography.aile,
                      fontWeight: FontWeight.w800,
                      fontSize: hedef.baslikPuntosu,
                      height: 1.1,
                      color: r.markaYuzeyUstu,
                    ),
                  ),
                ),
                SizedBox(height: tuval.height * 0.03),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: tuval.height * 0.035),
                    child: switch (tanitim) {
                      final tanitim? => Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tuval.width * 0.07,
                        ),
                        child: SizedBox.expand(
                          key: icerikAlaniAnahtari,
                          child: tanitim,
                        ),
                      ),
                      null => FittedBox(
                        child: _Telefon(
                          hedef: hedef,
                          durumCubuguAcik: durumCubuguAcik,
                          durumCubuguZemini: durumCubuguZemini,
                          child: uygulama!,
                        ),
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Telefon extends StatelessWidget {
  const _Telefon({
    required this.hedef,
    required this.durumCubuguAcik,
    required this.durumCubuguZemini,
    required this.child,
  });

  final MagazaHedefi hedef;
  final bool durumCubuguAcik;
  final bool durumCubuguZemini;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const acik = TayfamColors.acik;
    const koyu = TayfamColors.koyu;
    const cerceve = 12.0;
    final ekran = hedef.ekran;
    final yazi = durumCubuguAcik ? acik.markaYuzeyUstu : acik.metin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: koyu.zemin,
        borderRadius: BorderRadius.circular(hedef.kose + cerceve),
        border: Border.all(color: koyu.cizgi, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(cerceve),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(hedef.kose),
          child: SizedBox.fromSize(
            key: icerikAlaniAnahtari,
            size: ekran,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MediaQuery(
                    data: MediaQueryData(
                      size: ekran,
                      devicePixelRatio: 3,
                      padding: EdgeInsets.only(
                        top: hedef.ustBosluk,
                        bottom: hedef.altBosluk,
                      ),
                      viewPadding: EdgeInsets.only(
                        top: hedef.ustBosluk,
                        bottom: hedef.altBosluk,
                      ),
                    ),
                    child: child,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: hedef.ustBosluk,
                  child: _DurumCubugu(
                    hedef: hedef,
                    renk: yazi,
                    zemin: durumCubuguZemini ? acik.zemin : null,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: hedef.iosMu ? 8 : 6,
                  child: Center(
                    child: Container(
                      width: hedef.iosMu ? 134 : 108,
                      height: hedef.iosMu ? 5 : 4,
                      decoration: BoxDecoration(
                        color: acik.metin,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Telefonun durum çubuğu: saat solda, sinyal, kablosuz ve pil sağda;
/// iOS'ta ortada ada.
class _DurumCubugu extends StatelessWidget {
  const _DurumCubugu({
    required this.hedef,
    required this.renk,
    required this.zemin,
  });

  final MagazaHedefi hedef;
  final Color renk;
  final Color? zemin;

  @override
  Widget build(BuildContext context) {
    final ios = hedef.iosMu;
    final saat = Text(
      '9:41',
      style: TextStyle(
        fontFamily: TayfamTypography.aile,
        fontWeight: FontWeight.w700,
        fontSize: ios ? 17 : 14,
        color: renk,
      ),
    );
    final simgeler = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.signal_cellular_alt, size: ios ? 18 : 16, color: renk),
        const SizedBox(width: 4),
        Icon(Icons.wifi, size: ios ? 18 : 16, color: renk),
        const SizedBox(width: 4),
        Icon(Icons.battery_full, size: ios ? 20 : 16, color: renk),
      ],
    );
    return ColoredBox(
      color: zemin ?? Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: ios ? 32 : 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (ios)
              Positioned(
                top: 11,
                child: Container(
                  width: 124,
                  height: 36,
                  decoration: BoxDecoration(
                    color: TayfamColors.koyu.zemin,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            Align(
              alignment: ios ? const Alignment(-1, 0.25) : Alignment.center,
              child: Row(children: [saat, const Spacer(), simgeler]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uygulamanın gömülü fontlarını (Bricolage Grotesque) ve Material
/// simgelerini test ortamına yükler. `flutter test` varsayılan olarak her
/// metni kutularla çizen test fontunu kullanır; mağaza görselinde gerçek
/// fontlar gerekir. Font listesi Flutter'ın ürettiği `FontManifest.json`'dan
/// okunur (pubspec.yaml'daki fontlar ve `uses-material-design`).
Future<void> uygulamaFontlariniYukle() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>;
  for (final aile in manifest.cast<Map<String, Object?>>()) {
    final yukleyici = FontLoader(aile['family']! as String);
    for (final font
        in (aile['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      yukleyici.addFont(rootBundle.load(font['asset']! as String));
    }
    await yukleyici.load();
  }
}
