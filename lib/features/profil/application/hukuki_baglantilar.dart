import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/hesap.dart';

/// Bir hukuki metnin güncel sürümlü sayfasını bulur (ADR-0012 §4,
/// ADR-0018 §2).
typedef HukukiAdresBulucu = Future<Uri> Function(HukukiMetin metin);

/// Güncel sürümler `GET /v1/me/consents`'ten okunur, doğrulanır ve
/// `https://tayfam.app/yasal/<metin>/<sürüm>` adresi kurulur. Sürüm
/// geçersizse [FormatException]. Sonuç önbelleğe alınmaz; metin
/// güncellenince her zaman yeni sürüm açılır.
final hukukiAdresBulucuProvider = Provider<HukukiAdresBulucu>((ref) {
  final depo = ref.watch(hesapDeposuProvider);
  return (metin) async => (await depo.onaySurumleri()).adres(metin);
}, name: 'hukukiAdresBulucuProvider');
