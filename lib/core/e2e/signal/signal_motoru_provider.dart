import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/signal/desteklenmeyen_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/kanal_signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Uygulamanın tek [SignalMotoru]'su (kalıcı servis; durum tutmaz).
///
/// Android ve iOS'ta platform kanalı (Kotlin ve Swift köprüleri aynı
/// sözleşmeye cevap verir; ADR-0010, ADR-0034 §7); web geliştirme
/// derlemesinde (ADR-0011) [DesteklenmeyenSignalMotoru]. Testler bunu
/// `SahteSignalMotoru` ile ezer.
final signalMotoruProvider = Provider<SignalMotoru>(
  (ref) => _mobilPlatform()
      ? KanalSignalMotoru()
      : const DesteklenmeyenSignalMotoru(),
);

bool _mobilPlatform() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };
}

/// Bu derlemede E2E var mı (arayüzün "yalnızca mobil uygulamada" boş
/// durumu için).
final signalDestekleniyorProvider = Provider<bool>(
  (ref) => ref.watch(signalMotoruProvider) is! DesteklenmeyenSignalMotoru,
);
