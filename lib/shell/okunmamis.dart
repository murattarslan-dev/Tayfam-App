import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sohbet sekmesinin okunmamış sayısı (rozet). GEÇİCİ: sohbet paketi
/// gerçek sayıyı bağlayana kadar 0; 0 iken rozet gösterilmez.
final okunmamisSohbetSayisiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisSohbetSayisiProvider',
);

/// Bildirimler sekmesinin okunmamış sayısı (rozet). GEÇİCİ: bildirim
/// paketi gerçek sayıyı bağlayana kadar 0; 0 iken rozet gösterilmez.
final okunmamisBildirimSayisiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisBildirimSayisiProvider',
);
