import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';

/// Birebir mesajı sunucuya ileten tek nokta (ADR-0007 "Mesaj gönderimi").
///
/// Bugün yalnızca REST'tir (`POST /v1/direct-messages`). WebSocket
/// (`core/realtime/`) ve çevrimdışı kuyruk geldiğinde yalnızca bu
/// provider değişir: bağlantı açıksa `dm.send`, kapalıysa ya da 10
/// saniyede cevap gelmezse aynı [istekKimligi] ile REST. Ekranlar ve
/// notifier'lar bu arayüzü kullanır; hangi yoldan gidildiğini bilmez.
abstract interface class BirebirGonderici {
  /// [aliciId]'ye [metin]'i gönderir. Aynı iş her denemede aynı
  /// [istekKimligi] ile gönderilir; sunucu ikinci mesaj açmaz.
  Future<DirectMessageSent> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  });
}

/// REST ile gönderen [BirebirGonderici].
final class RestBirebirGonderici implements BirebirGonderici {
  const RestBirebirGonderici(this._depo);

  final BirebirDeposu _depo;

  @override
  Future<DirectMessageSent> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) => _depo.gonder(aliciId: aliciId, metin: metin, istekKimligi: istekKimligi);
}

/// Uygulamanın birebir mesaj göndericisi.
final birebirGondericiProvider = Provider<BirebirGonderici>(
  (ref) => RestBirebirGonderici(ref.watch(birebirDeposuProvider)),
  name: 'birebirGondericiProvider',
);
