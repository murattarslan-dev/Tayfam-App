import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/birebir/application/giden_mesaj.dart';
import 'package:tayfam/features/birebir/application/kisi_konusmasi_notifier.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/application/konusma_notifier.dart';
import 'package:tayfam/features/birebir/application/mesaj_kurallari.dart';
import 'package:tayfam/features/birebir/application/reddedilenler_notifier.dart';

import '../tayfa/sahteler.dart';
import 'sahteler.dart';

final class _Kurulum {
  _Kurulum([
    Map<String, TayfaYaniti>? yanitlar,
    OturumDurumu? oturum,
    SahteRealtime? realtime,
  ]) : tasima = birebirTasimasi(yanitlar),
       realtime = realtime ?? SahteRealtime() {
    kap = ProviderContainer.test(
      overrides: birebirEkranOverridelari(
        tasima,
        oturum: oturum ?? OturumDurumu.acik,
        realtime: this.realtime,
      ),
    );
  }

  final SahteTayfaTasima tasima;
  final SahteRealtime realtime;
  late final ProviderContainer kap;

  Future<KonusmaListesiNotifier> liste() async {
    kap.listen(konusmaListesiProvider, (_, _) {});
    await kap.read(konusmaListesiProvider.future);
    return kap.read(konusmaListesiProvider.notifier);
  }

  List<Conversation> get konusmalar =>
      kap.read(konusmaListesiProvider).requireValue.ogeler;

  Future<KonusmaNotifier> konusma([String id = konusmaId1]) async {
    final saglayici = konusmaProvider(id);
    kap.listen(saglayici, (_, _) {});
    await kap.read(saglayici.future);
    return kap.read(saglayici.notifier);
  }

  KonusmaDurumu durum([String id = konusmaId1]) =>
      kap.read(konusmaProvider(id)).requireValue;

  /// Karşı tarafa giden, kuyruktaki mesajlar.
  List<GidenMesaj> get bekleyen => kap.read(bekleyenBirebirProvider(karsiId));
}

/// Konuşma ve mesaj uçlarının varsayılan yanıtları.
Map<String, TayfaYaniti> _konusmaYanitlari({
  String durum = 'active',
  String? karsi = karsiId,
  String? karsiOkundu,
  List<Map<String, Object?>>? mesajlar,
}) => {
  'GET $konusmaYolu': (_) => konusmaJson(
    konusmaId1,
    durum: durum,
    karsi: karsi,
    karsiOkundu: karsiOkundu,
  ),
  'GET $mesajlarYolu': (_) => mesajListesiJson(
    mesajlar ??
        [
          mesajJson(mesajId2, zaman: '2026-11-10T11:00:00Z'),
          mesajJson(mesajId1, gonderen: benId, metin: 'Merhaba'),
        ],
  ),
};

Map<String, Object?> _gonderimJson({String durum = 'active'}) => {
  'message': mesajJson(
    mesajId3,
    gonderen: benId,
    metin: 'Geliyorum',
    zaman: '2026-11-10T12:00:00Z',
  ),
  'conversation': konusmaJson(
    konusmaId1,
    durum: durum,
    zaman: '2026-11-10T12:00:00Z',
  ),
};

Future<void> _bekle() => Future<void>.delayed(Duration.zero);

void main() {
  group('mesaj kuralları', () {
    test('boş, yalnız boşluk, 4000 üstü ve kontrol karakteri geçersiz', () {
      expect(birebirMetniGecerli(''), isFalse);
      expect(birebirMetniGecerli('  \n\t '), isFalse);
      expect(birebirMetniGecerli('a' * 4001), isFalse);
      expect(birebirMetniGecerli('selam\u0007'), isFalse);
      expect(birebirMetniGecerli('selam\u0085'), isFalse);
    });

    test('sekme ve satır sonu serbest; 4000 karakter geçerli', () {
      expect(birebirMetniGecerli('a\tb\nc'), isTrue);
      expect(birebirMetniGecerli('ş' * 4000), isTrue);
    });

    test('hazırlama satır sonlarını birleştirir ve kırpar', () {
      expect(birebirMetniniHazirla('  a\r\nb\rc  '), 'a\nb\nc');
    });
  });

  group('konuşma listesi', () {
    test('oturum açık değilse istek atılmaz ve liste boş', () async {
      final k = _Kurulum(null, OturumDurumu.girisYok);
      await k.liste();
      expect(k.konusmalar, isEmpty);
      expect(k.tasima.istekler, isEmpty);
    });

    test('okunmamış toplamı ve mesaj istekleri ayrılıyor', () async {
      final k = _Kurulum({
        'GET $konusmalarYolu': (_) => konusmaListesiJson([
          konusmaJson(konusmaId1, okunmamis: 3),
          konusmaJson(konusmaId2, durum: 'request_received', okunmamis: 1),
          konusmaJson(konusmaId3, durum: 'request_sent'),
        ]),
      });
      await k.liste();
      expect(k.kap.read(birebirOkunmamisSayisiProvider), 4);
      expect(k.kap.read(mesajIstekleriProvider).map((c) => c.id), [konusmaId2]);
    });

    test('yansıtılan konuşma son mesaja göre sıraya giriyor', () async {
      final k = _Kurulum({
        'GET $konusmalarYolu': (_) => konusmaListesiJson([
          konusmaJson(konusmaId1, zaman: '2026-11-10T10:00:00Z'),
          konusmaJson(konusmaId2, zaman: '2026-11-09T10:00:00Z'),
        ]),
      });
      final liste = await k.liste();
      liste.yansit(
        Conversation.fromJson(
          konusmaJson(konusmaId2, zaman: '2026-11-11T10:00:00Z'),
        ),
      );
      expect(k.konusmalar.map((c) => c.id), [konusmaId2, konusmaId1]);
      liste.cikar(konusmaId2);
      expect(k.konusmalar.map((c) => c.id), [konusmaId1]);
    });
  });

  group('konuşma', () {
    test('mesajlar en yeni önce; giden mesaj ayırt ediliyor', () async {
      final k = _Kurulum(_konusmaYanitlari());
      await k.konusma();
      final d = k.durum();
      expect(d.mesajlar.map((m) => m.id), [mesajId2, mesajId1]);
      expect(d.gidenMi(d.mesajlar.first), isFalse);
      expect(d.gidenMi(d.mesajlar.last), isTrue);
    });

    test('gönderim: gövdede alıcı, metin ve istek kimliği', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(),
        'POST $gonderYolu': (_) => _gonderimJson(),
      });
      await k.liste();
      final n = await k.konusma();
      expect(n.gonder('  Geliyorum  '), isTrue);
      expect(k.bekleyen.single.durum, GidenDurumu.gonderiliyor);
      await _bekle();

      final istek = k.tasima.giden('POST', gonderYolu).single;
      expect(istek.govde, {
        'recipient_user_id': karsiId,
        'body': 'Geliyorum',
        'client_request_id': sahteIstekKimligi,
      });
      final d = k.durum();
      expect(k.bekleyen, isEmpty);
      expect(d.mesajlar.first.id, mesajId3);
      expect(k.konusmalar.map((c) => c.id), [konusmaId1]);
    });

    test('geçersiz metin gönderilmiyor', () async {
      final k = _Kurulum(_konusmaYanitlari());
      final n = await k.konusma();
      expect(n.gonder('   '), isFalse);
      expect(k.tasima.giden('POST', gonderYolu), isEmpty);
    });

    test('gönderilemeyen mesaj aynı kimlikle yeniden deneniyor', () async {
      var deneme = 0;
      final k = _Kurulum({
        ..._konusmaYanitlari(durum: 'request_sent'),
        'POST $gonderYolu': (_) => deneme++ == 0
            ? const ApiProblem(
                type: ProblemType.messageRequestPending,
                status: 409,
              )
            : _gonderimJson(durum: 'request_sent'),
      });
      final n = await k.konusma();
      n.gonder('Geliyorum');
      await _bekle();
      final basarisiz = k.bekleyen.single;
      expect(basarisiz.durum, GidenDurumu.basarisiz);
      expect(
        (basarisiz.hata! as ApiProblem).type,
        ProblemType.messageRequestPending,
      );

      n.tekrarDene(basarisiz.istekKimligi);
      await _bekle();
      final kimlikler = [
        for (final i in k.tasima.giden('POST', gonderYolu))
          (i.govde! as Map<String, Object?>)['client_request_id'],
      ];
      expect(kimlikler, [sahteIstekKimligi, sahteIstekKimligi]);
      expect(k.bekleyen, isEmpty);
    });

    test('gönderilemeyen mesaj silinebiliyor', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(),
        'POST $gonderYolu': (_) => const ApiOffline(),
      });
      final n = await k.konusma();
      n.gonder('Geliyorum');
      await _bekle();
      // Bağlantı yok geçici hatadır: mesaj beklemede kalır (ADR-0006).
      expect(k.bekleyen.single.durum, GidenDurumu.gonderiliyor);
      n.vazgec(sahteIstekKimligi);
      expect(k.bekleyen, isEmpty);
    });

    test('bağlantı açıkken dm.send ile gidiyor', () async {
      final r = SahteRealtime();
      final k = _Kurulum(_konusmaYanitlari(), null, r);
      final n = await k.konusma();
      final soket = await r.baglan();
      expect(n.gonder('Geliyorum'), isTrue);
      await pumpEventQueue();

      final cerceve = soket.tur('dm.send').single;
      expect(cerceve['data'], {
        'recipient_user_id': karsiId,
        'body': 'Geliyorum',
        'client_request_id': sahteIstekKimligi,
      });
      soket.cerceve('dm.sent', {
        ...mesajJson(mesajId3, gonderen: benId, metin: 'Geliyorum'),
        'created_at': '2026-11-10T12:00:00Z',
        'conversation_status': 'active',
      }, id: cerceve['id']! as String);
      await pumpEventQueue();

      expect(k.tasima.giden('POST', gonderYolu), isEmpty);
      expect(k.bekleyen, isEmpty);
      expect(k.durum().mesajlar.first.id, mesajId3);
    });

    test('WebSocket olayları akışı güncelliyor', () async {
      final r = SahteRealtime();
      final k = _Kurulum(_konusmaYanitlari(), null, r);
      await k.konusma();
      final soket = await r.baglan();

      soket.cerceve('dm.message_created', {
        'id': mesajId4,
        'conversation_id': konusmaId1,
        'sender_user_id': karsiId,
        'body': 'Yoldayım',
        'created_at': '2026-11-10T13:00:00Z',
      });
      soket.cerceve('dm.message_deleted', {
        'conversation_id': konusmaId1,
        'message_id': mesajId2,
      });
      soket.cerceve('dm.read', {
        'conversation_id': konusmaId1,
        'user_id': karsiId,
        'last_read_message_id': mesajId1,
      });
      // Başka konuşmanın olayı yok sayılır.
      soket.cerceve('dm.message_deleted', {
        'conversation_id': konusmaId2,
        'message_id': mesajId1,
      });
      await pumpEventQueue();

      final d = k.durum();
      expect(d.mesajlar.first.body, 'Yoldayım');
      expect(d.mesajlar.firstWhere((m) => m.id == mesajId2).deleted, isTrue);
      expect(d.mesajlar.firstWhere((m) => m.id == mesajId1).deleted, isFalse);
      expect(d.gorulenGidenId, mesajId1);
    });

    test('kabul olayı konuşmayı aktif yapıyor', () async {
      final r = SahteRealtime();
      final k = _Kurulum(_konusmaYanitlari(durum: 'request_sent'), null, r);
      await k.konusma();
      final soket = await r.baglan();
      soket.cerceve('dm.conversation_accepted', {
        'conversation_id': konusmaId1,
      });
      await pumpEventQueue();
      expect(k.durum().konusma.status, ConversationStatus.active);
    });

    test('hesabı silinmiş kişiye gönderilmiyor', () async {
      final k = _Kurulum(_konusmaYanitlari(karsi: null));
      final n = await k.konusma();
      expect(n.gonder('Selam'), isFalse);
    });

    test('silme mesajı "silindi" yapıyor', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(),
        'DELETE $mesajYolu': (_) => null,
      });
      final n = await k.konusma();
      expect(await n.sil(mesajId1), isNull);
      final silinen = k.durum().mesajlar.firstWhere((m) => m.id == mesajId1);
      expect(silinen.deleted, isTrue);
      expect(silinen.body, isNull);
      expect(k.tasima.giden('DELETE', mesajYolu).single.yolParametreleri, {
        'conversation_id': konusmaId1,
        'message_id': mesajId1,
      });
    });

    test('kabul konuşmayı aktif yapıyor', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(durum: 'request_received'),
        'POST $kabulYolu': (_) => konusmaJson(konusmaId1),
      });
      final n = await k.konusma();
      expect(await n.kabulEt(), isNull);
      expect(k.durum().konusma.status, ConversationStatus.active);
    });

    test('ret konuşmayı listeden çıkarıyor', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(durum: 'request_received'),
        'GET $konusmalarYolu': (_) => konusmaListesiJson([
          konusmaJson(konusmaId1, durum: 'request_received'),
        ]),
        'POST $retYolu': (_) => null,
      });
      await k.liste();
      final n = await k.konusma();
      expect(await n.reddet(), isNull);
      expect(k.konusmalar, isEmpty);
    });

    test('okundu işareti en yeni mesaja; ikinci kez istek gitmiyor', () async {
      final k = _Kurulum(_konusmaYanitlari());
      final n = await k.konusma();
      await n.okunduIsaretle();
      await n.okunduIsaretle();
      final istekler = k.tasima.giden('PUT', okunduYolu);
      expect(istekler, hasLength(1));
      expect(istekler.single.govde, {'message_id': mesajId2});
      expect(k.durum().konusma.unreadCount, 0);
    });

    test('yenileme son mesajdan sonrakileri ekliyor', () async {
      final k = _Kurulum({
        ..._konusmaYanitlari(),
        'GET $mesajlarYolu': (i) => i.sorgu['after_message_id'] == null
            ? mesajListesiJson([mesajJson(mesajId1)])
            : mesajListesiJson([
                mesajJson(mesajId4, zaman: '2026-11-10T13:00:00Z'),
              ]),
      });
      final n = await k.konusma();
      await n.yeniler();
      expect(
        k.tasima.giden('GET', mesajlarYolu).last.sorgu['after_message_id'],
        mesajId1,
      );
      expect(k.durum().mesajlar.map((m) => m.id), [mesajId4, mesajId1]);
    });

    test('"Görüldü" karşının okuduğu en yeni giden mesajda', () async {
      final k = _Kurulum(
        _konusmaYanitlari(
          karsiOkundu: mesajId2,
          mesajlar: [
            mesajJson(mesajId3, gonderen: benId, zaman: '2026-11-10T12:00:00Z'),
            mesajJson(mesajId2, zaman: '2026-11-10T11:00:00Z'),
            mesajJson(mesajId1, gonderen: benId),
          ],
        ),
      );
      await k.konusma();
      expect(k.durum().gorulenGidenId, mesajId1);
    });
  });

  group('kişiyle konuşma', () {
    test('sayfalar taranıyor ve konuşma bulunuyor', () async {
      final k = _Kurulum({
        'GET $konusmalarYolu': (i) => switch (i.sorgu['page_token']) {
          null => konusmaListesiJson([
            konusmaJson(konusmaId1, karsi: digerId),
          ], sonraki: 'opak-1'),
          _ => konusmaListesiJson([konusmaJson(konusmaId2)]),
        },
      });
      final saglayici = kisiKonusmasiProvider(karsiId);
      k.kap.listen(saglayici, (_, _) {});
      expect(await k.kap.read(saglayici.future), konusmaId2);
    });

    test('konuşma yoksa ilk mesaj konuşmayı açıyor', () async {
      final k = _Kurulum({'POST $gonderYolu': (_) => _gonderimJson()});
      final saglayici = kisiKonusmasiProvider(karsiId);
      k.kap.listen(saglayici, (_, _) {});
      expect(await k.kap.read(saglayici.future), isNull);

      final yeni = yeniMesajProvider(karsiId);
      k.kap.listen(yeni, (_, _) {});
      expect(k.kap.read(yeni.notifier).gonder('Selam'), isTrue);
      await _bekle();
      expect(k.kap.read(yeni).konusmaId, konusmaId1);
      final govde =
          k.tasima.giden('POST', gonderYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['recipient_user_id'], karsiId);
    });

    test('izin yoksa hata mesajda kalıyor', () async {
      final k = _Kurulum({
        'POST $gonderYolu': (_) => const ApiProblem(
          type: ProblemType.directMessageNotAllowed,
          status: 403,
        ),
      });
      final yeni = yeniMesajProvider(karsiId);
      k.kap.listen(yeni, (_, _) {});
      k.kap.read(yeni.notifier).gonder('Selam');
      await _bekle();
      final giden = k.kap.read(yeni).giden!;
      expect(giden.durum, GidenDurumu.basarisiz);
      expect(
        (giden.hata! as ApiProblem).type,
        ProblemType.directMessageNotAllowed,
      );
      k.kap.read(yeni.notifier).vazgec();
      expect(k.kap.read(yeni).giden, isNull);
    });
  });

  group('reddedilenler', () {
    test('listeden çıkarınca konuşma listesi yenileniyor', () async {
      var cikarildi = false;
      final k = _Kurulum({
        'GET $reddedilenlerYolu': (_) => reddedilenlerJson([konusmaId2]),
        'DELETE $reddedilenYolu': (_) {
          cikarildi = true;
          return null;
        },
        'GET $konusmalarYolu': (_) => konusmaListesiJson([
          if (cikarildi)
            konusmaJson(konusmaId2, karsi: digerId, durum: 'request_received'),
        ]),
      });
      await k.liste();
      k.kap.listen(reddedilenlerProvider, (_, _) {});
      await k.kap.read(reddedilenlerProvider.future);

      final hata = await k.kap
          .read(reddedilenlerProvider.notifier)
          .listedenCikar(konusmaId2);
      expect(hata, isNull);
      expect(k.kap.read(reddedilenlerProvider).requireValue.ogeler, isEmpty);
      expect(k.kap.read(mesajIstekleriProvider).map((c) => c.id), [konusmaId2]);
    });
  });
}
