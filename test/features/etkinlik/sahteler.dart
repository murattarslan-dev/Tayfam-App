import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/core/degerlendirme/magaza_degerlendirmesi.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_deposu.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli etkinlik kimlikleri.
const String ornekEtkinlikId = '3f6c2b1a-8d4e-4a7b-9c10-2e5d6f7a8b9c';
const String ikinciEtkinlikId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

/// Testlerde kullanılan organizatör ve katılımcı kimlikleri.
const String organizatorId = '5d4c3b2a-1f0e-4d9c-8b7a-6f5e4d3c2b1a';
const String katilimciId = '6e5d4c3b-2a1f-4e0d-9c8b-7a6f5e4d3c2b';

/// Testlerin sabit "şimdi"si (UTC).
final DateTime sabitSimdi = DateTime.utc(2026, 11, 11, 9);

/// Örnek etkinliğin başlangıcı: 14 Kasım 2026 Cumartesi 09:00 (Türkiye).
final DateTime ornekBaslangic = DateTime.utc(2026, 11, 14, 6);

/// Etkinlik uçları.
const String etkinliklerYolu = '/v1/tayfas/{tayfa_id}/events';
const String etkinlikYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}';
const String katilimYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/rsvp';
const String katilimcilarYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees';
const String takvimYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/calendar';
const String iptalYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/cancellation';
const String profilYolu = '/v1/users/{user_id}/profile';
const String varisYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/check-in';
const String bilesenlerYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/components';
const String bilesenYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/components/{component_key}';
const String listeYolu = '$bilesenYolu/items';
const String yoklamaYolu = '$bilesenYolu/roll-call';
const String gunlukYolu = '$bilesenYolu/entries';
const String gunlukKaydiYolu = '$gunlukYolu/{entry_id}';
const String olcumYolu = '$bilesenYolu/measure';
const String olcumToplamiYolu = '$olcumYolu/total';
const String olcumKaydiYolu = '$olcumYolu/entries/{user_id}';
const String hedefYolu = '$bilesenYolu/goal';
const String hedefDegeriYolu = '$hedefYolu/target';
const String dereceYolu = '$bilesenYolu/ranking';
const String dereceKaydiYolu = '$dereceYolu/entries/{user_id}';
const String kutlamaYolu = '$bilesenYolu/celebration';
const String sorularYolu = '$bilesenYolu/questions';
const String soruYolu = '$sorularYolu/{question_id}';
const String soruOyuYolu = '$soruYolu/vote';
const String soruCevaplandiYolu = '$soruYolu/answered';
const String programYolu = '$bilesenYolu/schedule';
const String programMaddeleriYolu = '$programYolu/items';
const String programMaddesiYolu = '$programMaddeleriYolu/{item_id}';
const String takimYolu = '$bilesenYolu/teams';
const String takimKurmaYolu = '$takimYolu/generate';
const String kuraYolu = '$bilesenYolu/draw';
const String yazbozYolu = '$bilesenYolu/scoreboard';
const String yazbozMasalariYolu = '$yazbozYolu/tables';
const String yazbozMasasiYolu = '$yazbozMasalariYolu/{table_id}';
const String yazbozYerleriYolu = '$yazbozMasasiYolu/players';
const String yazbozElleriYolu = '$yazbozMasasiYolu/rounds';
const String yazbozEliYolu = '$yazbozElleriYolu/{round}';
const String yazbozBitirYolu = '$yazbozMasasiYolu/finish';
const String agacYolu = '$bilesenYolu/bracket';
const String misafirlerYolu = '$bilesenYolu/guests';
const String misafirYolu = '$misafirlerYolu/{guest_id}';
const String agacTurlariYolu = '$agacYolu/rounds';
const String agacOyunlariYolu = '$agacYolu/matches/{match_id}/games';
const String agacOyunuYolu = '$agacOyunlariYolu/{game}';

/// Tayfa sözlüğü uçları (#232, Tayfam-Api #244).
const String sozlukYolu = '/v1/tayfas/{tayfa_id}/vocabulary/{namespace}';
const String sozlukBirlestirmeYolu = '$sozlukYolu/{vocabulary_id}/merge';
const String hakemlerYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/referees';
const String duzeltmeYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance';

/// Varış penceresi açık bir etkinliğin başlangıcı: [sabitSimdi]'den 10
/// dakika sonra.
final DateTime yakinBaslangic = sabitSimdi.add(const Duration(minutes: 10));

/// Bitmiş (iki gün önce başlamış, üç saat sürmüş) bir etkinliğin
/// başlangıcı; organizatör düzeltmesi ve av ekleme süresi içinde.
final DateTime gecmisBaslangic = sabitSimdi.subtract(const Duration(days: 2));

/// Örnek `Event` JSON'u (sözleşmedeki zorunlu alanlar dolu).
Map<String, Object?> etkinlikJson({
  String id = ornekEtkinlikId,
  String tur = 'camp',
  String mod = 'in_person',
  String baslik = 'Göl kampı',
  String aciklama = 'Çadırını getir.',
  DateTime? baslangic,
  Duration sure = const Duration(hours: 30),
  int kontenjan = 0,
  int gelen = 3,
  int belki = 1,
  int bekleyen = 0,
  String? cevap,
  bool yonetebilir = false,
  bool iptal = false,
  String? seri,
  String? katilim,
  Map<String, Object?>? ayrinti,
}) {
  final bas = baslangic ?? ornekBaslangic;
  final yuzYuze = mod == 'in_person';
  return {
    'id': id,
    'tayfa_id': ornekTayfaId,
    'type': tur,
    'type_version': 1,
    'mode': mod,
    'title': baslik,
    'description': aciklama,
    'starts_at': bas.toIso8601String(),
    'ends_at': bas.add(sure).toIso8601String(),
    if (yuzYuze) 'meeting_point_name': 'Abant Gölü',
    if (yuzYuze) 'meeting_point': {'lat': 40.6, 'lng': 31.28},
    if (yuzYuze) 'city': 'Bolu',
    if (yuzYuze) 'district': 'Merkez',
    if (!yuzYuze) 'online_url': 'https://ornek.tayfam.app/oda',
    'capacity': kontenjan,
    'status': iptal ? 'cancelled' : 'scheduled',
    if (iptal) 'cancelled_at': '2026-11-10T10:00:00Z',
    if (iptal) 'cancel_reason': 'Hava kötü',
    'discoverable': false,
    'created_by_user_id': organizatorId,
    'going_count': gelen,
    'maybe_count': belki,
    'waitlist_count': bekleyen,
    'caller_rsvp': ?cevap,
    'caller_can_manage': yonetebilir,
    'caller_attendance': ?katilim,
    'series_id': ?seri,
    'series_override': false,
    'created_at': '2026-11-01T10:00:00Z',
    'updated_at': '2026-11-01T10:00:00Z',
    tur: ?ayrinti,
  };
}

/// Örnek `EventComponentState` JSON'u; [secimler] parametre adından
/// (geçerli seçenek, seçenekler) çiftine.
Map<String, Object?> bilesenDurumuJson(
  String anahtar, {
  String? tur,
  bool? acik,
  Map<String, (String, List<String>)> secimler = const {},
}) => {
  'key': anahtar,
  'kind': tur ?? anahtar,
  'optional': acik != null,
  'enabled': acik ?? true,
  'choices': [
    for (final MapEntry(key: param, value: (deger, secenekler))
        in secimler.entries)
      {'param': param, 'value': deger, 'options': secenekler},
  ],
};

/// Örnek `Checklist` JSON'u (liste bileşeni, #229): varsayılanı kampın
/// boş malzeme listesi, üye gözüyle.
Map<String, Object?> kontrolListesiJson({
  List<Map<String, Object?>> maddeler = const [],
  String etiket = 'gear',
  bool atama = true,
  bool adet = true,
  bool yonetebilir = false,
  bool ustlenebilir = false,
}) => {
  'items': maddeler,
  'label': etiket,
  'assignment_enabled': atama,
  'quantity_enabled': adet,
  'caller_can_manage': yonetebilir,
  'caller_can_take': ustlenebilir,
};

/// Örnek `EventRollCall` JSON'u (yoklama bileşeni, #230): varsayılanı
/// alarmı açık, planı ve kaydı olmayan yoklama, üye gözüyle.
Map<String, Object?> yoklamaJson({
  bool alarm = true,
  int tolerans = 30,
  DateTime? donus,
  Map<String, Object?>? benim,
  List<Map<String, Object?>> kayitlar = const [],
  bool yonetebilir = false,
  bool duzenleyebilir = false,
}) => {
  'alarm': alarm,
  'return_grace_minutes': tolerans,
  'expected_return_at': ?donus?.toIso8601String(),
  'mine': ?benim,
  'entries': kayitlar,
  'caller_can_manage': yonetebilir,
  'caller_can_edit': duzenleyebilir,
};

/// Örnek `EventLogEntryList` JSON'u (günlük bileşeni, #231): varsayılanı
/// konumu açık, varsayılan görünürlüğü "Yalnızca ben" olan boş günlük,
/// kayıt ekleyemeyen üye gözüyle.
Map<String, Object?> gunlukJson({
  List<Map<String, Object?>> kayitlar = const [],
  bool konum = true,
  String? varsayilan = 'self',
  int enCok = 100,
  bool ekleyebilir = false,
  String? sonraki,
}) => {
  'entries': kayitlar,
  'next_page_token': ?sonraki,
  'location_enabled': konum,
  'location_default': ?(konum ? varsayilan : null),
  'max_entries': enCok,
  'caller_can_add': ekleyebilir,
};

/// Örnek `EventMeasure` JSON'u (ölçüm bileşeni, #233): varsayılanı
/// yürüyüşün mesafesi gibi km'lik, iki basamaklı, organizatörün girdiği,
/// değeri olmayan toplam ölçüm, yazamayan üye gözüyle.
Map<String, Object?> olcumJson({
  String birim = 'km',
  String kapsam = 'total',
  String giren = 'organizer',
  num enAz = 0,
  num enCok = 1000,
  int basamak = 2,
  num? toplam,
  List<Map<String, Object?>> kayitlar = const [],
  num? onerilen,
  bool yazabilir = false,
}) => {
  'unit': birim,
  'scope': kapsam,
  'entered_by': giren,
  'min': enAz,
  'max': enCok,
  'decimals': basamak,
  'total': ?toplam,
  'total_updated_at': ?(toplam == null ? null : '2026-11-11T08:00:00Z'),
  'entries': kayitlar,
  'suggested': ?onerilen,
  'caller_can_edit': yazabilir,
};

/// Örnek `EventGoal` JSON'u (hedef çubuğu bileşeni, #234): varsayılanı
/// yürüyüşün mesafesine bağlı, türün varsayılan hedefi 10 km olan, değeri
/// henüz olmayan hedef, değiştiremeyen üye gözüyle. [ulasildi] verilmezse
/// [mevcut] hedefe ulaştıysa `true`.
Map<String, Object?> hedefJson({
  String olcum = 'distance',
  String birim = 'km',
  int basamak = 2,
  num? hedef = 10,
  bool konuldu = false,
  num? varsayilan = 10,
  num? mevcut = 0,
  bool gizli = false,
  bool olcumAcik = true,
  bool? ulasildi,
  bool degistirebilir = false,
}) => {
  'measure_key': olcum,
  'unit': birim,
  'decimals': basamak,
  'target': ?hedef,
  'target_set': konuldu,
  'target_updated_at': ?(konuldu ? '2026-11-11T08:00:00Z' : null),
  'default_target': ?varsayilan,
  'current': ?(gizli || !olcumAcik ? null : mevcut),
  'progress_hidden': gizli,
  'measure_enabled': olcumAcik,
  'reached':
      ulasildi ??
      (hedef != null && mevcut != null && !gizli && mevcut >= hedef),
  'caller_can_edit': degistirebilir,
};

/// Örnek `EventRanking` JSON'u (derece bileşeni, #241): varsayılanı
/// elle girilen, süreye göre (artan) ve boş derece, yazamayan üye gözüyle.
/// [kaynak] verilirse ölçümden hesaplanır ([birim], [basamak]).
Map<String, Object?> dereceJson({
  String? kaynak,
  String olcut = 'duration',
  String yon = 'asc',
  String? birim,
  int? basamak,
  List<Map<String, Object?>> kayitlar = const [],
  bool gizli = false,
  bool olcumAcik = true,
  bool yazabilir = false,
}) => {
  'source': ?kaynak,
  'metric': ?(kaynak == null ? olcut : null),
  'direction': yon,
  'unit': ?(kaynak == null ? null : birim),
  'decimals': basamak ?? (olcut == 'rank' && kaynak == null ? 0 : 2),
  'entries': gizli || !olcumAcik ? const <Object?>[] : kayitlar,
  'hidden': gizli,
  'measure_enabled': olcumAcik,
  'caller_can_edit': yazabilir,
};

/// Örnek `EventRankingEntry` JSON'u.
Map<String, Object?> dereceKaydiJson(String kullaniciId, num deger, int sira) =>
    {
      'user_id': kullaniciId,
      'value': deger,
      'rank': sira,
      'updated_at': '2026-11-11T08:00:00Z',
    };

/// Örnek `EventCelebration` JSON'u (kutlama bileşeni, #243): varsayılanı
/// elle seçilen, kazanansız ve ilan edilmemiş kutlama, ilan edemeyen üye
/// gözüyle. [kaynak] verilirse kaynaklı ([kaynakTuru]).
Map<String, Object?> kutlamaJson({
  String? kaynak,
  String kaynakTuru = 'scoreboard',
  List<Map<String, Object?>> kazananlar = const [],
  bool gizli = false,
  bool ilanEdildi = false,
  bool ilanEdebilir = false,
}) => {
  'source': ?kaynak,
  'source_kind': ?(kaynak == null ? null : kaynakTuru),
  'winners': gizli ? const <Object?>[] : kazananlar,
  'hidden': gizli,
  'announced': ilanEdildi,
  if (ilanEdildi) 'announced_at': '2026-11-14T09:05:00Z',
  'caller_can_announce': ilanEdebilir,
};

/// Örnek `EventCelebrationWinner` JSON'u: kişi, takım ya da misafir;
/// yazboz kaynağında [masa].
Map<String, Object?> kutlamaKazananiJson({
  String? kisi,
  String? takim,
  String? misafir,
  String? masa,
}) => {
  'user_id': ?kisi,
  'team_id': ?takim,
  'guest_id': ?misafir,
  'table_id': ?masa,
};

/// Örnek `EventQuestion` JSON'u (soru toplama bileşeni, #244). Anonim
/// soruda yazar ([yazar]) hiçbir zaman yoktur (sözleşme).
Map<String, Object?> soruJson({
  required String id,
  String metin = 'Rota ne kadar sürecek?',
  String? yazar = katilimciId,
  bool anonim = false,
  bool benim = false,
  int oy = 0,
  bool oyVerdim = false,
  bool cevaplandi = false,
  bool kaldirabilir = false,
}) => {
  'id': id,
  'body': metin,
  'anonymous': anonim,
  'author_id': ?(anonim ? null : yazar),
  'caller_is_author': benim,
  'vote_count': oy,
  'caller_voted': oyVerdim,
  if (cevaplandi) 'answered_at': '2026-11-14T09:30:00Z',
  'created_at': '2026-11-14T09:05:00Z',
  'caller_can_remove': kaldirabilir,
};

/// Örnek `EventQuestionList` JSON'u: varsayılanı sorusuz, anonim soruya
/// izin veren, soru soramayan üye gözüyle.
Map<String, Object?> sorularJson({
  List<Map<String, Object?>> sorular = const [],
  bool anonimAcik = true,
  bool sorabilir = false,
  bool isaretleyebilir = false,
  int enCok = 20,
}) => {
  'questions': sorular,
  'anonymous_allowed': anonimAcik,
  'caller_can_ask': sorabilir,
  'caller_can_mark_answered': isaretleyebilir,
  'max_questions_per_person': enCok,
};

/// Örnek `EventScheduleItem` JSON'u (program akışı bileşeni, #235).
Map<String, Object?> programMaddesiJson({
  required String id,
  required DateTime baslangic,
  DateTime? bitis,
  String baslik = 'Varış',
  String? not,
}) => {
  'id': id,
  'starts_at': baslangic.toUtc().toIso8601String(),
  'ends_at': ?bitis?.toUtc().toIso8601String(),
  'title': baslik,
  'note': ?not,
};

/// Örnek `EventSchedule` JSON'u (program akışı bileşeni, #235): verilmezse
/// boş, 20 maddelik, düzenleyemeyen üye gözüyle.
Map<String, Object?> programJson({
  List<Map<String, Object?>> maddeler = const [],
  int enCok = 20,
  bool duzenleyebilir = false,
}) => {
  'items': maddeler,
  'max_items': enCok,
  'caller_can_edit': duzenleyebilir,
};

/// Örnek `EventTeam` JSON'u (takım kurma bileşeni, #236).
Map<String, Object?> takimJson({
  required String id,
  required int sira,
  List<String> uyeler = const [],
  String? ad,
}) => {'id': id, 'position': sira, 'name': ?ad, 'member_ids': uyeler};

/// Örnek `EventTeams` JSON'u (takım kurma bileşeni, #236): verilmezse
/// takımsız, rastgele modda, düzenleyemeyen üye gözüyle.
Map<String, Object?> takimlarJson({
  List<Map<String, Object?>> takimlar = const [],
  String mod = 'random',
  int? takimSayisi,
  int? takimBuyuklugu,
  bool duzenleyebilir = false,
}) => {
  'teams': takimlar,
  'mode': mod,
  'team_count': ?takimSayisi,
  'team_size': ?takimBuyuklugu,
  'caller_can_edit': duzenleyebilir,
};

/// Örnek `EventDrawEntry` JSON'u (kura bileşeni, #237): [kisi] ya da
/// [takim] verilmezse boş yer (bay).
Map<String, Object?> kuraYeriJson(
  int sira, {
  String? kisi,
  String? takim,
  String? misafir,
}) => {
  'position': sira,
  'user_id': ?kisi,
  'team_id': ?takim,
  'guest_id': ?misafir,
};

/// Örnek `EventDraw` JSON'u (kura bileşeni, #237): verilmezse çekilmemiş
/// katılımcı kurası, çekemeyen üye gözüyle.
Map<String, Object?> kuraJson({
  List<Map<String, Object?>> yerler = const [],
  String konu = 'participants',
  String? takimAnahtari,
  String? cekildi,
  bool cekebilir = false,
}) => {
  'drawn': cekildi != null,
  'subject': konu,
  'teams_key': ?takimAnahtari,
  'drawn_at': ?cekildi,
  'entries': yerler,
  'caller_can_draw': cekebilir,
};

/// Örnek `EventBracketGame` JSON'u (eşleşme ağacı, #239): puan kuralında
/// [a] ve [b], galibiyet/beraberlik/mağlubiyette [sonuc].
Map<String, Object?> agacOyunuJson(int no, {int? a, int? b, String? sonuc}) => {
  'number': no,
  'a_points': ?a,
  'b_points': ?b,
  'a_outcome': ?sonuc,
};

/// Örnek `EventBracketMatch` JSON'u (eşleşme ağacı, #239).
Map<String, Object?> agacMaciJson({
  required String id,
  int tur = 1,
  int sira = 1,
  int? a,
  int? b,
  List<Map<String, Object?>> oyunlar = const [],
  bool sonuclandi = false,
  bool bay = false,
  int? kazanan,
  num aToplam = 0,
  num bToplam = 0,
  int aOyun = 0,
  int bOyun = 0,
  bool girebilir = false,
}) => {
  'id': id,
  'round': tur,
  'slot': sira,
  'a_position': ?a,
  'b_position': ?b,
  'games': oyunlar,
  'decided': sonuclandi,
  'bye': bay,
  'winner_position': ?kazanan,
  'a_total': aToplam,
  'b_total': bToplam,
  'a_games_won': aOyun,
  'b_games_won': bOyun,
  'caller_can_score': girebilir,
};

/// Örnek `EventBracketStanding` JSON'u (eşleşme ağacı, #239).
Map<String, Object?> agacSirasiJson(
  int yer, {
  required int sira,
  num puan = 0,
  int oynadi = 0,
  int galibiyet = 0,
  int beraberlik = 0,
  int maglubiyet = 0,
  num buchholz = 0,
}) => {
  'position': yer,
  'played': oynadi,
  'won': galibiyet,
  'drawn': beraberlik,
  'lost': maglubiyet,
  'points': puan,
  'head_to_head': 0,
  'buchholz': buchholz,
  'rank': sira,
};

/// Örnek `EventBracket` JSON'u (eşleşme ağacı, #239): verilmezse kura
/// çekilmemiş, başlamamış eleme ağacı, yönetemeyen üye gözüyle.
Map<String, Object?> agacJson({
  bool basladi = false,
  String bicim = 'elimination',
  int bo = 1,
  String sonuc = 'points',
  String kazanan = 'high',
  String? kura = 'draw',
  bool cekildi = false,
  String konu = 'participants',
  String? takimAnahtari,
  int turlar = 0,
  int mevcutTur = 0,
  List<Map<String, Object?>> yerler = const [],
  List<Map<String, Object?>> maclar = const [],
  List<Map<String, Object?>> siralama = const [],
  bool bitti = false,
  List<int> kazananlar = const [],
  bool yonetebilir = false,
}) => {
  'started': basladi,
  'format': bicim,
  'best_of': bo,
  'result': sonuc,
  'winner': kazanan,
  'draw_key': ?kura,
  'drawn': cekildi,
  'subject': konu,
  'teams_key': ?takimAnahtari,
  'rounds': turlar,
  'current_round': mevcutTur,
  if (basladi) 'started_at': '2026-11-20T11:10:00Z',
  'entrants': yerler,
  'matches': maclar,
  'standings': siralama,
  'finished': bitti,
  'winner_positions': kazananlar,
  'caller_can_manage': yonetebilir,
};

/// Örnek `EventScorePreset` JSON'u (yazboz bileşeni, #238).
Map<String, Object?> yazbozOnAyariJson(
  String anahtar,
  String ad, {
  int? enAz,
  int? enCok,
  Map<String, Object?> kurallar = const {},
  bool emekli = false,
}) => {
  'key': anahtar,
  'labels': {'tr': ad},
  'players_min': ?enAz,
  'players_max': ?enCok,
  'rules': kurallar,
  'retired': emekli,
};

/// Örnek `EventScorePlayer` JSON'u (yazboz bileşeni, #238): [kisi] ya da
/// [takim] verilmezse hesabı silinmiş kişi.
Map<String, Object?> yazbozYeriJson(
  String id,
  int sira, {
  String? kisi,
  String? takim,
  String? misafir,
}) => {
  'id': id,
  'position': sira,
  'user_id': ?kisi,
  'team_id': ?takim,
  'guest_id': ?misafir,
};

/// Örnek `EventScoreTable` JSON'u (yazboz bileşeni, #238): verilmezse
/// oyuncusuz, açık, puanla el el oynanan, yüksek toplamın kazandığı masa.
Map<String, Object?> yazbozMasasiJson({
  required String id,
  String ad = 'Masa 1',
  String? onAyar,
  Map<String, Object?> kurallar = const {
    'side': 'player',
    'rounds': 'round',
    'winner': 'high',
    'result': 'points',
  },
  String? takimAnahtari,
  bool bitti = false,
  List<Map<String, Object?>> yerler = const [],
  List<Map<String, Object?>> eller = const [],
  List<Map<String, Object?>> siralama = const [],
  List<String> kazananlar = const [],
  bool skorGirebilir = false,
}) => {
  'id': id,
  'label': ad,
  'preset_key': ?onAyar,
  'rules': kurallar,
  'teams_key': ?takimAnahtari,
  'status': bitti ? 'finished' : 'open',
  if (bitti) 'finished_at': '2026-11-14T08:00:00Z',
  'created_at': '2026-11-14T06:30:00Z',
  'players': yerler,
  'rounds': eller,
  'standings': siralama,
  'winner_ids': kazananlar,
  'caller_can_score': skorGirebilir,
};

/// Örnek `EventScoreboard` JSON'u (yazboz bileşeni, #238): verilmezse
/// masasız, yönetemeyen üye gözüyle.
Map<String, Object?> yazbozJson({
  List<Map<String, Object?>> masalar = const [],
  List<Map<String, Object?>> onAyarlar = const [],
  Map<String, Object?> kurallar = const {
    'side': 'player',
    'rounds': 'round',
    'winner': 'high',
    'result': 'points',
  },
  int enCok = 20,
  bool yonetebilir = false,
}) => {
  'tables': masalar,
  'presets': onAyarlar,
  'rules': kurallar,
  'max_tables': enCok,
  'caller_can_manage': yonetebilir,
};

/// Örnek `TayfaVocabularyValue` JSON'u; [hedefId] ve [hedef] verilirse
/// birleştirilmiş değer.
Map<String, Object?> sozlukDegeriJson(
  String id,
  String deger, {
  String? hedefId,
  String? hedef,
}) => {
  'id': id,
  'value': deger,
  'merged_into_id': ?hedefId,
  'merged_into_value': ?hedef,
};

/// Örnek `TayfaVocabularyList` JSON'u: varsayılanı boş, birleştiremeyen
/// üye gözüyle.
Map<String, Object?> sozlukJson({
  List<Map<String, Object?>> degerler = const [],
  bool birlestirebilir = false,
}) => {'values': degerler, 'caller_can_merge': birlestirebilir};

/// Örnek `EventComponentList` JSON'u.
Map<String, Object?> bilesenlerJson({
  List<Map<String, Object?>> bilesenler = const [],
  bool kilitli = false,
  bool yonetebilir = false,
}) => {
  'components': bilesenler,
  'locked': kilitli,
  'caller_can_manage': yonetebilir,
};

/// Örnek `EventRefereeList` JSON'u: [kullanicilar] etkinliğin tamamının
/// hakemidir.
Map<String, Object?> hakemlerJson([List<String> kullanicilar = const []]) => {
  'referees': [
    for (final (sira, id) in kullanicilar.indexed)
      {
        'id': '4b3a2918-0706-4f5e-8d4c-3b2a1908f7e${sira % 10}',
        'user_id': id,
        'created_at': '2026-11-10T10:00:00Z',
      },
  ],
};

/// Test bileşeni (ADR-0024 §7): detayda bağlamını metin olarak yazar;
/// [param] verilirse sihirbazda o parametrenin seçimini çizer ([etiketler]
/// seçenek adlarıdır; adı olmayan seçenek "tanınmayan seçenek"tir).
final class SahteBilesen extends KayitliBilesen {
  const SahteBilesen(
    super.tur, {
    this.param,
    this.etiketler = const {},
    this.detay = true,
  });

  final String? param;
  final Map<String, String> etiketler;
  final bool detay;

  /// Detay bölümünde yazan metin.
  static String detayMetni(
    String anahtar,
    BilesenRolu rol, [
    Map<String, String> secimler = const {},
  ]) => 'bileşen $anahtar ${rol.name} $secimler';

  @override
  String ad(AppLocalizations m) => 'Sahte $tur';

  @override
  Widget? formBolumu(BilesenBaglami b) {
    final param = this.param;
    if (param == null) return null;
    return BilesenSecimAlani(
      baglam: b,
      param: param,
      baslik: 'Seçim $param',
      etiketler: etiketler,
    );
  }

  @override
  Widget? detayBolumu(BilesenBaglami b) =>
      detay ? Text(detayMetni(b.anahtar, b.rol, b.secimler)) : null;
}

/// Örnek `Event` modeli.
Event ornekEtkinlik({
  String tur = 'camp',
  String mod = 'in_person',
  int kontenjan = 0,
  int gelen = 3,
  int belki = 1,
  int bekleyen = 0,
  String? cevap,
  bool yonetebilir = false,
  String? seri,
  Map<String, Object?>? ayrinti,
}) => Event.fromJson(
  etkinlikJson(
    tur: tur,
    mod: mod,
    kontenjan: kontenjan,
    gelen: gelen,
    belki: belki,
    bekleyen: bekleyen,
    cevap: cevap,
    yonetebilir: yonetebilir,
    seri: seri,
    ayrinti: ayrinti,
  ),
);

/// Etkinlik listesi JSON'u.
Map<String, Object?> etkinlikListesiJson(
  List<Map<String, Object?>> etkinlikler, {
  String? sonraki,
}) => {'events': etkinlikler, 'next_page_token': ?sonraki};

/// Katılımcı listesi JSON'u.
Map<String, Object?> katilimcilarJson(
  List<String> kimlikler, {
  String durum = 'going',
  String? sonraki,
}) => {
  'attendees': [
    for (final id in kimlikler)
      {'user_id': id, 'status': durum, 'updated_at': '2026-11-02T10:00:00Z'},
  ],
  'next_page_token': ?sonraki,
};

/// `GET /v1/me/account` yolu (kendi kimliğin).
const String hesapYolu = '/v1/me/account';

/// Kendi hesabının (`Account`) JSON'u; [id] oturumdaki kullanıcı.
Map<String, Object?> hesapJson(String id) => {
  'user_id': id,
  'display_name': 'Ben',
  'referral_code': 'TYF-8K2M4Q',
  'activity_visibility': 'tayfa',
  'birthday_visibility': 'birthday',
  'interests': const <Object?>[],
  'languages': const <Object?>[],
  'social_accounts': const <Object?>[],
  'declined_profile_fields': const <Object?>[],
  'about_visibility': 'friends_and_mutual',
  'profile_completion_pending': false,
};

/// Kullanıcı profili JSON'u; [ben] oturumdaki kullanıcının kendisi.
Map<String, Object?> profilJson(String id, String ad, {bool ben = false}) => {
  'user_id': id,
  'display_name': ad,
  'self': ben,
  'mutual_tayfas': const <Object?>[],
  'activity_visible': false,
};

/// Detay ekranının okuduğu uçların varsayılan yanıtları; [yanitlar]
/// önce gelir.
SahteTayfaTasima etkinlikTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final t = SahteTayfaTasima(yanitlar);
  t.yanitlar
    ..putIfAbsent(
      'GET /v1/tayfas',
      () =>
          (_) => listeJson([etkinJson(ornekTayfaId)]),
    )
    ..putIfAbsent(
      'GET $etkinliklerYolu',
      () =>
          (_) => etkinlikListesiJson([etkinlikJson()]),
    )
    ..putIfAbsent(
      'GET $etkinlikYolu',
      () =>
          (_) => etkinlikJson(),
    )
    ..putIfAbsent(
      'GET $katilimcilarYolu',
      () =>
          (_) => katilimcilarJson([katilimciId]),
    )
    ..putIfAbsent(
      'GET $bilesenlerYolu',
      () =>
          (_) => bilesenlerJson(),
    )
    ..putIfAbsent(
      'GET $hakemlerYolu',
      () =>
          (_) => hakemlerJson(),
    )
    ..putIfAbsent(
      'GET $listeYolu',
      () =>
          (_) => kontrolListesiJson(),
    )
    ..putIfAbsent(
      'GET $yoklamaYolu',
      () =>
          (_) => yoklamaJson(),
    )
    ..putIfAbsent(
      'GET $gunlukYolu',
      () =>
          (_) => gunlukJson(),
    )
    ..putIfAbsent(
      'GET $olcumYolu',
      () =>
          (_) => olcumJson(),
    )
    ..putIfAbsent(
      'GET $hedefYolu',
      () =>
          (_) => hedefJson(),
    )
    ..putIfAbsent(
      'GET $dereceYolu',
      () =>
          (_) => dereceJson(),
    )
    ..putIfAbsent(
      'GET $programYolu',
      () =>
          (_) => programJson(),
    )
    ..putIfAbsent(
      'GET $misafirlerYolu',
      () =>
          (_) => misafirlerJson(),
    )
    ..putIfAbsent(
      'GET $sozlukYolu',
      () =>
          (_) => sozlukJson(),
    )
    ..putIfAbsent(
      'GET $profilYolu',
      () =>
          (i) => profilJson(
            i.yolParametreleri['user_id']!,
            i.yolParametreleri['user_id'] == organizatorId ? 'Ayşe' : 'Mert',
          ),
    );
  return t;
}

/// Örnek `EventGuestPlayer` JSON'u (misafir oyuncu, #240); [ad] verilmezse
/// takma adı silinmiş misafir.
Map<String, Object?> misafirJson(String id, {String? ad}) => {
  'id': id,
  'nickname': ?ad,
  'created_at': '2026-11-20T10:00:00Z',
};

/// Örnek `EventGuestPlayers` JSON'u: verilmezse misafirsiz, ekleyemeyen ve
/// silemeyen üye gözüyle.
Map<String, Object?> misafirlerJson({
  List<Map<String, Object?>> misafirler = const [],
  int enCok = 30,
  bool ekleyebilir = false,
  bool silebilir = false,
}) => {
  'guests': misafirler,
  'max_guests': enCok,
  'caller_can_add': ekleyebilir,
  'caller_can_remove': silebilir,
};

/// Sahte takvim paylaşıcısı: paylaşılan metinleri tutar.
final class SahteTakvimPaylasici implements TakvimPaylasici {
  final List<String> paylasilan = [];

  @override
  Future<void> paylas(String icerik, {Rect? konum}) async {
    paylasilan.add(icerik);
  }
}

/// Sahte bağlantı açıcı: açılan noktaları ve adresleri tutar.
final class SahteBaglantiAcici implements EtkinlikBaglantiAcici {
  final List<(double, double)> noktalar = [];
  final List<Uri> adresler = [];

  @override
  Future<bool> haritadaAc(double enlem, double boylam) async {
    noktalar.add((enlem, boylam));
    return true;
  }

  @override
  Future<bool> baglantiAc(Uri adres) async {
    adresler.add(adres);
    return true;
  }
}

/// Sahte yer arayıcı: aramaları sayar, verilen sonuçları döndürür.
final class SahteYerArayici implements YerArayici {
  SahteYerArayici([this.sonuclar = const []]);

  final List<YerSonucu> sonuclar;
  final List<String> aramalar = [];

  @override
  Future<List<YerSonucu>> ara(String metin) async {
    aramalar.add(metin);
    return sonuclar;
  }
}

/// Testlerdeki cihaz konumu (buluşma noktasının yakını).
const LatLng sahteKonum = LatLng(lat: 40.600123, lng: 31.280456);

/// Sahte konum servisi: verilen sonucu döndürür, çağrıları sayar.
final class SahteKonumServisi implements KonumServisi {
  SahteKonumServisi([this.sonuc = const KonumAlindi(sahteKonum)]);

  KonumSonucu sonuc;
  int okuma = 0;
  int uygulamaAyarlari = 0;
  int konumAyarlari = 0;

  @override
  Future<KonumSonucu> tekSeferlikKonum({bool hassas = true}) async {
    okuma++;
    return sonuc;
  }

  @override
  Future<bool> uygulamaAyarlariniAc() async {
    uygulamaAyarlari++;
    return true;
  }

  @override
  Future<bool> konumAyarlariniAc() async {
    konumAyarlari++;
    return true;
  }
}

/// Sahte mağaza değerlendirme penceresi: istekleri sayar (ADR-0016).
final class SahteMagazaDegerlendirmesi implements MagazaDegerlendirmesi {
  SahteMagazaDegerlendirmesi({this.kullanilabilir = true});

  final bool kullanilabilir;
  int istek = 0;

  @override
  Future<bool> kullanilabilirMi() async => kullanilabilir;

  @override
  Future<void> iste() async {
    istek++;
  }
}

/// Sahte istek kimliği (UUID v4 biçiminde).
const String sahteEtkinlikIstekKimligi = '2c9d8e7f-6a5b-4c3d-8e2f-1a0b9c8d7e6f';

/// Etkinlik özelliğinin sahte bağımlılıkları: uçlar [tasima]'dan, saat
/// [sabitSimdi], karolar verilmezse çizilmez (ağ yok), paylaşım ve dış
/// bağlantılar ve konum sahte, istek kimliği sabit. Etkinlik modülü
/// kayıtlıdır; bileşen kaydı [bilesenler]'dir (verilmezse temel
/// `meeting_point`, liste, yoklama, günlük, ölçüm ve hedef). Mağaza
/// değerlendirme penceresi verilmezse kullanılamaz (istenmez);
/// değerlendirme bayrağı cihaz ayarlarındadır (`uygulamayiAc`'ın `cihazAyarlari`'ı).
List<Override> etkinlikOverridelari({
  required SahteTayfaTasima tasima,
  SahteTakvimPaylasici? takvim,
  SahteBaglantiAcici? baglanti,
  YerArayici? arayici,
  KaroSaglayiciUretici? karolar,
  KonumServisi? konum,
  SonTayfaDeposu? sonTayfa,
  MagazaDegerlendirmesi? magaza,
  Override? katalog,
  List<EtkinlikBileseni> bilesenler = const [
    TemelBilesen('meeting_point'),
    ListeBileseni(),
    YoklamaBileseni(),
    GunlukBileseni(),
    OlcumBileseni(),
    HedefBileseni(),
  ],
}) => [
  ...tayfaOverridelari(tasima: tasima, sonTayfa: sonTayfa, katalog: katalog),
  etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
  sozlukDeposuProvider.overrideWithValue(SozlukDeposu(tasima)),
  sikayetDeposuProvider.overrideWithValue(SikayetDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue((id) async {
    final profil = await UsersApi(tasima).getUserProfile(userId: id);
    return KullaniciAdi(profil.displayName);
  }),
  // Kendi kimliği `GET /v1/me/account`'tan (varsayılan yanıtı yoksa
  // okunamaz ve kimse "kendisi" sayılmaz).
  kendiKimligiOkuyucuProvider.overrideWithValue(
    () async => (await MeApi(tasima).getAccount()).userId,
  ),
  etkinlikSaatiProvider.overrideWithValue(() => sabitSimdi),
  karoSaglayiciProvider.overrideWithValue(karolar ?? (() => null)),
  takvimPaylasiciProvider.overrideWithValue(takvim ?? SahteTakvimPaylasici()),
  etkinlikBaglantiAciciProvider.overrideWithValue(
    baglanti ?? SahteBaglantiAcici(),
  ),
  yerArayiciProvider.overrideWithValue(arayici ?? SahteYerArayici()),
  etkinlikIstekKimligiProvider.overrideWithValue(
    () => sahteEtkinlikIstekKimligi,
  ),
  tayfaModulleriProvider.overrideWithValue(const [EtkinlikModulu()]),
  konumServisiProvider.overrideWithValue(konum ?? SahteKonumServisi()),
  etkinlikBilesenKaydiProvider.overrideWithValue(bilesenler),
  magazaDegerlendirmesiProvider.overrideWithValue(
    magaza ?? SahteMagazaDegerlendirmesi(kullanilabilir: false),
  ),
];
