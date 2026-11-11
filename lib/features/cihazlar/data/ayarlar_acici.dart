import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kamera izni reddedilince uygulamanın sistem ayarlarını açar. Yalnızca
/// iOS'ta mümkündür (`app-settings:`); Android'de `url_launcher` uygulama
/// ayarlarını açamaz, ekran yolu metinle anlatır. Testler sahtesini verir.
abstract interface class AyarlarAcici {
  /// Bu platformda ayarlar açılabilir mi.
  bool get destekleniyor;

  /// Uygulamanın ayarlarını açar; açılamazsa `false`.
  Future<bool> ac();
}

/// iOS'ta `app-settings:` adresini açar.
final class SistemAyarlarAcici implements AyarlarAcici {
  const SistemAyarlarAcici();

  @override
  bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> ac() async {
    if (!destekleniyor) return false;
    try {
      return await launchUrl(Uri(scheme: 'app-settings'));
    } on Exception {
      return false;
    }
  }
}

/// Uygulamanın ayarlar açıcısı.
final ayarlarAciciProvider = Provider<AyarlarAcici>(
  (ref) => const SistemAyarlarAcici(),
  name: 'ayarlarAciciProvider',
);
