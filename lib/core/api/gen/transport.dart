// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

/// Üretilen uç sınıflarının istek gönderdiği taşıma arayüzü (ADR-0005).
///
/// Gerçek uygulama `ApiClient`'tır: başlıkları (`Authorization`,
/// `X-Tayfam-Client`, `X-Tayfam-Client-Version`) o ekler, token yenilemeyi
/// ve `application/problem+json` yanıtlarını (`ApiProblem`) o yönetir.
library;

/// Başarılı yanıt gövdesinin beklenen biçimi.
enum ResponseKind {
  /// `application/json`; [ApiTransport.send] çözülmüş JSON döndürür.
  json,

  /// Gövde yok (`204`); [ApiTransport.send] `null` döndürür.
  none,

  /// Düz metin (örneğin `text/calendar`); [ApiTransport.send] `String`
  /// döndürür.
  text,
}

/// Uç sınıflarının tek bağımlılığı.
abstract interface class ApiTransport {
  /// İsteği gönderir ve başarılı yanıtın gövdesini [expect]'e göre döndürür.
  ///
  /// - [method]: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`.
  /// - [pathTemplate]: sözleşmedeki yol şablonu (`/v1/tayfas/{tayfa_id}`);
  ///   log'a yalnızca bu yazılır, gerçek kimlikler değil.
  /// - [pathParams]: şablondaki adlar → ham değerler; uygulama her değeri
  ///   yüzde kodlamasıyla (`Uri.encodeComponent`) yerleştirir.
  /// - [query]: yalnızca verilen sorgu parametreleri, dize olarak.
  /// - [body]: JSON'a çevrilecek gövde; `null` ise gövde gönderilmez.
  /// - [authenticated]: sözleşmedeki geçerli `security`'den gelir;
  ///   `false` (`security: []`) ise uygulama `Authorization` eklemez ve
  ///   token yenilemeyi denemez. Yoldan tahmin edilmez.
  ///
  /// Hata yanıtında tipli değer döndürmez, `ApiProblem` fırlatır.
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  });
}

/// Üretilen kod içindir: JSON yanıtının nesne olduğunu doğrular.
Map<String, Object?> jsonObject(Object? response, String operationId) {
  if (response is Map<String, Object?>) {
    return response;
  }
  throw FormatException('$operationId: yanıt JSON nesnesi değil');
}

/// Üretilen kod içindir: metin yanıtının dize olduğunu doğrular.
String textBody(Object? response, String operationId) {
  if (response is String) {
    return response;
  }
  throw FormatException('$operationId: yanıt metin değil');
}
