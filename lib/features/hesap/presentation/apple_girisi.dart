import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/application/giris_notifier.dart';
import 'package:tayfam/features/hesap/presentation/apple_dugmesi.dart';

/// "Apple ile devam et" (Design: Giriş iOS; ADR-0034 §5, Tayfam-Api
/// ADR-0045).
///
/// Giriş ekranı iOS'ta Apple düğmesini Google'ın üstünde gösterir; düğme
/// yalnızca üç koşul birlikte sağlanınca görünür ([appleGirisiGorunur]):
///
/// 1. Platform iOS.
/// 2. Derleme bayrağı açık: `--dart-define=TAYFAM_APPLE_GIRIS=true`
///    ([AppleGirisi.bayrak]; varsayılan kapalı). Sunucuda Apple ile giriş
///    açılmadan bayrak açılmaz.
/// 3. Düğme verilmiş ([appleGirisDugmesiProvider]): Apple'ın yerel düğmesi
///    ([AppleIleDevamDugmesi]).
abstract final class AppleGirisi {
  /// Derleme bayrağı.
  static const bool bayrak = bool.fromEnvironment('TAYFAM_APPLE_GIRIS');
}

/// Derleme bayrağı; testler açık halini bununla dener.
final appleGirisBayragiProvider = Provider<bool>(
  (ref) => AppleGirisi.bayrak,
  name: 'appleGirisBayragiProvider',
);

/// Apple ile giriş düğmesini çizen fonksiyon: dokununca Apple ile girişi
/// başlatır ([GirisNotifier.appleIleGirisYap]).
final appleGirisDugmesiProvider = Provider<WidgetBuilder?>(
  (ref) =>
      (context) => AppleIleDevamDugmesi(
        onPressed: () =>
            unawaited(ref.read(girisProvider.notifier).appleIleGirisYap()),
      ),
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
