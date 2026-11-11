import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/arkadas/data/arkadas_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kullanıcı kimlikleri.
const String benimId = '00000000-0000-4000-8000-0000000000aa';
const String kisiId1 = '00000000-0000-4000-8000-000000000001';
const String kisiId2 = '00000000-0000-4000-8000-000000000002';

/// Sahte referans kodu (gerçek değil).
const String sahteReferansKodu = 'TYF-ORNEK123';

/// Uç yolları (sahte taşımanın anahtarları).
const String arkadaslarYolu = '/v1/me/friends';
const String arkadasYolu = '/v1/me/friends/{user_id}';
const String isteklerYolu = '/v1/me/friend-requests';
const String kabulYolu = '/v1/me/friend-requests/{user_id}/acceptance';
const String engellerYolu = '/v1/me/blocks';
const String engelYolu = '/v1/me/blocks/{user_id}';
const String referansYolu = '/v1/referral-lookups';
const String tayfaDavetiYolu = '/v1/tayfas/{tayfa_id}/invitations';
const String davetlerimYolu = '/v1/me/invitations';
const String davetimYolu = '/v1/me/invitations/{tayfa_id}';
const String davetKabulYolu = '/v1/me/invitations/{tayfa_id}/acceptance';
const String profilYolu = '/v1/users/{user_id}/profile';
const String gecmisYolu = '/v1/users/{user_id}/activity';

/// [id]'nin örnek görünen adı.
String kisiAdi(String id) =>
    id == benimId ? 'Ben' : 'Kişi ${id.substring(id.length - 1)}';

/// `Friend` JSON'u.
Map<String, Object?> arkadasJson(String id, {String durum = 'friends'}) => {
  'user_id': id,
  'display_name': kisiAdi(id),
  'state': durum,
  'requested_at': '2026-11-10T09:00:00Z',
  if (durum == 'friends') 'accepted_at': '2026-11-10T10:00:00Z',
};

/// `FriendList` JSON'u.
Map<String, Object?> arkadasListesiJson(
  List<Map<String, Object?>> arkadaslar, {
  String? sonraki,
}) => {'friends': arkadaslar, 'next_page_token': ?sonraki};

/// `BlockedUser` JSON'u; [ad] `null` ise hesap silinmiştir.
Map<String, Object?> engelJson(String id, {String? ad}) => {
  'user_id': id,
  'display_name': ?ad,
  'blocked_at': '2026-11-09T09:00:00Z',
};

/// `Invitation` JSON'u.
Map<String, Object?> davetJson(String tayfaId, {String ad = 'Kampçılar'}) => {
  'tayfa_id': tayfaId,
  'tayfa_name': ad,
  'user_id': benimId,
  'inviter_user_id': kisiId1,
  'invited_at': '2026-11-10T09:00:00Z',
};

/// `UserProfile` JSON'u.
Map<String, Object?> kisiProfiliJson(
  String id, {
  String? durum,
  bool gecmisGorunur = false,
  List<Map<String, Object?>> ortak = const [],
}) => {
  'user_id': id,
  'display_name': kisiAdi(id),
  'self': id == benimId,
  'friend_state': ?durum,
  'mutual_tayfas': ortak,
  'activity_visible': gecmisGorunur,
};

/// `ActivityRecord` JSON'u: üyesi olunan tayfadaki ([uye]) ya da olunmayan
/// tayfadaki kayıt.
Map<String, Object?> kayitJson({bool uye = true, String mod = 'in_person'}) => {
  'event_type': 'hiking',
  'mode': mod,
  'city': 'Bursa',
  'district': 'Nilüfer',
  'started_at': '2026-10-01T07:00:00Z',
  'tayfa_member': uye,
  if (uye) ...{
    'tayfa_id': ornekTayfaId,
    'tayfa_name': 'Klasikçiler',
    'event_id': '3c4d5e6f-0000-4000-8000-000000000009',
    'event_title': 'Uludağ yürüyüşü',
    'duration_minutes': 240,
  },
};

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Varsayılan yanıtlarla sahte taşıma: boş listeler, profiller (ilişki
/// yok), boş geçmiş.
SahteTayfaTasima arkadasTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent('GET $arkadaslarYolu', () => yanit(arkadasListesiJson([])))
    ..putIfAbsent('GET $isteklerYolu', () => yanit(arkadasListesiJson([])))
    ..putIfAbsent('GET $engellerYolu', () => yanit({'users': <Object?>[]}))
    ..putIfAbsent(
      'GET $davetlerimYolu',
      () => yanit({'invitations': <Object?>[]}),
    )
    ..putIfAbsent(
      'GET $gecmisYolu',
      () => yanit({'records': <Object?>[]}),
    )
    ..putIfAbsent(
      'GET $profilYolu',
      () =>
          (i) => kisiProfiliJson(i.yolParametreleri['user_id']!),
    );
  return tasima;
}

/// Tayfa ve arkadaşlık uçlarını [tasima]'ya bağlayan override'lar; oturum
/// açık. Gerçek ağ yok.
List<Override> arkadasOverridelari(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  arkadasDeposuProvider.overrideWithValue(ArkadasDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue((id) async {
    final profil = await UsersApi(tasima).getUserProfile(userId: id);
    return KullaniciAdi(profil.displayName, ben: profil.self);
  }),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];
