import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Kameradan QR okuyan widget'ı kurar. Testler kamerasız bir sahte verir.
///
/// Kamera izni yalnızca bu widget ekrana gelince (kullanıcı "Cihaz bağla"ya
/// bastığında) istenir; görüntü saklanmaz ve gönderilmez.
typedef QrTarayiciKurucu =
    Widget Function({
      required ValueChanged<String> kodOkundu,
      required VoidCallback izinReddedildi,
      required VoidCallback acilamadi,
    });

/// Uygulamanın QR tarayıcısı (`mobile_scanner`).
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

/// `mobile_scanner` ile yalnızca QR biçimini okuyan kamera önizlemesi.
class KameraTarayici extends StatefulWidget {
  const KameraTarayici({
    super.key,
    required this.kodOkundu,
    required this.izinReddedildi,
    required this.acilamadi,
  });

  final ValueChanged<String> kodOkundu;
  final VoidCallback izinReddedildi;
  final VoidCallback acilamadi;

  @override
  State<KameraTarayici> createState() => _KameraTarayiciState();
}

class _KameraTarayiciState extends State<KameraTarayici> {
  final MobileScannerController _denetleyici = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _hataBildirildi = false;

  @override
  void dispose() {
    unawaited(_denetleyici.dispose());
    super.dispose();
  }

  void _okundu(BarcodeCapture yakalama) {
    for (final kod in yakalama.barcodes) {
      final metin = kod.rawValue;
      if (metin != null) {
        widget.kodOkundu(metin);
        return;
      }
    }
  }

  void _hata(MobileScannerException hata) {
    if (_hataBildirildi) return;
    _hataBildirildi = true;
    // Bildirim derleme sırasında değil, çerçeve bitince yapılır.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hata.errorCode == MobileScannerErrorCode.permissionDenied) {
        widget.izinReddedildi();
      } else {
        widget.acilamadi();
      }
    });
  }

  @override
  Widget build(BuildContext context) => MobileScanner(
    controller: _denetleyici,
    onDetect: _okundu,
    errorBuilder: (context, hata) {
      _hata(hata);
      return const SizedBox.shrink();
    },
  );
}
