import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/bildirim/bildirim.dart';
import 'package:tayfam/features/birebir/birebir.dart';

/// Sohbet sekmesinin okunmamış sayısı (rozet). Bugün yalnızca birebir
/// mesajlar (ADR-0018 §9); kanallar #63 ile eklenir. 0 iken rozet
/// gösterilmez.
final okunmamisSohbetSayisiProvider = Provider<int>(
  (ref) => ref.watch(birebirOkunmamisSayisiProvider),
  name: 'okunmamisSohbetSayisiProvider',
);

/// Bildirimler sekmesinin okunmamış sayısı (rozet; ADR-0018 §3). Sayı
/// bildirim özelliğinden gelir; okunamadıysa ya da henüz bilinmiyorsa 0'dır
/// ve 0 iken rozet gösterilmez.
final okunmamisBildirimSayisiProvider = Provider<int>(
  (ref) => ref.watch(okunmamisBildirimProvider).value ?? 0,
  name: 'okunmamisBildirimSayisiProvider',
);
