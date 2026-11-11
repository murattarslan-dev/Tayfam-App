import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/kuyruk/cevrimdisi_kuyruk.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/sohbet/application/kanal_akisi_notifier.dart';
import 'package:tayfam/features/sohbet/application/kanallar_notifier.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const KanalRef _kanal1 = (tayfaId: ornekTayfaId, kanalId: kanalId1);

final class _Kurulum {
  _Kurulum(this.ortam) {
    kap = ProviderContainer.test(overrides: ortam.overridelar);
  }

  final SohbetOrtami ortam;
  late final ProviderContainer kap;

  Future<List<int?>> okunmamislar() async {
    final liste = await kap.read(kanallarProvider(ornekTayfaId).future);
    return [for (final k in liste) k.unreadCount];
  }

  Future<KanalAkisi> akis() async {
    kap.listen(kanalAkisiProvider(_kanal1), (_, _) {});
    return kap.read(kanalAkisiProvider(_kanal1).future);
  }

  List<String> mesajKimlikleri() => [
    for (final m
        in kap.read(kanalAkisiProvider(_kanal1)).requireValue.mesajlar)
      m.id,
  ];
}

void main() {
  group('kanallar', () {
    test('liste canlıyken kanallara abone olunur; arşivliye olunmaz', () async {
      final o = SohbetOrtami(
        kanallar: [kanalJson(kanalId1), kanalJson(kanalId2, arsiv: true)],
      );
      final k = _Kurulum(o);
      k.kap.listen(okunmamisKanalSayisiProvider, (_, _) {});
      await k.okunmamislar();
      final soket = await o.baglan();
      expect(soket.tur('subscribe').map((c) => c['data']), [
        {'tayfa_id': ornekTayfaId, 'channel_id': kanalId1},
      ]);
    });

    test('başka kanala gelen mesaj okunmamışı artırır, açık kanala gelen '
        'artırmaz; aynı mesaj iki kez sayılmaz', () async {
      final o = SohbetOrtami(
        kanallar: [kanalJson(kanalId1), kanalJson(kanalId2, okunmamis: 2)],
      );
      final k = _Kurulum(o);
      k.kap.listen(okunmamisKanalSayisiProvider, (_, _) {});
      await k.okunmamislar();
      final soket = await o.baglan();
      k.kap.read(acikKanalProvider.notifier).ac(_kanal1);
      soket
        ..cerceve('message.created', olayMesaji(mesajId1))
        ..cerceve('message.created', olayMesaji(mesajId2, kanal: kanalId2))
        ..cerceve('message.created', olayMesaji(mesajId2, kanal: kanalId2));
      await pumpEventQueue();
      expect(await k.okunmamislar(), [0, 3]);
      expect(k.kap.read(okunmamisKanalSayisiProvider), 3);

      k.kap.read(kanallarProvider(ornekTayfaId).notifier).okundu(kanalId2);
      expect(k.kap.read(okunmamisKanalSayisiProvider), 0);
    });

    test('kendi mesajımız okunmamış sayılmaz', () async {
      final o = SohbetOrtami(kanallar: [kanalJson(kanalId2)]);
      final k = _Kurulum(o);
      k.kap.listen(okunmamisKanalSayisiProvider, (_, _) {});
      await k.okunmamislar();
      final soket = await o.baglan();
      soket.cerceve('message.created', olayMesaji(mesajId1, kanal: kanalId2));
      await pumpEventQueue();
      expect(await k.okunmamislar(), [1]);
      k.kap
          .read(kanallarProvider(ornekTayfaId).notifier)
          .kendiMesajim(kanalId2, mesajId1);
      expect(await k.okunmamislar(), [0]);
    });

    test('access_lost alınan kanal listeden çıkar', () async {
      final o = SohbetOrtami(
        kanallar: [kanalJson(kanalId1), kanalJson(kanalId2)],
      );
      final k = _Kurulum(o);
      k.kap.listen(okunmamisKanalSayisiProvider, (_, _) {});
      await k.okunmamislar();
      final soket = await o.baglan();
      soket.cerceve('unsubscribed', {
        'tayfa_id': ornekTayfaId,
        'channel_id': kanalId2,
        'reason': 'access_lost',
      });
      await pumpEventQueue();
      final liste = await k.kap.read(kanallarProvider(ornekTayfaId).future);
      expect(liste.map((c) => c.id), [kanalId1]);
    });

    test('yeniden bağlanınca liste REST\'ten yenilenir', () async {
      final o = SohbetOrtami();
      final k = _Kurulum(o);
      k.kap.listen(okunmamisKanalSayisiProvider, (_, _) {});
      await k.okunmamislar();
      await o.baglan();
      await pumpEventQueue();
      expect(o.tasima.giden('GET', '/v1/tayfas/{tayfa_id}/channels'), hasLength(2));
    });
  });

  group('mesaj akışı', () {
    test('olaylar akışı günceller ve id ile tekilleştirir', () async {
      final o = SohbetOrtami(mesajlar: [mesajJson(mesajId1)]);
      final k = _Kurulum(o);
      await k.akis();
      final soket = await o.baglan();
      soket
        ..cerceve('message.created', olayMesaji(mesajId2))
        ..cerceve('message.created', olayMesaji(mesajId2))
        ..cerceve('message.deleted', {
          'tayfa_id': ornekTayfaId,
          'channel_id': kanalId1,
          'message_id': mesajId1,
        });
      await pumpEventQueue();
      expect(k.mesajKimlikleri(), [mesajId2, mesajId1]);
      final silinen = k.kap
          .read(kanalAkisiProvider(_kanal1))
          .requireValue
          .mesajlar
          .last;
      expect(silinen.deleted, isTrue);
      expect(silinen.body, isNull);
    });

    test('yeniden bağlanınca kaçırılanlar son mesajdan itibaren çekilir', () async {
      final o = SohbetOrtami(mesajlar: [mesajJson(mesajId1)]);
      final k = _Kurulum(o);
      await k.akis();
      await o.baglan();
      await pumpEventQueue();
      final cekilen = o.tasima
          .giden('GET', '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages')
          .last;
      expect(cekilen.sorgu['after_message_id'], mesajId1);
    });

    test('bağlantı kapalıyken REST ile, aynı istek kimliğiyle gönderilir', () async {
      final o = SohbetOrtami();
      var deneme = 0;
      o.tasima.yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] =
          (_) {
            deneme++;
            if (deneme == 1) return const ApiOffline();
            return mesajJson(mesajId3, yazar: benimId);
          };
      final k = _Kurulum(o);
      await k.akis();
      expect(
        k.kap.read(kanalAkisiProvider(_kanal1).notifier).gonder('selam'),
        isTrue,
      );
      await pumpEventQueue();
      expect(k.kap.read(cevrimdisiKuyrukProvider).single.durum, KuyrukDurumu.bekliyor);
      k.kap.read(cevrimdisiKuyrukProvider.notifier).simdiDene();
      await pumpEventQueue();
      final gonderimler = o.tasima.giden(
        'POST',
        '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages',
      );
      expect(gonderimler, hasLength(2));
      final idler = {
        for (final g in gonderimler)
          (g.govde! as Map<String, Object?>)['client_request_id'],
      };
      expect(idler, {sahteIstekKimligi});
      expect(k.mesajKimlikleri(), [mesajId3]);
      expect(k.kap.read(cevrimdisiKuyrukProvider), isEmpty);
    });

    test('bağlantı açıkken send çerçevesi; cevapsızsa REST, aynı id', () async {
      final o = SohbetOrtami();
      o.tasima.yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] =
          (_) => mesajJson(mesajId3, yazar: benimId);
      final k = _Kurulum(o);
      await k.akis();
      final soket = await o.baglan();
      k.kap.read(kanalAkisiProvider(_kanal1).notifier).gonder('selam');
      await pumpEventQueue();
      final giden = soket.tur('send').single;
      expect(
        (giden['data']! as Map)['client_request_id'],
        sahteIstekKimligi,
      );
      o.zaman.calistir(RealtimeIstemcisi.cevapSuresi);
      await pumpEventQueue();
      final rest = o.tasima
          .giden('POST', '/v1/tayfas/{tayfa_id}/channels/{channel_id}/messages')
          .single;
      expect(
        (rest.govde! as Map<String, Object?>)['client_request_id'],
        sahteIstekKimligi,
      );
      expect(k.mesajKimlikleri(), [mesajId3]);
    });

    test('kalıcı hata (muted) gönderilemedi olur', () async {
      final o = SohbetOrtami();
      o.tasima.yanitlar['POST /v1/tayfas/{tayfa_id}/channels/{channel_id}/messages'] =
          (_) => const ApiProblem(type: ProblemType.muted, status: 403);
      final k = _Kurulum(o);
      await k.akis();
      k.kap.read(kanalAkisiProvider(_kanal1).notifier).gonder('selam');
      await pumpEventQueue();
      expect(
        k.kap.read(cevrimdisiKuyrukProvider).single.durum,
        KuyrukDurumu.gonderilemedi,
      );
    });

    test('boş ya da çok uzun metin gönderilmez', () async {
      final k = _Kurulum(SohbetOrtami());
      await k.akis();
      final n = k.kap.read(kanalAkisiProvider(_kanal1).notifier);
      expect(n.gonder('   '), isFalse);
      expect(n.gonder('a' * (mesajEnUzun + 1)), isFalse);
      expect(k.kap.read(cevrimdisiKuyrukProvider), isEmpty);
    });

    test('okundu işareti en yeni mesajla bir kez gönderilir', () async {
      final o = SohbetOrtami(
        mesajlar: [
          mesajJson(mesajId2, zaman: '2026-11-11T10:05:00Z'),
          mesajJson(mesajId1),
        ],
      );
      final k = _Kurulum(o);
      await k.akis();
      final n = k.kap.read(kanalAkisiProvider(_kanal1).notifier);
      await n.okunduIsaretle();
      await n.okunduIsaretle();
      final isaret = o.tasima
          .giden('PUT', '/v1/tayfas/{tayfa_id}/channels/{channel_id}/read')
          .single;
      expect(isaret.govde, {'message_id': mesajId2});
    });
  });
}
