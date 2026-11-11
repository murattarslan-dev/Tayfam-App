import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/birebir/birebir.dart';

/// Sohbet sekmesinin okunmamış sayısı (rozet). Bugün yalnızca birebir
/// mesajlar (ADR-0018 §9); kanallar #63 ile eklenir. 0 iken rozet
/// gösterilmez.
final okunmamisSohbetSayisiProvider = Provider<int>(
  (ref) => ref.watch(birebirOkunmamisSayisiProvider),
  name: 'okunmamisSohbetSayisiProvider',
);

/// Bildirimler sekmesinin okunmamış sayısı (rozet). GEÇİCİ: bildirim
/// paketi gerçek sayıyı bağlayana kadar 0; 0 iken rozet gösterilmez.
final okunmamisBildirimSayisiProvider = Provider<int>(
  (ref) => 0,
  name: 'okunmamisBildirimSayisiProvider',
);
