import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Apple ile devam et" (Design: Giriş iOS; Proje Planı §11: Apple ile giriş
/// sonraya bırakıldı).
///
/// Apple ile giriş henüz uygulanmadı. Giriş ekranı iOS'ta Apple düğmesini
/// Google'ın üstünde gösterecek yere sahiptir; düğme yalnızca üç koşul
/// birlikte sağlanınca görünür ([appleGirisiGorunur]):
///
/// 1. Platform iOS.
/// 2. Derleme bayrağı açık: `--dart-define=TAYFAM_APPLE_GIRIS=true`
///    ([AppleGirisi.bayrak]; varsayılan kapalı).
/// 3. Düğme verilmiş ([appleGirisDugmesiProvider]). Apple girişi
///    uygulanınca Apple'ın yerel düğmesi (ASAuthorizationAppleIDButton ya
///    da paketinin yerel düğmesi) ve gerçek akış bu provider'la verilir;
///    şimdilik `null`'dır, yani bayrak açılsa da sahte bir düğme ya da akış
///    gösterilmez.
abstract final class AppleGirisi {
  /// Derleme bayrağı.
  static const bool bayrak = bool.fromEnvironment('TAYFAM_APPLE_GIRIS');
}

/// Apple ile giriş düğmesini çizen fonksiyon; Apple girişi uygulanana kadar
/// `null`.
final appleGirisDugmesiProvider = Provider<WidgetBuilder?>(
  (ref) => null,
  name: 'appleGirisDugmesiProvider',
);

/// Apple düğmesi gösterilsin mi.
bool appleGirisiGorunur({
  required TargetPlatform platform,
  required bool bayrak,
  required WidgetBuilder? dugme,
}) {
  return platform == TargetPlatform.iOS && bayrak && dugme != null;
}
