import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/apis/direct_messages_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/birebir/application/birebir_gonderici.dart';
import 'package:tayfam/features/birebir/application/konusma_notifier.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';
import 'package:tayfam/features/birebir/data/sessiz_deposu.dart';

import '../../core/realtime/sahte_soket.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String konusmaId1 = '3c4d5e6f-0000-4000-8000-000000000001';
const String konusmaId2 = '3c4d5e6f-0000-4000-8000-000000000002';
const String konusmaId3 = '3c4d5e6f-0000-4000-8000-000000000003';
const String mesajId1 = '4d5e6f70-0000-4000-8000-000000000001';
const String mesajId2 = '4d5e6f70-0000-4000-8000-000000000002';
const String mesajId3 = '4d5e6f70-0000-4000-8000-000000000003';
const String mesajId4 = '4d5e6f70-0000-4000-8000-000000000004';

/// Oturumdaki kullanıcı (testte yalnızca gönderen kimliği olarak).
const String benId = '5e6f7081-0000-4000-8000-000000000001';

/// Karşı taraf.
const String karsiId = '5e6f7081-0000-4000-8000-000000000002';

/// Başka bir kişi.
const String digerId = '5e6f7081-0000-4000-8000-000000000003';

/// Birebir uçlarının yol şablonları (sahte taşımanın anahtarları).
const String gonderYolu = '/v1/direct-messages';
const String konusmalarYolu = '/v1/direct-messages/conversations';
const String konusmaYolu =
    '/v1/direct-messages/conversations/{conversation_id}';
const String mesajlarYolu =
    '/v1/direct-messages/conversations/{conversation_id}/messages';
const String mesajYolu =
    '/v1/direct-messages/conversations/{conversation_id}/messages/{message_id}';
const String okunduYolu =
    '/v1/direct-messages/conversations/{conversation_id}/read';
const String kabulYolu =
    '/v1/direct-messages/conversations/{conversation_id}/accept';
const String retYolu =
    '/v1/direct-messages/conversations/{conversation_id}/decline';
const String reddedilenlerYolu = '/v1/direct-messages/declined-requests';
const String reddedilenYolu =
    '/v1/direct-messages/declined-requests/{conversation_id}';

/// Bildirim tercihi uçlarının yol şablonları.
const String tercihlerYolu = '/v1/notification-preferences';
const String konusmaTercihiYolu =
    '/v1/notification-preferences/conversations/{conversation_id}';

/// Örnek birebir konuşma bildirim tercihi (`NotificationPreference`)
/// JSON'u; [bitis] yoksa süresiz.
Map<String, Object?> konusmaTercihiJson(
  String konusma, {
  String seviye = 'none',
  String? bitis,
  String kapsam = 'dm_conversation',
}) => {
  'scope_type': kapsam,
  'scope_id': konusma,
  'level': seviye,
  'mute_until': ?bitis,
  'updated_at': '2026-11-10T10:00:00Z',
};

/// `GET /v1/notification-preferences` yanıtı.
Map<String, Object?> tercihListesiJson(List<Map<String, Object?>> tercihler) =>
    {'preferences': tercihler};

/// Örnek konuşma (`Conversation`) JSON'u.
Map<String, Object?> konusmaJson(
  String id, {
  String? karsi = karsiId,
  String durum = 'active',
  int okunmamis = 0,
  String? okundu,
  String? karsiOkundu,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'other_user_id': ?karsi,
  'status': durum,
  'unread_count': okunmamis,
  'last_read_message_id': ?okundu,
  'peer_last_read_message_id': ?karsiOkundu,
  'last_message_at': zaman,
  'created_at': '2026-11-01T10:00:00Z',
};

/// `GET …/conversations` yanıtı.
Map<String, Object?> konusmaListesiJson(
  List<Map<String, Object?>> konusmalar, {
  String? sonraki,
}) => {'conversations': konusmalar, 'next_page_token': ?sonraki};

/// Örnek birebir mesaj (`DirectMessage`) JSON'u. Her birebir mesaj uçtan
/// uca şifrelidir ve içerik taşımaz (Tayfam-Api #151); metni testte
/// [cozulmusIcerik] verir.
Map<String, Object?> mesajJson(
  String id, {
  String konusma = konusmaId1,
  String? gonderen = karsiId,
  bool silinmis = false,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'conversation_id': konusma,
  'sender_user_id': ?gonderen,
  'deleted': silinmis,
  'encryption': 'e2e',
  'created_at': zaman,
};

/// Bellekte çözülmüş içerik: mesaj kimliği → metin ([konusma]'da).
BirebirIcerikDurumu cozulmusIcerik(
  Map<String, String> metinler, {
  String konusma = konusmaId1,
}) => BirebirIcerikDurumu(
  mesajlar: {
    for (final MapEntry(key: id, value: metin) in metinler.entries)
      id: CozulmusBirebirMesaj(
        mesajId: id,
        konusmaId: konusma,
        gonderenKullaniciId: karsiId,
        metin: metin,
        olusturma: DateTime.utc(2026, 11, 10, 10),
        kaynak: CozulmusMesajKaynagi.zarf,
      ),
  },
);

/// Bellekteki çözülmüş içerik sabit bir durumla başlar.
class SabitIcerik extends BirebirIcerikNotifier {
  SabitIcerik(this._ilk);

  final BirebirIcerikDurumu _ilk;

  @override
  BirebirIcerikDurumu build() => _ilk;
}

/// E2E cihaz durumu sabit (ağ, Signal motoru ve kayıt yok).
class SabitCihaz extends E2eCihazNotifier {
  SabitCihaz(this._durum);

  final E2eCihazBilgisi _durum;

  @override
  E2eCihazBilgisi build() => _durum;
}

/// Sahte zarf (testte şifreleme yok; içerik metni taşımaz).
const OutgoingEnvelope sahteZarf = OutgoingEnvelope(
  deviceId: '6f708192-0000-4000-8000-000000000001',
  registrationId: 1,
  type: OutgoingEnvelopeType.whisper,
  content: 'AAAA',
);

/// Testteki şifreli gönderim: Signal yerine [sahteZarf]'la aynı REST
/// isteğini (`POST /v1/direct-messages`, `envelopes`) [tasima]'ya atar ve
/// gerçek gönderim gibi metni bellekteki içeriğe ekler. Gerçek E2E yolu
/// `e2e_test.dart` ve `core/e2e/mesaj/` testlerindedir.
SifreliGonderim sahteSifreliGonderim(Ref ref, ApiTransport tasima) =>
    ({
      required String aliciId,
      required String metin,
      required String istekKimligi,
    }) async {
      final sonuc = await DirectMessagesApi(tasima).sendDirectMessage(
        body: DirectMessageCreateRequest(
          recipientUserId: aliciId,
          envelopes: const [sahteZarf],
          clientRequestId: istekKimligi,
        ),
      );
      ref.read(birebirIcerikProvider.notifier).ekle([
        CozulmusBirebirMesaj(
          mesajId: sonuc.message.id,
          konusmaId: sonuc.message.conversationId,
          gonderenKullaniciId: benId,
          metin: metin,
          olusturma: sonuc.message.createdAt,
          kaynak: CozulmusMesajKaynagi.gonderildi,
        ),
      ]);
      return sonuc;
    };

/// `GET …/messages` yanıtı.
Map<String, Object?> mesajListesiJson(
  List<Map<String, Object?>> mesajlar, {
  String? sonraki,
}) => {'messages': mesajlar, 'next_page_token': ?sonraki};

/// `GET /v1/direct-messages/declined-requests` yanıtı.
Map<String, Object?> reddedilenlerJson(
  List<String> konusmalar, {
  String? sonraki,
}) => {
  'declined_requests': [
    for (final k in konusmalar)
      {
        'conversation_id': k,
        'sender_user_id': digerId,
        'declined_at': '2026-11-09T10:00:00Z',
        'created_at': '2026-11-08T10:00:00Z',
      },
  ],
  'next_page_token': ?sonraki,
};

/// Varsayılan yanıtlarla sahte taşıma: konuşma yok, okundu işareti kabul.
SahteTayfaTasima birebirTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent(
      'GET $konusmalarYolu',
      () =>
          (_) => konusmaListesiJson(const []),
    )
    ..putIfAbsent(
      'PUT $okunduYolu',
      () =>
          (_) => null,
    );
  return tasima;
}

/// Birebir uçlarını [tasima]'ya bağlayan override'lar; yenileme
/// zamanlayıcısı test süresince tetiklenmez. Gerçek ağ yok. Bu derlemede
/// E2E yoktur (web/iOS gibi); gönderim [sahteSifreliGonderim]'le gider.
/// E2E testleri kendi override'larını verir.
List<Override> birebirOverridelari([SahteTayfaTasima? tasima]) => [
  e2eEtkinProvider.overrideWithValue(false),
  ...birebirUcOverridelari(tasima),
];

/// [birebirOverridelari]'nın E2E anahtarı olmadan hali (E2E testleri
/// `e2eEtkinProvider`'ı kendisi verir). [sahteGonderim] `false` ise
/// gönderim gerçek E2E yolundan ([birebirGondericiProvider]) gider.
List<Override> birebirUcOverridelari([
  SahteTayfaTasima? tasima,
  bool sahteGonderim = true,
]) {
  final t = tasima ?? birebirTasimasi();
  // Bildirim tercihleri (sessize alma): varsayılan olarak tercih yok.
  t.yanitlar.putIfAbsent(
    'GET $tercihlerYolu',
    () =>
        (_) => tercihListesiJson(const []),
  );
  return [
    birebirDeposuProvider.overrideWithValue(BirebirDeposu(t)),
    sessizDeposuProvider.overrideWithValue(SessizDeposu(t)),
    birebirYenilemeAraligiProvider.overrideWithValue(const Duration(days: 1)),
    if (sahteGonderim)
      birebirGondericiProvider.overrideWith(
        (ref) => BirebirGonderici(sahteSifreliGonderim(ref, t)),
      ),
  ];
}

/// Profil adları: karşı taraf "Deniz", diğer kişi "Ece"; ağ yok.
final Override profilAdlari = profilOkuyucuProvider.overrideWithValue(
  (id) async => switch (id) {
    karsiId => const KullaniciAdi('Deniz'),
    digerId => const KullaniciAdi('Ece'),
    _ => const KullaniciAdi('Ben', ben: true),
  },
);

/// Sahte WebSocket: bağlantı [baglan] çağrılana kadar kapalıdır (gönderim
/// REST'ten gider); zamanlayıcı elle çalışır.
final class SahteRealtime {
  SahteRealtime() {
    istemci = RealtimeIstemcisi(
      adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
      baglayici: (adres, basliklar) {
        final s = SahteSoket(adres, basliklar);
        soketler.add(s);
        return s;
      },
      tokenAl: () async => 'token',
      reddedildi: (_) async => 'token',
      oturumuKapat: () async {},
      zamanlayici: zaman.kur,
      rastgele: Random(1),
      gunluk: (_) {},
    );
  }

  final SahteZamanlayici zaman = SahteZamanlayici();
  final List<SahteSoket> soketler = [];
  late final RealtimeIstemcisi istemci;

  /// Bağlantıyı açar (`ready`).
  Future<SahteSoket> baglan() async {
    istemci.baslat();
    await pumpEventQueue();
    await soketler.last.ac();
    return soketler.last;
  }
}

/// Birebir ve tayfa uçlarını [tasima]'ya bağlayan, oturumu [oturum] ile
/// (varsayılan: açık) başlatan override'lar. WebSocket [realtime]'dan
/// (verilmezse hiç bağlanmayan sahte). [cihaz] verilirse E2E cihaz
/// durumu, [metinler] verilirse bellekteki çözülmüş içerik sabittir.
List<Override> birebirEkranOverridelari(
  SahteTayfaTasima tasima, {
  OturumDurumu oturum = OturumDurumu.acik,
  SahteRealtime? realtime,
  bool e2e = false,
  E2eCihazBilgisi? cihaz,
  Map<String, String>? metinler,
  bool sahteGonderim = true,
}) {
  final r = realtime ?? SahteRealtime();
  return [
    ...tayfaOverridelari(tasima: tasima),
    e2eEtkinProvider.overrideWithValue(e2e),
    ...birebirUcOverridelari(tasima, sahteGonderim),
    if (cihaz != null) e2eCihazProvider.overrideWith(() => SabitCihaz(cihaz)),
    if (metinler != null)
      birebirIcerikProvider.overrideWith(
        () => SabitIcerik(cozulmusIcerik(metinler)),
      ),
    profilAdlari,
    oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(oturum)),
    realtimeIstemcisiProvider.overrideWithValue(r.istemci),
    zamanlayiciProvider.overrideWithValue(r.zaman.kur),
  ];
}
