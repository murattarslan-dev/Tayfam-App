import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/sohbet/sohbet.dart';

/// Sohbet sekmesinin okunmamış sayısı (rozet; ADR-0003): aktif tayfanın
/// kanallarındaki okunmamış mesajlar (WebSocket olaylarıyla canlı;
/// ADR-0007). Birebir mesaj paketi kendi sayısını buraya ekler. 0 iken
/// rozet gösterilmez.
final okunmamisSohbetSayisiProvider = Provider<int>(
  (ref) => ref.watch(okunmamisKanalSayisiProvider),
  name: 'okunmamisSohbetSayisiProvider',
);

/// Bildirimler sekmesinin okunmamış sayısı (rozet). GEÇİCİ: bildirim
/// paketi gerçek sayıyı bağlayana kadar 0; 0 iken rozet gösterilmez.
final okunmamisBildirimSayisiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisBildirimSayisiProvider',
);
