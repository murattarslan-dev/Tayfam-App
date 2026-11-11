import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/bildirim/bildirim.dart';

/// Sohbet sekmesinin okunmamış sayısı (rozet). GEÇİCİ: sohbet paketi
/// gerçek sayıyı bağlayana kadar 0; 0 iken rozet gösterilmez.
final okunmamisSohbetSayisiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisSohbetSayisiProvider',
);

/// Bildirimler sekmesinin okunmamış sayısı (rozet; ADR-0018 §3). Sayı
/// bildirim özelliğinden gelir; okunamadıysa ya da henüz bilinmiyorsa 0'dır
/// ve 0 iken rozet gösterilmez.
final okunmamisBildirimSayisiProvider = Provider<int>(
  (ref) => ref.watch(okunmamisBildirimProvider).value ?? 0,
  name: 'okunmamisBildirimSayisiProvider',
);
