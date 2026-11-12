import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/application/islem.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';

/// Bekleyen katılım istekleri (`GET /v1/tayfas/{tayfa_id}/join-requests`,
/// eskiden yeniye, sayfalı; moderatör ve yönetici). Onay ve ret
/// (ADR-0018 §1); kimin davetiyle gelindiği istekte yazar.
///
/// Tayfaya bağlıdır: `family(tayfaId)` + `autoDispose`. Yalnızca
/// bellektedir (ADR-0006).
class KatilimIstekleriNotifier extends SayfaliListeNotifier<JoinRequest> {
  KatilimIstekleriNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<SayfaliListe<JoinRequest>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(yonetimDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<JoinRequest>> sayfaGetir(String? sayfaToken) => ref
      .read(yonetimDeposuProvider)
      .katilimIstekleri(tayfaId, sayfaToken: sayfaToken);

  @override
  String kimlik(JoinRequest oge) => oge.userId;

  /// İsteği onaylar; üyelik etkin olur.
  Future<Object?> onayla(String uyeId) => yonetimIslemi(ref, () async {
    await ref.read(yonetimDeposuProvider).istegiOnayla(tayfaId, uyeId);
    _sonuclandi(uyeId, uyeEklendi: true);
  });

  /// İsteği reddeder; kişi daha sonra tekrar isteyebilir.
  Future<Object?> reddet(String uyeId) => yonetimIslemi(ref, () async {
    await ref.read(yonetimDeposuProvider).istegiReddet(tayfaId, uyeId);
    _sonuclandi(uyeId, uyeEklendi: false);
  });

  void _sonuclandi(String uyeId, {required bool uyeEklendi}) {
    if (!ref.mounted) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final i in ogeler)
          if (i.userId != uyeId) i,
      ],
    );
    // Bekleyen sayısı (`pending_join_request_count`) tayfa görünümünde ve
    // Tayfalarım listesinde gelir; ikisi de sunucudan yeniden okunur.
    unawaited(gorunumuYenile(ref, tayfaId));
    unawaited(ref.read(tayfalarimProvider.notifier).yenile());
    if (!uyeEklendi) return;
    final uyeler = uyelerProvider((tayfaId: tayfaId, banlilar: false));
    if (ref.read(uyeler.exists)) ref.invalidate(uyeler);
  }
}

/// Bir tayfanın bekleyen katılım istekleri.
final katilimIstekleriProvider = AsyncNotifierProvider.autoDispose
    .family<KatilimIstekleriNotifier, SayfaliListe<JoinRequest>, String>(
      KatilimIstekleriNotifier.new,
      name: 'katilimIstekleriProvider',
      retry: yenidenDenemeYok,
    );
