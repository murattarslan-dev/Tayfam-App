import 'dart:math';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/e2e/mesaj/e2e_mesaj.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/birebir/application/konusma_notifier.dart';
import 'package:tayfam/features/birebir/data/birebir_deposu.dart';

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

/// Örnek birebir mesaj (`DirectMessage`) JSON'u.
Map<String, Object?> mesajJson(
  String id, {
  String konusma = konusmaId1,
  String? gonderen = karsiId,
  String? metin = 'Selam, pazar geliyor musun?',
  bool silinmis = false,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'conversation_id': konusma,
  'sender_user_id': ?gonderen,
  'body': ?(silinmis ? null : metin),
  'deleted': silinmis,
  'created_at': zaman,
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
/// zamanlayıcısı test süresince tetiklenmez. Gerçek ağ yok. Uçtan uca
/// şifreleme kapalıdır (düz sürüm yolu); E2E testleri kendi
/// override'larını verir.
List<Override> birebirOverridelari([SahteTayfaTasima? tasima]) => [
  e2eEtkinProvider.overrideWithValue(false),
  ...birebirUcOverridelari(tasima),
];

/// [birebirOverridelari]'nın E2E anahtarı olmadan hali (E2E testleri
/// `e2eEtkinProvider`'ı kendisi verir).
List<Override> birebirUcOverridelari([SahteTayfaTasima? tasima]) {
  final t = tasima ?? birebirTasimasi();
  return [
    birebirDeposuProvider.overrideWithValue(BirebirDeposu(t)),
    birebirYenilemeAraligiProvider.overrideWithValue(const Duration(days: 1)),
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
/// (verilmezse hiç bağlanmayan sahte).
List<Override> birebirEkranOverridelari(
  SahteTayfaTasima tasima, {
  OturumDurumu oturum = OturumDurumu.acik,
  SahteRealtime? realtime,
  bool e2e = false,
}) {
  final r = realtime ?? SahteRealtime();
  return [
    ...tayfaOverridelari(tasima: tasima),
    e2eEtkinProvider.overrideWithValue(e2e),
    ...birebirUcOverridelari(tasima),
    profilAdlari,
    oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(oturum)),
    realtimeIstemcisiProvider.overrideWithValue(r.istemci),
    zamanlayiciProvider.overrideWithValue(r.zaman.kur),
  ];
}
