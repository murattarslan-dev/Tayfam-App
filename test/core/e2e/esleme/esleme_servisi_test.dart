import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/esleme/esleme_qr.dart';
import 'package:tayfam/core/e2e/esleme/esleme_servisi.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';

import '../gecmis/sahteler.dart';

/// İki cihazın paylaştığı sahte sunucu: eşleştirme isteği ve cevabı.
final class _Sunucu {
  _Sunucu({Uint8List? listedekiBKimligi})
    : listedekiBKimligi = listedekiBKimligi ?? kimlik(2);

  final Uint8List listedekiBKimligi;
  bool suresiDoldu = false;
  bool yenilendi = false;
  String? cevap;
  int? cevapSurumu;
  String? cevaplayan;
  bool tamamlandi = false;

  Map<String, Object? Function(SahteIstek)> yanitlar(String cihaz) => {
    istekAc: (_) => {
      'link_request_id': istekId,
      'expires_at': '2026-11-11T19:10:00Z',
    },
    istekOku: (_) => suresiDoldu
        ? problem(ProblemType.e2eLinkRequestNotFound)
        : {
            'link_request_id': istekId,
            'expires_at': '2026-11-11T19:10:00Z',
            'answered': cevap != null,
            'answer': ?cevap,
            'history_key_version': ?cevapSurumu,
            'answered_by_device_id': ?cevaplayan,
          },
    istekCevapla: (i) {
      if (suresiDoldu) return problem(ProblemType.e2eLinkRequestNotFound);
      cevap = i.json['answer']! as String;
      cevapSurumu = i.json['history_key_version']! as int;
      cevaplayan = cihaz;
      return null;
    },
    istekTamamla: (_) {
      if (yenilendi) return problem(ProblemType.e2eHistoryKeyStale);
      tamamlandi = true;
      return cihazJson(cihazB, kimlik(2));
    },
    cihazlarUc: (_) => {
      'devices': [
        cihazJson(cihazA, kimlik(1)),
        cihazJson(cihazB, listedekiBKimligi, eslesmis: false),
      ],
    },
    paylasimlarUc: (_) => {'shares': <Object?>[]},
  };
}

/// Bir cihazın servis ve sahte bağımlılıkları.
final class _Cihaz {
  _Cihaz(
    _Sunucu sunucu,
    String cihaz, {
    required bool eslesmis,
    int kimlikNo = 1,
    Map<String, Uint8List>? paketKimlikleri,
  }) : tasima = SahteTasima(sunucu.yanitlar(cihaz)),
       kaynak = SahteKaynak(
         bilgi(
           cihaz: cihaz,
           eslesmis: eslesmis,
           baska: !eslesmis,
           surum: 2,
           kimlikNo: kimlikNo,
         ),
       ),
       oturum = SahteKendiOturum(cihaz, kimlikler: paketKimlikleri) {
    final api = GecmisApi(tasima);
    anahtarlar = GecmisAnahtariDeposu(depo);
    servis = EslemeServisi(
      api: api,
      oturum: oturum,
      anahtarlar: anahtarlar,
      kaynak: kaynak,
      paylasimAlici: PaylasimAlici(
        api: api,
        oturum: oturum,
        anahtarlar: anahtarlar,
      ),
    );
  }

  final SahteTasima tasima;
  final SahteKaynak kaynak;
  final SahteKendiOturum oturum;
  final BellekE2eDepo depo = BellekE2eDepo();
  late final GecmisAnahtariDeposu anahtarlar;
  late final EslemeServisi servis;
}

Matcher _hata(EslemeHataTuru tur) =>
    throwsA(isA<EslemeHatasi>().having((h) => h.tur, 'tur', tur));

void main() {
  late _Sunucu sunucu;
  late _Cihaz eski;
  late _Cihaz yeni;

  void kur({Uint8List? listedekiBKimligi, Uint8List? paketteBKimligi}) {
    sunucu = _Sunucu(listedekiBKimligi: listedekiBKimligi);
    eski = _Cihaz(
      sunucu,
      cihazA,
      eslesmis: true,
      paketKimlikleri: {cihazB: paketteBKimligi ?? kimlik(2)},
    );
    yeni = _Cihaz(sunucu, cihazB, eslesmis: false, kimlikNo: 2);
  }

  setUp(() async {
    kur();
    await eski.anahtarlar.yaz(1, anahtar(1));
    await eski.anahtarlar.yaz(2, anahtar(2));
  });

  test('iki cihaz: QR → cevap → çöz → anahtarlar yeni cihazda → tamamla', () async {
    final oturum = await yeni.servis.baslat();
    expect(oturum.qr.cihazId, cihazB);
    expect(oturum.qr.kimlikAnahtari, kimlik(2));
    expect(await yeni.servis.cevabiAl(oturum), isFalse);

    await eski.servis.cevapla(oturum.qr.kodla());
    expect(eski.oturum.sifrelenen, [cihazB]);
    expect(sunucu.cevapSurumu, 2);
    // Cevap opak: tür baytı + şifreli; QR kodu düz görünmez.
    final paket = base64.decode(sunucu.cevap!);
    expect(paket.first, 3);

    expect(await yeni.servis.cevabiAl(oturum), isTrue);
    expect(await yeni.anahtarlar.hepsi(), {1: anahtar(1), 2: anahtar(2)});
    expect(sunucu.tamamlandi, isTrue);
    expect(yeni.kaynak.tazelemeSayisi, 1);
  });

  test('QR\'daki kimlik sunucunun listesindekiyle aynı değilse hiçbir şey '
      'gönderilmez', () async {
    kur(listedekiBKimligi: kimlik(9));
    await eski.anahtarlar.yaz(2, anahtar(2));
    final oturum = await yeni.servis.baslat();
    await expectLater(
      eski.servis.cevapla(oturum.qr.kodla()),
      _hata(EslemeHataTuru.anahtarUyusmuyor),
    );
    expect(eski.oturum.sifrelenen, isEmpty);
    expect(sunucu.cevap, isNull);
  });

  test('ön anahtar paketindeki kimlik QR\'dakinden farklıysa reddedilir', () async {
    kur(paketteBKimligi: kimlik(9));
    await eski.anahtarlar.yaz(2, anahtar(2));
    final oturum = await yeni.servis.baslat();
    await expectLater(
      eski.servis.cevapla(oturum.qr.kodla()),
      _hata(EslemeHataTuru.anahtarUyusmuyor),
    );
    expect(sunucu.cevap, isNull);
  });

  test('listede olmayan cihaz ve kendi QR\'ı reddedilir', () async {
    final yabanci = EslemeQr(
      istekId: istekId,
      cihazId: cihazC,
      kimlikAnahtari: kimlik(3),
      kod: Uint8List(16),
    );
    await expectLater(
      eski.servis.cevapla(yabanci.kodla()),
      _hata(EslemeHataTuru.cihazBulunamadi),
    );
    final kendi = EslemeQr(
      istekId: istekId,
      cihazId: cihazA,
      kimlikAnahtari: kimlik(1),
      kod: Uint8List(16),
    );
    await expectLater(
      eski.servis.cevapla(kendi.kodla()),
      _hata(EslemeHataTuru.kendiCihazi),
    );
    await expectLater(
      eski.servis.cevapla('bozuk'),
      _hata(EslemeHataTuru.qrGecersiz),
    );
  });

  test('eşleştirilmemiş cihaz cevaplayamaz', () async {
    final oturum = await yeni.servis.baslat();
    await expectLater(
      yeni.servis.cevapla(oturum.qr.kodla()),
      _hata(EslemeHataTuru.eslestirilmemis),
    );
  });

  test('süresi dolmuş istek: cevap ve okuma suresiDoldu', () async {
    final oturum = await yeni.servis.baslat();
    sunucu.suresiDoldu = true;
    await expectLater(
      eski.servis.cevapla(oturum.qr.kodla()),
      _hata(EslemeHataTuru.suresiDoldu),
    );
    await expectLater(
      yeni.servis.cevabiAl(oturum),
      _hata(EslemeHataTuru.suresiDoldu),
    );
  });

  test('doğrulama kodu tutmazsa anahtarlar yazılmaz, tamamlanmaz', () async {
    final oturum = await yeni.servis.baslat();
    // QR'ı başka bir kodla (araya giren) cevaplamış gibi.
    final sahte = EslemeQr(
      istekId: oturum.qr.istekId,
      cihazId: oturum.qr.cihazId,
      kimlikAnahtari: oturum.qr.kimlikAnahtari,
      kod: Uint8List(16),
    );
    await eski.servis.cevapla(sahte.kodla());
    await expectLater(
      yeni.servis.cevabiAl(oturum),
      _hata(EslemeHataTuru.cevapGecersiz),
    );
    expect(await yeni.anahtarlar.hepsi(), isEmpty);
    expect(sunucu.tamamlandi, isFalse);
  });

  test('cevap çözülemezse cevapGecersiz', () async {
    final oturum = await yeni.servis.baslat();
    await eski.servis.cevapla(oturum.qr.kodla());
    yeni.oturum.cozmeHatasi = true;
    await expectLater(
      yeni.servis.cevabiAl(oturum),
      _hata(EslemeHataTuru.cevapGecersiz),
    );
    expect(await yeni.anahtarlar.hepsi(), isEmpty);
  });

  test('arada anahtar yenilendiyse anahtarYenilendi (yeni istek)', () async {
    final oturum = await yeni.servis.baslat();
    await eski.servis.cevapla(oturum.qr.kodla());
    sunucu.yenilendi = true;
    await expectLater(
      yeni.servis.cevabiAl(oturum),
      _hata(EslemeHataTuru.anahtarYenilendi),
    );
  });

  test('cevap düz metni: kod, istek ve bütün sürümler', () {
    final c = EslemeCevabi(
      kod: Uint8List(16),
      istekId: istekId,
      anahtarlar: {1: anahtar(1), 3: anahtar(3)},
    );
    final geri = EslemeCevabi.coz(c.kodla())!;
    expect(geri.istekId, istekId);
    expect(geri.anahtarlar, {1: anahtar(1), 3: anahtar(3)});
    expect(c.kodla().length % 160, 0);
    expect(c.toString(), isNot(contains(istekId)));
  });
}
