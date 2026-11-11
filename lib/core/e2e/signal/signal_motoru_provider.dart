import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/signal/desteklenmeyen_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/kanal_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Uygulamanın tek [SignalMotoru]'su (kalıcı servis; durum tutmaz).
///
/// Android'de platform kanalı; web geliştirme derlemesinde (ADR-0011) ve
/// iOS köprüsü yazılana kadar iOS'ta [DesteklenmeyenSignalMotoru].
/// Testler bunu `SahteSignalMotoru` ile ezer.
final signalMotoruProvider = Provider<SignalMotoru>(
  (ref) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? KanalSignalMotoru()
      : const DesteklenmeyenSignalMotoru(),
);

/// Bu derlemede E2E var mı (arayüzün "yalnızca mobil uygulamada" boş
/// durumu için).
final signalDestekleniyorProvider = Provider<bool>(
  (ref) => ref.watch(signalMotoruProvider) is! DesteklenmeyenSignalMotoru,
);
