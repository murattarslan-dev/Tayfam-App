// ÜRETİLMİŞ KOD — elle düzenleme; tool/openapi_gen ile üret.

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Yol kaynağı `invite-previews` olan uçlar.
final class InvitePreviewsApi {
  const InvitePreviewsApi(this._transport);

  final ApiTransport _transport;

  /// Davet linkinin tayfasının dar görünümü ("X'e katıl?")
  ///
  /// Linki tüketmez. Token URL'de değil gövdede taşındığı için POST'tur;
  /// bir şey değiştirmez. IP başına sınır vardır.
  ///
  /// `POST /v1/invite-previews`
  Future<InvitePreview> previewInvite({
    required InviteTokenRequest body,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      pathTemplate: '/v1/invite-previews',
      body: body.toJson(),
      expect: ResponseKind.json,
    );
    return InvitePreview.fromJson(jsonObject(response, 'previewInvite'));
  }
}
