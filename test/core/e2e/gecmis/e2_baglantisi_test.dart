import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/gecmis/e2_baglantisi.dart';
import 'package:tayfam/core/e2e/mesaj/birebir_icerik.dart';
import 'package:tayfam/core/realtime/realtime_olaylari.dart';

import 'sahteler.dart';

CozulmusBirebirMesaj _mesaj(int i, CozulmusMesajKaynagi kaynak) =>
    CozulmusBirebirMesaj(
      mesajId: mesajId(i),
      konusmaId: konusmaId,
      gonderenKullaniciId: karsiKullanici,
      metin: 'm$i',
      olusturma: DateTime.utc(2026),
      kaynak: kaynak,
    );

void main() {
  test('mesaj yayını: gönderilen ve zarftan çözülenler arşive gider, '
      'arşivden okunanlar gitmez', () async {
    final akis = StreamController<CozulmusBirebirMesaj>();
    final gelen = <ArsivlenecekMesaj>[];
    E2MesajAkisi(akis.stream).mesajlar.listen(gelen.add);
    akis
      ..add(_mesaj(1, CozulmusMesajKaynagi.gonderildi))
      ..add(_mesaj(2, CozulmusMesajKaynagi.arsiv))
      ..add(_mesaj(3, CozulmusMesajKaynagi.zarf));
    await pumpEventQueue();
    expect(gelen.map((m) => m.mesajId), [mesajId(1), mesajId(3)]);
    expect(gelen.last.govde, 'm3');
    expect(gelen.last.gonderenId, karsiKullanici);
    await akis.close();
  });

  test('realtime olayları geçmiş sinyallerine çevrilir', () async {
    final akis = StreamController<RealtimeOlayi>();
    final gelen = <E2eSinyali>[];
    E2Sinyalleri(akis.stream).sinyaller.listen(gelen.add);
    akis
      ..add(const E2eEslemeCevaplandi(istekId))
      ..add(const E2eGecmisAnahtariPaylasildi())
      ..add(const Baglandi())
      ..add(const E2eOnAnahtarlarAzaldi());
    await pumpEventQueue();
    expect(gelen, hasLength(3));
    expect((gelen[0] as EslemeCevaplandi).eslemeIstegiId, istekId);
    expect(gelen[1], isA<GecmisAnahtariPaylasildi>());
    expect(gelen[2], isA<E2eYenidenBaglandi>());
    await akis.close();
  });
}
