import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru_provider.dart';
import 'package:tayfam/features/profil/data/disa_aktarma_bicimi.dart';

/// Dışa aktarma dosyasının AES-256-GCM çözmesi (ADR-0022). Kendi kriptomuz
/// yoktur (CLAUDE.md kesin kural 4): gerçek uygulama Signal köprüsündeki
/// `aes256GcmCoz`'dur (libsignal `Aes256GcmDecryption`).
abstract interface class DisaAktarmaCozucu {
  /// Etiket doğrulanırsa düz metni, doğrulanamazsa `null` döner.
  /// Doğrulanmamış düz metin hiçbir zaman dönmez.
  Future<Uint8List?> coz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreliVeEtiket,
    required Uint8List aad,
  });
}

/// Signal köprüsüyle çözme. Köprünün hatası ([SignalHatasi]) doğrulanamamış
/// sayılır.
final class SignalDisaAktarmaCozucu implements DisaAktarmaCozucu {
  const SignalDisaAktarmaCozucu(this._motor);

  final SignalMotoru _motor;

  @override
  Future<Uint8List?> coz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreliVeEtiket,
    required Uint8List aad,
  }) async {
    try {
      return await _motor.aes256GcmCoz(
        anahtar: anahtar,
        nonce: nonce,
        sifreliVeEtiket: sifreliVeEtiket,
        aad: aad,
      );
    } on SignalHatasi {
      return null;
    }
  }
}

/// Signal köprüsünün olmadığı derleme (web geliştirme derlemesi; iOS
/// köprüsü yazılana kadar iOS): her çağrı
/// [DisaAktarmaHataTuru.desteklenmiyor].
final class OlmayanDisaAktarmaCozucu implements DisaAktarmaCozucu {
  const OlmayanDisaAktarmaCozucu();

  @override
  Future<Uint8List?> coz({
    required Uint8List anahtar,
    required Uint8List nonce,
    required Uint8List sifreliVeEtiket,
    required Uint8List aad,
  }) async {
    throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.desteklenmiyor);
  }
}

/// Uygulamanın çözücüsü: Signal köprüsü varsa (`signalDestekleniyorProvider`)
/// onunla, yoksa "desteklenmiyor" (ADR-0022 §4).
final disaAktarmaCozucuProvider = Provider<DisaAktarmaCozucu>(
  (ref) => ref.watch(signalDestekleniyorProvider)
      ? SignalDisaAktarmaCozucu(ref.watch(signalMotoruProvider))
      : const OlmayanDisaAktarmaCozucu(),
  name: 'disaAktarmaCozucuProvider',
);
