import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayfam/core/tema/tema.dart';

/// "Apple ile devam et" düğmesi (Design: Giriş iOS; ADR-0034 §5): Apple'ın
/// kendi yerel düğmesi (`ASAuthorizationAppleIDButton`), platform görünümü
/// olarak. Düğmeyi Apple çizer: işaret, metin, yazı tipi ve dil Apple'ın
/// kurallarına göredir; açık temada siyah, koyu temada beyaz biçim.
/// Erişilebilirlik etiketini de yerel düğme verir.
///
/// Yükseklik Google düğmesiyle aynıdır ([TayfamSizes.girisDugmesi]), köşeler
/// hap biçimindedir. Yerel taraf: `ios/Runner/AppleGirisKoprusu.swift`.
/// Yalnızca iOS'ta kurulur; başka platformda boş yer tutar.
class AppleIleDevamDugmesi extends StatefulWidget {
  const AppleIleDevamDugmesi({super.key, required this.onPressed});

  /// Platform görünümünün türü (yerel taraftaki kayıtla aynı).
  static const String gorunumTuru = 'tayfam/apple-giris-dugmesi';

  /// Yerel düğmenin dokunuşu bildirdiği metod.
  static const String basildiMetodu = 'basildi';

  final VoidCallback onPressed;

  @override
  State<AppleIleDevamDugmesi> createState() => _AppleIleDevamDugmesiDurumu();
}

class _AppleIleDevamDugmesiDurumu extends State<AppleIleDevamDugmesi> {
  MethodChannel? _kanal;

  void _olustu(int kimlik) {
    _kanal?.setMethodCallHandler(null);
    final kanal = MethodChannel('${AppleIleDevamDugmesi.gorunumTuru}/$kimlik');
    kanal.setMethodCallHandler((cagri) async {
      if (cagri.method == AppleIleDevamDugmesi.basildiMetodu && mounted) {
        widget.onPressed();
      }
    });
    _kanal = kanal;
  }

  @override
  void dispose() {
    _kanal?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const yukseklik = TayfamSizes.girisDugmesi;
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox(height: yukseklik);
    }
    final koyu = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: yukseklik,
      child: UiKitView(
        // Biçim oluşturulurken verilir; tema değişince görünüm yeniden
        // kurulur.
        key: ValueKey<bool>(koyu),
        viewType: AppleIleDevamDugmesi.gorunumTuru,
        creationParams: <String, Object>{
          'koyuTema': koyu,
          'koseYaricapi': yukseklik / 2,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _olustu,
      ),
    );
  }
}
