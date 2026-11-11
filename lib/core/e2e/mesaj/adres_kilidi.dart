import 'dart:async';

/// Anahtar başına async kilit: aynı anahtarla gelen işler sırayla, farklı
/// anahtarlar birbirini beklemeden çalışır (ADR-0020: aynı Signal adresi
/// için motor çağrıları ve depo yazmaları sıraya sokulur; libsignal
/// eşzamanlı işlemleri desteklemez).
final class AdresKilidi {
  final Map<String, Future<void>> _kuyruklar = {};

  /// [anahtar] için önceki işler bitince [islem]'i çalıştırır. Önceki işin
  /// hatası sonrakini etkilemez.
  Future<T> altinda<T>(String anahtar, Future<T> Function() islem) {
    final onceki = _kuyruklar[anahtar] ?? Future<void>.value();
    final tamam = Completer<void>();
    final kuyruk = tamam.future;
    _kuyruklar[anahtar] = kuyruk;
    Future<T> calistir() async {
      try {
        return await islem();
      } finally {
        tamam.complete();
        if (identical(_kuyruklar[anahtar], kuyruk)) {
          _kuyruklar.remove(anahtar);
        }
      }
    }

    return onceki.then((_) => calistir());
  }

  /// Bekleyen ya da süren iş var mı (test için).
  bool mesgulMu(String anahtar) => _kuyruklar.containsKey(anahtar);
}
