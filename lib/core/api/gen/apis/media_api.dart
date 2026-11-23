// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `media` olan uçlar.
final class MediaApi {
  const MediaApi(this._transport);

  final ApiTransport _transport;

  /// Dosyaların 1 saat geçerli imzalı indirme linkleri
  ///
  /// Yanıtlardaki `*_upload_id` alanlarını (avatar, kapak, av ve albüm fotoğrafı)
  /// toplu çözer; istemci linkleri süreleri dolana kadar önbellekte
  /// tutar. Görülemeyen dosya nedeni söylenmeden atlanır (bilinmeyen,
  /// hazır olmayan, silinmiş ve yetkisiz aynıdır). Kurallar: kendi
  /// dosyanız her zaman; avatar oturum açmış herkese (iki taraftan biri
  /// engellediyse ya da hesap silindiyse kimseye); tayfa kapağı aktif
  /// üyelere; etkinlik kapağı, günlük fotoğrafı ve albüm fotoğrafı etkinliği
  /// görebilen aktif üyelere; kanal fotoğrafı (`chat_photo`) mesajın
  /// kanalının kitlesine (mesaj silinmemişken; chat'e sorulur); birebir
  /// mesaj eki (`dm_attachment`) konuşmanın iki tarafına (mesaj
  /// silinmemişken); şikâyet kanıtı (`report_evidence`) yalnızca sahibine.
  /// Ekin linki `full_url`'dir (`application/octet-stream`); önizlemesi ve
  /// ölçüsü yoktur. 1–100 farklı kimlik; sıra korunur.
  ///
  /// `POST /v1/media/urls`
  Future<MediaUrlsList> getMediaUrls({required MediaUrlsRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/media/urls',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return MediaUrlsList.fromJson(jsonObject(response, 'getMediaUrls'));
  }
}
