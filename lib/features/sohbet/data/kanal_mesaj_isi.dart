import 'dart:async';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';

/// Bir kanal mesajının kuyruk grubu.
String kanalGrubu(String kanalId) => 'kanal:$kanalId';

/// Çevrimdışı kuyruktaki bir kanal mesajı (ADR-0006, ADR-0007).
///
/// Bağlantı açıksa `send` çerçevesiyle gönderilir; bağlantı kapalıysa,
/// cevap gelmeden koparsa ya da 10 saniyede cevap gelmezse aynı
/// `client_request_id` ile REST'e düşülür. Sunucunun hata çerçevesi
/// (`slow_mode`, `muted` …) kesin cevaptır, REST'e düşülmez. Metin hiçbir
/// yere yazılmaz ve loglanmaz.
final class KanalMesajIsi extends KuyrukIsi {
  KanalMesajIsi({
    required this.tayfaId,
    required this.kanalId,
    required this.metin,
    required this.istekKimligi,
    required this._realtime,
    required this._depo,
  });

  final String tayfaId;
  final String kanalId;

  /// Mesaj metni (yalnızca bellekte; bekleyen balonda gösterilir).
  final String metin;

  @override
  final String istekKimligi;

  final RealtimeIstemcisi _realtime;
  final KanalDeposu _depo;

  @override
  String get grup => kanalGrubu(kanalId);

  @override
  Future<ChannelMessage> gonder() async {
    if (_realtime.durum == RealtimeDurumu.acik) {
      try {
        return await _realtime.kanalaGonder(
          tayfaId: tayfaId,
          kanalId: kanalId,
          metin: metin,
          istekKimligi: istekKimligi,
        );
      } on RealtimeKapali {
        // REST'e düşülür.
      } on TimeoutException {
        // REST'e düşülür.
      }
    }
    return _depo.gonder(
      tayfaId,
      kanalId,
      ChannelMessageCreateRequest(body: metin, clientRequestId: istekKimligi),
    );
  }
}
