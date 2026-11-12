import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/e2e/cihaz/e2e_cihaz.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/tema/tema_tercihi.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

import '../../yardimcilar.dart';
import '../hesap/sahteler.dart';

export '../hesap/sahteler.dart';
export '../tayfa/sahteler.dart' show SahtePaylasici, tayfaOverridelari;

/// Profil uçlarının yol şablonları (sahte taşımanın anahtarları).
const String hesapYolu = 'GET /v1/me/account';
const String hesapGuncelleYolu = 'PATCH /v1/me/account';
const String referansYolu = 'POST /v1/me/referral-code';
const String oturumlarYolu = 'GET /v1/me/sessions';
const String oturumKapatYolu = 'DELETE /v1/me/sessions/{session_id}';
const String digerleriYolu = 'POST /v1/me/sessions/sign-out-others';
const String profilYolu = 'GET /v1/users/{user_id}/profile';
const String hesapSilYolu = 'DELETE /v1/me';
const String girisYolu = 'POST /v1/auth/sign-in';
const String onaylarYolu = 'GET /v1/me/consents';

/// Testlerde kullanılan, biçimi geçerli örnek oturum kimlikleri.
const String buOturumId = '5e6f7a8b-0000-4000-8000-000000000001';
const String digerOturumId = '5e6f7a8b-0000-4000-8000-000000000002';
const String ucuncuOturumId = '5e6f7a8b-0000-4000-8000-000000000003';

/// Sahte referans kodu (gerçek değil).
const String ornekKod = 'TYF-8K2M4Q';

/// Oturumdaki kullanıcının kimliği (sahte oturumun `user_id`'si).
const String benimKimligim = '00000000-0000-4000-8000-000000000001';

/// Başka bir hesabın kimliği (yeniden girişte farklı hesap).
const String baskaKimlik = '00000000-0000-4000-8000-000000000002';

/// `Account` JSON'u.
Map<String, Object?> hesapJson({
  String kod = ornekKod,
  String gorunurluk = 'tayfa',
  String kimlik = benimKimligim,
  String ad = 'Deniz Örnek',
}) => {
  'user_id': kimlik,
  'display_name': ad,
  'referral_code': kod,
  'activity_visibility': gorunurluk,
};

/// `DeviceSession` JSON'u.
Map<String, Object?> oturumJson(
  String id, {
  String platform = 'android',
  bool bu = false,
}) => {
  'session_id': id,
  'platform': platform,
  'created_at': '2026-11-01T10:00:00Z',
  'last_seen_at': '2026-11-10T14:30:00Z',
  'current': bu,
};

/// `GET /v1/me/sessions` yanıtı: bu cihaz, bir Android ve bir iOS.
Map<String, Object?> oturumListesiJson() => {
  'sessions': [
    oturumJson(buOturumId, bu: true),
    oturumJson(digerOturumId),
    oturumJson(ucuncuOturumId, platform: 'ios'),
  ],
};

/// `UserProfile` JSON'u.
Map<String, Object?> profilJson({bool ben = true}) => {
  'user_id': '00000000-0000-4000-8000-000000000001',
  'display_name': 'Deniz Örnek',
  'self': ben,
  'mutual_tayfas': const <Object?>[],
  'activity_visible': true,
};

/// Varsayılan yanıtlar; [ek] ile değiştirilir.
Map<String, Object? Function()> profilYanitlari([
  Map<String, Object? Function()> ek = const {},
]) => {
  hesapYolu: hesapJson,
  hesapGuncelleYolu: () => hesapJson(gorunurluk: 'private'),
  referansYolu: () => {'referral_code': 'TYF-YENI42'},
  oturumlarYolu: oturumListesiJson,
  oturumKapatYolu: () => null,
  digerleriYolu: () => {'revoked_count': 2},
  profilYolu: profilJson,
  hesapSilYolu: () => null,
  girisYolu: () => oturum(n: 3).toJson(),
  onaylarYolu: surumGovdesi,
  ...ek,
};

/// Profil özelliğinin sahte bağımlılıkları. Gerçek ağ ve güvenli depo
/// yoktur; oturum durumu açık başlar. Paylaşıcı tayfa override'larıyla
/// (`tayfaOverridelari`) verilir.
List<Override> profilOverridelari({
  required SahteTasima tasima,
  required SahteOturum oturum,
  SahteGoogle? google,
  SahteAcici? acici,
  BellekTemaTercihiDeposu? tema,
}) => [
  profilDeposuProvider.overrideWithValue(ProfilDeposu(tasima)),
  hesapDeposuProvider.overrideWithValue(HesapDeposu(tasima)),
  hesapPlatformuProvider.overrideWithValue('android'),
  sessionStoreProvider.overrideWithValue(oturum.store),
  googleKimlikSaglayiciProvider.overrideWithValue(google ?? SahteGoogle()),
  disBaglantiAciciProvider.overrideWithValue(acici ?? SahteAcici()),
  temaTercihiDeposuProvider.overrideWithValue(
    tema ?? BellekTemaTercihiDeposu(),
  ),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
  // Cihaz bağlama girişi E2'nin cihaz durumunu okur; profil testlerinde
  // uçtan uca şifreleme kapalı.
  e2eEtkinProvider.overrideWithValue(false),
  // Çıkış (`POST /v1/auth/sign-out`) için sahte HTTP; gerçek ağ yok.
  apiClientProvider.overrideWithValue(
    ApiClient(
      tasima: HttpTasima(
        istemci: MockClient((_) async => http.Response('', 204)),
        tabanAdres: Uri.parse('https://api.ornek.test'),
        istemciAdi: 'android',
      ),
      oturum: oturum.store,
    ),
  ),
];
