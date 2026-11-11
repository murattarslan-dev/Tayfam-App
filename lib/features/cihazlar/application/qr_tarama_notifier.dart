import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/e2e/esleme/esleme_servisi.dart';

/// "Cihaz bağla" (QR okutma) ekranının durumu.
sealed class QrTaramaDurumu {
  const QrTaramaDurumu();
}

/// Kamera açık, QR bekleniyor.
final class QrTaraniyor extends QrTaramaDurumu {
  const QrTaraniyor();
}

/// QR okundu; doğrulanıp cevap gönderiliyor.
final class QrIsleniyor extends QrTaramaDurumu {
  const QrIsleniyor();
}

/// Cevap gönderildi; yeni cihaz eşleşmeyi kendisi tamamlar.
final class QrGonderildi extends QrTaramaDurumu {
  const QrGonderildi();
}

/// Kamera izni verilmedi.
final class QrKameraIzniYok extends QrTaramaDurumu {
  const QrKameraIzniYok();
}

/// Kamera açılamadı (izin dışı bir neden).
final class QrKameraAcilamadi extends QrTaramaDurumu {
  const QrKameraAcilamadi();
}

/// QR geçersiz ya da cevap gönderilemedi.
final class QrTaramaHatasi extends QrTaramaDurumu {
  const QrTaramaHatasi(this.hata);

  final Object hata;
}

/// Eşleştirilmiş cihaz: okunan QR'ı doğrular ve cevaplar. Bir QR
/// işlenirken yeni okumalar yok sayılır.
final class QrTaramaNotifier extends Notifier<QrTaramaDurumu> {
  @override
  QrTaramaDurumu build() => const QrTaraniyor();

  /// Kamera bir QR okudu.
  Future<void> kodOkundu(String metin) async {
    if (state is! QrTaraniyor) return;
    state = const QrIsleniyor();
    try {
      await ref.read(eslemeServisiProvider).cevapla(metin);
      if (ref.mounted) state = const QrGonderildi();
    } on Exception catch (hata) {
      if (ref.mounted) state = QrTaramaHatasi(hata);
    }
  }

  /// Kamera izni reddedildi.
  void izinReddedildi() => state = const QrKameraIzniYok();

  /// Kamera başka bir nedenle açılamadı.
  void kameraAcilamadi() => state = const QrKameraAcilamadi();

  /// Yeniden taramaya döner.
  void tekrarTara() => state = const QrTaraniyor();
}

/// "Cihaz bağla" ekranının durumu.
final qrTaramaProvider =
    NotifierProvider.autoDispose<QrTaramaNotifier, QrTaramaDurumu>(
      QrTaramaNotifier.new,
      name: 'qrTaramaProvider',
    );
