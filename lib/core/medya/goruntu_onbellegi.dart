import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Flutter'ın global görüntü önbelleğini (çözülmüş bitmap'ler) boşaltır
/// (istemci ADR-0028 §4, ADR-0006). Oturum değişince (çıkış, başka hesap)
/// çağrılır: birebir fotoğraflar ve kanal fotoğrafları bellekte kalmaz.
/// Bağlayıcı yoksa (saf birim testi) bir şey yapmaz.
void flutterGoruntuOnbelleginiTemizle() {
  final ImageCache onbellek;
  try {
    onbellek = PaintingBinding.instance.imageCache;
  } on FlutterError {
    return;
  }
  onbellek
    ..clear()
    ..clearLiveImages();
}
