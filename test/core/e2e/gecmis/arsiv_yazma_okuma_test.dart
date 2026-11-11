import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_okuyucu.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_yazici.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_anahtari_deposu.dart';
import 'package:tayfam/core/e2e/gecmis/gecmis_api.dart';
import 'package:tayfam/core/e2e/gecmis/paylasim_alici.dart';

import '../signal/sahte_signal_motoru.dart';
import 'sahteler.dart';

ArsivlenecekMesaj _mesaj(int i) => ArsivlenecekMesaj(
  mesajId: mesajId(i),
  konusmaId: konusmaId,
  gonderenId: karsiKullanici,
  olusturma: DateTime.utc(2026, 11, 11, 18, i % 60),
  govde: 'mesaj $i',
);

/// Ortak kurulum: A cihazı, eşleştirilmiş, sürüm 1 anahtarı depoda.
final class _Ortam {
  _Ortam({SahteTasima? tasima})
    : tasima = tasima ?? SahteTasima(),
      kaynak = SahteKaynak(bilgi()) {
    api = GecmisApi(this.tasima);
    anahtarlar = GecmisAnahtariDeposu(depo);
    bicim = ArsivBicimi(SahteSignalMotoru());
    paylasimAlici = PaylasimAlici(
      api: api,
      oturum: SahteKendiOturum(cihazA),
      anahtarlar: anahtarlar,
    );
    yazici = ArsivYazici(
      api: api,
      bicim: bicim,
      anahtarlar: anahtarlar,
      kaynak: kaynak,
      paylasimAlici: paylasimAlici,
    );
    okuyucu = ArsivOkuyucu(
      api: api,
      bicim: bicim,
      anahtarlar: anahtarlar,
      kaynak: kaynak,
    );
  }

  final SahteTasima tasima;
  final SahteKaynak kaynak;
  final BellekE2eDepo depo = BellekE2eDepo();
  late final GecmisApi api;
  late final GecmisAnahtariDeposu anahtarlar;
  late final ArsivBicimi bicim;
  late final PaylasimAlici paylasimAlici;
  late final ArsivYazici yazici;
  late final ArsivOkuyucu okuyucu;
}

Object? _kabul(SahteIstek i) => {
  'accepted_message_ids': [
    for (final e in i.json['entries']! as List<Object?>)
      (e! as Map<String, Object?>)['message_id'],
  ],
};

void main() {
  group('ArsivYazici', () {
    test('aynı anda gelen mesajlar 50\'lik gruplarla yazılır', () async {
      final o = _Ortam(tasima: SahteTasima({arsivYaz: _kabul}));
      await o.anahtarlar.yaz(1, anahtar(1));
      for (var i = 1; i <= 120; i++) {
        o.yazici.ekle(_mesaj(i));
      }
      await pumpEventQueue();
      final giden = o.tasima.giden(arsivYaz);
      expect([
        for (final g in giden) (g.json['entries']! as List<Object?>).length,
      ], [50, 50, 20]);
      expect(giden.first.json['history_key_version'], 1);
      expect(o.yazici.bekleyen, 0);
    });

    test('yazılan kayıt aynı cihazda okunup çözülür', () async {
      final yazilan = <Map<String, Object?>>[];
      final o = _Ortam(
        tasima: SahteTasima({
          arsivYaz: (i) {
            for (final e in i.json['entries']! as List<Object?>) {
              yazilan.add({
                ...(e! as Map<String, Object?>),
                'conversation_id': konusmaId,
                'key_version': i.json['history_key_version'],
                'created_at': '2026-11-11T18:00:00Z',
              });
            }
            return _kabul(i);
          },
          arsivOku: (_) => {'entries': yazilan},
        }),
      );
      await o.anahtarlar.yaz(1, anahtar(1));
      o.yazici.ekle(_mesaj(1));
      o.yazici.ekle(_mesaj(2));
      await pumpEventQueue();

      final arsiv = await o.okuyucu.oku(konusmaId);
      expect(arsiv.erisim, ArsivErisimi.okundu);
      expect(arsiv.okunamayan, 0);
      expect(arsiv.mesajlar[mesajId(2)]!.govde, 'mesaj 2');
      expect(arsiv.mesajlar[mesajId(1)]!.gonderenId, karsiKullanici);
    });

    test('e2e-history-key-stale: paylaşım çekilir ve yeni sürümle tekrar '
        'yazılır', () async {
      var ilk = true;
      final paylasim = kendiCihazPaketi(
        await SahteKendiOturum(
          cihazB,
        ).sifrele(cihazA, paylasimDuzMetni({2: anahtar(2)})),
      );
      final o = _Ortam(
        tasima: SahteTasima({
          arsivYaz: (i) {
            if (ilk) {
              ilk = false;
              return problem(ProblemType.e2eHistoryKeyStale);
            }
            return _kabul(i);
          },
          paylasimlarUc: (_) => {
            'shares': [
              {
                'id': istekId,
                'sender_device_id': cihazB,
                'history_key_version': 2,
                'bundle': base64.encode(paylasim),
                'created_at': '2026-11-11T18:00:00Z',
              },
            ],
          },
          paylasimOnay: (_) => null,
        }),
      );
      o.kaynak.sonraki = () => bilgi(surum: 2);
      await o.anahtarlar.yaz(1, anahtar(1));
      o.yazici.ekle(_mesaj(1));
      await pumpEventQueue();

      final giden = o.tasima.giden(arsivYaz);
      expect(giden, hasLength(2));
      expect(giden.last.json['history_key_version'], 2);
      expect(await o.anahtarlar.oku(2), anahtar(2));
      expect(o.tasima.giden(paylasimOnay).single.json['share_ids'], [istekId]);
      expect(o.yazici.bekleyen, 0);
    });

    test('e2e-not-paired: kuyruk boşalır, yazılmaz, durum tazelenir', () async {
      final o = _Ortam(
        tasima: SahteTasima({
          arsivYaz: (_) => problem(ProblemType.e2eNotPaired),
        }),
      );
      await o.anahtarlar.yaz(1, anahtar(1));
      o.yazici
        ..ekle(_mesaj(1))
        ..ekle(_mesaj(2));
      await pumpEventQueue();
      expect(o.yazici.bekleyen, 0);
      expect(o.kaynak.tazelemeSayisi, 1);
    });

    test('bağlantı hatası: grup kuyruğa döner, sonra gönderilir', () async {
      var cevrimdisi = true;
      final o = _Ortam(
        tasima: SahteTasima({
          arsivYaz: (i) => cevrimdisi ? const ApiOffline() : _kabul(i),
        }),
      );
      await o.anahtarlar.yaz(1, anahtar(1));
      o.yazici
        ..ekle(_mesaj(1))
        ..ekle(_mesaj(2));
      await pumpEventQueue();
      expect(o.yazici.bekleyen, 2);

      cevrimdisi = false;
      await o.yazici.bosalt();
      expect(o.yazici.bekleyen, 0);
      final son = o.tasima.giden(arsivYaz).last;
      expect(son.json['entries'], hasLength(2));
    });

    test('eşleştirilmemiş cihazda mesajlar yok sayılır', () async {
      final o = _Ortam();
      o.kaynak.yayinla(bilgi(eslesmis: false));
      o.yazici.ekle(_mesaj(1));
      await pumpEventQueue();
      expect(o.yazici.bekleyen, 0);
      expect(o.tasima.istekler, isEmpty);
    });
  });

  group('ArsivOkuyucu', () {
    Future<Map<String, Object?>> kayit(
      _Ortam o,
      int i, {
      int surum = 1,
      String konusma = konusmaId,
    }) async => {
      'message_id': mesajId(i),
      'conversation_id': konusma,
      'key_version': surum,
      'content': base64.encode(
        await o.bicim.sifrele(
          gecmisAnahtari: anahtar(surum),
          surum: surum,
          kullaniciId: kullaniciId,
          mesajId: mesajId(i),
          duz: ArsivDuzMetni(
            gonderenId: karsiKullanici,
            olusturma: DateTime.utc(2026),
            govde: 'g$i',
          ),
        ),
      ),
      'created_at': '2026-11-11T18:00:00Z',
    };

    test('anahtarı olmayan sürüm ve başka konuşmanın kaydı okunamaz '
        'sayılır', () async {
      final o = _Ortam();
      await o.anahtarlar.yaz(2, anahtar(2));
      final kayitlar = [
        await kayit(o, 1, surum: 1),
        await kayit(o, 2, surum: 2),
        await kayit(o, 3, surum: 2, konusma: istekId),
      ];
      o.tasima.yanitlar[arsivOku] = (_) => {
        'entries': kayitlar,
        'next_page_token': 'sonraki',
      };
      final arsiv = await o.okuyucu.oku(konusmaId);
      expect(arsiv.mesajlar.keys, [mesajId(2)]);
      expect(arsiv.okunamayan, 2);
      expect(arsiv.eskiMesajlarOkunamiyor, isTrue);
      expect(arsiv.sonrakiSayfa, 'sonraki');
      expect(o.tasima.giden(arsivOku).single.parametreler, {
        'conversation_id': konusmaId,
        'page_size': '100',
      });
    });

    test('eşleştirilmemiş cihaz istek atmaz; sunucu e2e-not-paired derse '
        'de eşleştirilmemiş', () async {
      final o = _Ortam();
      o.kaynak.yayinla(bilgi(eslesmis: false));
      expect(
        (await o.okuyucu.oku(konusmaId)).erisim,
        ArsivErisimi.eslestirilmemis,
      );
      expect(o.tasima.istekler, isEmpty);

      o.kaynak.yayinla(bilgi());
      o.tasima.yanitlar[arsivOku] = (_) => problem(ProblemType.e2eNotPaired);
      final arsiv = await o.okuyucu.oku(konusmaId);
      expect(arsiv.erisim, ArsivErisimi.eslestirilmemis);
      expect(arsiv.eskiMesajlarOkunamiyor, isTrue);
    });

    test('E2E yoksa boş', () async {
      final o = _Ortam();
      o.kaynak.yayinla(null);
      expect((await o.okuyucu.oku(konusmaId)).erisim, ArsivErisimi.yok);
    });
  });

  test('ArsivlenecekMesaj ve ArsivMesaji toString içerik yazmaz', () {
    expect(_mesaj(1).toString(), isNot(contains('mesaj 1')));
    expect(
      ArsivMesaji(
        mesajId: mesajId(1),
        gonderenId: karsiKullanici,
        olusturma: DateTime.utc(2026),
        govde: 'gizli',
      ).toString(),
      isNot(contains('gizli')),
    );
  });

  test('Timer.run ile kurulan gönderim tek grupta birleşir', () async {
    final o = _Ortam(tasima: SahteTasima({arsivYaz: _kabul}));
    await o.anahtarlar.yaz(1, anahtar(1));
    final akis = StreamController<ArsivlenecekMesaj>();
    akis.stream.listen(o.yazici.ekle);
    for (var i = 1; i <= 3; i++) {
      akis.add(_mesaj(i));
    }
    await pumpEventQueue();
    expect(o.tasima.giden(arsivYaz).single.json['entries'], hasLength(3));
    await akis.close();
  });
}
