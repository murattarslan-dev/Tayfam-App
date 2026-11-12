import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';

/// Gönderilen birebir mesaj ve gönderenin gözünden konuşmanın tamamı
/// (`POST /v1/direct-messages` cevabı).
@immutable
final class BirebirGonderimi {
  const BirebirGonderimi({required this.mesaj, required this.konusma});

  final DirectMessage mesaj;

  final Conversation konusma;
}

/// Şifreleyip `POST /v1/direct-messages` (`envelopes`) ile gönderen işlev;
/// uygulamada [E2eBirebir.gonder].
typedef SifreliGonderim = Future<DirectMessageSent> Function({
  required String aliciId,
  required String metin,
  required String istekKimligi,
});

/// Birebir mesajı sunucuya ileten tek nokta (ADR-0007 "Mesaj gönderimi"
/// birebir istisnası, ADR-0020).
///
/// Birebir mesaj yalnızca uçtan uca şifreli gider (Tayfam-Api #151): her
/// zaman [E2eBirebir] üzerinden, yalnızca REST'ten (`envelopes`);
/// WebSocket'ten birebir mesaj gönderilmez ve düz metne geri düşülmez.
/// Tekrar gönderimde aynı istek kimliği kullanılır. E2E'nin olmadığı
/// derlemede (web geliştirme derlemesi, iOS köprüsü yazılana kadar iOS)
/// cihaz hazır olmadığı için gönderim hata fırlatır ve genel hata yolundan
/// "gönderilemedi" olur. Metin hiçbir yere yazılmaz ve loglanmaz.
final class BirebirGonderici {
  const BirebirGonderici(this._gonderim);

  final SifreliGonderim _gonderim;

  /// [aliciId]'ye [metin]'i gönderir. Aynı iş her denemede aynı
  /// [istekKimligi] ile gönderilir; sunucu ikinci mesaj açmaz.
  Future<BirebirGonderimi> gonder({
    required String aliciId,
    required String metin,
    required String istekKimligi,
  }) async {
    final g = await _gonderim(
      aliciId: aliciId,
      metin: metin,
      istekKimligi: istekKimligi,
    );
    return BirebirGonderimi(mesaj: g.message, konusma: g.conversation);
  }
}

/// Uygulamanın birebir mesaj göndericisi.
final birebirGondericiProvider = Provider<BirebirGonderici>(
  (ref) => BirebirGonderici(ref.watch(e2eBirebirProvider).gonder),
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
