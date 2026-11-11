import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';

/// Gönderilen birebir mesaj ve gönderenin gözünden konuşmanın durumu.
/// REST'ten gidildiyse konuşmanın tamamı da vardır ([konusma]);
/// WebSocket `dm.sent` yalnızca durumu döndürür.
@immutable
final class BirebirGonderimi {
  const BirebirGonderimi({
    required this.mesaj,
    required this.durum,
    this.konusma,
  });

  final DirectMessage mesaj;

  final ConversationStatus durum;

  final Conversation? konusma;
}

/// Birebir mesajı sunucuya ileten tek nokta (ADR-0007 "Mesaj gönderimi").
///
/// Bağlantı açıksa `dm.send` çerçevesiyle gönderilir; bağlantı kapalıysa,
/// cevap gelmeden koparsa ya da 10 saniyede cevap gelmezse aynı
/// [istekKimligi] ile REST'e (`POST /v1/direct-messages`) düşülür.
/// Sunucunun hata çerçevesi kesin cevaptır, REST'e düşülmez. Metin hiçbir
/// yere yazılmaz ve loglanmaz.
final class BirebirGonderici {
  const BirebirGonderici(this._realtime, this._depo);

  final RealtimeIstemcisi _realtime;
  final BirebirDeposu _depo;

  /// [aliciId]'ye [metin]'i gönderir. Aynı iş her denemede aynı
  /// [istekKimligi] ile gönderilir; sunucu ikinci mesaj açmaz.
  Future<BirebirGonderimi> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    if (_realtime.durum == RealtimeDurumu.acik) {
      try {
        final g = await _realtime.dmGonder(
          aliciId: aliciId,
          metin: metin,
          istekKimligi: istekKimligi,
        );
        return BirebirGonderimi(mesaj: g.mesaj, durum: g.konusmaDurumu);
      } on RealtimeKapali {
        // REST'e düşülür.
      } on TimeoutException {
        // REST'e düşülür.
      }
    }
    final g = await _depo.gonder(
      aliciId: aliciId,
      metin: metin,
      istekKimligi: istekKimligi,
    );
    return BirebirGonderimi(
      mesaj: g.message,
      durum: g.conversation.status,
      konusma: g.conversation,
    );
  }
}

/// Uygulamanın birebir mesaj göndericisi.
final birebirGondericiProvider = Provider<BirebirGonderici>(
  (ref) => BirebirGonderici(
    ref.watch(realtimeIstemcisiProvider),
    ref.watch(birebirDeposuProvider),
  ),
  name: 'birebirGondericiProvider',
);

/// Bir kişiye giden birebir mesajların kuyruk grubu (aynı kişiye giden
/// mesajlar sırayla gider).
String birebirGrubu(String aliciId) => 'birebir:$aliciId';

/// Çevrimdışı kuyruktaki bir birebir mesaj (ADR-0006: düz sürüm kuyruğa
/// girer). Metin yalnızca bellektedir; bekleyen balonda gösterilir.
final class BirebirMesajIsi extends KuyrukIsi {
  BirebirMesajIsi({
    required this.aliciId,
    required this.metin,
    required this.istekKimligi,
    required this._gonderici,
  });

  /// Yazılan kişi.
  final String aliciId;

  /// Mesaj metni.
  final String metin;

  @override
  final String istekKimligi;

  final BirebirGonderici _gonderici;

  @override
  String get grup => birebirGrubu(aliciId);

  @override
  Future<BirebirGonderimi> gonder() => _gonderici.gonder(
    aliciId: aliciId,
    metin: metin,
    istekKimligi: istekKimligi,
  );
}
