import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/cihazlar/data/qr_cozucu.dart';

/// Kameradan QR okuyan widget'ı kurar. Testler kamerasız bir sahte verir.
///
/// Kamera izni yalnızca bu widget ekrana gelince (kullanıcı "Cihaz bağla"ya
/// bastığında) istenir; görüntü saklanmaz ve gönderilmez.
typedef QrTarayiciKurucu = Widget Function({
  required ValueChanged<String> kodOkundu,
  required VoidCallback izinReddedildi,
  required VoidCallback acilamadi,
});

/// Uygulamanın QR tarayıcısı (`camera` + ZXing'in Dart portu `zxing2`;
/// ADR-0020 §7).
final qrTarayiciProvider = Provider<QrTarayiciKurucu>(
  (ref) =>
      ({
        required ValueChanged<String> kodOkundu,
        required VoidCallback izinReddedildi,
        required VoidCallback acilamadi,
      }) => KameraTarayici(
        kodOkundu: kodOkundu,
        izinReddedildi: izinReddedildi,
        acilamadi: acilamadi,
      ),
  name: 'qrTarayiciProvider',
);

/// Bir kareyi çözer; QR yoksa null.
typedef QrKaresiCozucu = Future<String?> Function(ParlaklikKaresi kare);

/// Kareyi ayrı isolate'ta çözer (arayüz iş parçacığı beklemez).
Future<String?> _isolatetaCoz(ParlaklikKaresi kare) =>
    compute(qrMetniCoz, kare);

/// `camera` eklentisinin izin reddi hata kodları (Android CameraX ve iOS
/// AVFoundation uygulamaları).
const Set<String> _izinHataKodlari = {
  'CameraAccessDenied',
  'CameraAccessDeniedWithoutPrompt',
  'CameraAccessRestricted',
};

/// Arka kameranın önizlemesi; görüntü akışının parlaklık düzleminde
/// yalnızca QR biçimi aranır.
///
/// - Kamera ve izin isteği widget ekrana gelince başlar; ses kapalıdır.
/// - Aynı anda tek kare çözülür (ayrı isolate'ta); çözülürken gelen kareler
///   atlanır. Kareler yalnızca bellekte, çözülene kadar tutulur.
/// - İlk okunan QR'da akış durur ve metin bir kez bildirilir; doğrulama
///   eşleştirme servisindedir.
/// - Uygulama arka plana geçince kamera kapanır, dönünce yeniden açılır.
class KameraTarayici extends StatefulWidget {
  const KameraTarayici({
    super.key,
    required this.kodOkundu,
    required this.izinReddedildi,
    required this.acilamadi,
    this.coz = _isolatetaCoz,
  });

  final ValueChanged<String> kodOkundu;
  final VoidCallback izinReddedildi;
  final VoidCallback acilamadi;

  /// Kare çözücü; testler isolate'sız bir çözücü verir.
  final QrKaresiCozucu coz;

  @override
  State<KameraTarayici> createState() => _KameraTarayiciState();
}

class _KameraTarayiciState extends State<KameraTarayici>
    with WidgetsBindingObserver {
  CameraController? _denetleyici;

  /// Kamera açılıyor (izin penceresi dahil).
  bool _aciliyor = false;

  /// Bir kare çözülüyor.
  bool _cozuluyor = false;

  /// QR okundu, hata bildirildi ya da widget kaldırıldı: tarama bitti.
  bool _bitti = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ac());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bitti = true;
    final denetleyici = _denetleyici;
    _denetleyici = null;
    if (denetleyici != null) unawaited(_birak(denetleyici));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    // Açılırken gelen değişiklikler (izin penceresi) yok sayılır; açılış
    // bitince uygulamanın durumuna bakılır.
    if (_bitti || _aciliyor) return;
    switch (durum) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.paused ||
          AppLifecycleState.hidden:
        unawaited(_kapat());
      case AppLifecycleState.resumed:
        if (_denetleyici == null) unawaited(_ac());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _ac() async {
    _aciliyor = true;
    CameraController? denetleyici;
    try {
      final kameralar = await availableCameras();
      if (kameralar.isEmpty) {
        _hata(izinYok: false);
        return;
      }
      final kamera = kameralar.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kameralar.first,
      );
      denetleyici = CameraController(
        kamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await denetleyici.initialize();
      final yasam = WidgetsBinding.instance.lifecycleState;
      final onde = yasam == null || yasam == AppLifecycleState.resumed;
      if (_bitti || !mounted || !onde) {
        await _birak(denetleyici);
        return;
      }
      if (!denetleyici.supportsImageStreaming()) {
        await _birak(denetleyici);
        _hata(izinYok: false);
        return;
      }
      await denetleyici.startImageStream(_kareGeldi);
      if (_bitti || !mounted) {
        await _birak(denetleyici);
        return;
      }
      setState(() => _denetleyici = denetleyici);
    } on CameraException catch (hata) {
      if (denetleyici != null) await _birak(denetleyici);
      _hata(izinYok: _izinHataKodlari.contains(hata.code));
    } on Exception {
      if (denetleyici != null) await _birak(denetleyici);
      _hata(izinYok: false);
    } finally {
      _aciliyor = false;
    }
  }

  Future<void> _kapat() async {
    final denetleyici = _denetleyici;
    if (denetleyici == null) return;
    setState(() => _denetleyici = null);
    await _birak(denetleyici);
  }

  /// Görüntü akışını durdurur ve kamerayı kapatır.
  static Future<void> _birak(CameraController denetleyici) async {
    if (denetleyici.value.isStreamingImages) {
      await denetleyici.stopImageStream();
    }
    await denetleyici.dispose();
  }

  void _hata({required bool izinYok}) {
    if (_bitti || !mounted) return;
    _bitti = true;
    if (izinYok) {
      widget.izinReddedildi();
    } else {
      widget.acilamadi();
    }
  }

  void _kareGeldi(CameraImage kare) {
    if (_cozuluyor || _bitti) return;
    final parlaklik = _parlaklikKaresi(kare);
    if (parlaklik == null) return;
    _cozuluyor = true;
    unawaited(_coz(parlaklik));
  }

  Future<void> _coz(ParlaklikKaresi kare) async {
    try {
      final metin = await widget.coz(kare);
      if (metin == null || _bitti || !mounted) return;
      _bitti = true;
      final denetleyici = _denetleyici;
      if (denetleyici != null && denetleyici.value.isStreamingImages) {
        unawaited(denetleyici.stopImageStream());
      }
      widget.kodOkundu(metin);
    } finally {
      _cozuluyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final denetleyici = _denetleyici;
    final boyut = denetleyici?.value.previewSize;
    if (denetleyici == null ||
        !denetleyici.value.isInitialized ||
        boyut == null) {
      return const SizedBox.expand();
    }
    // Önizleme kareyi kaplar (dikey: önizleme boyutu yatay verilir).
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: boyut.height,
        height: boyut.width,
        child: CameraPreview(denetleyici),
      ),
    );
  }
}

/// Kamera karesinin parlaklık düzlemi; desteklenmeyen biçimde null.
///
/// YUV 4:2:0 ve NV21'de ilk düzlem parlaklıktır (Y).
ParlaklikKaresi? _parlaklikKaresi(CameraImage kare) {
  if (kare.planes.isEmpty) return null;
  switch (kare.format.group) {
    case ImageFormatGroup.yuv420 || ImageFormatGroup.nv21:
      final y = kare.planes.first;
      return ParlaklikKaresi.olustur(
        baytlar: y.bytes,
        genislik: kare.width,
        yukseklik: kare.height,
        satirBaytlari: y.bytesPerRow,
      );
    case ImageFormatGroup.bgra8888 ||
        ImageFormatGroup.jpeg ||
        ImageFormatGroup.unknown:
      return null;
  }
}
