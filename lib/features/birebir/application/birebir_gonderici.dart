import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
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

/// Birebir mesajı sunucuya ileten tek nokta (ADR-0007 "Mesaj gönderimi",
/// ADR-0020).
///
/// Mobilde ([E2eBirebir] verildiyse) mesaj uçtan uca şifrelenir ve
/// yalnızca REST'ten (`envelopes`) gider; WebSocket'ten zarflı gönderim
/// yoktur ve düz metne geri düşülmez. Web geliştirme derlemesinde düz
/// sürüm kalır: bağlantı açıksa `dm.send` çerçevesiyle gönderilir;
/// bağlantı kapalıysa, cevap gelmeden koparsa ya da 10 saniyede cevap
/// gelmezse aynı
/// [istekKimligi] ile REST'e (`POST /v1/direct-messages`) düşülür.
/// Sunucunun hata çerçevesi kesin cevaptır, REST'e düşülmez. Metin hiçbir
/// yere yazılmaz ve loglanmaz.
final class BirebirGonderici {
  const BirebirGonderici(this._realtime, this._depo, [this._e2e]);

  final RealtimeIstemcisi _realtime;
  final BirebirDeposu _depo;
  final E2eBirebir? _e2e;

  /// [aliciId]'ye [metin]'i gönderir. Aynı iş her denemede aynı
  /// [istekKimligi] ile gönderilir; sunucu ikinci mesaj açmaz.
  Future<BirebirGonderimi> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    if (_e2e case final e2e?) {
      final g = await e2e.gonder(
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
    ref.watch(e2eEtkinProvider) ? ref.watch(e2eBirebirProvider) : null,
  ),
  name: 'birebirGondericiProvider',
);

/// Bir kişiye giden birebir mesajların kuyruk grubu (aynı kişiye giden
/// mesajlar sırayla gider).
String birebirGrubu(String aliciId) => 'birebir:$aliciId';

/// Çevrimdışı kuyruktaki bir birebir mesaj (ADR-0006). Düz metin yalnızca
/// bellektedir; bekleyen balonda gösterilir. E2E'de şifreleme kuyruktan
/// çıkınca, gönderim anında yapılır (ADR-0020).
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
