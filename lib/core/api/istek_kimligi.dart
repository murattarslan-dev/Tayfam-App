import 'dart:math';

import 'package:flutter/foundation.dart';

/// Oluşturma isteklerinin `client_request_id`'si için UUID v4 üretir
/// (RFC 9562; ADR-0005, 2026-11-10 notu).
///
/// Sözleşmede alan istek modelinin zorunlu alanıdır, bu yüzden `ApiClient`
/// koyamaz: id'yi işi oluşturan katman (application / çevrimdışı kuyruk)
/// iş oluşturulurken bir kez üretir ve aynı iş her tekrar gönderiminde aynı
/// id'yle gider. Rastgelelik yalnızca `Random.secure()`'dan gelir (CLAUDE.md
/// kesin kural 4).
String yeniIstekKimligi() => uuidV4(Random.secure());

/// [rastgele]'den 16 bayt alıp UUID v4 biçimine getirir. Uygulama kodu
/// [yeniIstekKimligi]'ni kullanır; bu fonksiyon testte bit düzenini
/// sınamak içindir.
@visibleForTesting
String uuidV4(Random rastgele) {
  final baytlar = List<int>.generate(16, (_) => rastgele.nextInt(256));
  baytlar[6] = (baytlar[6] & 0x0f) | 0x40; // sürüm 4
  baytlar[8] = (baytlar[8] & 0x3f) | 0x80; // RFC 9562 variant (10xx)
  final hex = [for (final b in baytlar) b.toRadixString(16).padLeft(2, '0')];
  return '${hex.sublist(0, 4).join()}-'
      '${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-'
      '${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10, 16).join()}';
}
