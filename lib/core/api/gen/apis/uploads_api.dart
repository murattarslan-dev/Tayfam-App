// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `uploads` olan uçlar.
final class UploadsApi {
  const UploadsApi(this._transport);

  final ApiTransport _transport;

  /// Dosya yüklemesi açar ve her varyant için imzalı PUT linki döner
  ///
  /// `variants`'ta tam bir `preview` ve bir `full`. Her link 5 dakika
  /// geçerlidir ve yalnızca o varyantın nesnesi, türü ve boyutu içindir:
  /// `headers`'taki `Content-Type` ve `Content-Length` aynen
  /// gönderilmelidir; başka tür ya da boyutla R2 isteği reddeder. Anahtarı
  /// sunucu belirler. Kapak ve av fotoğrafında `tayfa_id` zorunludur
  /// (aktif üye olunmalı, tayfa salt okunur olmamalı); avatarda verilmez.
  /// Aynı `client_request_id` ile tekrar, kayıt `pending` iken aynı
  /// yüklemeyi yeni linklerle döner. Sınırlar: kullanıcı başına saatte 30
  /// yükleme (`upload-rate-limited`) ve 500 MiB toplam
  /// (`upload-quota-exceeded`; iki varyantın boyutları birlikte).
  ///
  /// `POST /v1/uploads`
  Future<UploadCreated> createUpload({
    required UploadCreateRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/uploads',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return UploadCreated.fromJson(jsonObject(response, 'createUpload'));
  }

  /// Kendi yüklemenizin durumu (hazırsa linkleriyle)
  ///
  /// Başkasının yüklemesi `upload-not-found` döner.
  ///
  /// `GET /v1/uploads/{upload_id}`
  Future<UploadView> getUpload({required String uploadId}) async {
    final response = await _transport.send(
      method: 'GET',
      pathTemplate: '/v1/uploads/{upload_id}',
      pathParams: {'upload_id': uploadId},
      expect: ResponseKind.json,
      authenticated: true,
    );
    return UploadView.fromJson(jsonObject(response, 'getUpload'));
  }

  /// PUT'ların bittiğini bildirir; sunucu denetler (ready ya da rejected)
  ///
  /// Gövde full varyantın ölçüleridir. Sunucu aynı çağrıda, pikselleri
  /// çözmeden, her varyant için denetler: saklanan boyut bildirilenle
  /// aynı; ilk baytlar bildirilen türde JPEG ya da WebP; başlıktaki ölçü
  /// full için bildirilenle aynı ve en uzun kenar ≤ 1600, preview için en
  /// uzun kenar ≤ 400 ve en-boy oranı full ile en çok ±1 px farkla aynı;
  /// EXIF (GPS dahil), XMP, IPTC yok (WebP'de EXIF/XMP parçası ya da
  /// bayrağı yok). Geçen varyantlar istemcinin yazamadığı yere
  /// kopyalanır. Bir varyant henüz yoksa `upload-not-received` (409):
  /// PUT'u bitirip link geçerliyken tekrar çağırın. Depoya ulaşılamazsa
  /// 503 ve yükleme `pending` kalır. Yükleme `pending` değilse tekrar
  /// çağrı onu değiştirmeden döner.
  ///
  /// `POST /v1/uploads/{upload_id}/complete`
  Future<UploadView> completeUpload({
    required String uploadId,
    required UploadCompleteRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/uploads/{upload_id}/complete',
      pathParams: {'upload_id': uploadId},
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return UploadView.fromJson(jsonObject(response, 'completeUpload'));
  }
}
