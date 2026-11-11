import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';

/// "Güvenlik kodu değişti" denetimi (ADR-0020 "Uyarılar"; TOFU).
///
/// Konuşma açılınca karşı tarafın anahtar olayları
/// (`GET /v1/users/{id}/e2e/key-events`, son görülen olaydan sonrası) ve
/// cihaz listesinin son bilinen kümeyle farkı okunur. Kişiye ilk bakışta
/// yalnızca taban kaydedilir; satır çıkmaz.
final class E2eGuvenlikDenetcisi {
  E2eGuvenlikDenetcisi({
    required this.oturumlar,
    required ApiTransport api,
    DateTime Function()? saat,
  }) : _users = UsersApi(api),
       _saat = saat ?? DateTime.now;

  final E2eOturumlari oturumlar;
  final UsersApi _users;
  final DateTime Function() _saat;

  /// [kullaniciId] için yeni "güvenlik kodu değişti" satırları.
  Future<List<E2eSistemSatiri>> denetle(String kullaniciId) async {
    final depo = oturumlar.depo;
    final satirlar = <E2eSistemSatiri>[];
    final yanit = await _users.listE2EKeyEvents(
      userId: kullaniciId,
      pageSize: 50,
    );
    final olaylar = yanit.events;
    if (olaylar.isNotEmpty) {
      final son = depo.sonAnahtarOlayi(kullaniciId);
      await depo.sonAnahtarOlayiYaz(kullaniciId, olaylar.first.id);
      if (son != null) {
        for (final o in olaylar) {
          if (o.id == son) break;
          if (o.type == E2EKeyEventType.unknown) continue;
          satirlar.add(
            E2eSistemSatiri(
              kimlik: 'olay:${o.id}',
              tur: E2eSatirTuru.guvenlikKoduDegisti,
              zaman: o.createdAt,
            ),
          );
        }
      }
    }
    final cihazlar = await oturumlar.cihazlar(kullaniciId, tazele: true);
    final simdiki = {for (final c in cihazlar) c.id};
    final onceki = depo.karsiCihazlar(kullaniciId);
    await depo.karsiCihazlarYaz(kullaniciId, simdiki);
    if (onceki != null && !setEquals(onceki, simdiki) && satirlar.isEmpty) {
      final anahtar = (simdiki.toList()..sort()).join(',');
      satirlar.add(
        E2eSistemSatiri(
          kimlik: 'liste:$anahtar',
          tur: E2eSatirTuru.guvenlikKoduDegisti,
          zaman: _saat().toUtc(),
        ),
      );
    }
    return satirlar;
  }
}
