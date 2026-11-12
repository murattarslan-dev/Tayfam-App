import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

/// Zarf işlemenin sonucu.
enum ZarfSonucu {
  /// Çözüldü; içerik bellekte.
  cozuldu,

  /// Daha önce işlenmişti (tekrar teslim).
  tekrar,

  /// Çözülemedi; konuşmaya "bir mesaj çözülemedi" satırı eklendi.
  cozulemedi,
}

/// Gelen zarfları işleyen tek nokta (ADR-0020 "Alım").
///
/// Sıra: zarf kimliğiyle tekrar ayıklama → (gönderen cihazın kilidi
/// altında) çöz → oturum ve ön anahtar tüketimi depoya → "görüldü"
/// işareti depoya → içerik belleğe → **sonra** onay (ack). Depoya
/// yazılamazsa zarf onaylanmaz; sunucu yeniden teslim eder.
///
/// Çözülemeyen zarf düşürülür ve onaylanır (oturum sıfırlanmaz);
/// konuşmada "bir mesaj çözülemedi" satırı görünür.
final class E2eAlici {
  E2eAlici({
    required this.oturumlar,
    required ApiTransport api,
    required this.icerikEkle,
    required this.cozulemedi,
    required this.onayla,
    this.yayin,
  }) : _me = MeApi(api);

  /// REST'ten bir seferde çekilen zarf sayısı (sözleşme: en çok 100).
  static const int sayfaBoyutu = 100;

  /// Bir çekmede en çok tur (sonsuz döngüye karşı).
  static const int enCokTur = 20;

  final E2eOturumlari oturumlar;
  final MeApi _me;

  /// Çözülen içeriği belleğe ekler.
  final void Function(CozulmusBirebirMesaj mesaj) icerikEkle;

  /// Çözülemeyen zarf için konuşmaya satır ekler.
  final void Function(String konusmaId, E2eSistemSatiri satir) cozulemedi;

  /// Zarfları onaylar: WebSocket açıksa `dm.envelope_ack`, değilse REST.
  final Future<void> Function(List<String> zarfIdleri) onayla;

  /// Çözülen mesajın geçmiş arşivine yazılması için yayın (E3).
  final E2eMesajYayini? yayin;

  E2eDeposu get _depo => oturumlar.depo;

  /// Bu çalışmada işlenen zarf kimlikleri (depodakine ek, hızlı yol).
  final Set<String> _islenen = {};

  Future<void>? _cekme;

  /// WebSocket'ten gelen tek zarf: işlenir ve onaylanır.
  Future<ZarfSonucu> zarfGeldi(E2EEnvelope zarf) async {
    final sonuc = await isle(zarf);
    await _sessizOnayla([zarf.id]);
    return sonuc;
  }

  /// Bekleyen zarfları REST'ten çeker (açılışta ve yeniden bağlanınca).
  /// Süren bir çekme varsa onu bekler.
  Future<void> cek() => _cekme ??= _cek().whenComplete(() => _cekme = null);

  Future<void> _cek() async {
    for (var tur = 0; tur < enCokTur; tur++) {
      final liste = await _me.listE2EEnvelopes(pageSize: sayfaBoyutu);
      if (liste.envelopes.isEmpty) return;
      final onaylanacak = <String>[];
      for (final z in liste.envelopes) {
        try {
          await isle(z);
          onaylanacak.add(z.id);
        } on E2eDepoHatasi {
          // Onaylanmaz; sonra yeniden teslim edilir.
        }
      }
      if (onaylanacak.isEmpty) return;
      await _sessizOnayla(onaylanacak);
    }
  }

  Future<void> _sessizOnayla(List<String> idler) async {
    try {
      await onayla(idler);
    } on Exception {
      // Onaylanamayan zarf yeniden gelir; kimliğiyle ayıklanır.
    }
  }

  /// Zarfı işler (onaylamaz). Depoya yazılamazsa [E2eDepoHatasi].
  Future<ZarfSonucu> isle(E2EEnvelope z) {
    if (_islenen.contains(z.id)) return Future.value(ZarfSonucu.tekrar);
    return oturumlar.kilit.altinda(z.senderDeviceId, () async {
      if (_islenen.contains(z.id) || _depo.gorulenZarflar.contains(z.id)) {
        _islenen.add(z.id);
        return ZarfSonucu.tekrar;
      }
      String? metin;
      var eski = false;
      try {
        metin = zarfIcerigiCoz(await oturumlar.coz(z));
      } on SignalHatasi catch (hata) {
        eski = hata.tur == SignalHatasiTuru.eskiMesaj;
      } on E2eHazirDegil {
        metin = null;
      } on FormatException {
        metin = null;
      }
      if (!await _depo.gorulduYaz(z.id)) throw const E2eDepoHatasi();
      _islenen.add(z.id);
      if (eski) return ZarfSonucu.tekrar;
      if (metin == null) {
        cozulemedi(
          z.conversationId,
          E2eSistemSatiri(
            kimlik: 'zarf:${z.id}',
            tur: E2eSatirTuru.mesajCozulemedi,
            zaman: z.createdAt,
          ),
        );
        return ZarfSonucu.cozulemedi;
      }
      final icerik = CozulmusBirebirMesaj(
        mesajId: z.messageId,
        konusmaId: z.conversationId,
        gonderenKullaniciId: z.senderUserId,
        metin: metin,
        olusturma: z.createdAt,
        kaynak: CozulmusMesajKaynagi.zarf,
      );
      icerikEkle(icerik);
      yayin?.yay(icerik);
      return ZarfSonucu.cozuldu;
    });
  }
}
