import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/apis/auth_api.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/api/http_tasima.dart';
import 'package:tayfam/core/oturum/session_store.dart';

/// Bütün isteklerin geçtiği tek istemci (ADR-0005 §2).
///
/// Üretilen uç sınıflarına [ApiTransport] olarak verilir:
/// `TayfasApi(ref.watch(apiClientProvider))`.
///
/// - `authenticated: false` (sözleşmede `security: []`) uçlarda token
///   eklenmez ve yenileme denenmez.
/// - Diğer uçlarda erişim token'ı `SessionStore`'dan alınır (gerekirse
///   önce tek uçuşta yenilenir). `unauthenticated` gelirse bir kez yenilenir
///   ve istek bir kez tekrarlanır; ikinci `unauthenticated` oturumu kapatır.
/// - `integrity-required` gelirse (istemci ADR-0023 §5) bütünlük kanıtıyla
///   bir kez yenilenir ve istek bir kez tekrarlanır.
/// - Başlıklar, problem ayrıştırma, zaman aşımı ve günlük [HttpTasima]'dadır.
final class ApiClient implements ApiTransport {
  ApiClient({required this._tasima, required this._oturum});

  final HttpTasima _tasima;
  final SessionStore _oturum;

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
    Future<Object?> gonder(String? token) => _tasima.gonder(
      method: method,
      pathTemplate: pathTemplate,
      pathParams: pathParams,
      query: query,
      body: body,
      expect: expect,
      erisimTokeni: token,
    );

    if (!authenticated) return gonder(null);

    final ilk = await _oturum.erisimTokeni();
    try {
      return await gonder(ilk);
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.integrityRequired) {
        // istemci ADR-0023 §5: kanıtla bir kez yenilenir, istek bir kez
        // tekrarlanır; yine reddedilirse hata çağırana gider.
        final kanitli = await _oturum.butunlukGerekti(ilk);
        if (kanitli == null) rethrow;
        return gonder(kanitli);
      }
      if (problem.type != ProblemType.unauthenticated) rethrow;
    }

    final yeni = await _oturum.reddedildi(ilk);
    try {
      return await gonder(yeni);
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.unauthenticated) {
        await _oturum.kapat(OturumKapanisNedeni.yetkisiz);
      }
      rethrow;
    }
  }

  /// Çıkış: `POST /v1/auth/sign-out` denenir; başarısız olsa da yerel
  /// token'lar silinir ve oturum kapanır (ADR-0005 §3).
  Future<void> cikisYap() async {
    try {
      await AuthApi(this).signOut();
    } on ApiHatasi {
      // Sunucuya ulaşılamasa da yerel oturum kapanır.
    } on OturumYok {
      // Oturum zaten kapanmış.
    } finally {
      await _oturum.kapat(OturumKapanisNedeni.cikis);
    }
  }
}

/// Uygulamanın tek `ApiClient`'ı (kalıcı).
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    tasima: ref.watch(httpTasimaProvider),
    oturum: ref.watch(sessionStoreProvider),
  ),
  name: 'apiClientProvider',
);
