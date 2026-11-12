import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/realtime/realtime_istemcisi.dart';

import '../zaman_sahteleri.dart';
import 'sahte_soket.dart';

const String tayfaA = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10';
const String kanal1 = '11111111-1111-4111-8111-111111111111';
const String kanal2 = '22222222-2222-4222-8222-222222222222';
const String mesaj1 = '33333333-3333-4333-8333-333333333333';
const String kullanici = '44444444-4444-4444-8444-444444444444';
const String istek = '55555555-5555-4555-8555-555555555555';

final class _Kurulum {
  _Kurulum() {
    istemci = RealtimeIstemcisi(
      adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
      baglayici: (adres, basliklar) {
        final s = SahteSoket(adres, basliklar);
        soketler.add(s);
        return s;
      },
      tokenAl: () async {
        tokenIstendi++;
        if (oturumYok) throw const OturumYok();
        return token;
      },
      reddedildi: (eski) async {
        reddedilenler.add(eski);
        token = 'yeni-token';
        return token;
      },
      oturumuKapat: () async => oturumKapandi++,
      zamanlayici: zaman.kur,
      basliklar: const {'X-Tayfam-Client-Version': 'android/1.0.0'},
      rastgele: Random(1),
      gunluk: gunluk.add,
    );
  }

  late final RealtimeIstemcisi istemci;
  final SahteZamanlayici zaman = SahteZamanlayici();
  final List<SahteSoket> soketler = [];
  final List<String> reddedilenler = [];
  final List<String> gunluk = [];
  String token = 'eski-token';
  bool oturumYok = false;
  int tokenIstendi = 0;
  int oturumKapandi = 0;

  SahteSoket get son => soketler.last;

  Future<SahteSoket> baglan() async {
    istemci.baslat();
    await pumpEventQueue();
    await son.ac();
    return son;
  }
}

void main() {
  group('bağlantı', () {
    test('token başlıkta, URL\'de değil; ready sonrası açık', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      expect(soket.basliklar['Authorization'], 'Bearer eski-token');
      expect(soket.basliklar['X-Tayfam-Client-Version'], 'android/1.0.0');
      expect(soket.adres.toString(), isNot(contains('token')));
      expect(k.istemci.durum, RealtimeDurumu.acik);
    });

    test('oturum yoksa bağlanmaz ve yeniden denemez', () async {
      final k = _Kurulum()..oturumYok = true;
      k.istemci.baslat();
      await pumpEventQueue();
      expect(k.soketler, isEmpty);
      expect(k.zaman.etkin, isEmpty);
    });

    test(
      '4003: token reddedildi bildirilir, hemen yeniden bağlanılır',
      () async {
        final k = _Kurulum();
        final ilk = await k.baglan();
        await ilk.sunucuKapatti(4003);
        expect(k.reddedilenler, ['eski-token']);
        expect(k.soketler, hasLength(2));
        expect(k.son.basliklar['Authorization'], 'Bearer yeni-token');
        expect(k.zaman.etkin, isEmpty);
      },
    );

    test('4001: oturum kapatılır, yeniden bağlanılmaz', () async {
      final k = _Kurulum();
      final ilk = await k.baglan();
      await ilk.sunucuKapatti(4001);
      expect(k.oturumKapandi, 1);
      expect(k.soketler, hasLength(1));
      expect(k.zaman.etkin, isEmpty);
      expect(k.istemci.durum, RealtimeDurumu.kapali);
    });

    for (final kod in [1006, 4002, 1008, 1001, 1003, 1009]) {
      test('$kod: artan aralıkla yeniden denenir', () async {
        final k = _Kurulum();
        final ilk = await k.baglan();
        await ilk.sunucuKapatti(kod);
        expect(k.soketler, hasLength(1));
        expect(k.zaman.etkin, hasLength(1));
        k.zaman.calistir();
        await pumpEventQueue();
        expect(k.soketler, hasLength(2));
        expect(k.gunluk.single, 'realtime: kapandı ($kod)');
      });
    }

    test('geri çekilme 1, 2, 4 … 30 sn, ±%20', () {
      final r = Random(7);
      for (final (deneme, taban) in [
        (0, 1),
        (1, 2),
        (2, 4),
        (4, 16),
        (9, 30),
      ]) {
        final sure = yenidenBaglanmaBeklemesi(deneme, r).inMilliseconds;
        expect(sure, greaterThanOrEqualTo(taban * 800));
        expect(sure, lessThanOrEqualTo(taban * 1200));
      }
    });

    test(
      'arka planda 30 sn sonra kapanır, ön plana dönünce bağlanır',
      () async {
        final k = _Kurulum();
        final ilk = await k.baglan();
        k.istemci.arkaPlana();
        expect(k.zaman.etkin.single.sure, RealtimeIstemcisi.arkaPlanSuresi);
        k.zaman.calistir();
        await pumpEventQueue();
        expect(ilk.kapatmaKodu, 1000);
        expect(k.istemci.durum, RealtimeDurumu.kapali);
        expect(k.zaman.etkin, isEmpty);
        k.istemci.onPlana();
        await pumpEventQueue();
        expect(k.soketler, hasLength(2));
      },
    );

    test('30 sn dolmadan ön plana dönülürse bağlantı kalır', () async {
      final k = _Kurulum();
      final ilk = await k.baglan();
      k.istemci
        ..arkaPlana()
        ..onPlana();
      expect(k.zaman.etkin, isEmpty);
      expect(ilk.kapatmaKodu, isNull);
    });

    test('durdur: bağlantı kapanır, yeniden denenmez', () async {
      final k = _Kurulum();
      final ilk = await k.baglan();
      k.istemci.durdur();
      await pumpEventQueue();
      expect(ilk.kapatmaKodu, 1000);
      expect(k.zaman.etkin, isEmpty);
      expect(k.soketler, hasLength(1));
    });
  });

  group('abonelikler', () {
    test('ready sonrası kurulur, yeniden bağlanınca yeniden kurulur', () async {
      final k = _Kurulum();
      k.istemci.abonelikleriAyarla(tayfaA, [
        (tayfaId: tayfaA, kanalId: kanal1),
        (tayfaId: tayfaA, kanalId: kanal2),
      ]);
      final ilk = await k.baglan();
      expect(ilk.tur('subscribe').map((c) => c['data']), [
        {'tayfa_id': tayfaA, 'channel_id': kanal1},
        {'tayfa_id': tayfaA, 'channel_id': kanal2},
      ]);
      await ilk.sunucuKapatti(1006);
      k.zaman.calistir();
      await pumpEventQueue();
      await k.son.ac();
      expect(k.son.tur('subscribe'), hasLength(2));
    });

    test('açık kanal önce; 100 sınırı aşılmaz', () async {
      final k = _Kurulum();
      final cok = [
        for (var i = 0; i < 120; i++)
          (
            tayfaId: tayfaA,
            kanalId: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          ),
      ];
      final soket = await k.baglan();
      k.istemci.abonelikleriAyarla(
        tayfaA,
        cok,
        oncelikli: (tayfaId: tayfaA, kanalId: kanal1),
      );
      final abonelikler = soket.tur('subscribe');
      expect(abonelikler, hasLength(RealtimeIstemcisi.enFazlaAbonelik));
      expect((abonelikler.first['data']! as Map)['channel_id'], kanal1);
    });

    test('tayfa değişince öncekiler bırakılır', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      k.istemci.abonelikleriAyarla(tayfaA, [
        (tayfaId: tayfaA, kanalId: kanal1),
      ]);
      k.istemci.abonelikleriBirak(tayfaA);
      expect(soket.tur('unsubscribe').single['data'], {
        'tayfa_id': tayfaA,
        'channel_id': kanal1,
      });
      expect(k.istemci.aboneler, isEmpty);
    });

    test('access_lost: kanal bırakılır, olay yayılır', () async {
      final k = _Kurulum();
      final olaylar = <RealtimeOlayi>[];
      k.istemci.olaylar.listen(olaylar.add);
      k.istemci.abonelikleriAyarla(tayfaA, [
        (tayfaId: tayfaA, kanalId: kanal1),
      ]);
      final soket = await k.baglan();
      soket.cerceve('unsubscribed', {
        'tayfa_id': tayfaA,
        'channel_id': kanal1,
        'reason': 'access_lost',
      });
      await pumpEventQueue();
      expect(k.istemci.aboneler, isEmpty);
      final bitti = olaylar.whereType<AbonelikBitti>().single;
      expect(bitti.neden, AbonelikBitisNedeni.erisimKalmadi);
      // Yeniden bağlanınca o kanala tekrar abone olunmaz.
      await soket.sunucuKapatti(1006);
      k.zaman.calistir();
      await pumpEventQueue();
      await k.son.ac();
      expect(k.son.tur('subscribe'), isEmpty);
    });

    test('recheck_failed: 5 sn sonra bir kez yeniden abone olunur', () async {
      final k = _Kurulum();
      k.istemci.abonelikleriAyarla(tayfaA, [
        (tayfaId: tayfaA, kanalId: kanal1),
      ]);
      final soket = await k.baglan();
      soket.cerceve('unsubscribed', {
        'tayfa_id': tayfaA,
        'channel_id': kanal1,
        'reason': 'recheck_failed',
      });
      await pumpEventQueue();
      final bekleme = k.zaman.etkin.where(
        (t) => t.sure == RealtimeIstemcisi.yenidenDenetimBeklemesi,
      );
      expect(bekleme, hasLength(1));
      bekleme.single.calistir();
      expect(soket.tur('subscribe'), hasLength(2));
    });

    test('channel_not_found: bulunamadı olayı yayılır', () async {
      final k = _Kurulum();
      final olaylar = <RealtimeOlayi>[];
      k.istemci.olaylar.listen(olaylar.add);
      k.istemci.abonelikleriAyarla(tayfaA, [
        (tayfaId: tayfaA, kanalId: kanal1),
      ]);
      final soket = await k.baglan();
      final id = soket.tur('subscribe').single['id']! as String;
      soket.cerceve('error', {'code': 'channel_not_found'}, id: id);
      await pumpEventQueue();
      expect(
        olaylar.whereType<AbonelikBitti>().single.neden,
        AbonelikBitisNedeni.bulunamadi,
      );
    });
  });

  group('gönderim', () {
    Map<String, Object?> mesajJson() => {
      'id': mesaj1,
      'tayfa_id': tayfaA,
      'channel_id': kanal1,
      'author_user_id': kullanici,
      'body': 'merhaba',
      'created_at': '2026-11-11T10:00:00Z',
    };

    test('send çerçevesi ve sent cevabı', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      final sonuc = k.istemci.kanalaGonder(
        tayfaId: tayfaA,
        kanalId: kanal1,
        metin: 'merhaba',
        istekKimligi: istek,
      );
      final giden = soket.tur('send').single;
      expect(giden['data'], {
        'tayfa_id': tayfaA,
        'channel_id': kanal1,
        'body': 'merhaba',
        'client_request_id': istek,
      });
      soket.cerceve('sent', mesajJson(), id: giden['id']! as String);
      final mesaj = await sonuc;
      expect(mesaj.id, mesaj1);
      expect(mesaj.deleted, isFalse);
    });

    test('bağlantı kapalıyken RealtimeKapali', () async {
      final k = _Kurulum();
      await expectLater(
        k.istemci.kanalaGonder(
          tayfaId: tayfaA,
          kanalId: kanal1,
          metin: 'x',
          istekKimligi: istek,
        ),
        throwsA(isA<RealtimeKapali>()),
      );
    });

    test('10 sn cevap gelmezse TimeoutException', () async {
      final k = _Kurulum();
      await k.baglan();
      final sonuc = k.istemci.kanalaGonder(
        tayfaId: tayfaA,
        kanalId: kanal1,
        metin: 'x',
        istekKimligi: istek,
      );
      k.zaman.calistir(RealtimeIstemcisi.cevapSuresi);
      await expectLater(sonuc, throwsA(isA<TimeoutException>()));
    });

    test('cevap gelmeden bağlantı koparsa RealtimeKapali', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      final sonuc = k.istemci.kanalaGonder(
        tayfaId: tayfaA,
        kanalId: kanal1,
        metin: 'x',
        istekKimligi: istek,
      );
      final beklenti = expectLater(sonuc, throwsA(isA<RealtimeKapali>()));
      await soket.sunucuKapatti(1006);
      await beklenti;
    });

    test('slow_mode hatası problem türüne ve süreye çevrilir', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      final sonuc = k.istemci.kanalaGonder(
        tayfaId: tayfaA,
        kanalId: kanal1,
        metin: 'x',
        istekKimligi: istek,
      );
      soket.cerceve('error', {
        'code': 'slow_mode',
        'retry_after_seconds': 12,
      }, id: soket.tur('send').single['id']! as String);
      await expectLater(
        sonuc,
        throwsA(
          isA<ApiProblem>()
              .having((p) => p.type, 'type', ProblemType.slowMode)
              .having(
                (p) => p.retryAfter,
                'retryAfter',
                const Duration(seconds: 12),
              ),
        ),
      );
    });

    test('dm.message_created içeriksiz çözülür', () async {
      final k = _Kurulum();
      final olaylar = <RealtimeOlayi>[];
      k.istemci.olaylar.listen(olaylar.add);
      final soket = await k.baglan();
      soket.cerceve('dm.message_created', {
        'id': mesaj1,
        'conversation_id': kanal2,
        'sender_user_id': kullanici,
        'encryption': 'e2e',
        'created_at': '2026-11-11T10:00:00Z',
      });
      await pumpEventQueue();
      final mesaj = (olaylar.last as DmMesajiGeldi).mesaj;
      expect(mesaj.conversationId, kanal2);
      expect(mesaj.encryption, DirectMessageEncryption.e2e);
      // Birebir mesaj WebSocket'ten gönderilmez (Tayfam-Api #151).
      expect(soket.tur('dm.send'), isEmpty);
    });
  });

  group('olaylar', () {
    test('mesaj, silme, bildirim ve birebir olayları çözülür', () async {
      final k = _Kurulum();
      final olaylar = <RealtimeOlayi>[];
      k.istemci.olaylar.listen(olaylar.add);
      final soket = await k.baglan();
      soket
        ..cerceve('message.created', {
          'id': mesaj1,
          'tayfa_id': tayfaA,
          'channel_id': kanal1,
          'author_user_id': kullanici,
          'body': 'merhaba',
          'created_at': '2026-11-11T10:00:00Z',
        })
        ..cerceve('message.deleted', {
          'tayfa_id': tayfaA,
          'channel_id': kanal1,
          'message_id': mesaj1,
        })
        ..cerceve('notification', {
          'type': 'event_created',
          'tayfa_id': tayfaA,
          'target_type': 'event',
          'target_id': kanal2,
        })
        ..cerceve('dm.read', {
          'conversation_id': kanal2,
          'user_id': kullanici,
          'last_read_message_id': mesaj1,
        })
        ..cerceve('bilinmeyen.tur', {})
        ..cerceve('message.created', {'id': 'kimlik-degil'});
      await pumpEventQueue();
      expect(olaylar.map((o) => o.runtimeType), [
        Baglandi,
        KanalMesajiGeldi,
        KanalMesajiSilindi,
        BildirimGeldi,
        DmOkundu,
      ]);
    });

    test('çerçeve içeriği loglanmaz', () async {
      final k = _Kurulum();
      final soket = await k.baglan();
      soket
        ..cerceve('error', {'code': 'rate_limited'})
        ..cerceve('message.created', {
          'id': mesaj1,
          'tayfa_id': tayfaA,
          'channel_id': kanal1,
          'body': 'gizli metin',
          'created_at': '2026-11-11T10:00:00Z',
        });
      await soket.sunucuKapatti(1006);
      final hepsi = k.gunluk.join('\n');
      expect(hepsi, isNot(contains('gizli')));
      expect(hepsi, isNot(contains('token')));
      expect(k.gunluk, contains('realtime: hata rate_limited'));
    });
  });

  group('uçtan uca şifreleme çerçeveleri', () {
    test(
      'dm.envelope, e2e.* olayları çözülür; bozuk zarf yok sayılır',
      () async {
        final k = _Kurulum();
        final olaylar = <RealtimeOlayi>[];
        k.istemci.olaylar.listen(olaylar.add);
        final soket = await k.baglan();
        final zarf = {
          'id': mesaj1,
          'message_id': mesaj1,
          'conversation_id': kanal2,
          'sender_user_id': kullanici,
          'sender_device_id': istek,
          'sender_device_number': 2,
          'type': 'prekey',
          'content': 'AQID',
          'created_at': '2026-11-11T10:00:00Z',
        };
        soket
          ..cerceve('dm.envelope', zarf)
          ..cerceve('dm.envelope', {...zarf, 'type': 'bilinmeyen'})
          ..cerceve('dm.envelope', {...zarf, 'sender_device_id': 'x'})
          ..cerceve('e2e.prekeys_low', {'ec': 3, 'kyber': 20})
          ..cerceve('e2e.link_answered', {'link_request_id': istek})
          ..cerceve('e2e.history_key_shared', {});
        await pumpEventQueue();
        expect(olaylar.map((o) => o.runtimeType), [
          Baglandi,
          DmZarfiGeldi,
          E2eOnAnahtarlarAzaldi,
          E2eEslemeCevaplandi,
          E2eGecmisAnahtariPaylasildi,
        ]);
        final z = (olaylar[1] as DmZarfiGeldi).zarf;
        expect(z.senderDeviceNumber, 2);
        expect(z.content, 'AQID');
      },
    );

    test('dm.envelope_ack gönderilir; bağlantı yoksa RealtimeKapali', () async {
      final k = _Kurulum();
      await expectLater(
        k.istemci.zarflariOnayla([mesaj1]),
        throwsA(isA<RealtimeKapali>()),
      );
      final soket = await k.baglan();
      final sonuc = k.istemci.zarflariOnayla([mesaj1]);
      final giden = soket.tur('dm.envelope_ack').single;
      expect(giden['data'], {
        'envelope_ids': [mesaj1],
      });
      soket.cerceve('dm.envelope_acked', {}, id: giden['id']! as String);
      await sonuc;
    });
  });

  test('realtime adresi taban adresin wss karşılığı', () {
    expect(
      realtimeAdresi(Uri.parse('https://api.ornek.test')).toString(),
      'wss://api.ornek.test/v1/realtime',
    );
  });
}
