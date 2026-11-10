import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Tayfa kodunun paylaşılması ve panoya kopyalanması (ADR-0014 §5).
///
/// Paylaşılan metin log'a yazılmaz. Testlerde sahtesi verilir.
abstract interface class Paylasici {
  /// [metin]'i sistem paylaşım menüsüyle paylaşır. [konum], iPad'de
  /// menünün bağlanacağı düğmenin ekrandaki yeridir.
  Future<void> paylas(String metin, {Rect? konum});

  /// [metin]'i panoya kopyalar.
  Future<void> kopyala(String metin);
}

/// `share_plus` ve Flutter'ın panosu.
final class SistemPaylasici implements Paylasici {
  const SistemPaylasici();

  @override
  Future<void> paylas(String metin, {Rect? konum}) async {
    await SharePlus.instance.share(
      ShareParams(text: metin, sharePositionOrigin: konum),
    );
  }

  @override
  Future<void> kopyala(String metin) =>
      Clipboard.setData(ClipboardData(text: metin));
}

/// Uygulamanın paylaşıcısı.
final paylasiciProvider = Provider<Paylasici>(
  (ref) => const SistemPaylasici(),
  name: 'paylasiciProvider',
);
