import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/soru_cevap/data/soru_cevap_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String soruId1 = '3c4d5e6f-0000-4000-8000-000000000001';
const String soruId2 = '3c4d5e6f-0000-4000-8000-000000000002';
const String soruId3 = '3c4d5e6f-0000-4000-8000-000000000003';
const String soruId4 = '3c4d5e6f-0000-4000-8000-000000000004';
const String cevapId1 = '4d5e6f70-0000-4000-8000-000000000001';
const String cevapId2 = '4d5e6f70-0000-4000-8000-000000000002';
const String cevapId3 = '4d5e6f70-0000-4000-8000-000000000003';
const String etiketId1 = '5e6f7081-0000-4000-8000-000000000001';
const String etiketId2 = '5e6f7081-0000-4000-8000-000000000002';

/// Oturumdaki kullanıcı ve başka bir üye.
const String benimId = '00000000-0000-4000-8000-0000000000aa';
const String digerId = '00000000-0000-4000-8000-0000000000bb';

/// Sahte görünen adlar.
const String benimAdim = 'Deniz';
const String digerAdi = 'Ayşe';

/// Soru-cevap uçlarının yol şablonları (sahte taşımanın anahtarları).
const String sorularYolu = '/v1/tayfas/{tayfa_id}/questions';
const String soruYolu = '/v1/tayfas/{tayfa_id}/questions/{question_id}';
const String cevaplarYolu =
    '/v1/tayfas/{tayfa_id}/questions/{question_id}/answers';
const String cevapYolu = '/v1/tayfas/{tayfa_id}/answers/{answer_id}';
const String oyYolu = '/v1/tayfas/{tayfa_id}/answers/{answer_id}/vote';
const String etiketlerYolu = '/v1/tayfas/{tayfa_id}/tags';

/// Örnek etiket (`Tag`) JSON'u.
Map<String, Object?> etiketJson(String id, String ad, {int? sayi}) => {
  'id': id,
  'name': ad,
  'question_count': ?sayi,
};

/// Örnek soru (`Question`) JSON'u.
Map<String, Object?> soruJson(
  String id, {
  String baslik = 'Kamp için hangi çadırı alalım?',
  String govde = 'Dört kişilik, hafif bir şey arıyoruz.',
  String? yazar = digerId,
  List<Map<String, Object?>> etiketler = const [],
  int cevapSayisi = 0,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'author_user_id': ?yazar,
  'title': baslik,
  'body': govde,
  'tags': etiketler,
  'answer_count': cevapSayisi,
  'created_at': zaman,
  'updated_at': zaman,
};

/// `GET …/questions` yanıtı.
Map<String, Object?> soruListesiJson(
  List<Map<String, Object?>> sorular, {
  String? sonraki,
}) => {'questions': sorular, 'next_page_token': ?sonraki};

/// Örnek cevap (`Answer`) JSON'u.
Map<String, Object?> cevapJson(
  String id, {
  String soruId = soruId1,
  String govde = 'Bizim ekip iki tane hafif kubbe çadır kullanıyor.',
  String? yazar = digerId,
  int oy = 0,
  bool oyladim = false,
  String zaman = '2026-11-10T12:00:00Z',
}) => {
  'id': id,
  'question_id': soruId,
  'tayfa_id': ornekTayfaId,
  'author_user_id': ?yazar,
  'body': govde,
  'vote_count': oy,
  'voted': oyladim,
  'created_at': zaman,
  'updated_at': zaman,
};

/// `GET …/answers` yanıtı.
Map<String, Object?> cevapListesiJson(
  List<Map<String, Object?>> cevaplar, {
  String? sonraki,
}) => {'answers': cevaplar, 'next_page_token': ?sonraki};

/// `GET /v1/tayfas/{tayfa_id}` yanıtı; rol verilebilir.
Map<String, Object?> rolluGorunum({String rol = 'member'}) =>
    gorunumJson(ornekTayfaId, rol: rol);

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Sahte taşımaya varsayılan yanıtları ekler: tayfa görünümü (üye), boş
/// soru listesi, boş cevap listesi ve boş etiket listesi.
SahteTayfaTasima soruTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent('GET /v1/tayfas/{tayfa_id}', () => yanit(rolluGorunum()))
    ..putIfAbsent('GET $sorularYolu', () => yanit(soruListesiJson([])))
    ..putIfAbsent('GET $cevaplarYolu', () => yanit(cevapListesiJson([])))
    ..putIfAbsent('GET $etiketlerYolu', () => yanit({'tags': <Object?>[]}));
  return tasima;
}

/// Tayfa ve soru-cevap uçlarını [tasima]'ya bağlayan override'lar; oturum
/// açık başlar, görünen adlar sahtedir ([benimId] oturumdaki kullanıcı).
/// Gerçek ağ ve güvenli depo yok.
List<Override> soruOverridelari(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  soruCevapDeposuProvider.overrideWithValue(SoruCevapDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => id == benimId
        ? const KullaniciAdi(benimAdim, ben: true)
        : const KullaniciAdi(digerAdi),
  ),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];
