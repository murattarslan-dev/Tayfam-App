import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/signal/signal_motoru.dart';
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

/// Çözmenin olmadığı derleme (web geliştirme derlemesi; Signal köprüsünün
/// provider'ı gelene kadar mobil de): her çağrı
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

/// Uygulamanın çözücüsü.
///
/// Signal köprüsünün motor provider'ı (`feat/e2e-signal-kopru`) birleşince
/// mobilde `SignalDisaAktarmaCozucu(ref.watch(<motor provider>))` olur;
/// o zamana kadar indirme "desteklenmiyor" hatası verir (ADR-0022 §4).
final disaAktarmaCozucuProvider = Provider<DisaAktarmaCozucu>(
  (ref) => const OlmayanDisaAktarmaCozucu(),
  name: 'disaAktarmaCozucuProvider',
);
