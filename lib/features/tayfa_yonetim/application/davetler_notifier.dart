import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/tayfa_yonetim/application/islem.dart';
import 'package:tayfam/features/tayfa_yonetim/application/yetki.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';

/// Davet linkinin geçerlilik seçenekleri (sözleşme: 1 saat – 30 gün).
const List<Duration> davetSureleri = [
  Duration(days: 1),
  Duration(days: 7),
  Duration(days: 30),
];

/// Davet linkinin kullanım sayısı seçenekleri (sözleşme: 1–100).
const List<int> davetKullanimlari = [1, 10, 100];

/// Oluşturulan davetin sonucu: paylaşılacak link ya da hata. Link
/// yalnızca bu değerde ve paylaşım sayfasının belleğinde yaşar; durumda
/// tutulmaz, diske ve log'a yazılmaz (kesin kural 3, 9).
typedef DavetSonucu = ({String? link, Object? hata});

/// Tayfanın geçerli davet linkleri (`GET /v1/tayfas/{tayfa_id}/invites`,
/// yeniden eskiye, en çok 100; ADR-0018 §1). Yönetici bütün linkleri,
/// diğerleri yalnızca kendi açtıklarını görür (sunucu). Token hiçbir
/// zaman dönmez.
///
/// Tayfaya bağlıdır: `family(tayfaId)` + `autoDispose`.
class DavetlerNotifier extends AsyncNotifier<List<Invite>> {
  DavetlerNotifier(this.tayfaId);

  /// Adresteki tayfa kimliği.
  final String tayfaId;

  @override
  Future<List<Invite>> build() async {
    ref.watch(oturumDurumuProvider);
    final depo = ref.watch(yonetimDeposuProvider);
    return List.unmodifiable(await depo.davetler(tayfaId));
  }

  /// Listeyi yeniden okur. Okunamazsa eldeki liste kalır; elde liste
  /// yoksa hata gösterilir.
  Future<void> yenile() async {
    try {
      final liste = await ref.read(yonetimDeposuProvider).davetler(tayfaId);
      if (ref.mounted) state = AsyncData(List.unmodifiable(liste));
    } on Exception catch (hata, yigin) {
      if (ref.mounted && !state.hasValue) state = AsyncError(hata, yigin);
    }
  }

  /// [sure] geçerli, [kullanim] kez kullanılabilir bir link açar ve listenin
  /// başına ekler.
  Future<DavetSonucu> olustur({
    required Duration sure,
    required int kullanim,
  }) async {
    String? link;
    final hata = await yonetimIslemi(ref, () async {
      final olusan = await ref.read(yonetimDeposuProvider).davetOlustur(
        tayfaId,
        InviteCreateRequest(ttlSeconds: sure.inSeconds, maxUses: kullanim),
      );
      link = davetLinki(olusan.token);
      if (!ref.mounted) return;
      final eski = state.value ?? const <Invite>[];
      state = AsyncData(List.unmodifiable([olusan.invite, ...eski]));
    });
    return (link: hata == null ? link : null, hata: hata);
  }

  /// Linki hemen geçersiz kılar ve listeden çıkarır.
  Future<Object?> iptal(String davetId) => yonetimIslemi(ref, () async {
    await ref.read(yonetimDeposuProvider).davetIptal(tayfaId, davetId);
    if (!ref.mounted) return;
    final eski = state.value ?? const <Invite>[];
    state = AsyncData(
      List.unmodifiable([
        for (final d in eski)
          if (d.id != davetId) d,
      ]),
    );
  });
}

/// Bir tayfanın davet linkleri.
final davetlerProvider = AsyncNotifierProvider.autoDispose
    .family<DavetlerNotifier, List<Invite>, String>(
      DavetlerNotifier.new,
      name: 'davetlerProvider',
      retry: yenidenDenemeYok,
    );
