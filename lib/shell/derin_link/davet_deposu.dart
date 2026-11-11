import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/invite_joins_api.dart';
import 'package:tayfam/core/api/gen/apis/invite_previews_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';

/// Davet linkinin uçları (ADR-0018 §6). Token yalnızca istek gövdesine
/// gider (sözleşme: "Gizli değerler URL'de taşınmaz"; kesin kural 9).
final class DavetDeposu {
  DavetDeposu(ApiTransport istemci)
    : _onizleme = InvitePreviewsApi(istemci),
      _katilim = InviteJoinsApi(istemci);

  final InvitePreviewsApi _onizleme;
  final InviteJoinsApi _katilim;

  /// `POST /v1/invite-previews`: tayfanın dar görünümü; linki tüketmez.
  Future<InvitePreview> onizle(String token) =>
      _onizleme.previewInvite(body: InviteTokenRequest(token: token));

  /// `POST /v1/invite-joins`: etkin ya da bekleyen üyelik.
  Future<Membership> katil(String token) =>
      _katilim.joinByInvite(body: InviteTokenRequest(token: token));
}

/// Davet uçlarının deposu.
final davetDeposuProvider = Provider<DavetDeposu>(
  (ref) => DavetDeposu(ref.watch(apiClientProvider)),
  name: 'davetDeposuProvider',
);
