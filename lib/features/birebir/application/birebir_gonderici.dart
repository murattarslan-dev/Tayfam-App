import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/e2e/ek/ek_servisi.dart';
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart' show E2eHazirDegil;
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/medya/goruntu_hazirlama.dart';
import 'package:tayfam/core/sohbet/giden_icerik.dart';

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
  required BirebirIcerik icerik,
  required String istekKimligi,
});

/// Birebir fotoğrafın şifreli ekini hazırlayan işlemler (istemci ADR-0028
/// §4); uygulamada [E2eEkServisi]. Testlerde sahtesi verilir.
abstract interface class BirebirEkIslemleri {
  /// Cihazın E2E'ye hazır olmasını bekler (hazır değilse yükleme yapılmaz).
  Future<void> hazirOl();

  /// Görüntüyü yeni bir anahtarla şifreler.
  Future<SifreliEk> sifrele(HazirGoruntu goruntu);

  /// Şifreli eki aynı [istekKimligi] ile yükler, zarf içeriğini döndürür.
  Future<FotografIcerigi> yukle({
    required HazirGoruntu goruntu,
    required SifreliEk ek,
    required String istekKimligi,
  });
}

final class _UygulamaEkIslemleri implements BirebirEkIslemleri {
  const _UygulamaEkIslemleri(this._e2e, this._servis);

  final E2eBirebir _e2e;
  final E2eEkServisi _servis;

  @override
  Future<void> hazirOl() => _e2e.hazirOl();

  @override
  Future<SifreliEk> sifrele(HazirGoruntu goruntu) => _servis.sifrele(goruntu);

  @override
  Future<FotografIcerigi> yukle({
    required HazirGoruntu goruntu,
    required SifreliEk ek,
    required String istekKimligi,
  }) => _servis.yukle(goruntu: goruntu, ek: ek, istekKimligi: istekKimligi);
}

/// Birebir mesajı sunucuya ileten tek nokta (ADR-0007 "Mesaj gönderimi"
/// birebir istisnası, ADR-0020, istemci ADR-0028 §4).
///
/// Birebir mesaj yalnızca uçtan uca şifreli gider (Tayfam-Api #151): her
/// zaman [E2eBirebir] üzerinden, yalnızca REST'ten (`envelopes`);
/// WebSocket'ten birebir mesaj gönderilmez ve düz metne geri düşülmez.
/// Tekrar gönderimde aynı istek kimliği kullanılır. E2E'nin olmadığı
/// derlemede (web geliştirme derlemesi, iOS köprüsü yazılana kadar iOS)
/// cihaz hazır olmadığı için gönderim hata fırlatır ve genel hata yolundan
/// "gönderilemedi" olur. İçerik hiçbir yere yazılmaz ve loglanmaz.
final class BirebirGonderici {
  const BirebirGonderici(this._gonderim, {this.ek});

  final SifreliGonderim _gonderim;

  /// Fotoğraf ekinin hazırlanması; verilmezse fotoğraf gönderilemez.
  final BirebirEkIslemleri? ek;

  /// [aliciId]'ye [icerik]'i gönderir. Aynı iş her denemede aynı
  /// [istekKimligi] ile gönderilir; sunucu ikinci mesaj açmaz.
  Future<BirebirGonderimi> gonder({
    required String aliciId,
    required BirebirIcerik icerik,
    required String istekKimligi,
  }) async {
    final g = await _gonderim(
      aliciId: aliciId,
      icerik: icerik,
      istekKimligi: istekKimligi,
    );
    return BirebirGonderimi(mesaj: g.message, konusma: g.conversation);
  }
}

/// Uygulamanın birebir mesaj göndericisi.
final birebirGondericiProvider = Provider<BirebirGonderici>((ref) {
  final e2e = ref.watch(e2eBirebirProvider);
  return BirebirGonderici(
    e2e.gonder,
    ek: _UygulamaEkIslemleri(e2e, ref.watch(e2eEkServisiProvider)),
  );
}, name: 'birebirGondericiProvider');

/// Bir kişiye giden birebir mesajların kuyruk grubu (aynı kişiye giden
/// mesajlar sırayla gider).
String birebirGrubu(String aliciId) => 'birebir:$aliciId';

/// Çevrimdışı kuyruktaki bir birebir mesaj (ADR-0006). İçerik yalnızca
/// bellektedir; bekleyen balonda gösterilir. E2E'de şifreleme kuyruktan
/// çıkınca, gönderim anında yapılır (ADR-0020).
///
/// Fotoğrafta iş, görüntüyü bir kez şifreler ve aynı yükleme kimliğiyle
/// bir kez yükler; ikisi de iş boyunca bellekte tutulur, tekrar denemede
/// aynı ek (aynı anahtar ve blob) gider (istemci ADR-0028 §4).
final class BirebirMesajIsi extends KuyrukIsi {
  BirebirMesajIsi({
    required this.aliciId,
    required this.icerik,
    required this.istekKimligi,
    required this._gonderici,
  });

  /// Yazılan kişi.
  final String aliciId;

  /// Metin, fotoğraf ya da yer.
  final GidenIcerik icerik;

  @override
  final String istekKimligi;

  final BirebirGonderici _gonderici;

  SifreliEk? _sifreli;
  FotografIcerigi? _ek;

  @override
  String get grup => birebirGrubu(aliciId);

  @override
  Future<BirebirGonderimi> gonder() async => _gonderici.gonder(
    aliciId: aliciId,
    icerik: await _zarfIcerigi(),
    istekKimligi: istekKimligi,
  );

  Future<BirebirIcerik> _zarfIcerigi() async {
    switch (icerik) {
      case GidenMetin(:final metin):
        return MetinIcerigi(metin);
      case GidenYer(:final yer):
        return YerIcerigi(yer);
      case GidenFotograf(:final goruntu, :final yuklemeKimligi):
        final hazir = _ek;
        if (hazir != null) return hazir;
        final islemler = _gonderici.ek;
        if (islemler == null) throw const E2eHazirDegil();
        await islemler.hazirOl();
        final sifreli = _sifreli ??= await islemler.sifrele(goruntu);
        return _ek = await islemler.yukle(
          goruntu: goruntu,
          ek: sifreli,
          istekKimligi: yuklemeKimligi,
        );
    }
  }
}
