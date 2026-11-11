import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_yenileme.dart';
import 'package:tayfam/core/e2e/gecmis/ilk_cihaz.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';

import '../signal/sahte_signal_motoru.dart';
import 'sahteler.dart';

Map<String, Object?> _paylasim(
  String id,
  String gonderen,
  int surum,
  Uint8List paket,
) => {
  'id': id,
  'sender_device_id': gonderen,
  'history_key_version': surum,
  'bundle': base64.encode(paket),
  'created_at': '2026-11-11T18:00:00Z',
};

void main() {
  group('İlk cihaz (ClaimHistoryKey)', () {
    late SahteTasima tasima;
    late SahteKaynak kaynak;
    late BellekE2eDepo depo;
    late GecmisAnahtariDeposu anahtarlar;
    late IlkCihazKurulumu kurulum;

    void kur(E2eBilgisiUretici b, Object? Function(SahteIstek) cevap) {
      tasima = SahteTasima({anahtarAl: cevap});
      kaynak = SahteKaynak(b());
      depo = BellekE2eDepo();
      anahtarlar = GecmisAnahtariDeposu(depo);
      kurulum = IlkCihazKurulumu(
        api: GecmisApi(tasima),
        anahtarlar: anahtarlar,
        kaynak: kaynak,
      );
    }

    test('eşleştirilmiş cihaz yoksa 32 bayt üretilir, depoya yazılır, '
        'sürüm bildirilir', () async {
      kur(() => bilgi(eslesmis: false, surum: 0), (_) => {'history_key_version': 1});
      final sonuc = await kurulum.kur();
      expect(sonuc, isA<IlkCihazAnahtarAldi>());
      expect((sonuc as IlkCihazAnahtarAldi).eskiArsivOkunamaz, isFalse);
      final hepsi = await anahtarlar.hepsi();
      expect(hepsi.keys, [1]);
      expect(hepsi[1], hasLength(32));
      expect(hepsi[1], isNot(Uint8List(32)));
      expect(kaynak.tazelemeSayisi, 1);
    });

    test('önceki sürüm varsa eski arşiv bu cihazda okunamaz', () async {
      kur(() => bilgi(eslesmis: false, surum: 3), (_) => {'history_key_version': 4});
      final sonuc = await kurulum.kur() as IlkCihazAnahtarAldi;
      expect(sonuc.eskiArsivOkunamaz, isTrue);
      expect((await anahtarlar.hepsi()).keys, [4]);
    });

    test('sunucu başka sürüm verirse anahtar o sürüme taşınır', () async {
      kur(() => bilgi(eslesmis: false, surum: 3), (_) => {'history_key_version': 5});
      await kurulum.kur();
      expect((await anahtarlar.hepsi()).keys, [5]);
    });

    test('e2e-paired-device-exists → QR gerekli, aday silinir', () async {
      kur(
        () => bilgi(eslesmis: false, surum: 2),
        (_) => problem(ProblemType.e2ePairedDeviceExists),
      );
      expect(await kurulum.kur(), isA<IlkCihazQrGerekli>());
      expect(await anahtarlar.hepsi(), isEmpty);
    });

    test('bağlantı koparsa aday anahtar korunur (sunucu kabul etmiş '
        'olabilir)', () async {
      kur(() => bilgi(eslesmis: false, surum: 0), (_) => const ApiOffline());
      await expectLater(kurulum.kur(), throwsA(isA<ApiOffline>()));
      expect((await anahtarlar.hepsi()).keys, [1]);
    });

    test('eşleştirilmiş cihaz ya da başka eşleştirilmiş cihaz varken istek '
        'atılmaz', () async {
      kur(() => bilgi(), (_) => throw StateError('çağrılmamalı'));
      expect(await kurulum.kur(), isA<IlkCihazGerekmedi>());
      kur(() => bilgi(eslesmis: false, baska: true), (_) => null);
      expect(await kurulum.kur(), isA<IlkCihazQrGerekli>());
      expect(tasima.istekler, isEmpty);
    });
  });

  group('Yenileme ve paylaşım alma', () {
    late SahteTasima tasimaA;
    late SahteKaynak kaynakA;
    late GecmisAnahtariDeposu anahtarlarA;
    late GecmisYenileyici yenileyici;

    void kur(Map<String, Object? Function(SahteIstek)> yanitlar) {
      tasimaA = SahteTasima(yanitlar);
      kaynakA = SahteKaynak(bilgi(surum: 3, yenile: true));
      anahtarlarA = GecmisAnahtariDeposu(BellekE2eDepo());
      final api = GecmisApi(tasimaA);
      final oturum = SahteKendiOturum(cihazA);
      yenileyici = GecmisYenileyici(
        api: api,
        oturum: oturum,
        anahtarlar: anahtarlarA,
        kaynak: kaynakA,
        paylasimAlici: PaylasimAlici(
          api: api,
          oturum: oturum,
          anahtarlar: anahtarlarA,
        ),
        bicim: ArsivBicimi(SahteSignalMotoru()),
      );
    }

    test('e2e-devices-changed: eksik cihazlar eklenir, fazlalar çıkar, '
        'paylaşım B\'de çözülüp onaylanır', () async {
      final gonderilen = <List<Object?>>[];
      kur({
        yenileUc: (i) {
          final paylasimlar = i.json['shares']! as List<Object?>;
          gonderilen.add(paylasimlar);
          expect(i.json['history_key_version'], 4);
          if (gonderilen.length == 1) {
            return problem(
              ProblemType.e2eDevicesChanged,
              fark: const E2eCihazFarki(eksik: [cihazB, cihazC], eski: []),
            );
          }
          if (gonderilen.length == 2) {
            return problem(
              ProblemType.e2eDevicesChanged,
              fark: const E2eCihazFarki(eksik: [], eski: [cihazC]),
            );
          }
          return null;
        },
      });
      kaynakA.sonraki = () => bilgi(surum: 4);

      expect(await yenileyici.yenile(), YenilemeSonucu.yenilendi);
      expect(gonderilen.map((p) => p.length), [0, 2, 1]);
      final yeniAnahtar = (await anahtarlarA.oku(4))!;

      // B paylaşımı alır.
      final paylasimB =
          (gonderilen.last.single! as Map<String, Object?>)['bundle']!
              as String;
      expect(
        (gonderilen.last.single! as Map<String, Object?>)['device_id'],
        cihazB,
      );
      final tasimaB = SahteTasima({
        paylasimlarUc: (_) => {
          'shares': [
            _paylasim(istekId, cihazA, 4, base64.decode(paylasimB)),
          ],
        },
        paylasimOnay: (_) => null,
      });
      final anahtarlarB = GecmisAnahtariDeposu(BellekE2eDepo());
      final alici = PaylasimAlici(
        api: GecmisApi(tasimaB),
        oturum: SahteKendiOturum(cihazB),
        anahtarlar: anahtarlarB,
      );
      expect(await alici.al(), 1);
      expect(await anahtarlarB.oku(4), yeniAnahtar);
      expect(tasimaB.giden(paylasimOnay).single.json['share_ids'], [istekId]);
    });

    test('stale yarışı: aday silinir, öteki cihazın paylaşımı alınır', () async {
      final oteki = kendiCihazPaketi(
        await SahteKendiOturum(cihazB)
            .sifrele(cihazA, paylasimDuzMetni({4: anahtar(44)})),
      );
      kur({
        yenileUc: (_) => problem(ProblemType.e2eHistoryKeyStale),
        paylasimlarUc: (_) => {
          'shares': [_paylasim(istekId, cihazB, 4, oteki)],
        },
        paylasimOnay: (_) => null,
      });
      expect(await yenileyici.yenile(), YenilemeSonucu.baskaCihazYeniledi);
      expect(await anahtarlarA.oku(4), anahtar(44));
      expect(kaynakA.tazelemeSayisi, 1);
    });

    test('cihaz kümesi oturmazsa (3 tekrar) vazgeçilir, aday silinir', () async {
      kur({
        yenileUc: (_) => problem(
          ProblemType.e2eDevicesChanged,
          fark: const E2eCihazFarki(eksik: [cihazB], eski: [cihazB]),
        ),
      });
      expect(await yenileyici.yenile(), YenilemeSonucu.basarisiz);
      expect(tasimaA.giden(yenileUc), hasLength(yenilemeTekrarEnCok + 1));
      expect(await anahtarlarA.oku(4), isNull);
    });

    test('sonucu bilinmeyen istekte (bağlantı koptu) aday korunur', () async {
      kur({yenileUc: (_) => const ApiOffline()});
      expect(await yenileyici.yenile(), YenilemeSonucu.basarisiz);
      expect(await anahtarlarA.oku(4), isNotNull);
    });

    test('yenileme gerekmiyorsa istek atılmaz', () async {
      kur({});
      kaynakA.yayinla(bilgi(surum: 3));
      expect(await yenileyici.yenile(), YenilemeSonucu.gerekmedi);
      kaynakA.yayinla(bilgi(eslesmis: false, yenile: true));
      expect(await yenileyici.yenile(), YenilemeSonucu.gerekmedi);
      expect(tasimaA.istekler, isEmpty);
    });

    test('bozuk ya da çözülemeyen paylaşım yazılmaz ama onaylanır', () async {
      final gecerli = kendiCihazPaketi(
        await SahteKendiOturum(cihazB)
            .sifrele(cihazA, paylasimDuzMetni({5: anahtar(5)})),
      );
      final tasima = SahteTasima({
        paylasimlarUc: (_) => {
          'shares': [
            _paylasim(mesajId(1), cihazB, 5, Uint8List.fromList([9, 9])),
            _paylasim(mesajId(2), cihazC, 5, gecerli), // gönderen tutmuyor
            _paylasim(mesajId(3), cihazB, 6, gecerli), // sürüm tutmuyor
            _paylasim(mesajId(4), cihazB, 5, gecerli),
          ],
        },
        paylasimOnay: (_) => null,
      });
      final anahtarlar = GecmisAnahtariDeposu(BellekE2eDepo());
      final alici = PaylasimAlici(
        api: GecmisApi(tasima),
        oturum: SahteKendiOturum(cihazA),
        anahtarlar: anahtarlar,
      );
      expect(await alici.al(), 1);
      expect(await anahtarlar.hepsi(), {5: anahtar(5)});
      expect(tasima.giden(paylasimOnay).single.json['share_ids'], [
        mesajId(1),
        mesajId(2),
        mesajId(3),
        mesajId(4),
      ]);
    });

    test('paylaşım yoksa onay isteği atılmaz', () async {
      final tasima = SahteTasima({paylasimlarUc: (_) => {'shares': []}});
      final alici = PaylasimAlici(
        api: GecmisApi(tasima),
        oturum: SahteKendiOturum(cihazA),
        anahtarlar: GecmisAnahtariDeposu(BellekE2eDepo()),
      );
      expect(await alici.al(), 0);
      expect(tasima.giden(paylasimOnay), isEmpty);
    });
  });

  test('geçmiş anahtarı deposu bozuk kayıtları yok sayar', () async {
    final depo = BellekE2eDepo();
    final anahtarlar = GecmisAnahtariDeposu(depo);
    await anahtarlar.yaz(2, anahtar(2));
    await anahtarlar.yaz(7, anahtar(7));
    depo.kayitlar['${gecmisAnahtariOneki}x'] = anahtar(1);
    depo.kayitlar['${gecmisAnahtariOneki}9'] = Uint8List(3);
    expect((await anahtarlar.hepsi()).keys.toSet(), {2, 7});
    expect(await anahtarlar.enYeni(), 7);
    expect(() => anahtarlar.yaz(0, anahtar(1)), throwsFormatException);
    expect(() => anahtarlar.yaz(1, Uint8List(31)), throwsFormatException);
    expect(yeniGecmisAnahtari(), hasLength(32));
  });
}

/// Testte cihaz bilgisi üreten fonksiyon.
typedef E2eBilgisiUretici = E2eCihazBilgisi Function();
