import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/features/anket/application/anket_formu_notifier.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';

import '../../yardimcilar.dart';
import '../duyuru/sahteler.dart';
import '../tayfa/sahteler.dart';

export '../duyuru/sahteler.dart' show modulTasimasi, modulluGorunum, yanit;

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String anketId1 = '3c4d5e6f-0000-4000-8000-000000000001';
const String anketId2 = '3c4d5e6f-0000-4000-8000-000000000002';
const String anketId3 = '3c4d5e6f-0000-4000-8000-000000000003';
const String secenekA = '4d5e6f70-0000-4000-8000-00000000000a';
const String secenekB = '4d5e6f70-0000-4000-8000-00000000000b';
const String secenekC = '4d5e6f70-0000-4000-8000-00000000000c';
const String anketEtkinlikId = '2b3c4d5e-0000-4000-8000-000000000009';

/// Oturumdaki kullanıcı ve başka bir üye.
const String benimId = '00000000-0000-4000-8000-0000000000b1';

/// Anket formunun sabit `client_request_id`'si (testlerde).
const String anketIstekId = '7a8b9c0d-0000-4000-8000-0000000000c1';
const String digerId = '00000000-0000-4000-8000-0000000000d2';

/// Testlerin sabit saati (UTC).
final DateTime anketSimdi = DateTime.utc(2026, 11, 11, 12);

/// Anket uçlarının yol şablonları (sahte taşımanın anahtarları).
const String anketlerYolu = '/v1/tayfas/{tayfa_id}/polls';
const String anketYolu = '/v1/tayfas/{tayfa_id}/polls/{poll_id}';
const String oyYolu = '/v1/tayfas/{tayfa_id}/polls/{poll_id}/vote';
const String kapatmaYolu = '/v1/tayfas/{tayfa_id}/polls/{poll_id}/closure';
const String oyVerenlerYolu =
    '/v1/tayfas/{tayfa_id}/polls/{poll_id}/options/{option_id}/voters';

/// Örnek anket (`Poll`) JSON'u. [oylar] seçenek A, B, C'nin oy sayıları.
Map<String, Object?> anketJson(
  String id, {
  String soru = 'Pazar nereye gidelim?',
  bool gizli = false,
  bool coklu = false,
  bool kapali = false,
  int oyVeren = 0,
  List<int> oylar = const [0, 0, 0],
  List<String> kendi = const [],
  String? acan = digerId,
  String? etkinlik,
  String? kapanis,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'event_id': ?etkinlik,
  'created_by_user_id': ?acan,
  'question': soru,
  'anonymous': gizli,
  'multiple_choice': coklu,
  'closes_at': ?kapanis,
  'closed': kapali,
  'created_at': zaman,
  'options': [
    for (final (sira, (kimlik, metin)) in [
      (secenekA, 'Moda sahili'),
      (secenekB, 'Belgrad ormanı'),
      (secenekC, 'Şile feneri'),
    ].indexed)
      {
        'id': kimlik,
        'text': metin,
        'position': sira,
        'vote_count': oylar[sira],
      },
  ],
  'voter_count': oyVeren,
  'own_option_ids': kendi,
};

/// `GET …/polls` yanıtı.
Map<String, Object?> anketListesiJson(
  List<Map<String, Object?>> anketler, {
  String? sonraki,
}) => {'polls': anketler, 'next_page_token': ?sonraki};

/// Sahte taşımaya varsayılan yanıtları ekler: modül uçları ve boş anket
/// listesi.
SahteTayfaTasima anketTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = modulTasimasi(yanitlar);
  tasima.yanitlar.putIfAbsent(
    'GET $anketlerYolu',
    () => yanit(anketListesiJson([])),
  );
  return tasima;
}

/// Tayfa ve anket uçlarını [tasima]'ya bağlayan override'lar: oturum açık,
/// saat [anketSimdi], kullanıcı adları sahte ([benimId] oturumdaki
/// kullanıcı). Gerçek ağ ve güvenli depo yok.
List<Override> anketOverridelari(SahteTayfaTasima tasima) => [
  ...modulOverridelari(tasima),
  anketDeposuProvider.overrideWithValue(AnketDeposu(tasima)),
  anketSaatiProvider.overrideWithValue(() => anketSimdi),
  anketIstekKimligiProvider.overrideWithValue(() => anketIstekId),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi(id == benimId ? 'Ben Üye' : 'Ayşe Yılmaz'),
  ),
  kendiKimligiOkuyucuProvider.overrideWithValue(() async => benimId),
];
