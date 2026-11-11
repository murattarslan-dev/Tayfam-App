import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

/// Mağazanın uygulama içi değerlendirme penceresi (ADR-0016 §4): Android'de
/// Play In-App Review, iOS'ta `SKStoreReviewController`.
///
/// Pencerenin gösterilip gösterilmeyeceğine mağaza karar verir, kota
/// uygular ve sonucu bildirmez; bu yüzden [iste] bir sonuç döndürmez.
/// Mağaza sayfasını açmak (kendi ön sorumuzla birlikte) kullanılmaz.
abstract interface class MagazaDegerlendirmesi {
  /// Pencere bu cihazda istenebilir mi (ör. Play hizmetleri var mı).
  Future<bool> kullanilabilirMi();

  /// Mağazadan pencereyi ister.
  Future<void> iste();
}

/// `in_app_review` paketiyle mağaza penceresi.
final class PaketMagazaDegerlendirmesi implements MagazaDegerlendirmesi {
  PaketMagazaDegerlendirmesi([InAppReview? paket])
    : _paket = paket ?? InAppReview.instance;

  final InAppReview _paket;

  @override
  Future<bool> kullanilabilirMi() => _paket.isAvailable();

  @override
  Future<void> iste() => _paket.requestReview();
}

/// Web geliştirme derlemesi: mağaza yoktur, hiçbir şey istenmez
/// (ADR-0011).
final class OlmayanMagazaDegerlendirmesi implements MagazaDegerlendirmesi {
  const OlmayanMagazaDegerlendirmesi();

  @override
  Future<bool> kullanilabilirMi() async => false;

  @override
  Future<void> iste() async {}
}

/// Platforma göre mağaza penceresi: web'de yok, mobilde paket.
final magazaDegerlendirmesiProvider = Provider<MagazaDegerlendirmesi>(
  _platformMagazasi,
  name: 'magazaDegerlendirmesiProvider',
);

MagazaDegerlendirmesi _platformMagazasi(Ref ref) {
  if (kIsWeb) return const OlmayanMagazaDegerlendirmesi();
  return PaketMagazaDegerlendirmesi();
}
