// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `join-qr` olan uçlar.
final class JoinQrApi {
  const JoinQrApi(this._transport);

  final ApiTransport _transport;

  /// Organizatörün QR'ıyla etkinliğe (ve tayfasına) katılır
  ///
  /// QR ile katılım (ADR-0038 §3). Token yalnızca gövdede gider (QR
  /// linkinde fragment'tadır, URL'ye yazılmaz).
  /// - Anlık etkinlik: onay beklemeden tayfaya üye olunur ve etkinliğe
  ///   `going` (doluysa `waitlist`) yazılır.
  /// - Kalıcı tayfa: tayfanın katılım politikası geçerlidir. Açık
  ///   tayfada üye olunur ve `going` yazılır; onaylı tayfada katılım
  ///   isteği bırakılır (`pending: true`, başka bir şey yazılmaz).
  /// - Zaten etkin üye: `going` yazılır; check-in penceresi açıksa
  ///   katılım `qr` yöntemiyle doğrulanır (`attendance: attended`).
  /// - Bekleyen katılım isteği: yine `pending: true`, değişiklik yok.
  /// Bozuk, bilinmeyen ya da süresi dolmuş token; bitmiş, iptal
  /// edilmiş ya da çevrimiçi etkinlik; tayfada banlı, organizatörle iki
  /// yönden engelli, silinmiş ya da platform banlı hesap aynı cevabı
  /// alır (`invalid-join-qr`). Cevap bekleyen doğrudan davet
  /// `already-pending`. Etkinlik başına en fazla 30 QR katılımı
  /// (`join-qr-limit-reached`; hiçbir şey değiştirmeyen tekrar
  /// sayılmaz). IP başına (gateway) ve kullanıcı başına dakikada 5
  /// (core) deneme sınırı vardır (`rate-limited`).
  ///
  /// `POST /v1/join-qr`
  Future<JoinQrResult> joinEventByQr({required InviteTokenRequest body}) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/join-qr',
      body: body.toJson(),
      expect: ResponseKind.json,
      authenticated: true,
    );
    return JoinQrResult.fromJson(jsonObject(response, 'joinEventByQr'));
  }
}
