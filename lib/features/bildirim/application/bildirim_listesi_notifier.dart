import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/sayfalama/sayfali_liste.dart';
import 'package:tayfam/features/bildirim/application/okunmamis_bildirim_notifier.dart';
import 'package:tayfam/features/bildirim/data/bildirim_deposu.dart';

/// Bildirimler sekmesindeki liste (`GET /v1/notifications`, sayfalı, en
/// yeni önce; ADR-0018 §3). Bütün tayfalar için tek listedir (ADR-0003).
///
/// Oturum değişince yeniden kurulur (ADR-0001 kural 8). Yalnızca
/// bellektedir (ADR-0006). Bildirim içerik taşımaz; liste de içerik
/// tutmaz (kesin kural 7).
class BildirimListesiNotifier extends SayfaliListeNotifier<Notification> {
  @override
  Future<SayfaliListe<Notification>> build() {
    ref.watch(oturumDurumuProvider);
    ref.watch(bildirimDeposuProvider);
    return ilkSayfayiOku();
  }

  @override
  Future<Sayfa<Notification>> sayfaGetir(String? sayfaToken) =>
      ref.read(bildirimDeposuProvider).sayfa(sayfaToken: sayfaToken);

  @override
  String kimlik(Notification oge) => oge.id;

  /// [bildirimId]'yi okundu işaretler. Liste ve rozet hemen güncellenir;
  /// istek başarısız olursa ikisi de sunucudan yeniden okunur. Zaten
  /// okunmuşsa ya da listede yoksa bir şey yapmaz. Hata fırlatmaz.
  Future<void> okunduIsaretle(String bildirimId) async {
    final mevcut = state.value?.ogeler;
    if (mevcut == null) return;
    final okunmamis = mevcut.any((b) => b.id == bildirimId && !b.read);
    if (!okunmamis) return;
    ogeleriDegistir(
      (ogeler) => [
        for (final b in ogeler) b.id == bildirimId ? okunmusHali(b) : b,
      ],
    );
    final rozet = ref.read(okunmamisBildirimProvider.notifier)..azalt();
    try {
      await ref.read(bildirimDeposuProvider).okunduIsaretle(bildirimId);
    } on Exception {
      if (!ref.mounted) return;
      await yenile();
      await rozet.yenile();
    }
  }

  /// Bütün bildirimleri okundu sayar (`POST /v1/notifications/read-all`).
  /// Başarıda liste ve rozet güncellenir ve `null` döner; aksi halde hata
  /// döner (ekran gösterir).
  Future<Object?> hepsiniOkunduSay() async {
    try {
      await ref.read(bildirimDeposuProvider).hepsiniOkunduSay();
    } on Exception catch (hata) {
      return hata;
    }
    if (!ref.mounted) return null;
    ogeleriDegistir((ogeler) => [for (final b in ogeler) okunmusHali(b)]);
    ref.read(okunmamisBildirimProvider.notifier).sifirla();
    return null;
  }
}

/// [bildirim]'in okunmuş hali (üretilmiş modelde `copyWith` yok).
Notification okunmusHali(Notification bildirim) => bildirim.read
    ? bildirim
    : Notification(
        id: bildirim.id,
        type: bildirim.type,
        tayfaId: bildirim.tayfaId,
        actorId: bildirim.actorId,
        targetType: bildirim.targetType,
        targetId: bildirim.targetId,
        questionId: bildirim.questionId,
        subjectUserId: bildirim.subjectUserId,
        warningReason: bildirim.warningReason,
        unreadCount: bildirim.unreadCount,
        read: true,
        createdAt: bildirim.createdAt,
      );

/// Bildirim listesi. Kullanıcıya bağlıdır, tayfaya değil; ekran kapanınca
/// bırakılır (`autoDispose`). Hata otomatik yeniden denenmez; ekran
/// "Tekrar dene" sunar, aşağı çekince yenilenir.
final bildirimListesiProvider =
    AsyncNotifierProvider.autoDispose<
      BildirimListesiNotifier,
      SayfaliListe<Notification>
    >(
      BildirimListesiNotifier.new,
      name: 'bildirimListesiProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
