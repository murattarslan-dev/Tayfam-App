import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:tayfam/core/api/api_client.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/core/oturum/token_deposu.dart';
import 'package:tayfam/features/hesap/data/dis_baglanti.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/features/hesap/data/hesap_deposu.dart';

/// Testlerde kullanılan sahte (gerçek olmayan) değerler.
const String sahteIdToken = 'sahte-id-token';
const String sahteNonce = 'sahte-nonce-0123456789abcdef';

/// Sözleşmeye uygun bir problem.
ApiProblem problem(ProblemType tur, [int durum = 400]) =>
    ApiProblem(type: tur, status: durum);

/// Gönderilen bir istek.
final class Istek {
  const Istek(this.method, this.yol, this.govde);

  final String method;
  final String yol;
  final Object? govde;

  @override
  String toString() => '$method $yol';
}

/// Üretilmiş uç sınıflarının sahte taşıması. Yanıtı `"METHOD yol"`
/// anahtarına göre [yanitlar]'dan alır; değer bir fonksiyonsa çağrılır,
/// [Exception] ise fırlatılır. Gerçek ağ yoktur.
final class SahteTasima implements ApiTransport {
  SahteTasima([Map<String, Object? Function()>? yanitlar])
    : yanitlar = yanitlar ?? {};

  final Map<String, Object? Function()> yanitlar;
  final List<Istek> istekler = [];

  /// Bir sonraki yanıtı bekletmek için (gönderiliyor durumunu görmek).
  Completer<void>? bekle;

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) async {
    istekler.add(Istek(method, pathTemplate, body));
    final b = bekle;
    if (b != null) await b.future;
    final yanit = yanitlar['$method $pathTemplate'];
    if (yanit == null) throw StateError('Beklenmeyen istek: $pathTemplate');
    final deger = yanit();
    if (deger is Exception) throw deger;
    return deger;
  }

  /// [yol]'a giden istek sayısı.
  int sayi(String method, String yol) =>
      istekler.where((i) => i.method == method && i.yol == yol).length;
}

/// `GET /v1/registration/requirements` ve `GET /v1/me/consents` gövdesi.
Map<String, Object?> surumGovdesi({
  String aydinlatma = '2026-11-08',
  String kosullar = '2026-11-08',
  bool onayGerekli = true,
}) => {
  'privacy_notice_version': aydinlatma,
  'terms_version': kosullar,
  'minimum_age': 16,
  'consent_required': onayGerekli,
};

/// Bir oturum yanıtı (`Session`).
Session oturum({int n = 1, bool kayitBekliyor = false, bool? onayGerekli}) {
  final simdi = DateTime.now().toUtc();
  return Session(
    userId: '00000000-0000-4000-8000-000000000001',
    sessionId: '00000000-0000-4000-8000-000000000002',
    accessToken: 'erisim-$n',
    accessExpiresAt: simdi.add(const Duration(minutes: 15)),
    refreshToken: 'yenileme-$n',
    refreshExpiresAt: simdi.add(const Duration(days: 90)),
    registrationPending: kayitBekliyor,
    consentRequired: onayGerekli,
  );
}

/// Sahte Google kimlik sağlayıcısı: [sonuc] döner ya da [hata] fırlatır.
final class SahteGoogle implements GoogleKimlikSaglayici {
  SahteGoogle({this.sonuc, this.hata});

  GoogleKimligi? sonuc;
  Exception? hata;
  int cagri = 0;

  @override
  Future<GoogleKimligi?> girisYap() async {
    cagri++;
    final h = hata;
    if (h != null) throw h;
    return sonuc;
  }
}

/// Örnek Google kimliği.
const GoogleKimligi ornekKimlik = GoogleKimligi(
  idToken: sahteIdToken,
  nonce: sahteNonce,
  ad: 'Deniz Örnek',
);

/// Açılan adresleri kaydeden sahte dış bağlantı açıcısı.
final class SahteAcici implements DisBaglantiAcici {
  SahteAcici({this.basarili = true});

  final bool basarili;
  final List<Uri> acilan = [];

  @override
  Future<bool> ac(Uri adres) async {
    acilan.add(adres);
    return basarili;
  }
}

/// Bellek depolu, yenilemesi [yenileme]'den gelen `SessionStore`.
final class SahteOturum {
  SahteOturum({Session Function()? yenileme})
    : _yenileme = yenileme ?? (() => oturum(n: 2)) {
    store = SessionStore(
      depo: BellekTokenDeposu(),
      yenileyici: (_, {butunlukTokeni}) async {
        yenilemeSayisi++;
        return _yenileme();
      },
      yoklayici: () async {},
    );
  }

  final Session Function() _yenileme;
  late final SessionStore store;
  int yenilemeSayisi = 0;
}

/// Hesap özelliğinin sahte bağımlılıkları için override'lar.
List<Override> hesapOverridelari({
  required SahteTasima tasima,
  required SahteOturum oturum,
  SahteGoogle? google,
  SahteAcici? acici,
}) => [
  hesapDeposuProvider.overrideWithValue(HesapDeposu(tasima)),
  hesapPlatformuProvider.overrideWithValue('android'),
  sessionStoreProvider.overrideWithValue(oturum.store),
  googleKimlikSaglayiciProvider.overrideWithValue(google ?? SahteGoogle()),
  disBaglantiAciciProvider.overrideWithValue(acici ?? SahteAcici()),
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
