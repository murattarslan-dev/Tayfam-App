import 'package:tayfam/core/e2e/cihaz/e2e_cihaz_yoneticisi.dart';
import 'package:tayfam/core/e2e/depo/e2e_anahtar_deposu.dart';
import 'package:tayfam/core/e2e/depo/e2e_deposu.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_alici.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_gonderici.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_guvenlik.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_oturumlari.dart';

import 'sahte_e2e_sunucu.dart';
import 'signal/sahte_signal_motoru.dart';

/// Bir kullanıcının bir cihazındaki E2E çekirdeği (Riverpod'suz):
/// bellek deposu, sahte Signal motoru ve sahte sunucu taşıması.
final class SahteE2eIstemcisi {
  SahteE2eIstemcisi(
    this.sunucu,
    this.kullaniciId, {
    int tohum = 1,
    BellekE2eAnahtarDeposu? ham,
  }) : ham = ham ?? BellekE2eAnahtarDeposu(),
       motor = SahteSignalMotoru(tohum: tohum) {
    tasima = sunucu.istemci(kullaniciId);
    depo = E2eDeposu(this.ham);
    yonetici = E2eCihazYoneticisi(
      motor: motor,
      depo: depo,
      api: tasima,
      saat: () => simdi,
    );
    oturumlar = E2eOturumlari(
      motor: motor,
      depo: depo,
      api: tasima,
      guvenlikDegisti: (k, kimlik) => guvenlikUyarilari.add('$k:$kimlik'),
    );
    gonderici = E2eGonderici(
      oturumlar: oturumlar,
      api: tasima,
      kullaniciKimligi: () async => kullaniciId,
      cihazKimligi: () => depo.cihaz?.id,
      yayin: yayin,
    );
    alici = E2eAlici(
      oturumlar: oturumlar,
      api: tasima,
      icerikEkle: alinanlar.add,
      cozulemedi: (k, s) => cozulemeyenler.add((k, s)),
      onayla: (idler) async {
        onaylar.add(idler);
        this.ham.islemler.add('ack');
        await tasima.send(
          method: 'POST',
          pathTemplate: '/v1/me/e2e/envelopes/ack',
          authenticated: true,
          body: {'envelope_ids': idler},
        );
      },
      yayin: yayin,
    );
    guvenlik = E2eGuvenlikDenetcisi(
      oturumlar: oturumlar,
      api: tasima,
      saat: () => simdi,
    );
  }

  final SahteE2eSunucu sunucu;
  final String kullaniciId;
  final BellekE2eAnahtarDeposu ham;
  final SahteSignalMotoru motor;
  late final SahteE2eTasima tasima;
  late final E2eDeposu depo;
  late final E2eCihazYoneticisi yonetici;
  late final E2eOturumlari oturumlar;
  late final E2eGonderici gonderici;
  late final E2eAlici alici;
  late final E2eGuvenlikDenetcisi guvenlik;

  final E2eMesajYayini yayin = E2eMesajYayini();
  final List<CozulmusBirebirMesaj> alinanlar = [];
  final List<(String, E2eSistemSatiri)> cozulemeyenler = [];
  final List<List<String>> onaylar = [];
  final List<String> guvenlikUyarilari = [];

  DateTime simdi = DateTime.utc(2026, 11, 11, 12);

  int _istekSayaci = 0;

  /// Cihazı kaydeder ya da hazırlar.
  Future<E2eCihazBilgisi> hazirla() => yonetici.hazirla();

  /// [aliciId]'ye gönderir.
  Future<CozulmusBirebirMesaj> gonder(
    String aliciId,
    String metin, {
    String? istek,
  }) async {
    final no = (++_istekSayaci).toString().padLeft(12, '0');
    final (_, icerik) = await gonderici.gonder(
      aliciId: aliciId,
      metin: metin,
      istekKimligi: istek ?? '9a000000-0000-4000-8000-$no',
    );
    return icerik;
  }

  /// Bekleyen zarfları çeker.
  Future<void> cek() => alici.cek();

  /// Sunucuda bu cihaza bekleyen zarf sayısı.
  int get bekleyenZarf => sunucu.oturumCihazi(tasima.oturum)!.zarflar.length;
}
